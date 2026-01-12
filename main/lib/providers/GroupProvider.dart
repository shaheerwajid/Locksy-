import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/helpers/duration_helper.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/mensajes_response.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/pages/forwardeTo.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/services/crypto.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/message_queue_service.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:CryptoChat/widgets/toast_message.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as pathPKG;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupChatProvider extends ChangeNotifier {
  final String? uid;
//  final String? toUid;
  final Grupo? groupUid;
  bool isLoadingFinished = false;
  int loadingnum = 30;
  String? filePath;
  String? fileType;
  AudioPlayer audioPlayer = AudioPlayer();
  Map<String, AudioPlayer> players = {};

  GroupChatProvider(
      {required this.uid,
      // required this.toUid,
      required this.groupUid,
      required this.socketService}) {
    init();
    initsubscription();
  }

  addNewPlayer(String path) {
    players[path] = AudioPlayer(playerId: path);
  }

  stopAllPlayers() {
    players.forEach((key, value) {
      value.pause();
    });
  }

  List<Mensaje> messajes = [];
  Stream<Mensaje> streamer = DBProvider.db.stream;
  late StreamSubscription<Mensaje> subscription;
  final SocketService socketService;
  Map<String, String> videoThumb = {};

  // Message deduplication: Track messages by unique key (fecha + de + para)
  // This prevents duplicate messages from being inserted multiple times
  final Set<String> _messageKeys = <String>{};

  /// Generate unique message key for deduplication
  String _getMessageKey(Mensaje message) {
    try {
      final mensajeData = jsonDecode(message.mensaje!);
      final fecha = mensajeData['fecha']?.toString() ?? '';
      final de = message.de ?? '';
      final para = message.para ?? '';
      return '${fecha}_${de}_$para';
    } catch (e) {
      return '';
    }
  }

  void _addMessageKey(Mensaje message) {
    final key = _getMessageKey(message);
    if (key.isNotEmpty) {
      _messageKeys.add(key);
    }
  }

  init() async {
    // CRITICAL FIX: Sync group members from server before loading messages
    // This ensures grupousuario table is populated for the message query
    // Without this, getTodosMensajes1 returns 0 messages because the query
    // requires user to be in grupousuario table (JOIN condition)
    try {
      debugPrint(
          '[GroupProvider] Syncing group members for ${groupUid!.codigo}');
      final usuarioService = UsuariosService();
      await usuarioService.getGrupoUsuario(groupUid!.codigo);
      debugPrint('[GroupProvider] ✅ Group members synced successfully');
    } catch (e) {
      debugPrint('[GroupProvider] ⚠️ Error syncing group members: $e');
      // Continue anyway - user might already be in local DB from saveGrupo()
    }

    // Load ALL local messages (batched) for full history
    messajes = await _loadAllLocalMessages();

    // Check if disappearing messages is enabled and clean up immediately after loading
    await _cleanupExpiredMessages();

    // Initialize message keys set for deduplication
    _messageKeys.clear();
    for (var msg in messajes) {
      _addMessageKey(msg);
    }

    debugPrint(
        '[GroupProvider] Loaded ${messajes.length} messages for group ${groupUid!.codigo}');

    // All local messages loaded
    isLoadingFinished = true;

    notifyListeners();
  }

  /// Start periodic timer to clean up expired messages in real-time
  void _startDisappearingMessagesCleanup() {
    _disappearingMessagesTimer?.cancel();
    // Run every 20 seconds
    _disappearingMessagesTimer =
        Timer.periodic(const Duration(seconds: 20), (timer) async {
      await _cleanupExpiredMessages();
    });
  }

  /// Check and clean up messages older than the selected duration
  Future<void> _cleanupExpiredMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDurationKey = prefs.getString('selectedDuration');

    // If disabled (null or empty), do nothing
    if (savedDurationKey == null || savedDurationKey.isEmpty) {
      return;
    }

    // Convert string setting to actual Duration
    final duration = DurationHelper.getDurationFromString(savedDurationKey);
    if (duration == null) return;

    final cutoffTime = DateTime.now().subtract(duration);
    bool listChanged = false;

    // 1. Remove from local memory list
    final int initialLength = messajes.length;
    messajes.removeWhere((msg) {
      try {
        final msgJson = jsonDecode(msg.mensaje!);
        final fechaStr = msgJson['fecha'].toString();
        DateTime msgTime;
        if (msg.createdAt != null) {
          msgTime = DateTime.parse(msg.createdAt!);
        } else {
           msgTime = parseFecha(fechaStr);
        }

        return msgTime.isBefore(cutoffTime);
      } catch (e) {
        // If date parsing fails, keep message to be safe
        return false;
      }
    });

    if (messajes.length != initialLength) {
      listChanged = true;
      debugPrint(
          '[GroupProvider] 🗑️ Cleaned up ${initialLength - messajes.length} expired messages from memory');
    }

    // 2. Trigger DB cleanup (this deletes from SQLite)
    await DBProvider.db.deleteOldRecords(await DBProvider.db.database);

    // 3. Notify UI if items were removed
    if (listChanged) {
      notifyListeners();
    }
  }

  /// Load all group messages from local DB in batches
  Future<List<Mensaje>> _loadAllLocalMessages() async {
    const batch = 500;
    int offset = 0;
    final all = <Mensaje>[];

    while (true) {
      final page = await DBProvider.db
          .getTodosMensajes2(groupUid!.codigo, uid, batch, offset);
      if (page.isEmpty) break;
      all.addAll(page);
      offset += batch;
      if (page.length < batch) break;
    }
    return all;
  }

  Timer? _updateDebounceTimer; // Timer for debouncing rapid updates
  Timer? _disappearingMessagesTimer; // Timer to clean up expired messages

  initsubscription() {
    // Start periodic check for disappearing messages
    _startDisappearingMessagesCleanup();

    subscription = streamer.listen((event) {
      // #region agent log
      final debugLogPath = r'd:\locksyy\.cursor\debug.log';
      try {
        final debugEntry = {
          'location': 'GroupProvider.dart:153',
          'message': 'Stream event received',
          'data': {
            'eventUid': event.uid,
            'groupCode': groupUid!.codigo,
            'myUid': uid,
            'eventDe': event.de,
            'eventPara': event.para,
            'messageType': jsonDecode(event.mensaje ?? '{}')['type'],
          },
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sessionId': 'debug-session',
          'hypothesisId': 'A'
        };
        File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
            mode: FileMode.append);
      } catch (_) {}
      // #endregion

      debugPrint(
          '[GroupProvider] Stream event - event.uid: ${event.uid}, groupCode: ${groupUid!.codigo}, myUid: $uid');

      final matchesFilter = event.uid == groupUid!.codigo || event.uid == uid;
      // #region agent log
      try {
        final debugEntry = {
          'location': 'GroupProvider.dart:170',
          'message': 'Stream filter check',
          'data': {
            'matchesFilter': matchesFilter,
            'eventUid': event.uid,
            'groupCode': groupUid!.codigo
          },
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sessionId': 'debug-session',
          'hypothesisId': 'A'
        };
        File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
            mode: FileMode.append);
      } catch (_) {}
      // #endregion

      if (matchesFilter) {
        // Check for duplicates before processing
        final wasInserted = insertMessageOrderedByFecha(event);

        // #region agent log
        try {
          final debugEntry = {
            'location': 'GroupProvider.dart:179',
            'message': 'Message insertion result',
            'data': {
              'wasInserted': wasInserted,
              'messageCount': messajes.length
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'sessionId': 'debug-session',
            'hypothesisId': 'B'
          };
          File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion

        // Only update UI if a new message was actually inserted
        if (wasInserted) {
          // Debounce rapid updates - batch updates every 100ms max
          _updateDebounceTimer?.cancel();
          _updateDebounceTimer = Timer(const Duration(milliseconds: 100), () {
            notifyListeners();
          });
        }
      } else {
        // #region agent log
        try {
          final debugEntry = {
            'location': 'GroupProvider.dart:195',
            'message': 'Message filtered out',
            'data': {'eventUid': event.uid, 'groupCode': groupUid!.codigo},
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'sessionId': 'debug-session',
            'hypothesisId': 'A'
          };
          File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion
      }
    });
  }

  // Function to insert a new message ordered by fecha
  // Returns true if message was inserted, false if it was a duplicate
  bool insertMessageOrderedByFecha(Mensaje newMessage) {
    // Check for duplicate before inserting
    final key = _getMessageKey(newMessage);
    if (key.isNotEmpty && _messageKeys.contains(key)) {
      debugPrint('[GroupProvider] Duplicate message detected, skipping: $key');
      return false; // Duplicate, don't insert
    }

    int indexToInsert =
        findInsertionIndex(jsonDecode(newMessage.mensaje!)['fecha']);
    messajes.insert(indexToInsert, newMessage);

    // Add to deduplication set
    if (key.isNotEmpty) {
      _messageKeys.add(key);
    }

    debugPrint('[GroupProvider] ✅ Message inserted at index $indexToInsert');
    return true;
  }

  // Function to convert the fecha string to DateTime
  DateTime parseFecha(String fecha) {
    return DateTime.parse(
        '${fecha.substring(0, 4)}-${fecha.substring(4, 6)}-${fecha.substring(6, 8)} '
        '${fecha.substring(8, 10)}:${fecha.substring(10, 12)}:${fecha.substring(12, 14)}.${fecha.substring(14, 17)}');
  }

  // Binary search to find the correct index for insertion
  int findInsertionIndex(String newMessageFecha) {
    int low = 0;
    int high = messajes.length;
    int inp = int.parse(newMessageFecha);

    while (low < high) {
      int mid = (low + high) ~/ 2;

      int tr = int.parse(jsonDecode(messajes[mid].mensaje!)['fecha']);

      if (inp > tr) {
        high = mid; // Narrow down to the lower half
      } else {
        low = mid + 1; // Narrow down to the upper half
      }
    }

    return low; // Return the index where the new message should be inserted
  }

  testsql() async {
    List<Mensaje> test =
        await DBProvider.db.getTodosMensajes2(groupUid!.codigo, uid, 60, 0);
    int j = 0;
    for (Mensaje i in test) {
      j = j + 1;
    }
    //print(test.length);
  }

  Future<bool> loadMore() async {
    // All messages already loaded; no further paging needed
    isLoadingFinished = true;
    notifyListeners();
    return false;
  }

  List<ChatMessage> _mensajeSelected = [];
  List<int> selectedItems = [];
  bool soloMios = true;
  final bool _recibido = false;
  bool esContacto = true;
  bool cargando = false;
  ChatMessage? messagetoReply;
  Mensaje? messagetoReply1;

  bool isRecording = false;
  CustomPopupMenuController controller = CustomPopupMenuController();
  FlutterSoundRecorder flutterSound = FlutterSoundRecorder();
  String? deration;
  final textController = TextEditingController();
  final focusNode = FocusNode();
  bool estaEscribiendo = false;
  bool enviado = false;
  bool showImageSave = false;

  bool incognito = false;

  updateUpload(String localurl, String fetcha, double result) {
    bool found = true;
    Mensaje? messageToUpdate = messajes.firstWhere(
        (message) => jsonDecode(message.mensaje!)["fecha"] == fetcha,
        orElse: () {
      found = false;
      return messajes[0];
    });

    if (found) {
      int index = messajes.indexOf(messageToUpdate);
      messajes[index].upload = result;
      notifyListeners();
    } else {}
  }

  CopyMessages(BuildContext context, String sender, String me) async {
    List<String> messagesToCopy = [];

    for (ChatMessage m in _mensajeSelected) {
      if (m.type == "text" && m.texto != null) {
        if (m.uid == uid) {
          messagesToCopy.add("$me:${m.texto!}");
        } else {
          messagesToCopy.add("$sender:${m.texto!}");
        }
        // Add the message text to the new list
      }
    }

    String messagetocopy = messagesToCopy.join("\n");

    if (messagetocopy != "") {
      Clipboard.setData(ClipboardData(text: messagetocopy.toString()))
          .then((_) {
        showToast(
          context,
          "Copied to your clipboard !",
          verde,
          Icons.check,
          duration: 2,
        );
      });

      selectedItems = [];
      _mensajeSelected = [];
    } else {
      selectedItems = [];
      _mensajeSelected = [];
    }
    notifyListeners();
  }

  SaveImageToGallerie(BuildContext context) async {
    List<File> imagestosave = [];
    String dir = (await getApplicationDocumentsDirectory()).path;
    for (ChatMessage m in _mensajeSelected) {
      if (m.type == "images") {
        showImageSave = true;
        notifyListeners();
        var ruta = "$dir/${m.fecha!}${m.exten!}";
        File file = File(ruta);
        if (await file.exists()) {
          await Gal.putImage(ruta);
        }

        // Add the message text to the new list
      } else if (m.type == "video") {
        showImageSave = true;
        notifyListeners();
        var ruta = "$dir/${m.fecha!}${m.exten!}";
        File file = File(ruta);
        if (await file.exists()) {
          await Gal.putVideo(ruta);
        }
      } else {
        showImageSave = false;
        notifyListeners();
      }
    }

    selectedItems = [];
    _mensajeSelected = [];

    notifyListeners();
  }

  Forwarde(BuildContext context) async {
    if (_mensajeSelected.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ForwardeTo(
                messgaes: _mensajeSelected,
                incognito: incognito,
                recibido: _recibido,
              )));
    }
  }

  Future<String?> getThumbnail(String path) async {
    String? thumpath = await VideoThumbnail.thumbnailFile(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxWidth:
          128, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
      quality: 25,
    ).onError((error, stackTrace) {
      getThumbnail(path);
      return null;
    });
    if (thumpath != null) {
      videoThumb[path] = thumpath;
      notifyListeners();
    }
    return thumpath;
  }

  Clearhistory(res) {
    if (res == 'vaciar') {
      messajes.clear();
      notifyListeners();
    } else {
      messajes.clear();
      init();
    }

    // _cargarHistorial(usuarioPara.uid);
  }

  eliminarParaTodos(BuildContext context) {
    for (var element in _mensajeSelected) {
      socketService.emit(
        'eliminar-para-todos',
        {
          'de': uid,
          'para': groupUid!.codigo!,
          'mensaje': {
            'texto': element.texto,
            'fecha': element.fecha,
            'type': element.type,
            'ext': element.exten,
          },
        },
      );
    }
  }

  eliminarMensajesChat(BuildContext context) async {
    final res = await DBProvider.db.deleteMensajesByMenseje(_mensajeSelected);
    if (res != 0) {
      showToast(
          context,
          selectedItems.length > 1
              ? '${selectedItems.length} ${AppLocalizations.of(context)!.translate('MESSAGES_DELETED')}'
              : capitalize(
                  AppLocalizations.of(context)!.translate('MESSAGE_DELETED')),
          verde,
          Icons.check);
      init();

      selectedItems.clear();
      _mensajeSelected.clear();
      notifyListeners();
    }
  }

  bool validarMensajesMios() {
    soloMios = true;
    for (var msj in _mensajeSelected) {
      if (msj.uid != uid) {
        soloMios = false;
      }
    }
    notifyListeners();
    return soloMios;
  }

  void LongSelect(int i, ChatMessage m) {
    if (!selectedItems.contains(i)) {
      selectedItems.add(i);
      _mensajeSelected.add(m);
      notifyListeners();
    }
    for (ChatMessage m in _mensajeSelected) {
      if (m.type == "images") {
        showImageSave = true;
        notifyListeners();

        // Add the message text to the new list
      } else if (m.type == "video") {
        showImageSave = true;
        notifyListeners();

        // Add the message text to the new list
      } else {
        showImageSave = false;
        notifyListeners();
        break;
      }
    }
  }

  void SelectM(int i, ChatMessage m) {
    if (selectedItems.isNotEmpty) {
      if (!selectedItems.contains(i)) {
        selectedItems.add(i);
        _mensajeSelected.add(m);
      } else {
        selectedItems.removeWhere((val) => val == i);
        _mensajeSelected.remove(m);
      }
    }
    for (ChatMessage m in _mensajeSelected) {
      if (m.type == "images") {
        showImageSave = true;
        notifyListeners();

        // Add the message text to the new list
      } else if (m.type == "video") {
        showImageSave = true;
        notifyListeners();

        // Add the message text to the new list
      } else {
        showImageSave = false;
        notifyListeners();
        break;
      }
    }
    notifyListeners();
  }

  swipeWright(Mensaje x) {
    messagetoReply1 = x;
    notifyListeners();
  }

  void SkipReply() {
    messagetoReply = null;
    messagetoReply1 = null;

    notifyListeners();
  }

  /*
    * Captura imagen de la camara
    * Envia mensaje de imagen
  */
  takePhoto(AuthService a, ChatService c) async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      List<XFile> result = [];
      result.add(pickedFile!);
      filePath = pickedFile.path;
      fileType = "img";
      notifyListeners();
      //createMessage(result: result, authService: a, c: c);
    } catch (e) {
      //print(e);
    }
  }

  /*
    * Captura video de la camara
    * Envia mensaje de video
  */
  takeVideo(AuthService a, ChatService c) async {
    try {
      ImagePicker picker = ImagePicker();
      XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      //File video = File(pickedFile!.path);
      List<XFile> result = [];
      result.add(pickedFile!);
      filePath = pickedFile.path;
      fileType = "vid";
      notifyListeners();
      // createMessage(result: result, authService: a, c: c);
    } catch (e) {
      //print(e);
    }
  }

  selectGalleryVideo(AuthService a, ChatService c) async {
    try {
      ImagePicker picker = ImagePicker();
      XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        List<XFile> result = [pickedFile];
        filePath = pickedFile.path;
        fileType = "vid";
        notifyListeners();
        // createMessage(result: result, authService: a, c: c);
      }
    } catch (e) {
      // Handle exceptions
      //print(e);
    }
  }

  /*
    * Inicia la grabacion de audio
  */
  // TO REPLACE{
  startRecording() async {
    String mifecha = deconstruirDateTime();

    var status = await Permission.microphone.request();

    if (status.isGranted) {
      String path = '';
      Directory appDocDirectory = await getApplicationDocumentsDirectory();
      path = '${appDocDirectory.path}/$mifecha';
      flutterSound.setLogLevel(Level.error);

      // await flutterSound.openAudioSession(
      //   mode: SessionMode.modeSpokenAudio,
      //   focus:
      //       AudioFocus.requestFocus, //requestFocus may be related to the issue
      //   category: SessionCategory.playAndRecord,
      // );

      await flutterSound.openRecorder();
      await flutterSound.startRecorder(
          codec: Codec.aacMP4, toFile: '$path.aac');

      await flutterSound.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );
      flutterSound.onProgress!.listen((e) {
        var date = DateTime.fromMillisecondsSinceEpoch(
            e.duration.inMilliseconds,
            isUtc: true);
        //print(e.duration);
        deration = e.duration.toString();
      });

      isRecording = flutterSound.isRecording;
      notifyListeners();
    }
  }

  /*
    * Detiene la grabacion de audio
    * Envia mensaje de audio
  */
  stopRecording(AuthService a, ChatService c, BuildContext ctx) async {
    XFile file;
    List<XFile> result = [];

    String duracion;

    var recording = await flutterSound.stopRecorder();

    var tiempo = deration;
    duracion =
        '${(tiempo.toString().split('.')[0]).split(':')[1]}:${(tiempo.toString().split('.')[0]).split(':')[2]}';
    file = strtoFile1(recording!);
    isRecording = flutterSound.isRecording;

    deration = null;
    notifyListeners();
    result.add(file);
    createMessage1(
        result: file.path, value: duracion, authService: a, ctx: ctx, c: c);
  }

  /*
    * Cancela la grabacion de audio
  */
  cancelRecording() async {
    var recording = await flutterSound.stopRecorder();

    isRecording = flutterSound.isRecording;
    notifyListeners();
  }

  /*
    * Abre la carpeta de archivos del telefono
    * Envia archivos seleccionados
  */
  searchFiles(AuthService a, ChatService c) async {
    try {
      // List<File> result = await FilePicker.getMultiFile(
      //     type: FileType.any,
      //     // allowedExtensions: types,
      //     allowCompression: true);
      FilePickerResult? fresult = await FilePicker.platform.pickFiles();
      List<XFile> result = [];

      if (fresult != null) {
        result = fresult.paths.map((path) => XFile(path!)).toList();
      }

      var exte = pathPKG.extension(result[0].path);
      if (exte == '.jpg' ||
          exte == '.png' ||
          exte == '.jpeg' ||
          exte == '.gif') {
        filePath = result[0].path;
        fileType = "img";
      } else if (exte == '.mp4' ||
          exte == '.avi' ||
          exte == '.mov' ||
          exte == '.mkv') {
        filePath = result[0].path;
        fileType = "vid";
      } else if (exte == '.pdf' ||
          exte == '.doc' ||
          exte == '.docx' ||
          exte == '.xls' ||
          exte == '.xlsx' ||
          exte == '.txt' ||
          exte == '.rtf') {
        // Handle documents
        filePath = result[0].path;
        fileType = "doc";
        notifyListeners();
      } else {
        // For other file types, create message directly
        createMessage(result: result, authService: a, c: c);
      }

      notifyListeners();

      //  createMessage(result: result, authService: a, c: c);
    } on Exception {
      //print(e);
    }
  }

  createMessage(
      {List<XFile>? result,
      String? value,
      required AuthService authService,
      required ChatService? c}) {
    if (result != null && result.isNotEmpty) {
      cargando = true;
      notifyListeners();
      String utc = DateTime.now().timeZoneName;

      authService
          .cargarArchivo1(
              para: c!.usuarioPara!.nombre,
              messagetoReply: messagetoReply,
              result: result,
              esGrupo: false,
              userPara: c.usuarioPara!,
              incognito: incognito,
              enviado: enviado,
              recibido: _recibido,
              utc: utc,
              val: value)
          .then((newMessage) {
        cargando = false;
        notifyListeners();
      });
    } else {
      cargando = false;
      notifyListeners();
    }
  }

  createMessage1(
      {String? result,
      String? value,
      BuildContext? ctx,
      required AuthService authService,
      required ChatService? c}) {
    if (result != null && result.isNotEmpty) {
      cargando = true;
      //   notifyListeners();
      String utc = DateTime.now().timeZoneName;

      authService
          .cargarArchivo2(
              para: authService.usuario!.nombre,
              messagetoReply: messagetoReply,
              result: result,
              esGrupo: true,
              grupoPara: groupUid,
              userPara: authService.usuario!,
              incognito: incognito,
              ctx: ctx,
              enviado: enviado,
              recibido: _recibido,
              utc: utc,
              val: value)
          .then((newMessage) {
        if (newMessage == null) {
          print('[GroupProvider] ⚠️ cargarArchivo2 returned null message');
          filePath = null;
          fileType = null;
          cargando = false;
          notifyListeners();
          return;
        }
        try {
          // CRITICAL: Insert message into list immediately so it shows in UI
          // This is the same pattern as ChatProvider - message needs to be in list to display
          try {
            var fecha = jsonDecode(newMessage.mensaje!)["fecha"];
            // Check if message is already in list (might have been added via stream)
            int messageIndex = findMessageIndexByFecha(fecha);
            if (messageIndex == -1) {
              // Message not in list yet - insert it to prevent blank chat
              insertMessageOrderedByFecha(newMessage);
              print('[GroupProvider] ✅ Inserted file message to list');
            } else {
              // Message already in list (from stream) - update it with the returned message
              messajes[messageIndex] = newMessage;
              print('[GroupProvider] ✅ Updated existing message in list');
            }

            // For videos and other file types, the message is now visible in the list
            // When upload completes and server ACKs, recibidoServidor will update enviado status
          } catch (insertError) {
            print(
                '[GroupProvider] ⚠️ Error inserting/updating message: $insertError');
            // Continue even if insert fails - message will come via stream
          }

          filePath = null;
          fileType = null;
          cargando = false;
          notifyListeners();
        } catch (e) {
          print('[GroupProvider] ❌ Error processing audio/video message: $e');
          filePath = null;
          fileType = null;
          cargando = false;
          notifyListeners();
        }
      }).catchError((error) {
        print('[GroupProvider] ❌ Error uploading audio/video: $error');
        filePath = null;
        fileType = null;
        cargando = false;
        notifyListeners();
      });
    } else {
      cargando = false;
      notifyListeners();
    }
  }

  /*
    * Envia mensaje de texto
  */
  Future<void> handleSubmit(String texto, Usuario usuario, Grupo grpPara,
      AuthService authService, ChatService? c, BuildContext context,
      {String type = 'text'}) async {
    String mifecha = deconstruirDateTime();
    selectedItems.clear();
    textController.clear();
    focusNode.requestFocus();
    if (filePath != null) {
      createMessage1(
          authService: authService, c: c, ctx: context, result: filePath);
      filePath = null;
      notifyListeners();
      return;
    }
    if (texto.isEmpty) return;
    //print("-----------------------groupUid!.publicKey-------------------");
    //print("----------------${groupUid!.publicKey!}----------------");

    String x = LocalCrypto().rsaEncryptMessage(texto, groupUid!.publicKey!);

    String utc = DateTime.now().timeZoneName;

    Map<String, dynamic>? msg;
    messagetoReply1 == null
        ? msg = null
        : msg = {
            'messageType': jsonDecode(messagetoReply1!.mensaje!)['type'],
            'messageContent': jsonDecode(messagetoReply1!.mensaje!)['content'],
            'parentSender':
                messagetoReply1 != null && messagetoReply1!.uid == usuario.uid!
                    ? usuario.nombre
                    : messagetoReply1!.nombreEmisor!
          };

    // DISAPPEARING MESSAGES: Get TTL in seconds if enabled
    final prefs = await SharedPreferences.getInstance();
    final selectedDuration = prefs.getString('selectedDuration');
    final int? ttl = selectedDuration != null
        ? DurationHelper.getDurationInSeconds(selectedDuration)
        : null;

    Map<String, dynamic> data;

    messagetoReply == null
        ? data = {
            'de': usuario.uid,
            'para': groupUid!.codigo!,
            'incognito': incognito,
            'forwarded': false,
            'reply': messagetoReply1 != null,
            'parentType': messagetoReply1 != null
                ? jsonDecode(messagetoReply1!.mensaje!)['type']
                : null,
            'parentContent': messagetoReply1 != null
                ? jsonDecode(messagetoReply1!.mensaje!)['content']
                : null,
            'parentSender':
                messagetoReply1 != null && messagetoReply1!.uid == usuario.uid
                    ? usuario.nombre
                    : null,
            'mensaje': {
              'type': type,
              'content': x,
              'fecha': '${mifecha}Z$utc',
            },
            'usuario': {
              'nombre': usuario.nombre,
            },
            if (ttl != null) 'ttl': ttl, // DISAPPEARING: Send TTL to backend
          }
        : data = {
            'de': usuario.uid,
            'para': groupUid!.codigo!,
            'incognito': incognito,
            'forwarded': false,
            'reply': messagetoReply1 != null,
            'parentType': messagetoReply1 != null
                ? jsonDecode(messagetoReply1!.mensaje!)['type']
                : null,
            'parentContent': messagetoReply1 != null
                ? jsonDecode(messagetoReply1!.mensaje!)['content']
                : null,
            'parentSender':
                messagetoReply1 != null && messagetoReply1!.uid == usuario.uid
                    ? usuario.nombre
                    : messagetoReply1!.nombreEmisor!,
            'mensaje': {
              'type': type,
              'content': x,
              'fecha': '${mifecha}Z$utc',
            },
            'usuario': {
              'nombre': usuario.nombre,
            },
            if (ttl != null) 'ttl': ttl, // DISAPPEARING: Send TTL to backend
          };

    //   await DBProvider.db.persistMessajeLocal(data, 'enviado', true);
    socketService.persistGMessajeLocal1(
        type, texto, mifecha, '', msg, incognito, usuario, grpPara);

    //   persistMessajeLocal(type, texto, mifecha, '', msg);

    //messajes.insert(0, xx);

    estaEscribiendo = false;

    //  var event = "mensaje-personal";
    var event = "mensaje-grupal";

    print('[GroupProvider] ========== SENDING GROUP MESSAGE ==========');
    print('[GroupProvider] Event: $event');
    print('[GroupProvider] Data keys: ${data.keys.toList()}');
    print('[GroupProvider] Message type: ${data['mensaje']['type']}');
    print(
        '[GroupProvider] Socket status: ${socketService.socket == null ? "null" : (socketService.socket!.connected ? "connected" : "disconnected")}');

    // Generate unique message ID for queue tracking
    final messageId =
        '${data['de']}_${data['para']}_${DateTime.now().millisecondsSinceEpoch}';

    // Check if socket is connected before sending
    if (socketService.socket == null || !socketService.socket!.connected) {
      print('[GroupProvider] ⚠️ Socket not connected, queueing message...');
      // Add to message queue for later retry
      try {
        final queueService = MessageQueueService();
        await queueService.enqueue(
          messageId: messageId,
          event: event,
          payload: data,
        );
        print('[GroupProvider] ✅ Message queued: $messageId');
        // Attempt to connect
        socketService.connect();
      } catch (e) {
        print('[GroupProvider] ❌ Error queueing message: $e');
      }
      return; // Exit early - message is queued
    } else {
      print(
          '[GroupProvider] ✅ Socket connected, sending message immediately...');
      final emitResult = socketService.emitAck(event, data);
      emitResult.then((ack) {
        if (ack != null && ack == "RECIBIDO_SERVIDOR") {
          print('[GroupProvider] ✅ Message acknowledged: $ack');
          recibidoServidor(ack, data, texto);
        } else {
          print(
              '[GroupProvider] ❌ Message failed - ACK was null or invalid: $ack');
          // Message failed - keep enviado as false (shows ! mark)
          // Could add to retry queue here if needed
        }
      }).catchError((error) {
        print('[GroupProvider] ❌ Error sending message: $error');
        // Message failed to send - keep enviado as false (shows ! mark)
      });
    }
    print('[GroupProvider] ===========================================');

    messagetoReply1 = null;
    notifyListeners();
  }

  recibidoServidor(ack, data, decrypted) async {
    print('[GroupProvider] ========== RECIBIDO SERVIDOR ==========');
    print('[GroupProvider] ACK received: $ack');
    print('[GroupProvider] ACK type: ${ack.runtimeType}');

    if (ack == "RECIBIDO_SERVIDOR") {
      print('[GroupProvider] ✅ Server acknowledged message');
      data["mensaje"]["content"] = decrypted;
      print('[GroupProvider] Updating message status in database...');
      await DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
      String fecha = data["mensaje"]["fecha"].split('Z')[0];
      print('[GroupProvider] Updating message by fecha: $fecha');
      updateMessageByFechaBinary(fecha);
      notifyListeners();
      print('[GroupProvider] ✅ Message sending complete');
    } else {
      print('[GroupProvider] ⚠️ Unexpected ACK value: $ack');
    }
    print('[GroupProvider] =====================================');
  }

  /// Retry sending a failed group message
  Future<void> retryFailedMessage(String fecha) async {
    try {
      // Find the message in the list
      int index = findMessageIndexByFecha(fecha);
      if (index == -1) {
        print('[GroupProvider] Message not found for retry: $fecha');
        return;
      }

      final message = messajes[index];
      if (message.enviado == 1) {
        print('[GroupProvider] Message already sent, no need to retry');
        return;
      }

      // Reconstruct message data from stored message
      final mensajeData = jsonDecode(message.mensaje!);
      final data = {
        'de': message.de,
        'para': message.para,
        'incognito': message.incognito == 1,
        'forwarded': message.forwarded,
        'reply': message.isReply,
        'parentType': message.parentType,
        'parentContent': message.parentContent,
        'parentSender': message.parentSender,
        'mensaje': {
          'type': mensajeData['type'],
          'content': mensajeData['content'],
          'fecha': mensajeData['fecha'],
        },
        'usuario': {
          'nombre': message.nombreEmisor,
        },
      };

      // Try to send again
      const event = "mensaje-grupal";
      final emitResult = socketService.emitAck(event, data);

      emitResult.then((ack) {
        if (ack != null && ack == "RECIBIDO_SERVIDOR") {
          print('[GroupProvider] ✅ Retry successful');
          recibidoServidor(ack, data, mensajeData['content']);
        } else {
          print(
              '[GroupProvider] ❌ Retry failed - ACK was null or invalid: $ack');
        }
      }).catchError((error) {
        print('[GroupProvider] ❌ Error retrying message: $error');
      });
    } catch (e) {
      print('[GroupProvider] Error in retryFailedMessage: $e');
    }
    notifyListeners();
  }

  // Function to update a message using binary search
  void updateMessageByFechaBinary(String fecha) {
    int index = findMessageIndexByFecha(fecha);
    //print("============[updateMessageByFechaBinary :: ${index}]===========");

    if (index != -1) {
      //print("================Urgent ++++++++++++++ NotFound ============");
      messajes[index].enviado = 1; //Update the message
    }
    notifyListeners();
  }

  int findMessageIndexByFecha(String fecha) {
    int low = 0;
    int high = messajes.length - 1;
    //  DateTime targetFecha = parseFecha(fecha).toLocal();

    int intTargetFecha = int.parse(fecha);

    while (low <= high) {
      int mid = (low + high) ~/ 2;

      // Safely decode the JSON and extract the 'fecha'
      var decodedMessage = jsonDecode(messajes[mid].mensaje!);
      String? midFechaString = decodedMessage['fecha'];

      int intFecha = int.parse(midFechaString!);

      // DateTime midFecha = parseFecha(midFechaString).toLocal();

      // Compare the midFecha with the targetFecha
      if (intFecha < intTargetFecha) {
        high = mid - 1; // Move right, to the higher half
      } else if (intFecha > intTargetFecha) {
        low = mid + 1; // Move left, to the lower half
      } else {
        return mid; // Found the exact match
      }
    }

    //print("===================// Not found================================");

    return -1; // Not found
  }

  onchangeTextfield(texto) {
    if (texto.trim().isNotEmpty) {
      estaEscribiendo = true;
    } else {
      estaEscribiendo = false;
    }
    notifyListeners();
  }

  onTape(Usuario usuario, Grupo grupoPara, BuildContext context,
      AuthService authService, ChatService? c) {
    estaEscribiendo
        ? handleSubmit(
            textController.text.trim(),
            usuario,
            grupoPara,
            authService,
            c,
            context,
          )
        : null;
  }

  @override
  void dispose() {
    // Cancel timers/subscriptions
    _updateDebounceTimer?.cancel();
    try {
      subscription.cancel();
    } catch (_) {}

    // Stop and dispose audio players
    try {
      stopAllPlayers();
      players.forEach((_, player) {
        player.stop();
        player.dispose();
      });
      players.clear();
      audioPlayer.stop();
      audioPlayer.dispose();
    } catch (_) {}

    // Reset state so next init starts clean
    messajes.clear();
    _messageKeys.clear();
    selectedItems.clear();
    _mensajeSelected.clear();
    loadingnum = 0;
    isLoadingFinished = false;
    filePath = null;
    fileType = null;
    showImageSave = false;
    messagetoReply = null;
    messagetoReply1 = null;

    // Dispose controllers
    controller.dispose();
    textController.dispose();

    super.dispose();
  }
}
