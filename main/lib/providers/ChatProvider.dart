import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:CryptoChat/services/crypto.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/message_queue_service.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:CryptoChat/widgets/toast_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:date_format/date_format.dart';
import 'package:file_picker/file_picker.dart';
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

// Debug logging helper - logs to both file (if accessible) and print for release APK
void _debugLog(String location, String message, Map<String, dynamic> data,
    String hypothesisId) {
  try {
    final logEntry = {
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}_$hypothesisId',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'data': data,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': hypothesisId,
    };
    final logJson = jsonEncode(logEntry);

    // Always print for release APK (visible via adb logcat)
    print('[DEBUG-LOG] $logJson');

    // Try to write to file (works on dev machine, may fail on device)
    try {
      final logFile = File(r'd:\locksyy\.cursor\debug.log');
      logFile.writeAsStringSync('$logJson\n', mode: FileMode.append);
    } catch (e) {
      // File path not accessible (e.g., on device) - that's okay, print was successful
    }
  } catch (e) {
    // Silently fail - don't break the app
  }
}

class ChatProvider extends ChangeNotifier {
  final String? uid;
  final String? toUid;
  final Grupo? groupUid;
  final ChatService chatService;
  bool isLoadingFinished = false;
  int loadingnum = 30;
  bool? isOnline;
  bool isTyping = false;
  String? filePath;
  String? fileType;
  AudioPlayer audioPlayer = AudioPlayer();
  Map<String, AudioPlayer> players = {};
  bool _hasSyncedServerHistory = false;
  int _msgsVersion = 0;
  int get msgsVersion => _msgsVersion;
  int _selectionVersion = 0;
  int get selectionVersion => _selectionVersion;

  ChatProvider(
      {required this.uid,
      required this.toUid,
      this.isOnline = false,
      required this.groupUid,
      required this.socketService,
      required this.chatService}) {
    // Initialize async operations without blocking constructor
    // This allows UI to render immediately with skeleton loader
    _initializeAsync();
    initsubscription();
    getIncognito();
  }

  /// Initialize chat data asynchronously
  /// This prevents blocking the UI thread during message loading
  Future<void> _initializeAsync() async {
    try {
      await init();
      await _syncServerHistory();
    } catch (e) {
      print('[ChatProvider] Error initializing chat: $e');
      // Ensure UI updates even on error
      notifyListeners();
    }
  }

  Future<void> _syncServerHistory() async {
    if (_hasSyncedServerHistory) return;
    if (groupUid != null || toUid == null) return;

    _hasSyncedServerHistory = true;

    // Skip full fetch when disappearing messages are enabled
    if (await _isDisappearingEnabled()) {
      print(
          '[ChatProvider] Disappearing messages enabled; skipping server history fetch');
      return;
    }

    try {
      int insertedTotal = 0;
      String? after; // paginate older messages using createdAt
      const pageLimit = 500; // fetch big pages to reduce calls

      while (true) {
        final page =
            await chatService.getChat(toUid!, limit: pageLimit, after: after);
        if (page.isEmpty) break;

        // Determine oldest createdAt in this page (messages are oldest->newest)
        final oldest = page.first;
        final oldestCreatedAt = oldest['createdAt']?.toString();

        int inserted = 0;
        for (final payload in page) {
          try {
            final dedupKey = _getMessageKeyFromPayload(payload);
            if (dedupKey.isNotEmpty && _messageKeys.contains(dedupKey)) {
              continue;
            }

            await socketService.importHistoricalMessage(payload,
                isGroup: payload['grupo'] != null);
            if (dedupKey.isNotEmpty) {
              _messageKeys.add(dedupKey);
            }
            inserted++;
          } catch (e) {
            print('[ChatProvider] Error importing message from history: $e');
          }
        }

        insertedTotal += inserted;
        if (inserted < pageLimit || oldestCreatedAt == null) {
          // no more pages
          break;
        }
        // paginate older than oldest
        after = oldestCreatedAt;
      }

      if (insertedTotal > 0) {
        print(
            '[ChatProvider] Synced $insertedTotal messages from server history');
      }
    } catch (e, stackTrace) {
      print('[ChatProvider] Error syncing server history: $e');
      print(stackTrace);
    }
  }

  Future<bool> _isDisappearingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDuration = prefs.getString('selectedDuration');
    return savedDuration != null && savedDuration.isNotEmpty;
  }

  String _getMessageKeyFromPayload(Map<String, dynamic> payload) {
    try {
      final mensajeData = payload['mensaje'];
      String fecha;
      if (mensajeData is Map && mensajeData['fecha'] != null) {
        fecha = mensajeData['fecha'].toString();
      } else if (payload['createdAt'] != null) {
        fecha = payload['createdAt'].toString().split('Z').first;
      } else if (payload['updatedAt'] != null) {
        fecha = payload['updatedAt'].toString().split('Z').first;
      } else {
        fecha = '';
      }
      final de = payload['de']?.toString() ?? '';
      final para = payload['para']?.toString() ?? '';
      return '${fecha}_${de}_$para';
    } catch (_) {
      return '';
    }
  }

  Random random = Random();
  addNewPlayer(String path) {
    players[path] = AudioPlayer(playerId: path);
  }

  stopAllPlayers() {
    players.forEach((key, value) {
      value.pause();
    });
  }

  late int randomNumber;
  List<Mensaje> messajes = [];
  Stream<Mensaje> streamer = DBProvider.db.stream;

  // Memory: allow effectively full history (no aggressive trimming)
  static const int _maxMessagesInMemory = 100000;

  late StreamSubscription<Mensaje> subscription;
  late StreamSubscription<Map<String, dynamic>> connectionsubscription;

  late StreamSubscription<Map<String, dynamic>> typingsubscription;
  StreamSubscription? _readReceiptSubscription;
  Timer? _disappearingMessagesTimer;

  final SocketService socketService;

  Map<String, String> videoThumb = {};

  // Message deduplication: Track messages by unique key (fecha + de + para)
  // This prevents duplicate messages from being inserted multiple times
  final Set<String> _messageKeys = <String>{};

  /// Generate unique message key for deduplication
  /// Format: "fecha_de_para" where fecha is the numeric timestamp
  String _getMessageKey(Mensaje message) {
    try {
      final mensajeData = jsonDecode(message.mensaje!);
      final fecha = mensajeData['fecha']?.toString() ?? '';
      final de = message.de ?? '';
      final para = message.para ?? '';
      return '${fecha}_${de}_$para';
    } catch (e) {
      // Fallback: use createdAt if fecha parsing fails
      return '${message.createdAt}_${message.de}_${message.para}';
    }
  }

  /// Check if message already exists in the list
  bool _messageExists(Mensaje message) {
    final key = _getMessageKey(message);
    return _messageKeys.contains(key);
  }

  /// Add message key to tracking set
  void _addMessageKey(Mensaje message) {
    final key = _getMessageKey(message);
    _messageKeys.add(key);
  }

  /// Remove message key from tracking set (for cleanup)
  void _removeMessageKey(Mensaje message) {
    final key = _getMessageKey(message);
    _messageKeys.remove(key);
  }

  /// Initialize chat: Load messages asynchronously
  /// This method runs in background to prevent UI blocking
  Future<void> init() async {
    try {
      // Load ALL local messages (batched) to show full history
      messajes = await _loadAllLocalMessages();

      // Initialize message keys set for deduplication
      _messageKeys.clear();
      for (var msg in messajes) {
        _addMessageKey(msg);
      }

      // All local messages loaded
      isLoadingFinished = true;
      _msgsVersion++;

      // Notify listeners after loading completes
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] Error in init(): $e');
      // On error, set empty list and mark as finished to show error state
      messajes = [];
      isLoadingFinished = true;
      notifyListeners();
      rethrow; // Re-throw to allow error handling in _initializeAsync
    }
  }

  /// Load all messages from local DB in batches
  Future<List<Mensaje>> _loadAllLocalMessages() async {
    const batch = 500;
    int offset = 0;
    final all = <Mensaje>[];

    while (true) {
      final page =
          await DBProvider.db.getTodosMensajes2(toUid, uid, batch, offset);
      if (page.isEmpty) break;
      all.addAll(page);
      offset += batch;
      if (page.length < batch) break;
    }
    return all;
  }

  Future<void> _ensureRecorderReady() async {
    if (_isRecorderReady) {
      return;
    }
    try {
      flutterSound.setLogLevel(Level.error);
      await flutterSound.openRecorder();
      _isRecorderReady = true;
    } catch (e, stackTrace) {
      print('[ChatProvider] Error initializing recorder: $e');
      print('[ChatProvider] Recorder stack: $stackTrace');
      rethrow;
    }
  }

  void _cleanupRecorderProgress() {
    _recorderProgressSubscription?.cancel();
    _recorderProgressSubscription = null;
  }

  String _formatRecordingDuration(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '00:00';
    }
    final safe = raw.split('.').first;
    final parts = safe.split(':');
    if (parts.length >= 3) {
      return '${parts[1]}:${parts[2]}';
    }
    return safe;
  }

  // Function to insert a new message ordered by fecha
  // Returns true if message was inserted, false if it was a duplicate
  bool insertMessageOrderedByFecha(Mensaje newMessage) {
    // Check for duplicates before inserting
    if (_messageExists(newMessage)) {
      print(
          '[ChatProvider] Duplicate message detected and skipped: ${_getMessageKey(newMessage)}');
      return false;
    }

    DateTime newMessageFecha =
        parseFecha(jsonDecode(newMessage.mensaje!)['fecha']);

    int indexToInsert = findInsertionIndex(newMessageFecha);
    messajes.insert(indexToInsert, newMessage);

    // Track the message key to prevent future duplicates
    _addMessageKey(newMessage);

    // Trim old messages if list exceeds limit (keep most recent)
    _trimOldMessages();

    _msgsVersion++;
    return true;
  }

  void _trimOldMessages() {
    // Trimming disabled to allow full chat history to remain loaded
  }

  /// Clean up old message keys to prevent set from growing indefinitely
  /// Should be called periodically (e.g., when list is trimmed)
  void _cleanupOldMessageKeys() {
    if (_messageKeys.length <= _maxMessagesInMemory * 2) {
      return; // Keys set is reasonable size
    }

    // If keys set is too large, rebuild it from current messages
    final currentKeys = <String>{};
    for (var msg in messajes) {
      currentKeys.add(_getMessageKey(msg));
    }
    _messageKeys.clear();
    _messageKeys.addAll(currentKeys);

    debugPrint(
        '[ChatProvider] Cleaned up message keys: reduced from ${_messageKeys.length + currentKeys.length - _messageKeys.length} to ${_messageKeys.length}');
  }

  // Function to convert the fecha string to DateTime
  DateTime parseFecha(String fecha) {
    return DateTime.parse(
        '${fecha.substring(0, 4)}-${fecha.substring(4, 6)}-${fecha.substring(6, 8)} '
        '${fecha.substring(8, 10)}:${fecha.substring(10, 12)}:${fecha.substring(12, 14)}.${fecha.substring(14, 17)}');
  }

// Binary search to find the correct index for insertion
  int findInsertionIndex(DateTime newMessageFecha) {
    int low = 0;
    int high = messajes.length;

    while (low < high) {
      int mid = (low + high) ~/ 2;

      DateTime midFecha =
          parseFecha(jsonDecode(messajes[mid].mensaje!)['fecha']);

      if (newMessageFecha.isAfter(midFecha)) {
        high = mid; // Narrow down to the lower half
      } else {
        low = mid + 1; // Narrow down to the upper half
      }
    }

    return low; // Return the index where the new message should be inserted
  }

  Timer? _updateDebounceTimer; // Timer for debouncing rapid updates

  initsubscription() {
    subscription = streamer.listen((event) {
      //print(event);
      //print("here we gooooooooooooooooooooooooo ${streamer.hashCode}");
      if (event.uid == toUid || event.uid == uid) {
        // Check for duplicates before processing
        // Only insert if message doesn't already exist
        final wasInserted = insertMessageOrderedByFecha(event);

        // Only update UI if a new message was actually inserted
        if (wasInserted) {
          // Debounce rapid updates - batch updates every 250ms for better performance
          _updateDebounceTimer?.cancel();
          _updateDebounceTimer = Timer(const Duration(milliseconds: 250), () {
            notifyListeners();
          });
        }
      }
    });

    Stream<Map<String, dynamic>> Connectionstreamer =
        socketService.connectionstatusstream;
    Stream<Map<String, dynamic>> Typingstreamer = socketService.typingstream;

    connectionsubscription = Connectionstreamer.listen((event) {
      if (event['user'] == toUid) {
        //print("--------event from chat ----------");
        //print(event);
        isOnline = event['connected'];
        notifyListeners();
      }
    });
    typingsubscription = Typingstreamer.listen((event) {
      //print("======================:${event['user']}========================");

      if (event['user'] == toUid) {
        //print("--------event from chat ----------");
        isTyping = event['typing'];
        notifyListeners();

        // Auto-hide typing indicator after 3 seconds
        if (isTyping) {
          Future.delayed(const Duration(seconds: 3), () {
            if (isTyping) {
              isTyping = false;
              notifyListeners();
            }
          });
        }
      } else if (event['msgDeleted']) {
        init();
      }
    });

    // Listen for read receipts (recibido-cliente) to update message read status in real-time
    _setupReadReceiptListener();

    // Start periodic check for disappearing messages
    _startDisappearingMessagesCleanup();
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
    // We iterate backwards or use removeWhere to safely remove items
    final int initialLength = messajes.length;
    messajes.removeWhere((msg) {
      try {
        final msgJson = jsonDecode(msg.mensaje!);
        final fechaStr = msgJson['fecha'].toString();
        // Parse fecha (stripping timezone parts if needed)
        // Format example: 20241022102030123
        // Simple parse assuming standard format
        // For robustness, reuse existing parsing logic or use createdAt if available
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
      print(
          '[ChatProvider] 🗑️ Cleaned up ${initialLength - messajes.length} expired messages from memory');
    }

    // 2. Trigger DB cleanup (this deletes from SQLite)
    // DBProvider.db.deleteOldRecords() handles the DB side using the same pref
    await DBProvider.db.deleteOldRecords(await DBProvider.db.database);

    // 3. Notify UI if items were removed
    if (listChanged) {
      _msgsVersion++;
      notifyListeners();
    }
  }

  /// Set up socket listener for read receipts
  void _setupReadReceiptListener() {
    // Set up listener when socket is available
    void addListener() {
      if (socketService.socket != null && socketService.socket!.connected) {
        // Remove existing listener to avoid duplicates
        socketService.socket!.off('recibido-cliente');
        socketService.socket!.on('recibido-cliente', (payload) {
          _handleReadReceipt(payload);
        });
        print('[ChatProvider] ✅ Read receipt listener added');
      }
    }

    // Try to add listener immediately if socket is already connected
    addListener();

    // Also listen for socket connection to add listener when it connects
    socketService.connectionstatusstream.listen((event) {
      if (event['status'] == 'online') {
        addListener();
      }
    });
  }

  setOnline(bool online) {
    isOnline = online;
    notifyListeners();
  }

  getIncognito() async {
    var res1 = await DBProvider.db.esContacto(toUid);
    incognito = res1 == 1 ? true : false;
  }

  testsql() async {
    //print("sending query");

    List<Mensaje> test =
        await DBProvider.db.getTodosMensajes2(toUid, uid, 60, 0);
    int j = 0;
    for (Mensaje i in test) {
      j = j + 1;
      //print("message number: ${j} content : ${i.mensaje}");
    }
    //print(test.length);
  }

  Future<bool> loadMore() async {
    //print("OnLoadMore");

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
  final FlutterSoundRecorder flutterSound = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  StreamSubscription<RecordingDisposition>? _recorderProgressSubscription;
  String? deration;
  final textController = TextEditingController();
  final focusNode = FocusNode();
  bool estaEscribiendo = false;
  bool enviado = false;
  bool showImageSave = false;

  bool incognito = false;

  Timer? _typingTimer; // Timer for debouncing typing indicator

  updateUpload(String localurl, String fetcha, double result) {
    bool found = true;
    Mensaje? messageToUpdate = messajes.firstWhere(
        (message) => jsonDecode(message.mensaje!)["fecha"] == fetcha,
        orElse: () {
      found = false;
      return messajes[0];
    });

    if (found) {
      //print("hello");
      //print("results : $result");
      int index = messajes.indexOf(messageToUpdate);
      messajes[index].upload = result;
      _msgsVersion++;
      notifyListeners();
    } else {
      //print("Message with ID not found.");
    }
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
      _selectionVersion++;
    } else {
      selectedItems = [];
      _mensajeSelected = [];
      _selectionVersion++;
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
    _selectionVersion++;
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
    try {
      // CRITICAL: Check if file exists before generating thumbnail
      if (!File(path).existsSync()) {
        print(
            '[ChatProvider] ⚠️ Video file does not exist for thumbnail: $path');
        return null;
      }

      String? thumpath = await VideoThumbnail.thumbnailFile(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth:
            128, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
        quality: 25,
      ).onError((error, stackTrace) {
        print('[ChatProvider] ⚠️ Error generating video thumbnail: $error');
        return null;
      });

      if (thumpath != null && thumpath.isNotEmpty) {
        videoThumb[path] = thumpath;
        notifyListeners();
        return thumpath;
      }
      return null;
    } catch (e) {
      print('[ChatProvider] ⚠️ Exception generating video thumbnail: $e');
      return null;
    }
  }

  Clearhistory(res) {
    if (res == 'vaciar') {
      messajes.clear();
      _messageKeys.clear(); // Clear deduplication tracking
      _msgsVersion++;
      notifyListeners();
    } else {
      messajes.clear();
      _messageKeys.clear(); // Clear deduplication tracking
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
          'para': toUid,
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

  deleteMensajesV2(BuildContext context) {}

  // deleteMSGWithMSGdeleted

  deleteMensajes(BuildContext context) async {
    final res = await DBProvider.db.deleteMSGWithMSGdeleted(_mensajeSelected);
    // //print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------eliminarMensajesChat ");
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
      _selectionVersion++;
      notifyListeners();
    }
  }

  eliminarMensajesChat(BuildContext context) async {
    final res = await DBProvider.db.deleteMensajesByMenseje(_mensajeSelected);
    //print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------eliminarMensajesChat ");
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
      _selectionVersion++;
      notifyListeners();
    }
  }

  bool validarMensajesMios() {
    soloMios = true;
    for (var msj in _mensajeSelected) {
      if (msj.uid != uid || msj.deleted) {
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
      _selectionVersion++;
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
        _selectionVersion++;
      } else {
        selectedItems.removeWhere((val) => val == i);
        _mensajeSelected.remove(m);
        _selectionVersion++;
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
    //print('-----------onLeftSwipe mmmmmmmmm-----------------');
  }

  void SkipReply() {
    messagetoReply = null;
    messagetoReply1 = null;

    //print("shiiiiiiiiiit");
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

  /*
    * Inicia la grabacion de audio
  */
  // TO REPLACE{
  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('[ChatProvider] Microphone permission denied');
      return;
    }

    final String mifecha = deconstruirDateTime();
    final Directory appDocDirectory = await getApplicationDocumentsDirectory();
    final String path = '${appDocDirectory.path}/$mifecha';
    deration = null;

    try {
      await _ensureRecorderReady();
      await flutterSound.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );

      _cleanupRecorderProgress();
      _recorderProgressSubscription = flutterSound.onProgress?.listen((event) {
        deration = event.duration.toString();
      });

      await flutterSound.startRecorder(
        codec: Codec.aacMP4,
        toFile: '$path.aac',
      );
      isRecording = true;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[ChatProvider] Error starting recorder: $e');
      debugPrint('[ChatProvider] Stack: $stackTrace');
      _cleanupRecorderProgress();
      isRecording = false;
      notifyListeners();
    }
  }

  /*
    * Detiene la grabacion de audio
    * Envia mensaje de audio
  */
  Future<void> stopRecording(AuthService a, ChatService c) async {
    if (!_isRecorderReady || !flutterSound.isRecording) {
      return;
    }
    try {
      final recording = await flutterSound.stopRecorder();
      _cleanupRecorderProgress();
      isRecording = flutterSound.isRecording;

      if (recording == null) {
        debugPrint('[ChatProvider] stopRecorder returned null path');
        deration = null;
        notifyListeners();
        return;
      }

      final file = strtoFile1(recording);
      final durationLabel = _formatRecordingDuration(deration);
      deration = null;
      notifyListeners();

      createMessage(result: [file], value: durationLabel, authService: a, c: c);
    } catch (e, stackTrace) {
      debugPrint('[ChatProvider] Error stopping recorder: $e');
      debugPrint('[ChatProvider] Stack: $stackTrace');
      deration = null;
      _cleanupRecorderProgress();
      isRecording = false;
      notifyListeners();
    }
  }

  /*
    * Cancela la grabacion de audio
  */
  Future<void> cancelRecording() async {
    if (!_isRecorderReady || !flutterSound.isRecording) {
      deration = null;
      return;
    }

    try {
      await flutterSound.stopRecorder();
    } catch (e) {
      debugPrint('[ChatProvider] Error cancelling recorder: $e');
    } finally {
      _cleanupRecorderProgress();
      isRecording = false;
      deration = null;
      notifyListeners();
    }
  }
  // cancelRecording() async {
  //   var recording = await flutterSound.stopRecorder();
  //   await flutterSound.closeRecorder();
  //   isRecording = flutterSound.isRecording;
  //   notifyListeners();
  // }

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
      } else {
        createMessage(result: result, authService: a, c: c);
      }

      notifyListeners();

      //  createMessage(result: result, authService: a, c: c);
    } on Exception {}
  }

  selectAudio(AuthService a, ChatService c) async {
    try {
      // Using FilePicker to select audio files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null) {
        List<XFile> selectedFiles =
            result.paths.map((path) => XFile(path!)).toList();
        filePath = selectedFiles[0].path;
        fileType = "audio";
        notifyListeners();
        // createMessage(result: selectedFiles, authService: a, c: c);
      }
    } catch (e) {
      // Handle exceptions
      //print(e);
    }
  }

  selectGalleryImage(AuthService a, ChatService c) async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (pickedFile != null) {
        List<XFile> result = [pickedFile];
        filePath = pickedFile.path;
        fileType = "img";
        notifyListeners();
        // createMessage(result: result, authService: a, c: c);
      }
    } catch (e) {
      // Handle exceptions
      //print(e);
    }
  }

  selectDocument(AuthService a, ChatService c) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx'
        ], // You can add more extensions
      );
      if (result != null) {
        List<XFile> selectedFiles =
            result.paths.map((path) => XFile(path!)).toList();
        filePath = selectedFiles[0].path;
        fileType = "doc";
        notifyListeners();
        // createMessage(result: selectedFiles, authService: a, c: c);
      }
    } catch (e) {
      // Handle exceptions
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

      // #region agent log
      _debugLog(
          'ChatProvider.dart:1072',
          'Starting cargarArchivo1 for video',
          {
            'resultLength': result?.length,
            'messageType': value,
          },
          'A');
      // #endregion
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
        // #region agent log
        _debugLog(
            'ChatProvider.dart:1083',
            'cargarArchivo1 succeeded',
            {
              'hasNewMessage': newMessage != null,
              'messageCount': messajes.length,
            },
            'A');
        // #endregion
        if (newMessage == null) {
          print('[ChatProvider] ⚠️ cargarArchivo1 returned null message');
          cargando = false;
          notifyListeners();
          return;
        }
        try {
          var fecha = jsonDecode(newMessage.mensaje!)["fecha"];
          // #region agent log
          final debugLogPath = r'd:\locksyy\.cursor\debug.log';
          try {
            final debugEntry = {
              'location': 'ChatProvider.dart:1148',
              'message': 'Processing video message after upload',
              'data': {
                'fecha': fecha,
                'messageCount': messajes.length,
                'hasNewMessage': newMessage != null,
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'sessionId': 'debug-session',
              'hypothesisId': 'D'
            };
            File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
                mode: FileMode.append);
          } catch (_) {}
          // #endregion

          // CRITICAL: Ensure message exists in list before updating
          // If not found, it will be added via stream and updated later
          // This prevents chat from going blank if message isn't in list yet
          int messageIndex = findMessageIndexByFecha(fecha);
          // #region agent log
          try {
            final debugEntry = {
              'location': 'ChatProvider.dart:1165',
              'message': 'Message index check',
              'data': {'messageIndex': messageIndex, 'fecha': fecha},
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'sessionId': 'debug-session',
              'hypothesisId': 'D'
            };
            File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
                mode: FileMode.append);
          } catch (_) {}
          // #endregion

          if (messageIndex != -1) {
            updateMessageByFechaBinary(fecha);
            // #region agent log
            try {
              final debugEntry = {
                'location': 'ChatProvider.dart:1176',
                'message': 'Updated existing video message',
                'data': {
                  'messageIndex': messageIndex,
                  'finalMessageCount': messajes.length
                },
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'sessionId': 'debug-session',
                'hypothesisId': 'D'
              };
              File(debugLogPath).writeAsStringSync(
                  '${jsonEncode(debugEntry)}\n',
                  mode: FileMode.append);
            } catch (_) {}
            // #endregion
          } else {
            // Message not in list yet - it will come via stream and be updated then
            print(
                '[ChatProvider] Message with fecha $fecha not in list yet, will update when stream delivers it');
            // CRITICAL: Insert message to list if it's missing to prevent blank chat
            // The message should already be in DB from _persistMessajeLocal
            try {
              insertMessageOrderedByFecha(newMessage);
              print(
                  '[ChatProvider] ✅ Inserted video message to list to prevent blank chat');
              // #region agent log
              try {
                final debugEntry = {
                  'location': 'ChatProvider.dart:1192',
                  'message': 'Inserted video message to list',
                  'data': {'finalMessageCount': messajes.length},
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'sessionId': 'debug-session',
                  'hypothesisId': 'D'
                };
                File(debugLogPath).writeAsStringSync(
                    '${jsonEncode(debugEntry)}\n',
                    mode: FileMode.append);
              } catch (_) {}
              // #endregion
            } catch (insertError) {
              print('[ChatProvider] ⚠️ Error inserting message: $insertError');
              // #region agent log
              try {
                final debugEntry = {
                  'location': 'ChatProvider.dart:1201',
                  'message': 'Error inserting video message',
                  'data': {'error': insertError.toString()},
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'sessionId': 'debug-session',
                  'hypothesisId': 'D'
                };
                File(debugLogPath).writeAsStringSync(
                    '${jsonEncode(debugEntry)}\n',
                    mode: FileMode.append);
              } catch (_) {}
              // #endregion
            }
          }
          cargando = false;
          notifyListeners();
          // #region agent log
          _debugLog(
              'ChatProvider.dart:1095',
              'Video message updated successfully',
              {
                'fecha': fecha,
                'finalMessageCount': messajes.length,
                'wasInList': messageIndex != -1,
              },
              'A');
          // #endregion
        } catch (e) {
          print('[ChatProvider] ❌ Error processing video message: $e');
          // #region agent log
          _debugLog(
              'ChatProvider.dart:1100',
              'Error processing video message',
              {
                'error': e.toString(),
                'messageCount': messajes.length,
              },
              'A');
          // #endregion
          cargando = false;
          notifyListeners();
        }
      }).catchError((error) {
        print('[ChatProvider] ❌ Error uploading video: $error');
        // #region agent log
        _debugLog(
            'ChatProvider.dart:1108',
            'cargarArchivo1 failed',
            {
              'error': error.toString(),
              'messageCount': messajes.length,
            },
            'A');
        // #endregion
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

      // #region agent log
      _debugLog(
          'ChatProvider.dart:1111',
          'Starting cargarArchivo2 for video',
          {
            'resultLength': result?.length,
            'messageType': value,
          },
          'A');
      // #endregion
      authService
          .cargarArchivo2(
              para: c!.usuarioPara!.nombre,
              messagetoReply: messagetoReply,
              result: result,
              esGrupo: false,
              userPara: c.usuarioPara!,
              incognito: incognito,
              ctx: ctx,
              enviado: enviado,
              recibido: _recibido,
              utc: utc,
              val: value)
          .then((newMessage) {
        // #region agent log
        _debugLog(
            'ChatProvider.dart:1123',
            'cargarArchivo2 succeeded',
            {
              'hasNewMessage': newMessage != null,
              'isIncognito': incognito,
              'messageCount': messajes.length,
            },
            'A');
        // #endregion
        if (newMessage == null) {
          print('[ChatProvider] ⚠️ cargarArchivo2 returned null message');
          cargando = false;
          notifyListeners();
          return;
        }
        try {
          var fecha = jsonDecode(newMessage.mensaje!)["fecha"];

          if (incognito) {
            newMessage.incognito = incognito ? 1 : 0;
            newMessage.enviado = 1;
            insertMessageOrderedByFecha(newMessage);
          } else {
            // CRITICAL: For non-incognito, ensure message is in list before updating
            // If not found, insert it to prevent blank chat
            int messageIndex = findMessageIndexByFecha(fecha);
            if (messageIndex != -1) {
              updateMessageByFechaBinary(fecha);
            } else {
              // Message not in list yet - insert it to prevent blank chat
              print(
                  '[ChatProvider] Message with fecha $fecha not in list yet, inserting...');
              try {
                insertMessageOrderedByFecha(newMessage);
                print(
                    '[ChatProvider] ✅ Inserted video message to list to prevent blank chat');
              } catch (insertError) {
                print(
                    '[ChatProvider] ⚠️ Error inserting message: $insertError');
                // Still try to update in case it exists with slightly different fecha format
                updateMessageByFechaBinary(fecha);
              }
            }
          }

          filePath = null;
          fileType = null;
          cargando = false;
          notifyListeners();
          // #region agent log
          _debugLog(
              'ChatProvider.dart:1145',
              'Video message updated successfully',
              {
                'fecha': fecha,
                'finalMessageCount': messajes.length,
                'isIncognito': incognito,
              },
              'A');
          // #endregion
        } catch (e) {
          print('[ChatProvider] ❌ Error processing video message: $e');
          // #region agent log
          _debugLog(
              'ChatProvider.dart:1152',
              'Error processing video message',
              {
                'error': e.toString(),
                'messageCount': messajes.length,
              },
              'A');
          // #endregion
          filePath = null;
          fileType = null;
          cargando = false;
          notifyListeners();
        }
      }).catchError((error) {
        print('[ChatProvider] ❌ Error uploading video: $error');
        // #region agent log
        _debugLog(
            'ChatProvider.dart:1162',
            'cargarArchivo2 failed',
            {
              'error': error.toString(),
              'messageCount': messajes.length,
            },
            'A');
        // #endregion
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
  Future<void> handleSubmit(String texto, Usuario usuario, Usuario usuarioPara,
      AuthService authService, ChatService? c, BuildContext context,
      {String type = 'text'}) async {
    //  usuarioPara.printUsuario();

    // CRITICAL: Prevent self-chat
    if (usuario.uid == usuarioPara.uid) {
      debugPrint('[ChatProvider] ⚠️ Cannot send message to self, ignoring');
      return;
    }

    String mifecha = deconstruirDateTime();
    selectedItems.clear();
    _selectionVersion++;
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

    String x = LocalCrypto().rsaEncryptMessage(texto, usuarioPara.publicKey!);

    String utc = DateTime.now().timeZoneName;

    Map<String, dynamic>? msg;
    messagetoReply1 == null
        ? msg = null
        : msg = {
            'messageType': jsonDecode(messagetoReply1!.mensaje!)['type'],
            'messageContent': jsonDecode(messagetoReply1!.mensaje!)['fecha'],
            'parentSender':
                messagetoReply1 != null && messagetoReply1!.uid == usuario.uid!
                    ? usuario.nombre
                    : usuarioPara.nombre
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
            'para': usuarioPara.uid,
            'incognito': incognito,
            'forwarded': false,
            'reply': messagetoReply1 != null,
            'parentType': msg != null ? msg['messageType'] : null,
            'parentContent': msg != null
                ? msg['messageContent']
                // ? LocalCrypto().rsaEncryptMessage(
                //     msg['messageContent'], usuarioPara.publicKey!)
                : null,
            'parentSender':
                messagetoReply1 != null && messagetoReply1!.uid == usuario.uid
                    ? usuario.nombre
                    : usuarioPara.nombre,
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
            'para': usuarioPara.uid,
            'incognito': incognito,
            'forwarded': false,
            'reply': messagetoReply1 != null,
            'parentType': messagetoReply1 != null
                ? jsonDecode(messagetoReply1!.mensaje!)['type']
                : null,
            'parentContent': messagetoReply1 != null
                ? jsonDecode(messagetoReply1!.mensaje!)['fecha']
                : null,
            'parentSender':
                messagetoReply1 != null && messagetoReply1!.uid == usuario.uid
                    ? usuario.nombre
                    : usuarioPara.nombre,
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
    if (incognito) {
      var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
          [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);
      Mensaje mensajeLocal = Mensaje(deleted: false);
      mensajeLocal.mensaje = jsonEncode(
          {'type': type, 'content': texto, 'fecha': mifecha, 'extension': ''});
      if (msg != null) {
        mensajeLocal.isReply = true;
        mensajeLocal.parentContent = msg['messageContent'];
        mensajeLocal.parentType = msg['messageType'];
        mensajeLocal.parentSender = msg['parentSender'];
      }
      mensajeLocal.de = usuario.uid;
      mensajeLocal.para = usuarioPara.uid;
      mensajeLocal.createdAt = fechaActual;
      mensajeLocal.updatedAt = fechaActual;
      mensajeLocal.uid = usuarioPara.uid;
      // Use insertMessageOrderedByFecha to maintain order and prevent duplicates
      insertMessageOrderedByFecha(mensajeLocal);
    }
    if (msg != null) {
      msg['messageContent'] = jsonDecode(messagetoReply1!.mensaje!)["content"];
    }
    socketService.persistMessajeLocal1(
        type, texto, mifecha, '', msg, incognito, usuario, usuarioPara);

    //   persistMessajeLocal(type, texto, mifecha, '', msg);

    //messajes.insert(0, xx);

    estaEscribiendo = false;

    var event = "mensaje-personal";

    print('[ChatProvider] ========== SENDING MESSAGE ==========');
    print('[ChatProvider] Event: $event');
    print('[ChatProvider] Data keys: ${data.keys.toList()}');
    print('[ChatProvider] Message type: ${data['mensaje']['type']}');
    print(
        '[ChatProvider] Message content length: ${data['mensaje']['content'].toString().length}');
    print(
        '[ChatProvider] Socket status: ${socketService.socket == null ? "null" : (socketService.socket!.connected ? "connected" : "disconnected")}');

    // Generate unique message ID for queue tracking
    final messageId =
        '${data['de']}_${data['para']}_${DateTime.now().millisecondsSinceEpoch}';

    // Check if socket is connected before sending - use serverStatus for accurate state
    final isConnected = socketService.socket != null &&
        socketService.socket!.connected &&
        socketService.serverStatus == ServerStatus.Online;

    if (!isConnected) {
      print('[ChatProvider] ⚠️ Socket not connected, queueing message...');
      print('[ChatProvider] Socket exists: ${socketService.socket != null}');
      print(
          '[ChatProvider] Socket connected: ${socketService.socket != null ? socketService.socket!.connected : false}');
      print('[ChatProvider] Server status: ${socketService.serverStatus}');
      // Add to message queue for later retry
      try {
        final queueService = MessageQueueService();
        await queueService.enqueue(
          messageId: messageId,
          event: event,
          payload: data,
        );
        print('[ChatProvider] ✅ Message queued: $messageId');
        // Attempt to connect
        socketService.connect();
      } catch (e) {
        print('[ChatProvider] ❌ Error queueing message: $e');
      }
      return; // Exit early - message is queued
    } else {
      print(
          '[ChatProvider] ✅ Socket connected, sending message immediately...');
      final emitResult = socketService.emitAck(event, data);
      emitResult.then((ack) {
        if (ack != null && ack == "RECIBIDO_SERVIDOR") {
          print('[ChatProvider] ✅ Message acknowledged: $ack');
          recibidoServidor(ack, data, texto);
        } else {
          print(
              '[ChatProvider] ❌ Message failed - ACK was null or invalid: $ack');
          // Message failed - keep enviado as false (shows ! mark)
          // Could add to retry queue here if needed
        }
      }).catchError((error) {
        print('[ChatProvider] ❌ Error sending message: $error');
        print('[ChatProvider] Error type: ${error.runtimeType}');
        print('[ChatProvider] Error stack: ${StackTrace.current}');
        // Message failed to send - keep enviado as false (shows ! mark)
      });
    }
    print('[ChatProvider] =====================================');

    messagetoReply1 = null;
    notifyListeners();
  }

  recibidoServidor(ack, data, decrypted) async {
    print('[ChatProvider] ========== RECIBIDO SERVIDOR ==========');
    print('[ChatProvider] ACK received: $ack');
    print('[ChatProvider] ACK type: ${ack.runtimeType}');
    print('[ChatProvider] Expected: RECIBIDO_SERVIDOR');

    if (ack == "RECIBIDO_SERVIDOR") {
      print('[ChatProvider] ✅ Server acknowledged message');
      data["mensaje"]["content"] = decrypted;
      print('[ChatProvider] Updating message status in database...');
      await DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
      print('[ChatProvider] Message status updated');

      String fecha = data["mensaje"]["fecha"].split('Z')[0];
      print('[ChatProvider] Updating message by fecha: $fecha');
      updateMessageByFechaBinary(fecha);
      notifyListeners();
      print('[ChatProvider] ✅ Message sending complete');
    } else {
      print('[ChatProvider] ⚠️ Unexpected ACK value: $ack');
    }
    print('[ChatProvider] =====================================');
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

  int findMessageIndexByFecha1(String fecha) {
    int low = 0;
    int high = messajes.length - 1;
    DateTime targetFecha = parseFecha(fecha);

    //print("=======================[Messajes :: ====================");

    //print("===============${[
    //   for (var x in messajes) jsonDecode(x.mensaje!)['fecha']
    // ].join(',')}");

    //print("===================================================");
    while (low <= high) {
      int mid = (low + high) ~/ 2;

      DateTime midFecha =
          parseFecha(jsonDecode(messajes[mid].mensaje!)['fecha']);

      if (midFecha.isBefore(targetFecha)) {
        low = mid + 1;
      } else if (midFecha.isAfter(targetFecha)) {
        high = mid - 1;
      } else {
        return mid; // Found the message
      }
    }

    return -1; // Not found
  }

// Function to update a message using binary search
  void updateMessageByFechaBinary(String fecha) {
    int index = findMessageIndexByFecha(fecha);
    //print("=======[updateMessageByFechaBinary :: ${index}]========");

    if (index != -1) {
      //print("================Urgent ++++++++++++++ NotFound ============");
      messajes[index].enviado = 1; //Update the message
      _msgsVersion++;
    } else {
      // CRITICAL: If message not found in list, it might still be in DB and will come via stream
      // Don't fail silently - log for debugging
      print(
          '[ChatProvider] ⚠️ updateMessageByFechaBinary: Message with fecha $fecha not found in list (will update when stream delivers it)');
      // Message will be updated when it arrives via stream subscription
    }
  }

  /// Update message read status (recibido) when read receipt is received
  void updateMessageReadStatusByFecha(String fecha) {
    int index = findMessageIndexByFecha(fecha);
    print(
        '[ChatProvider] Updating read status for message fecha: $fecha, index: $index');

    if (index != -1) {
      messajes[index].recibido = 1; // Update the read status
      print('[ChatProvider] ✅ Message read status updated to 1');
      _msgsVersion++;
      notifyListeners(); // Immediately update UI to show double ticks
    } else {
      print('[ChatProvider] ⚠️ Message not found for fecha: $fecha');
      // If message not found in current list, reload messages from DB
      // This handles cases where message might not be loaded yet
      _refreshMessageFromDB(fecha);
    }
  }

  /// Refresh message from database if not found in current list
  Future<void> _refreshMessageFromDB(String fecha) async {
    try {
      // Reload messages from database to get updated read status
      final updatedMessages = await DBProvider.db
          .getTodosMensajes1(toUid, uid, messajes.length + 10);

      // Find the updated message
      for (var updatedMsg in updatedMessages) {
        final mensajeData = jsonDecode(updatedMsg.mensaje!);
        final msgFecha = mensajeData['fecha']
            ?.toString()
            .split('Z')[0]
            .replaceAll(RegExp(r'[^\d]'), '');
        if (msgFecha == fecha.replaceAll(RegExp(r'[^\d]'), '')) {
          // Update the message in our list
          int index = findMessageIndexByFecha(fecha);
          if (index != -1) {
            messajes[index].recibido = updatedMsg.recibido;
            notifyListeners();
            print('[ChatProvider] ✅ Message read status refreshed from DB');
          }
          break;
        }
      }
    } catch (e) {
      print('[ChatProvider] Error refreshing message from DB: $e');
    }
  }

  /// Handle read receipt (recibido-cliente) from socket
  /// Updates the message read status in real-time to show double ticks
  void _handleReadReceipt(Map<String, dynamic> payload) {
    try {
      print('[ChatProvider] 📩 Read receipt received: $payload');

      // Check if this read receipt is for a message in the current chat
      final para = payload['para']?.toString();
      final de = payload['de']?.toString();

      // Read receipt should be for messages we sent (de = recipient, para = us)
      // So para should match our uid (the sender who's receiving the read receipt)
      if (para != uid) {
        print(
            '[ChatProvider] Read receipt not for current chat (para: $para, our uid: $uid)');
        return;
      }

      // Extract fecha from mensaje payload
      Map<String, dynamic> mensajeData;
      if (payload['mensaje'] is String) {
        mensajeData = jsonDecode(payload['mensaje']);
      } else if (payload['mensaje'] is Map) {
        mensajeData = Map<String, dynamic>.from(payload['mensaje']);
      } else {
        print('[ChatProvider] Invalid mensaje format in read receipt');
        return;
      }

      final fechaRaw = mensajeData['fecha']?.toString();
      if (fechaRaw == null || fechaRaw.isEmpty) {
        print('[ChatProvider] No fecha in read receipt');
        return;
      }

      // Extract numeric fecha - fecha format can be:
      // - "20251126165311399Z+0000" (with timezone)
      // - "20251126165311399" (numeric only)
      // - ISO format with separators
      // We need to extract just the numeric part (17 digits: YYYYMMDDHHMMSSmmm)
      String fechaNumeric;
      if (fechaRaw.contains('Z')) {
        // Remove timezone part (everything after 'Z')
        fechaNumeric = fechaRaw.split('Z')[0].replaceAll(RegExp(r'[^\d]'), '');
      } else {
        // Already numeric or has separators, extract only digits
        fechaNumeric = fechaRaw.replaceAll(RegExp(r'[^\d]'), '');
      }

      // Ensure we have at least 17 digits (YYYYMMDDHHMMSSmmm format)
      if (fechaNumeric.length < 17) {
        print(
            '[ChatProvider] ⚠️ Invalid fecha format: $fechaRaw (extracted: $fechaNumeric)');
        return;
      }

      // Take first 17 digits (standard fecha format)
      fechaNumeric = fechaNumeric.substring(0, 17);
      print(
          '[ChatProvider] Updating read status for fecha: $fechaNumeric (from: $fechaRaw)');

      // Update the message read status
      updateMessageReadStatusByFecha(fechaNumeric);
    } catch (e, stackTrace) {
      print('[ChatProvider] ❌ Error handling read receipt: $e');
      print('[ChatProvider] Stack trace: $stackTrace');
    }
  }

  /// Retry sending a failed message
  Future<void> retryFailedMessage(String fecha) async {
    try {
      // Find the message in the list
      int index = findMessageIndexByFecha(fecha);
      if (index == -1) {
        print('[ChatProvider] Message not found for retry: $fecha');
        return;
      }

      final message = messajes[index];
      if (message.enviado == 1) {
        print('[ChatProvider] Message already sent, no need to retry');
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
      const event = "mensaje-personal";
      final emitResult = socketService.emitAck(event, data);

      emitResult.then((ack) {
        if (ack != null && ack == "RECIBIDO_SERVIDOR") {
          print('[ChatProvider] ✅ Retry successful');
          recibidoServidor(ack, data, mensajeData['content']);
        } else {
          print(
              '[ChatProvider] ❌ Retry failed - ACK was null or invalid: $ack');
        }
      }).catchError((error) {
        print('[ChatProvider] ❌ Error retrying message: $error');
      });
    } catch (e) {
      print('[ChatProvider] Error in retryFailedMessage: $e');
    }
    notifyListeners();
  }

/*
  testing() {
    String texto = "ooh shit here we go again";

    var Sender = generateRSAkeyPair();
    var Receiver = generateRSAkeyPair();

    Uint8List encryptedMessage =
        rsaEncrypt(Receiver.publicKey, utf8.encode(texto));

    String shshsh = base64.encode(encryptedMessage);

    Uint8List unencrypted =
        rsaDecrypt(Receiver.privateKey, base64.decode(shshsh));

    String data = utf8.decode(unencrypted);
  }
*/
  onchangeTextfield(
    texto,
    Usuario usuario,
    Usuario usuarioPara,
  ) {
    // Cancel previous timer
    _typingTimer?.cancel();

    // PERFORMANCE FIX: Capture previous state
    // Only notify listeners if state changes to avoid rebuilding message list (and reloading videos) on every character
    bool wasTyping = estaEscribiendo;

    if (texto.trim().isNotEmpty) {
      estaEscribiendo = true;
      // Debounce typing indicator - only emit after 500ms of no typing
      _typingTimer = Timer(const Duration(milliseconds: 500), () {
        socketService.emit("userTyping",
            {"user": usuario.uid, "to": usuarioPara.uid, "typing": true});
      });
    } else {
      estaEscribiendo = false;
      socketService.emit("userTyping",
          {"user": usuario.uid, "to": usuarioPara.uid, "typing": false});
    }

    // Only notify if typing state changed
    if (wasTyping != estaEscribiendo) {
      notifyListeners();
    }
  }

  onTape(Usuario usuario, Usuario usuarioPara, BuildContext context,
      AuthService authService, ChatService? c) {
    estaEscribiendo
        ? handleSubmit(
            textController.text.trim(),
            usuario,
            usuarioPara,
            authService,
            c,
            context,
          )
        : null;
  }

  @override
  void dispose() {
    controller.dispose();
    textController.dispose();
    focusNode.dispose();
    _typingTimer?.cancel();
    _updateDebounceTimer?.cancel();
    _cleanupRecorderProgress();
    if (flutterSound.isRecording) {
      flutterSound.stopRecorder();
    }
    if (_isRecorderReady) {
      flutterSound.closeRecorder().catchError((_) {});
      _isRecorderReady = false;
    }
    audioPlayer.dispose();
    players.forEach((_, player) {
      player.dispose();
    });
    players.clear();
    try {
      subscription.cancel();
    } catch (_) {}
    try {
      typingsubscription.cancel();
    } catch (_) {}
    try {
      connectionsubscription.cancel();
    } catch (_) {}
    // Remove read receipt socket listener
    try {
      socketService.socket?.off('recibido-cliente');
      socketService.socket?.off('recibido-cliente');
      _readReceiptSubscription?.cancel();
      _disappearingMessagesTimer?.cancel();
    } catch (_) {}
    super.dispose();
  }
}
