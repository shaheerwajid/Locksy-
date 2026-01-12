import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:CryptoChat/crypto/crypto.dart';
import 'package:CryptoChat/services/crypto.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/grupo_usuario.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/push_providers/push_notifications.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/message_queue_service.dart';
import 'package:CryptoChat/services/telemetry_service.dart';
import 'package:CryptoChat/services/file_cache_service.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:CryptoChat/models/mensajes_response.dart';
import '../providers/db_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send =
      IsolateNameServer.lookupPortByName('downloader_send_port');
  //print("[id, status, progress] ======== [${id},${status},${progress}]");
  send!.send([id, status, progress]);
}

enum ServerStatus { Online, Offline, Connecting }

var ultimoMensaje;

class SocketService extends ChangeNotifier with WidgetsBindingObserver {
  ServerStatus _serverStatus = ServerStatus.Offline;
  IO.Socket? _socket;
  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? myKey;

  bool _descargando = false;
  bool _solicitudesNuevas = false;
  String _porcentajeDescarga = "";
  late ReceivePort _port;
  final _Connectioncontroller =
      StreamController<Map<String, dynamic>>.broadcast();
  final _Refreshcontroller = StreamController<Map<String, dynamic>>.broadcast();
  final _Typingcontroller = StreamController<Map<String, dynamic>>.broadcast();

  // Track app lifecycle state for background notifications
  bool _isAppInBackground = false;
  bool get isAppInBackground => _isAppInBackground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppInBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached;
    print(
        '[SocketService] App lifecycle changed: $state, isBackground: $_isAppInBackground');
  }

  static const _storage = FlutterSecureStorage();

  Stream<Map<String, dynamic>> get connectionstatusstream =>
      _Connectioncontroller.stream;
  Stream<Map<String, dynamic>> get typingstream => _Typingcontroller.stream;
  Stream<Map<String, dynamic>> get refreshstream => _Refreshcontroller.stream;

  Future<String?> _getCurrentUserId() async {
    try {
      final auth = AuthService();
      if (auth.usuario != null) return auth.usuario!.uid;
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('usuario');
      if (userJson != null) {
        final data = jsonDecode(userJson);
        return data['uid']?.toString();
      }
    } catch (_) {}
    return null;
  }

  // Socket lifecycle helpers
  static const Duration _minConnectGap = Duration(seconds: 3);
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);
  static const int _maxReconnectSteps = 6;

  Timer? _throttleTimer;
  Timer? _reconnectTimer;
  DateTime? _lastConnectAttempt;
  bool _connectInProgress = false;
  bool _intentionalDisconnect = false;
  int _reconnectAttempts = 0;

  bool get solicitudesNuevas {
    return _solicitudesNuevas;
  }

  set solicitudesNuevas(bool sol) {
    _solicitudesNuevas = sol;
  }

  bool get descargando {
    return _descargando;
  }

  String get porcentajeDescarga {
    return _porcentajeDescarga;
  }

  set descargando(bool descargando) {
    _descargando = descargando;
    notifyListeners();
  }

  set porcentajeDescarga(String porcentajeDescarga) {
    _porcentajeDescarga = porcentajeDescarga;
    notifyListeners();
  }

  ServerStatus get serverStatus {
    // Sync with actual socket state
    if (_socket != null &&
        _socket!.connected &&
        _serverStatus != ServerStatus.Online) {
      print(
          '[SocketService] Syncing status: socket is connected but status was $_serverStatus');
      _serverStatus = ServerStatus.Online;
      notifyListeners();
    } else if (_socket == null || !_socket!.connected) {
      if (_serverStatus != ServerStatus.Offline &&
          _serverStatus != ServerStatus.Connecting) {
        print(
            '[SocketService] Syncing status: socket is disconnected but status was $_serverStatus');
        _serverStatus = ServerStatus.Offline;
        notifyListeners();
      }
    }
    return _serverStatus;
  }

  bool get isReconnecting {
    return _connectInProgress ||
        _serverStatus == ServerStatus.Connecting ||
        _reconnectTimer != null;
  }

  IO.Socket? get socket => _socket;

  Function get emit => _socket!.compress(true).emit;
  Future<dynamic> Function(String, dynamic) get emitAck {
    if (_socket == null) {
      print('[SocketService] ERROR: emitAck called but socket is null');
      return (String event, dynamic data) {
        print(
            '[SocketService] emitAck: socket is null, returning rejected Future');
        return Future.value(null);
      };
    }
    if (!_socket!.connected) {
      print(
          '[SocketService] WARNING: emitAck called but socket is not connected');
      return (String event, dynamic data) {
        print(
            '[SocketService] emitAck: socket not connected, returning rejected Future');
        return Future.value(null);
      };
    }
    // Return a wrapper function that handles acknowledgments
    // Note: socket_io_client v2.0.3+1 may not support emitWithAck directly
    // We use a workaround with a unique acknowledgment ID
    return (String event, dynamic data) {
      try {
        print(
            '[SocketService] emitAck: Emitting event "$event" with acknowledgment...');

        final completer = Completer<dynamic>();
        Timer? timeoutTimer;

        // Generate unique acknowledgment ID
        final ackId =
            '${DateTime.now().millisecondsSinceEpoch}_${event}_${data.hashCode}';

        // Set up timeout
        timeoutTimer = Timer(const Duration(seconds: 10), () {
          if (!completer.isCompleted) {
            print(
                '[SocketService] emitAck: Timeout waiting for acknowledgment');
            _socket!.off('ack_$ackId'); // Clean up listener
            completer.complete(null);
          }
        });

        // Listen for acknowledgment
        _socket!.once('ack_$ackId', (ack) {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            print('[SocketService] emitAck: Received acknowledgment: $ack');
            completer.complete(ack);
          }
        });

        // Add acknowledgment ID to data
        // Handle both Map and other types
        dynamic dataWithAck;
        if (data is Map) {
          dataWithAck = {
            ...data,
            '_ackId': ackId,
          };
        } else {
          // If data is not a Map, wrap it
          dataWithAck = {
            '_data': data,
            '_ackId': ackId,
          };
        }

        // Emit the event
        try {
          print('[SocketService] 📤 About to emit event: $event');
          print(
              '[SocketService] 📤 Socket connected before emit: ${_socket!.connected}');
          print('[SocketService] 📤 ACK ID: $ackId');
          _socket!.emit(event, dataWithAck);
          print('[SocketService] 📤 Event emitted successfully');
          print(
              '[SocketService] 📤 Socket connected after emit: ${_socket!.connected}');
        } catch (e) {
          timeoutTimer.cancel();
          _socket!.off('ack_$ackId');
          print('[SocketService] ❌ Error emitting event: $e');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }

        return completer.future;
      } catch (e, stackTrace) {
        print('[SocketService] Error in emitAck wrapper: $e');
        print('[SocketService] Stack trace: $stackTrace');
        return Future.value(null);
      }
    };
  }

  Function get emitBin => _socket!.compress(true).emit;
  // Future<Function> get recibirAcuse async => this._recibirAcuse;

  // void setServerStatus(ServerStatus serverStatus) {
  //   _serverStatus = serverStatus;
  // }

  setmyKey() async {
    print('[SocketService] setmyKey() called');
    try {
      var x = await getKeys();
      if (x == null) {
        print('[SocketService] WARNING: getKeys() returned null');
      } else {
        myKey = x;
        print('[SocketService] ✅ myKey set successfully');
      }
    } catch (e, stackTrace) {
      print('[SocketService] ❌ ERROR in setmyKey(): $e');
      print('[SocketService] Stack trace: $stackTrace');
    }
  }

  bool canConnect() {
    setmyKey();
    connect();
    var res = _serverStatus == ServerStatus.Online ? true : false;

    return res;
  }

  check() {
    if (_socket == null) {
      return true;
    } else {
      bool res = _socket!.connected;
      return !res;
    }
  }

  Future<void> connect({bool force = false}) async {
    print('[SocketService] ========================================');
    print('[SocketService] connect() called');
    print('[SocketService] Current serverStatus: $_serverStatus');
    print('[SocketService] Socket exists: ${_socket != null}');
    print(
        '[SocketService] Socket connected: ${_socket != null ? _socket!.connected : false}');
    print('[SocketService] ========================================');
    TelemetryService.log('socket_connect_attempt', data: {
      'force': force,
      'status': _serverStatus.toString(),
      'hasSocket': _socket != null,
      'connected': _socket?.connected ?? false,
    });

    // Register lifecycle observer to track app state
    WidgetsBinding.instance.addObserver(this);

    // Check if already connected
    if (_socket != null && _socket!.connected) {
      print('[SocketService] Socket already connected, syncing status...');
      _serverStatus = ServerStatus.Online;
      notifyListeners();
      _Connectioncontroller.add({'status': 'online'});
      _resetReconnectBackoff();
      return;
    }

    if (_connectInProgress && !force) {
      print('[SocketService] connect() ignored - another attempt in progress');
      return;
    }

    if (!force && _shouldThrottleConnect()) {
      print('[SocketService] connect() throttled - waiting before retrying');
      return;
    }

    _connectInProgress = true;
    _intentionalDisconnect = false;
    _lastConnectAttempt = DateTime.now();
    _throttleTimer?.cancel();
    _reconnectTimer?.cancel();

    try {
      if (_serverStatus != ServerStatus.Online) {
        print(
            '[SocketService] Status is Offline/Connecting, starting connection...');
        _serverStatus = ServerStatus.Connecting;
        notifyListeners();
      }

      // Initialize myKey before connecting - CRITICAL for message decryption
      print('[SocketService] About to call setmyKey()...');
      await setmyKey();
      print('[SocketService] setmyKey() completed');

      // Verify keys were loaded
      if (myKey == null) {
        print(
            '[SocketService] ⚠️ WARNING: myKey is still null after setmyKey()');
        print('[SocketService] Attempting to load keys directly...');
        final key = await getKeys();
        if (key != null) {
          myKey = key;
          print('[SocketService] ✅ Keys loaded directly');
        } else {
          print(
              '[SocketService] ❌ ERROR: Could not load keys - messages may not decrypt');
        }
      } else {
        print('[SocketService] ✅ myKey is initialized');
      }

      final token = await AuthService.getToken();
      if (token == " " || token.trim().isEmpty) {
        print('[SocketService] ❌ No valid token found (getToken returned "$token") - Aborting connection');
        _connectInProgress = false;
        return;
      }
      final pushProvider = PushNotifications();

      _socket?.dispose();
      _socket = null;

      await pushProvider.initNotifications().then((value) {
        if (value != null && value.isNotEmpty) {
          print(
              '[SocketService] ✅ FCM Token obtained: ${value.substring(0, 20)}...');
          print(
              '[SocketService] Sending FCM token to backend via socket header');
        } else {
          print('[SocketService] ⚠️ WARNING: FCM Token is null or empty!');
        }
        _socket = IO.io(
          Environment.socketUrl,
          IO.OptionBuilder()
              .setTransports(['websocket']) // Use WebSocket transport
              .enableAutoConnect()
              .enableForceNew()
              .setExtraHeaders({
                'x-token': token,
                'firebaseid': value ?? ''
              }) // Custom headers
              .enableReconnection()
              .setReconnectionAttempts(100)
              .setReconnectionDelay(60)
              .setReconnectionDelayMax(50000)
              // Delay between reconnections in ms
              .build(),
        );
      });
      initDownloaderTask();
      _socket!.on('connect', (_) async {
        print('[SocketService] ✅ Socket connected event received');
        print('[SocketService] Socket ID: ${_socket!.id}');
        print('[SocketService] Socket connected: ${_socket!.connected}');
        TelemetryService.log('socket_connect_success',
            data: {'socketId': _socket!.id});
        _resetReconnectBackoff();
        _serverStatus = ServerStatus.Online;
        notifyListeners();
        // Notify connection stream
        _Connectioncontroller.add({'status': 'online'});

        // Ensure keys are loaded after connection
        if (myKey == null) {
          print('[SocketService] ⚠️ myKey is null on connect, loading keys...');
          await setmyKey();
        }

        // Send a setup event to keep connection alive and register with server
        print('[SocketService] 🔧 Attempting to send setup event...');
        try {
          final prefs = await SharedPreferences.getInstance();
          print('[SocketService] 🔧 SharedPreferences loaded');
          final usuario = prefs.getString('usuario');
          print(
              '[SocketService] 🔧 Usuario from prefs: ${usuario != null ? "YES" : "NO"}');

          if (usuario != null) {
            final usuarioData = json.decode(usuario);
            final uid = usuarioData['uid'];
            print('[SocketService] 🚀 Sending setup event with UID: $uid');
            _socket!.emit('setup', {'codigo': uid});
            print('[SocketService] ✅ Setup event sent successfully');
          } else {
            print(
                '[SocketService] ⚠️ WARNING: Usuario is null in SharedPreferences, cannot send setup event');
          }
        } catch (e) {
          print('[SocketService] ❌ Error sending setup: $e');
          print('[SocketService] Error stack: ${StackTrace.current}');
        }

        // Process message queue on connect
        _processMessageQueue();
      });

      // Handle connection errors
      _socket!.on('connect_error', (data) {
        print('[SocketService] ❌ Socket connection error: $data');
        _serverStatus = ServerStatus.Offline;
        notifyListeners();
        _Connectioncontroller.add({'status': 'offline'});
        
        // Schedule reconnect if not intentional disconnect
        if (!_intentionalDisconnect) {
          _scheduleReconnect(reason: 'connect_error: $data');
        }
      });

      _socket!.on('connect_timeout', (data) {
        print('[SocketService] ⚠️ Socket connection timeout: $data');
        _serverStatus = ServerStatus.Offline;
        notifyListeners();
        _Connectioncontroller.add({'status': 'offline'});
        
        // Schedule reconnect if not intentional disconnect
        if (!_intentionalDisconnect) {
          _scheduleReconnect(reason: 'connect_timeout');
        }
      });

      _socket!.on('error', (data) {
         print('[SocketService] ⚠️ Socket error: $data');
         // Depending on error, we might want to stay online or go offline
         // Usually 'error' is for middleware errors, not connection state
      });

      _socket!.on('reconnect', (_) {
        // //print(
        //     "===============================================================");
        // //print(
        //     "======================={reconnect}===============================");
        _serverStatus = ServerStatus.Online;
        notifyListeners();
        _resetReconnectBackoff();
        // Notify connection stream
        _Connectioncontroller.add({'status': 'online'});
        // Process message queue on reconnect
        _processMessageQueue();
      });

      _socket!.on('reconnect_attempt', (_) {
        // //print(
        //     "===============================================================");
        // //print(
        //     "======================={reconnect_attempt}===============================");
        // _serverStatus = ServerStatus.Online;
        //notifyListeners();
      });

      _socket!.on('grupo-borrado', (payload) {
        var codigo = payload['grupo']['codigo'];
        DBProvider.db.deleteGroup(codigo);
        notifyListeners();
      });

      _socket!.on('solicitud-amistad', (payload) {
        if (payload['solicitudes'] > 0) {
          _solicitudesNuevas = true;
        } else {
          _solicitudesNuevas = false;
        }
        notifyListeners();
      });

      _socket!.on('update-group', (payload) {
        saveGrupo(payload);
        notifyListeners();
      });

      _socket!.on('usuario-borrado-grupo', (payload) async {
        var grupo = payload['grupousuario']['grupo']['codigo'];
        var usuario = payload['grupousuario']['usuarioContacto'];
        DBProvider.db.deleteMiembro(grupo, usuario);
        // if(usuario == ) {
        //   DBProvider.db.deleteGroup(grupo);
        // }
        notifyListeners();
      });

      _socket!.on("userConnection", (data) {
        fetchDataAndUpdateStream(data);
      });

      _socket!.on("userDesConnection", (data) {
        //print("");
        DateTime utcDateTime = DateTime.parse(data['lastConnection']);

        // Step 2: Convert to local time
        DateTime localDateTime = utcDateTime.toLocal();

        // Step 3: Format the date as per your requirements
        String formattedDate =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(localDateTime);
        data['lastConnection'] = formattedDate;
        fetchDataAndUpdateStream(data);

        DBProvider.db.updateContacto(data['lastConnection'], data['user']);
      });
      _socket!.on("userTyping", (data) {
        fetchDataAndUpdateTypingStream(data);
      });

      _socket!.on('recibido-cliente', (payload) {
        _recibirAcuse(payload);
        notifyListeners();
      });

      _socket!.on('mensaje-grupal', (payload) {
        // CRITICAL: Immediately notify UI FIRST - don't wait for processing
        _Refreshcontroller.add(payload);
        //print(
        //    "🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯 Received");
        _socket!.emit('message-received-ack', {
          'payload': payload,
          'messageId':
              payload['mensaje'], // Use a unique identifier for the message
          'status': 'received', // Let the server know the message was received
        });

        // Process message in background - use microtask to ensure it doesn't block
        Future.microtask(() {
          saveFileAndNotify(payload, true);
        });
      });

      _socket!.on('mensaje-personal', (payload) {
        // CRITICAL: Immediately notify UI FIRST - don't wait for processing
        _Refreshcontroller.add(payload);

        // Send ACK immediately to server
        _socket!.emit('message-received-ack', {
          'payload': payload,
          'messageId':
              payload['mensaje'], // Use a unique identifier for the message
          'status': 'received', // Let the server know the message was received
        });

        // CRITICAL: Show notification if app is in background
        // Backend doesn't send FCM when socket is connected, so we need to handle it here
        if (_isAppInBackground) {
          Future.microtask(() {
            _showBackgroundNotification(payload);
          });
        }

        // Process message in background - use microtask to ensure it doesn't block
        Future.microtask(() {
          saveFileAndNotify(payload, false);
        });
      });

      _socket!.on('eliminar-para-todos', (payload) async {
        var de = payload['de'];
        var para = payload['para'];
        if (payload['mensaje'] != null) {
          var fecha = payload['mensaje']['fecha'];
          var texto = payload['mensaje']['texto'];
          var type = payload['mensaje']['type'];
          var ext = payload['mensaje']['ext'];

          var values = {
            'texto': texto,
            'fecha': fecha,
            'type': type,
            'ext': ext,
            'de': de,
            'para': para,
          };

          // DBProvider.db.deleteMensaje(values);
          DBProvider.db.deleteMensajeV2(values);
          updatedeletedmsg(true);
        } else {
          DBProvider.db.borrarMensajesContacto(de);
          DBProvider.db.borrarContacto(de);
        }
        notifyListeners();
      });

      _socket!.on('modo-incognito', (payload) async {
        var incognito = payload['incognito'];
        var uid = payload['de'];
        await DBProvider.db.updateContactos(uid, 'incognito', incognito);
        notifyListeners();
      });

      _socket!.on('disconnect', (reason) {
        print('[SocketService] ❌ Socket disconnected. Reason: $reason');
        print('[SocketService] Socket ID at disconnect: ${_socket!.id}');
        print('[SocketService] Socket connected: ${_socket!.connected}');

        // DON'T clear listeners here - it removes reconnect handlers!
        // The reconnect handler will re-setup listeners when connection is restored

        _serverStatus = ServerStatus.Offline;
        notifyListeners();
        _Connectioncontroller.add({'status': 'offline'});
        TelemetryService.log('socket_disconnect', data: {
          'reason': reason,
          'socketId': _socket?.id,
        });

        // Log detailed disconnect reason
        if (reason == 'transport close') {
          print(
              '[SocketService] ⚠️ TRANSPORT CLOSE - Network issue or server disconnected the socket');
        } else if (reason == 'io server disconnect') {
          print(
              '[SocketService] ⚠️ SERVER DISCONNECT - Server forcefully disconnected this client');
        } else if (reason == 'io client disconnect') {
          print(
              '[SocketService] ℹ️ CLIENT DISCONNECT - Intentional disconnect');
        } else if (reason == 'ping timeout') {
          print(
              '[SocketService] ⚠️ PING TIMEOUT - Connection lost, no response from server');
        } else {
          print('[SocketService] ⚠️ UNKNOWN DISCONNECT: $reason');
        }

        // If disconnect was not intentional, attempt to reconnect
        if (reason != 'io client disconnect') {
          print(
              '[SocketService] Disconnect was unintentional, socket.io will attempt to reconnect...');
          _scheduleReconnect(reason: reason?.toString());
        }
      });
    } finally {
      _connectInProgress = false;
    }
  }

  void fetchDataAndUpdateStream(x) async {
    // final db = await database;

    _Connectioncontroller.add(x);
  }

  bool _shouldThrottleConnect() {
    if (_lastConnectAttempt == null) {
      return false;
    }
    final elapsed = DateTime.now().difference(_lastConnectAttempt!);
    if (elapsed < _minConnectGap) {
      final waitTime = _minConnectGap - elapsed;
      _throttleTimer?.cancel();
      _throttleTimer = Timer(waitTime, () {
        _throttleTimer = null;
        connect();
      });
      print(
          '[SocketService] Throttling connect attempt. Retrying in ${waitTime.inMilliseconds}ms');
      return true;
    }
    return false;
  }

  void _resetReconnectBackoff() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect({String? reason}) {
    if (_intentionalDisconnect) {
      print(
          '[SocketService] Reconnect skipped because disconnect was intentional');
      return;
    }
    _reconnectTimer?.cancel();
    final cappedAttempts = _reconnectAttempts.clamp(0, _maxReconnectSteps);
    final delaySeconds = (_initialReconnectDelay.inSeconds *
            (1 << cappedAttempts))
        .clamp(_initialReconnectDelay.inSeconds, _maxReconnectDelay.inSeconds)
        .toInt();
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, _maxReconnectSteps);
    final delay = Duration(seconds: delaySeconds);
    print(
        '[SocketService] Scheduling reconnect in ${delay.inSeconds}s (reason: $reason)');
    TelemetryService.log('socket_reconnect_scheduled',
        data: {'delaySeconds': delay.inSeconds, 'reason': reason});
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      connect();
    });
  }

  void updatedeletedmsg(bool delete) async {
    Map<String, dynamic> yx = {"msgDeleted": true};
    _Typingcontroller.add(yx);
  }

  void fetchDataAndUpdateTypingStream(x, {bool delete = false}) async {
    _Typingcontroller.add(x);
  }

  emitirAcuseRecibo(payload) {
    emit("recibido-cliente", {
      "de": payload["para"],
      "para": payload["de"],
      "mensaje": payload["mensaje"],
      "forwarded": payload["forwarded"],
      "reply": payload["reply"],
      "parentType": payload["reply"],
      "parentSender": payload["parentSender"],
      "parentContent": payload["parentContent"],
    });
  }

  _recibirAcuse(payload) async {
    print('[SocketService] ========== _recibirAcuse ==========');
    print('[SocketService] Read receipt received');
    print('[SocketService] payload de: ${payload['de']}');
    print('[SocketService] payload para: ${payload['para']}');
    print(
        '[SocketService] payload mensaje type: ${payload['mensaje']?.runtimeType}');

    final result = await DBProvider.db
        .actualizarEnviadoRecibido(payload, 'recibido', true);
    print('[SocketService] DB update result: $result');
    print('[SocketService] =====================================');

    notifyListeners();
    stateChatPage();
  }

  persistMessajeLocal(type, content, fecha, ext, payload, {String? d}) async {
    // Extract timezone from message date
    try {
      jsonDecode(payload['mensaje'])['fecha'].split('Z')[1];
    } catch (e) {
      //print(e);
      payload['mensaje']['fecha'].split('Z')[1];
    }
    var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
        [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);

    Mensaje mensajeLocal = Mensaje(deleted: false);

    // String decrypted = content; // Unused variable removed
    String? replyContent;
    if (payload["parentContent"] != null) {
      //print("⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️");

      //print("=============={${payload["parentContent"]}}===================");
      //print("=============={${payload['para']}}===================");
      String originalParentContent = payload["parentContent"].toString();
      debugPrint(
          '[SocketService] Looking up reply content for parentContent: $originalParentContent');
      debugPrint(
          '[SocketService] Sender (de): ${payload['de']}, Receiver (para): ${payload['para']}');

      // Check if parentContent is already a URL/hash (not a fecha)
      bool isUrlOrHash = originalParentContent.startsWith('http://') ||
          originalParentContent.startsWith('https://') ||
          (!RegExp(r'^\d{15,}$').hasMatch(
                  originalParentContent.replaceAll(RegExp(r'[^\d]'), '')) &&
              originalParentContent.length < 50 &&
              !originalParentContent
                  .replaceAll(RegExp(r'[^\d]'), '')
                  .contains(RegExp(r'^\d{15,}$')));

      if (isUrlOrHash) {
        // Already a URL or hash, use it directly
        debugPrint(
            '[SocketService] ParentContent is URL/hash, using directly: $originalParentContent');
        replyContent = originalParentContent;
      } else {
        // It's likely a fecha, try to look it up
        // Extract numeric fecha for lookup (remove 'Z' suffix and timezone if present)
        String fechaToLookup = originalParentContent;
        if (fechaToLookup.contains('Z')) {
          fechaToLookup = fechaToLookup.split('Z')[0];
        }
        // Remove any non-digit characters to get pure numeric fecha
        String numericFecha = fechaToLookup.replaceAll(RegExp(r'[^\d]'), '');
        // Take first 17 digits (standard fecha format)
        if (numericFecha.length > 17) {
          numericFecha = numericFecha.substring(0, 17);
        } else if (numericFecha.length < 17 && numericFecha.isNotEmpty) {
          // Pad with zeros if too short (shouldn't happen but handle it)
          numericFecha = numericFecha.padRight(17, '0');
        }

        debugPrint(
            '[SocketService] Extracted numeric fecha for lookup: $numericFecha');

        // Try lookup with receiver's UID (when receiving, para is our UID)
        List<Map<String, dynamic>> testing = await DBProvider.db
            .getMensajeByFecha(numericFecha, payload['para']);
        debugPrint(
            '[SocketService] Lookup result with para (${payload['para']}): ${testing.length} messages found');

        // If not found, try with sender's UID as well
        if (testing.isEmpty &&
            payload['de'] != null &&
            payload['de'] != payload['para']) {
          testing = await DBProvider.db
              .getMensajeByFecha(numericFecha, payload['de']);
          debugPrint(
              '[SocketService] Lookup result with de (${payload['de']}): ${testing.length} messages found');
        }

        if (testing.isNotEmpty) {
          replyContent = jsonDecode(testing[0]["mensaje"])["content"];
          debugPrint(
              '[SocketService] ✅ Found reply content: ${replyContent?.substring(0, 50)}...');
        } else {
          debugPrint(
              '[SocketService] ⚠️ Lookup failed, using original parentContent as fallback');
          // Lookup failed - use original as fallback (might be URL/hash we didn't detect)
          replyContent = originalParentContent;
        }
      }
      //print("=============={${payload["parentType"]}}===================");
      //print("⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️⭕️");
      //print("=============={${replyContent}}===================");
    }
    //print("=============={${replyContent}}===================");
    mensajeLocal.mensaje = jsonEncode(
        {'type': type, 'content': content, 'fecha': fecha, 'extension': ext});
    mensajeLocal.createdAt = fechaActual;
    mensajeLocal.updatedAt = fechaActual;
    mensajeLocal.forwarded = payload["forwarded"];
    mensajeLocal.isReply = payload["reply"];
    mensajeLocal.parentContent =
        replyContent ?? payload["parentContent"]?.toString();
    mensajeLocal.parentSender = payload["parentSender"];
    mensajeLocal.parentType = payload["parentType"];
    mensajeLocal.incognito = payload["incognito"] ? 1 : 0;

    // CRITICAL FIX: Backend sends group messages with different field meanings:
    // For group messages from backend:
    //   - payload['de'] = group code (backend swaps: mensaje.de = payload.para which is group code)
    //   - payload['para'] = recipient user ID (the current user)
    //   - payload['grupo']['codigo'] = the actual group code
    //   - payload['usuario']['uid'] or payload['usuario']['_id'] = actual sender's UID
    // For personal messages:
    //   - payload['de'] = sender user ID
    //   - payload['para'] = recipient user ID
    //
    // Database query for groups: WHERE para = groupCode
    // So for groups, we must set para = group code (from grupo.codigo)
    // And de = actual sender UID (from usuario._id or uid)

    // Diagnostic logging for group detection
    debugPrint('[SocketService] payload["grupo"] = ${payload["grupo"]}');
    debugPrint(
        '[SocketService] payload["grupo"] type = ${payload["grupo"]?.runtimeType}');
    debugPrint(
        '[SocketService] payload["grupo"] != null = ${payload["grupo"] != null}');

    bool isGroup = payload["grupo"] != null;
    String? grupoCodigo =
        isGroup ? payload["grupo"]["codigo"]?.toString() : null;

    // FALLBACK: If grupo is null, check if para is a known group code in local DB
    // This handles the case where backend sends group messages through mensaje-personal
    // without the grupo object
    if (!isGroup && payload["para"] != null) {
      final para = payload["para"].toString();
      try {
        final isGroupCode = await DBProvider.db.isGroupCode(para);
        if (isGroupCode) {
          debugPrint(
              '[SocketService] ✅ FALLBACK: para=$para is a group code, treating as group message');
          isGroup = true;
          grupoCodigo = para;
        }
      } catch (e) {
        debugPrint('[SocketService] Error checking if para is group code: $e');
      }
    }

    debugPrint(
        '[SocketService] isGroup = $isGroup, grupoCodigo = $grupoCodigo');

    if (isGroup) {
      // For group messages:
      // - para = group code (for query: WHERE para = groupCode)
      // - uid = group code (for GroupProvider subscription filter)
      // - de = actual sender UID (from usuario object, NOT payload['de'] which is group code)
      mensajeLocal.para = grupoCodigo ?? '';
      mensajeLocal.uid = grupoCodigo ?? '';

      // Get actual sender UID from usuario object
      final senderUid = payload['usuario']?['_id']?.toString() ??
          payload['usuario']?['uid']?.toString() ??
          payload['de']?.toString() ??
          '';
      mensajeLocal.de = senderUid;

      debugPrint(
          '[SocketService] Group message - para: ${mensajeLocal.para}, de (sender): $senderUid, grupo: $grupoCodigo');
    } else {
      // For personal messages: standard de/para
      mensajeLocal.de = payload['de']?.toString() ?? '';
      mensajeLocal.para = payload['para']?.toString() ?? '';
      mensajeLocal.uid = payload['de']?.toString() ?? '';
    }

    // CRITICAL: Set nombreEmisor for both group and personal messages
    if (payload['usuario'] != null && payload['usuario']['nombre'] != null) {
      mensajeLocal.nombreEmisor = payload['usuario']['nombre'];
    } else {
      debugPrint(
          '[SocketService] ⚠️ Warning: usuario.nombre is null, setting empty nombreEmisor');
      mensajeLocal.nombreEmisor = '';
    }

    await DBProvider.db.nuevoMensaje(mensajeLocal);
    debugPrint(
        '[SocketService] ✅ Message saved - uid: ${mensajeLocal.uid}, de: ${mensajeLocal.de}, para: ${mensajeLocal.para}, isGroup: $isGroup, grupoCodigo: $grupoCodigo, nombreEmisor: ${mensajeLocal.nombreEmisor}');

    // #region agent log
    final debugLogPath = r'd:\locksyy\.cursor\debug.log';
    try {
      final debugEntry = {
        'location': 'socket_service.dart:909',
        'message': 'Message persisted to DB',
        'data': {
          'uid': mensajeLocal.uid,
          'de': mensajeLocal.de,
          'para': mensajeLocal.para,
          'isGroup': isGroup,
          'grupoCodigo': grupoCodigo,
          'nombreEmisor': mensajeLocal.nombreEmisor,
          'messageType': type,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sessionId': 'debug-session',
        'hypothesisId': 'C'
      };
      File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
          mode: FileMode.append);
    } catch (_) {}
    // #endregion
    if (payload["grupo"] == null) {
      // CRITICAL: Prevent creating contact with own UID
      final currentUserId = await AuthService.getToken();
      if (payload['de'] == currentUserId || payload['para'] == currentUserId) {
        // Only create contact if it's the OTHER user, not ourselves
        final otherUserId =
            payload['de'] == currentUserId ? payload['para'] : payload['de'];
        if (otherUserId == currentUserId) {
          debugPrint('[SocketService] ⚠️ Cannot create contact with own UID');
          return;
        }
      }

      var contacto = payload["usuario"];
      Usuario contactoNuevo = Usuario(publicKey: contacto['publicKey']);
      contactoNuevo.uid = payload['de'];
      contactoNuevo.nombre = contacto['nombre'];
      contactoNuevo.online = contacto['online'];
      contactoNuevo.email = contacto['email'];
      contactoNuevo.avatar = contacto['avatar'];

      contactoNuevo.codigoContacto = contacto['codigoContacto'];

      // CRITICAL: Ensure contact UID is not current user
      final authService = AuthService();
      if (contactoNuevo.uid == authService.usuario?.uid) {
        debugPrint(
            '[SocketService] ⚠️ Skipping contact creation - UID matches current user');
        return;
      }

      try {
        DBProvider.db.nuevoContacto(contactoNuevo);
      } catch (e) {}
    } else {
      saveGrupo(payload, d: d);
    }
  }

  /*
   * Guarda mensaje
   * Envia archivos seleccionados
   */
  persistMessajeLocal1(type, content, datefecha, exte, replymsg, incognito,
      usuario, usuarioPara) {
    // CRITICAL: Prevent self-chat
    if (usuario!.uid == usuarioPara!.uid) {
      debugPrint('[SocketService] ⚠️ Cannot persist message to self, ignoring');
      return;
    }

    if (!incognito) {
      var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
          [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);

      Mensaje mensajeLocal = Mensaje(deleted: false);
      mensajeLocal.mensaje = jsonEncode({
        'type': type,
        'content': content,
        'fecha': datefecha,
        'extension': exte
      });

      // //print(
      //     "++++++++++++++++++++++++++++++++{{replymsg}++++++++++++++++++++++++++++}");
      if (replymsg != null) {
        mensajeLocal.isReply = true;
        mensajeLocal.parentContent = replymsg['messageContent'];
        mensajeLocal.parentType = replymsg['messageType'];
        mensajeLocal.parentSender = replymsg['parentSender'];
        // //print(
        //     "++++++++++++++++++++++++++++++++{${mensajeLocal.parentContent}++++++++++++++++++++++++++++}");
        // //print(
        //     "++++++++++++++++++++++++++++++++{${mensajeLocal.parentType}++++++++++++++++++++++++++++}");
        // //print(
        //     "++++++++++++++++++++++++++++++++{${mensajeLocal.parentSender}++++++++++++++++++++++++++++}");
      }
      mensajeLocal.de = usuario!.uid;
      mensajeLocal.para = usuarioPara!.uid;
      mensajeLocal.createdAt = fechaActual;
      mensajeLocal.updatedAt = fechaActual;
      mensajeLocal.uid = usuarioPara!.uid;

      DBProvider.db.nuevoMensaje(mensajeLocal);
    }
    //ta9wadiyt here
    // CRITICAL: Ensure contact UID is not current user
    if (usuarioPara!.uid == usuario!.uid) {
      debugPrint('[SocketService] ⚠️ Cannot create contact with own UID');
      return;
    }

    Usuario contactoNuevo = Usuario(publicKey: usuarioPara!.publicKey);
    contactoNuevo.nombre = usuarioPara!.nombre;
    contactoNuevo.avatar = usuarioPara!.avatar;
    contactoNuevo.uid = usuarioPara!.uid;
    contactoNuevo.online = usuarioPara!.online;
    contactoNuevo.codigoContacto = usuarioPara!.codigoContacto;
    contactoNuevo.email = usuarioPara!.email;
    DBProvider.db.nuevoContacto(contactoNuevo);
  }

  persistGMessajeLocal1(type, content, datefecha, exte, replymsg, incognito,
      usuario, grupoPara) async {
    if (!incognito) {
      var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
          [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);
      Mensaje mensajeLocal = Mensaje(deleted: false);
      mensajeLocal.mensaje = jsonEncode({
        'type': type,
        'content': content,
        'fecha': datefecha,
        'extension': exte
      });
      if (replymsg != null) {
        mensajeLocal.isReply = true;
        mensajeLocal.parentContent = replymsg['messageContent'];
        mensajeLocal.parentType = replymsg['messageType'];
        mensajeLocal.parentSender = replymsg['parentSender'];
      }

      mensajeLocal.de = usuario!.uid;
      mensajeLocal.para = grupoPara!.codigo;
      mensajeLocal.createdAt = fechaActual;
      mensajeLocal.updatedAt = fechaActual;
      mensajeLocal.uid = grupoPara!.codigo;
      mensajeLocal.nombreEmisor = usuario!.nombre;
      DBProvider.db.nuevoMensaje(mensajeLocal);
    }
    Grupo grupoNuevo = Grupo();
    grupoNuevo.nombre = grupoPara!.nombre;
    grupoNuevo.avatar = grupoPara!.avatar;
    grupoNuevo.codigo = grupoPara!.codigo;
    grupoNuevo.descripcion = grupoPara!.descripcion;
    grupoNuevo.fecha = grupoPara!.fecha;
    grupoNuevo.usuarioCrea = grupoPara!.usuarioCrea;
    grupoNuevo.publicKey = grupoPara.publicKey;
    grupoNuevo.privateKey = grupoPara.privateKey;
    await DBProvider.db.nuevoGrupo(grupoNuevo);

    // CRITICAL FIX: Add current user to grupousuario table when sending group messages
    // This ensures messages can be loaded later (getTodosMensajes1 requires user in grupousuario)
    try {
      if (usuario != null) {
        GrupoUsuario currentUserMembership = GrupoUsuario(
          codigoGrupo: grupoPara!.codigo,
          uidUsuario: usuario!.uid,
          codigoUsuario: usuario!.codigoContacto,
          nombreUsuario: usuario!.nombre,
          avatarUsuario: usuario!.avatar,
        );
        await DBProvider.db
            .nuevoMiembro([currentUserMembership], grupoPara!.codigo);
        debugPrint(
            '[SocketService] ✅ Added current user to grupousuario for outgoing group message');
      }
    } catch (e) {
      debugPrint('[SocketService] ⚠️ Error adding user to grupousuario: $e');
    }
  }

  /*
   * Guarda mensaje
   * Envia archivos seleccionados
   */

  saveGrupo(payload, {String? d}) async {
    debugPrint('[SocketService] saveGrupo called');

    var grupo = payload["grupo"];

    var usuarioCrea = jsonEncode({
      'uid': grupo['usuarioCrea']['_id'],
      'nombre': grupo['usuarioCrea']['nombre'],
      'avatar': grupo['usuarioCrea']['avatar'],
      'codigoContacto': grupo['usuarioCrea']['codigoContacto'],
    });
    Grupo grupoNuevo = Grupo();
    grupoNuevo.codigo = grupo['codigo'];
    grupoNuevo.nombre = grupo['nombre'];
    grupoNuevo.descripcion = grupo['descripcion'];
    grupoNuevo.avatar = grupo['avatar'];
    grupoNuevo.fecha = grupo['fecha'];
    grupoNuevo.privateKey = d;
    grupoNuevo.publicKey = grupo['publicKey'];
    grupoNuevo.usuarioCrea = usuarioCrea.toString();
    await DBProvider.db.nuevoGrupo(grupoNuevo);
    debugPrint('[SocketService] ✅ Group saved: ${grupo['codigo']}');

    // CRITICAL FIX: Add current user to grupousuario table
    // This ensures the user can load messages from this group
    // Try to get user info from AuthService first, fallback to SharedPreferences
    try {
      String? currentUserId;
      String? codigoContacto;
      String? nombreUsuario;
      String? avatarUsuario;

      final authService = AuthService();
      if (authService.usuario != null) {
        currentUserId = authService.usuario!.uid;
        codigoContacto = authService.usuario!.codigoContacto;
        nombreUsuario = authService.usuario!.nombre;
        avatarUsuario = authService.usuario!.avatar;
      } else {
        // Fallback: Try to get user info from SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final usuarioJson = prefs.getString('usuario');
          if (usuarioJson != null) {
            final usuarioData = json.decode(usuarioJson);
            currentUserId = usuarioData['uid']?.toString();
            codigoContacto = usuarioData['codigoContacto']?.toString();
            nombreUsuario = usuarioData['nombre']?.toString();
            avatarUsuario = usuarioData['avatar']?.toString();
            debugPrint(
                '[SocketService] ✅ Retrieved user info from SharedPreferences for grupousuario');
          }
        } catch (e) {
          debugPrint(
              '[SocketService] ⚠️ Error reading user from SharedPreferences: $e');
        }
      }

      // If we have user ID, add to grupousuario
      if (currentUserId != null && currentUserId.isNotEmpty) {
        GrupoUsuario currentUserMembership = GrupoUsuario(
          codigoGrupo: grupo['codigo'],
          uidUsuario: currentUserId,
          codigoUsuario: codigoContacto ?? '',
          nombreUsuario: nombreUsuario ?? '',
          avatarUsuario: avatarUsuario ?? '',
        );
        await DBProvider.db
            .nuevoMiembro([currentUserMembership], grupo['codigo']);
        debugPrint(
            '[SocketService] ✅ Added current user ($currentUserId) to grupousuario for group ${grupo['codigo']}');
      } else {
        debugPrint(
            '[SocketService] ⚠️ Cannot add user to grupousuario - user ID not available (authService.usuario is null and SharedPreferences has no user data)');
      }
    } catch (e, stackTrace) {
      debugPrint('[SocketService] ⚠️ Error adding user to grupousuario: $e');
      debugPrint('[SocketService] Stack trace: $stackTrace');
    }

    // Also add the message sender to grupousuario if it's a different user
    // NOTE: For group messages, payload['de'] is the GROUP CODE, not the sender UID!
    // The actual sender UID is in payload['usuario']['_id'] or payload['usuario']['uid']
    try {
      if (payload['usuario'] != null) {
        var senderInfo = payload['usuario'];
        // Get sender UID from usuario object, NOT from payload['de'] (which is group code)
        final senderUid = senderInfo['_id']?.toString() ??
            senderInfo['uid']?.toString() ??
            '';

        if (senderUid.isNotEmpty) {
          GrupoUsuario senderMembership = GrupoUsuario(
            codigoGrupo: grupo['codigo'],
            uidUsuario: senderUid,
            codigoUsuario: senderInfo['codigoContacto']?.toString() ?? '',
            nombreUsuario: senderInfo['nombre']?.toString() ?? '',
            avatarUsuario: senderInfo['avatar']?.toString() ?? '',
          );
          await DBProvider.db.nuevoMiembro([senderMembership], grupo['codigo']);
          debugPrint(
              '[SocketService] ✅ Added sender ($senderUid) to grupousuario for group ${grupo['codigo']}');
        } else {
          debugPrint(
              '[SocketService] ⚠️ Could not get sender UID from usuario object');
        }
      }
    } catch (e) {
      debugPrint('[SocketService] ⚠️ Error adding sender to grupousuario: $e');
    }
  }

/*
Función para guardar archivo
 */
  Future<String> saveFile(type, archivo, fecha, ext) async {
    // Extract hash from archivo - handle multiple formats:
    // "/hash", "hash", or full URL
    String hash = archivo.toString();

    // Remove leading/trailing slashes and extract just the hash
    hash = hash.trim();
    if (hash.startsWith('/')) {
      hash = hash.substring(1);
    }
    if (hash.contains('/')) {
      // If it contains slashes, get the last part (the hash)
      hash = hash.split('/').last;
    }
    // Remove any query parameters or fragments
    if (hash.contains('?')) {
      hash = hash.split('?').first;
    }
    if (hash.contains('#')) {
      hash = hash.split('#').first;
    }

    // For images, return the server URL instead of local path
    // This enables network-first loading with automatic caching
    if (type == 'images') {
      String imageUrl = "${Environment.urlArchivos}$hash";
      debugPrint(
          '[SocketService] ✅ Image URL stored (network-first): $imageUrl');
      debugPrint(
          '[SocketService] Original archivo value: ${archivo.toString()}');
      return imageUrl;
    }

    // For other file types (videos, audio, documents), download to app storage
    String dir = (await getApplicationDocumentsDirectory()).path;
    var exten = ext;
    if (type == 'recording') exten = ext.split('&')[0];

    String urlFile = "$dir/" + fecha + exten;
    String urlDownload = "${Environment.urlArchivos}$hash";

    // Download the file immediately to ensure it exists when played
    try {
      final response = await http.get(Uri.parse(urlDownload));
      if (response.statusCode == 200) {
        final file = File(urlFile);
        await file.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('[SocketService] ✅ File downloaded to $urlFile');
      } else {
        debugPrint(
            '[SocketService] ⚠️ Download failed (${response.statusCode}) for $urlDownload');
      }
    } catch (e) {
      debugPrint('[SocketService] ❌ Error downloading file $urlDownload: $e');
    }

    return urlFile;
  }

  Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>?> getKeys() async {
    try {
      print('[SocketService] getKeys() called');
      final String? privateKey = await _storage.read(key: 'privateKey');
      final String? publicKey = await _storage.read(key: 'publicKey');

      print(
          '[SocketService] privateKey: ${privateKey != null ? "YES (length: ${privateKey.length})" : "NULL"}');
      print(
          '[SocketService] publicKey: ${publicKey != null ? "YES (length: ${publicKey.length})" : "NULL"}');

      if (privateKey == null) {
        print('[SocketService] ERROR: privateKey is null');
        return null;
      }

      if (publicKey == null) {
        print('[SocketService] ERROR: publicKey is null');
        return null;
      }

      print('[SocketService] Calling LocalCrypto().getKeyPairFromString()...');
      AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> key =
          LocalCrypto().getKeyPairFromString(privateKey, publicKey);
      print('[SocketService] ✅ Keys successfully parsed');
      myKey = key;
      return key;
    } catch (e, stackTrace) {
      print('[SocketService] ❌ ERROR in getKeys(): $e');
      print('[SocketService] Stack trace: $stackTrace');
      return null;
    }
  }

/*
Función guardar Archivo, BD, emitir acuse y notificar al aplicativo
NOTE: This function is called asynchronously to avoid blocking the UI thread
*/
  Future<void> saveFileAndNotify(payload, bool isgrp) async {
    await _processIncomingPayload(payload, isgrp, emitAck: true);
  }

  /// Show notification when receiving socket message while app is in background
  /// This handles the case where backend doesn't send FCM (user is online via socket)
  /// but app is actually in background state
  Future<void> _showBackgroundNotification(Map<String, dynamic> payload,
      {bool isGroup = false}) async {
    try {
      print(
          '[SocketService] Showing background notification for socket message');

      // Get sender info from payload
      final senderId = payload['de']?.toString();
      final recipientId = payload['para']?.toString();

      if (senderId == null) {
        print('[SocketService] No sender ID in payload, skipping notification');
        return;
      }

      // Get sender name - try from usuario object in payload, or fetch from DB
      String senderName = 'New Message';
      String? groupName;
      try {
        if (isGroup &&
            payload['grupo'] != null &&
            payload['grupo']['nombre'] != null) {
          // For group messages, use group name as sender
          groupName = payload['grupo']['nombre']?.toString();
          if (payload['usuario'] != null &&
              payload['usuario']['nombre'] != null) {
            final userName =
                payload['usuario']['nombre']?.toString() ?? 'Someone';
            senderName = '$userName in ${groupName ?? 'Group'}';
          } else {
            senderName = groupName ?? 'Group';
          }
        } else if (payload['usuario'] != null &&
            payload['usuario']['nombre'] != null) {
          senderName = payload['usuario']['nombre'];
        } else {
          // Try to get from local DB - use esContacto to check if contact exists
          // For now, use a generic name if we can't find the contact
          // The sender name will be shown in the notification
        }
      } catch (e) {
        print('[SocketService] Error getting sender name: $e');
      }

      // Get message content
      String messageBody = 'New message';
      try {
        Map<String, dynamic> mensajeData;
        if (payload['mensaje'] is String) {
          mensajeData = jsonDecode(payload['mensaje']);
        } else if (payload['mensaje'] is Map) {
          mensajeData = Map<String, dynamic>.from(payload['mensaje']);
        } else {
          return; // Invalid message format
        }

        final type = mensajeData['type']?.toString() ?? 'text';

        // Format message body based on type
        if (type == 'text') {
          // For text, we'd need to decrypt, but for notification we can show a generic message
          messageBody = 'Sent you a message';
        } else if (type == 'images') {
          messageBody = 'Sent you a photo';
        } else if (type == 'video') {
          messageBody = 'Sent you a video';
        } else if (type == 'recording' || type == 'audio') {
          messageBody = 'Sent you a voice message';
        } else if (type == 'documents') {
          messageBody = 'Sent you a document';
        } else {
          messageBody = 'Sent you a message';
        }
      } catch (e) {
        print('[SocketService] Error getting message content: $e');
        messageBody = 'New message';
      }

      // Get or initialize notification plugin
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize if not already initialized
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      // Only initialize if not already done (check by trying to show a notification)
      try {
        await flutterLocalNotificationsPlugin
            .initialize(initializationSettings);
      } catch (e) {
        // Might already be initialized, that's okay
        print(
            '[SocketService] Notification plugin may already be initialized: $e');
      }

      // Ensure notification channel exists
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Notifications for calls and messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Create notification payload for navigation
      final recipientIdForPayload = isGroup
          ? (payload['grupo']?['codigo']?.toString() ?? '')
          : (recipientId?.toString() ?? '');
      final notificationPayload = jsonEncode({
        'route': isGroup ? 'groupChat' : 'chat',
        'data': {
          'type': 'message',
          'senderId': senderId,
          'recipientId': recipientIdForPayload,
          'isGroup': isGroup,
        },
      });

      // CRITICAL: Generate notification ID from message fecha to prevent duplicates
      // Use fecha if available, otherwise use timestamp
      String messageFecha = '';
      try {
        Map<String, dynamic>? mensajeData;
        if (payload['mensaje'] is String) {
          mensajeData = jsonDecode(payload['mensaje']) as Map<String, dynamic>?;
        } else if (payload['mensaje'] is Map) {
          mensajeData = Map<String, dynamic>.from(payload['mensaje']);
        }
        if (mensajeData != null) {
          messageFecha = mensajeData['fecha']?.toString() ?? '';
        }
      } catch (e) {
        print('[SocketService] Error extracting fecha for notification ID: $e');
      }

      // Generate notification ID - use fecha if available for better deduplication
      final groupCode =
          isGroup ? (payload['grupo']?['codigo']?.toString() ?? '') : '';
      final recipientIdStr = recipientId?.toString() ?? '';
      final targetId = isGroup ? groupCode : recipientIdStr;
      final notificationIdKey = messageFecha.isNotEmpty
          ? '${senderId}_${targetId}_$messageFecha'
          : '${senderId}_${DateTime.now().millisecondsSinceEpoch}';
      final notificationId = notificationIdKey.hashCode;

      // Show the notification
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        senderName,
        messageBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(
              messageBody,
              contentTitle: senderName,
              summaryText: messageBody,
            ),
          ),
        ),
        payload: notificationPayload,
      );

      print('[SocketService] ✅ Background notification shown successfully');
    } catch (e, stackTrace) {
      print('[SocketService] ❌ Error showing background notification: $e');
      print('[SocketService] Stack trace: $stackTrace');
    }
  }

  Future<void> importHistoricalMessage(Map<String, dynamic> payload,
      {bool isGroup = false}) async {
    await _processIncomingPayload(payload, isGroup, emitAck: false);
  }

  Future<void> _processIncomingPayload(payload, bool isgrp,
      {required bool emitAck}) async {
    print('[SocketService] saveFileAndNotify called - isgrp: $isgrp');
    print('[SocketService] payload type: ${payload.runtimeType}');
    print(
        '[SocketService] payload keys: ${payload is Map ? payload.keys.toList() : 'not a map'}');

    try {
      // var urlFile = '';
      var ext = '';

      // Handle payload['mensaje'] - it might be a Map or a JSON string
      Map<String, dynamic> mensajeData;
      if (payload['mensaje'] is String) {
        print('[SocketService] mensaje is String, decoding...');
        mensajeData = jsonDecode(payload['mensaje']);
      } else if (payload['mensaje'] is Map) {
        print('[SocketService] mensaje is already a Map');
        mensajeData = Map<String, dynamic>.from(payload['mensaje']);
      } else {
        print(
            '[SocketService] ERROR: mensaje is neither String nor Map: ${payload['mensaje'].runtimeType}');
        throw Exception(
            'Invalid mensaje type: ${payload['mensaje'].runtimeType}');
      }

      // Handle content - might be 'content' or 'ciphertext'
      var contentEncrypted =
          mensajeData['content'] ?? mensajeData['ciphertext'];
      String decrypted = "";

      var type = mensajeData['type'];
      print('[SocketService] Message type: $type');

      // Handle fecha - might be in mensajeData['fecha'] or payload['createdAt']/['updatedAt']
      String fechaStr;
      if (mensajeData['fecha'] != null) {
        fechaStr = mensajeData['fecha'];
      } else if (payload['createdAt'] != null) {
        fechaStr = payload['createdAt'];
      } else if (payload['updatedAt'] != null) {
        fechaStr = payload['updatedAt'];
      } else {
        // Fallback to current time
        fechaStr = DateTime.now().toUtc().toIso8601String();
        print('[SocketService] WARNING: No fecha found, using current time');
      }

      // CRITICAL: Extract numeric fecha - fecha format must be pure numeric (e.g., "20251215204742123")
      // This is required because GroupProvider and ChatProvider use int.parse() on fecha
      String fecha;

      // If fechaStr already looks like a numeric fecha (all digits), use it directly
      if (RegExp(r'^\d+$').hasMatch(fechaStr)) {
        fecha = fechaStr;
        // Ensure it's exactly 17 digits (standard format: YYYYMMDDHHmmssSSS)
        if (fecha.length > 17) {
          fecha = fecha.substring(0, 17);
        } else if (fecha.length < 17 && fecha.isNotEmpty) {
          fecha = fecha.padRight(17, '0');
        }
      } else {
        // fechaStr contains non-digits (e.g., ISO format "2025-12-15T20:47:42Z")
        // Remove 'Z' suffix if present, then extract numeric part
        String cleaned =
            fechaStr.contains('Z') ? fechaStr.split('Z')[0] : fechaStr;
        // Remove all non-digit characters to get pure numeric fecha
        String numericFecha = cleaned.replaceAll(RegExp(r'[^\d]'), '');
        // Take first 17 digits (standard fecha format)
        if (numericFecha.length > 17) {
          numericFecha = numericFecha.substring(0, 17);
        } else if (numericFecha.length < 17 && numericFecha.isNotEmpty) {
          // Pad with zeros if too short
          numericFecha = numericFecha.padRight(17, '0');
        }
        fecha = numericFecha;
      }

      print(
          '[SocketService] Message fecha (cleaned): $fecha (original: $fechaStr)');

      var timezone = fechaStr.contains('Z') ? fechaStr.split('Z')[1] : '';

      // Check if timezone is negative (unused but kept for potential future use)
      timezone.startsWith('-');

      // Get UTC offset (unused but kept for potential future use)
      DateTime.now().timeZoneOffset;

      if (type == 'images' ||
          type == 'recording' ||
          type == 'video' ||
          type == 'documents' ||
          type == 'audio') {
        print('[SocketService] Processing file type: $type');
        decrypted = contentEncrypted;
        ext = mensajeData['extension'] ?? '';

        // Process file asynchronously
        try {
          final value = await saveFile(type, decrypted, fecha, ext);
          print('[SocketService] File saved: $value');
          // #region agent log
          final debugLogPath = r'd:\locksyy\.cursor\debug.log';
          try {
            final debugEntry = {
              'location': 'socket_service.dart:1502',
              'message': 'Saving file message to DB',
              'data': {
                'type': type,
                'isgrp': isgrp,
                'fecha': fecha,
                'hasPayload': payload != null,
                'payloadGrupo': payload?['grupo'] != null,
                'grupoCodigo': payload?['grupo']?['codigo'],
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'sessionId': 'debug-session',
              'hypothesisId': 'C'
            };
            File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
                mode: FileMode.append);
          } catch (_) {}
          // #endregion

          await persistMessajeLocal(type, value, fecha, ext, payload);

          // #region agent log
          try {
            final debugEntry = {
              'location': 'socket_service.dart:1520',
              'message': 'File message saved to DB',
              'data': {'type': type, 'isgrp': isgrp},
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'sessionId': 'debug-session',
              'hypothesisId': 'C'
            };
            File(debugLogPath).writeAsStringSync('${jsonEncode(debugEntry)}\n',
                mode: FileMode.append);
          } catch (_) {}
          // #endregion

          if (emitAck) {
            emitirAcuseRecibo(payload);
          }
          notifyListeners();
        } catch (error) {
          print('[SocketService] Error saving file: $error');
        }
      } else {
        print('[SocketService] Processing text message - isgrp: $isgrp');
        if (isgrp) {
          print('[SocketService] Decrypting group message');
          String EncryptedPrivateKey = payload["grupo"]["privateKey"];
          String y12 = payload["grupo"]["publicKey"];
          String decryptedprivateKeyString =
              LocalCrypto().decrypt('Cryp16Zbqc@#4D%8', EncryptedPrivateKey);
          AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> grpKey = LocalCrypto()
              .getKeyPairFromString(decryptedprivateKeyString, y12);
          decrypted = utf8.decode(
              rsaDecrypt(grpKey.privateKey, base64.decode(contentEncrypted)));
          print('[SocketService] Group message decrypted successfully');
          await persistMessajeLocal(type, decrypted, fecha, ext, payload,
              d: decryptedprivateKeyString);
          if (emitAck) {
            emitirAcuseRecibo(payload);
          }
          notifyListeners();
        } else {
          print('[SocketService] Decrypting personal message');
          // Check if myKey is initialized
          if (myKey == null) {
            print(
                '[SocketService] ERROR: myKey is not initialized, attempting to load keys...');
            final key = await getKeys();
            if (key != null) {
              myKey = key;
              print('[SocketService] Keys loaded, retrying decryption...');
              // Retry decryption
              try {
                decrypted = utf8.decode(rsaDecrypt(
                    myKey!.privateKey, base64.decode(contentEncrypted)));
                print('[SocketService] Message decrypted successfully');
                await persistMessajeLocal(type, decrypted, fecha, ext, payload);
                if (emitAck) {
                  emitirAcuseRecibo(payload);
                }
                notifyListeners();
              } catch (e) {
                print('[SocketService] ERROR retrying decryption: $e');
                // Still send ACK but don't save - message can't be decrypted
                if (emitAck) {
                  emitirAcuseRecibo(payload);
                }
                return;
              }
            } else {
              print(
                  '[SocketService] ERROR: Could not load keys, message cannot be decrypted');
              // CRITICAL: Always send ACK to server even if we can't decrypt
              // This prevents the server from resending the message
              if (emitAck) {
                emitirAcuseRecibo(payload);
              }
              print(
                  '[SocketService] ⚠️ Message received but cannot be decrypted - keys unavailable');
              // Don't save the message if we can't decrypt it - it would be useless
              return;
            }
          } else {
            try {
              decrypted = utf8.decode(rsaDecrypt(
                  myKey!.privateKey, base64.decode(contentEncrypted)));
              print('[SocketService] Message decrypted successfully');
              await persistMessajeLocal(type, decrypted, fecha, ext, payload);
              if (emitAck) {
                emitirAcuseRecibo(payload);
              }
              notifyListeners();
            } catch (decryptError) {
              // Handle decryption errors gracefully (e.g., old messages encrypted with old keys)
              print(
                  '[SocketService] ⚠️ Decryption failed - message may be encrypted with old keys');
              print('[SocketService] Decryption error: $decryptError');

              // Fallback: if this message was sent by us and contentEncrypted is plain text,
              // persist it without decrypting so our own history shows after cache clear.
              try {
                final myUid = await _getCurrentUserId();
                if (myUid != null &&
                    payload['de']?.toString() == myUid &&
                    contentEncrypted is String &&
                    contentEncrypted.isNotEmpty) {
                  final fallbackPlaintext = contentEncrypted;
                  print(
                      '[SocketService] Using plaintext fallback for own message (uid=$myUid)');
                  await persistMessajeLocal(
                      type, fallbackPlaintext, fecha, ext, payload);
                  if (emitAck) {
                    emitirAcuseRecibo(payload);
                  }
                  notifyListeners();
                  return;
                }
              } catch (e) {
                print('[SocketService] Fallback for own message failed: $e');
              }

              // Still send ACK to server to acknowledge receipt
              if (emitAck) {
                emitirAcuseRecibo(payload);
              }
              // Don't notify listeners - message can't be displayed
              return;
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('[SocketService] ERROR in saveFileAndNotify: $e');
      print('[SocketService] Stack trace: $stackTrace');
      print('[SocketService] Payload: $payload');
    }
  }

  stateChatPage() async {
    var prefs = await SharedPreferences.getInstance();
    var res = prefs.getString('ChatPage');
    return res;
  }

  void disconnect({bool intentional = true}) {
    _intentionalDisconnect = intentional;
    _throttleTimer?.cancel();
    _reconnectTimer?.cancel();
    // Remove lifecycle observer when disconnecting
    WidgetsBinding.instance.removeObserver(this);
    try {
      _socket?.disconnect();
    } catch (_) {}
  }

/*
 * Función de cambiar descargando
 */
  void _cambiarDescargando(double val) {
    // String valor = (val * 100).toStringAsFixed(0) + '%';

    if (val != 100.0) {
      _porcentajeDescarga = val.toString();
      _descargando = true;
      notifyListeners();
    } else {
      _porcentajeDescarga = val.toString();
      _descargando = false;
      notifyListeners();
    }
  }

  initSocketCon() async {
    final token = await AuthService.getToken();
    final pushProvider = PushNotifications();

    await pushProvider.initNotifications().then((value) {
      if (value != null && value.isNotEmpty) {
        print(
            '[SocketService] ✅ FCM Token obtained for initSocketCon: ${value.substring(0, 20)}...');
      } else {
        print(
            '[SocketService] ⚠️ WARNING: FCM Token is null or empty in initSocketCon!');
      }
      _socket = IO.io(Environment.socketUrl, {
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
        'extraHeaders': {'x-token': token, 'firebaseid': value ?? ''}
      });
    });
  }

  getOfflineData(uid) {
    emit("get-offline-data", {
      "uid": uid,
    });
  }

  refreshDownloadFile() async {
    try {
      // STATUSES
      //0:UNDEFINED
      //1:ENQUEUED
      //2:RUNNING
      //3:COMPLETE
      //4:FAILED
      //5:CANCELED
      //6:PAUSED

      List<DownloadTask>? tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task",
      );
      if (tasks != null && tasks.isNotEmpty) {
        for (final task in tasks) {
          if (task.status == DownloadTaskStatus.complete) {
            // Verify file integrity before caching
            final filePath = '${task.savedDir}/${task.filename}';
            final file = File(filePath);
            if (await file.exists()) {
              final length = await file.length();
              if (length > 0) {
                // Verify file is valid before marking as available
                final isValid = await _verifyFileIsValid(filePath, length);
                if (isValid) {
                  FileCacheService().setFileExists(filePath, true);
                  debugPrint(
                      '[SocketService] ✅ File verified in refreshDownloadFile: $filePath');
                  // Remove task after successful validation
                  await FlutterDownloader.remove(taskId: task.taskId);
                } else {
                  debugPrint(
                      '[SocketService] ⚠️ File failed validation in refreshDownloadFile: $filePath');
                  FileCacheService().clearCache(filePath);
                  // Delete corrupted file
                  try {
                    await file.delete();
                    debugPrint(
                        '[SocketService] Deleted corrupted file in refreshDownloadFile: $filePath');
                  } catch (e) {
                    debugPrint(
                        '[SocketService] Error deleting corrupted file: $e');
                  }
                  // Remove task to prevent re-download attempts that could hit HTTP 416
                  await FlutterDownloader.remove(taskId: task.taskId);
                  debugPrint(
                      '[SocketService] Removed corrupted task to force fresh download: ${task.taskId}');
                }
              } else {
                // Zero-byte file - delete and remove task
                FileCacheService().clearCache(filePath);
                try {
                  await file.delete();
                } catch (e) {
                  debugPrint(
                      '[SocketService] Error deleting zero-byte file: $e');
                }
                await FlutterDownloader.remove(taskId: task.taskId);
              }
            } else {
              // File doesn't exist - remove task
              FileCacheService().clearCache(filePath);
              await FlutterDownloader.remove(taskId: task.taskId);
            }
          } else if (task.status == DownloadTaskStatus.failed) {
            // Clear cache for failed downloads
            final filePath = '${task.savedDir}/${task.filename}';
            FileCacheService().clearCache(filePath);
            // Delete incomplete file if it exists
            final file = File(filePath);
            if (await file.exists()) {
              try {
                await file.delete();
                debugPrint(
                    '[SocketService] Deleted incomplete file from failed download: $filePath');
              } catch (e) {
                debugPrint(
                    '[SocketService] Error deleting incomplete file: $e');
              }
            }
            // Remove failed task instead of retrying to prevent HTTP 416 loops
            await FlutterDownloader.remove(taskId: task.taskId);
            debugPrint(
                '[SocketService] Removed failed download task to prevent retry loop: ${task.taskId}');
          } else {
            // For other statuses (RUNNING, PAUSED, etc), leave them as-is
            // Don't automatically retry as it might cause issues
          }
        }
      }
    } catch (e) {
      //print(e);
    }
  }

  Future<bool> requestStoragePermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    var storageIsGranted = await Permission.storage.isGranted;

    var manageExternalStorageIsGranted =
        await Permission.manageExternalStorage.isGranted;

    var isGranted = storageIsGranted && manageExternalStorageIsGranted;
    return isGranted;
  }

  addDownloadFile(urlArchivoServer, nombreArchivo) async {
    // try {
    String dir = (await getApplicationDocumentsDirectory()).path;

    await requestStoragePermissions();

    await FlutterDownloader.enqueue(
      url: urlArchivoServer,
      savedDir: dir,
      fileName: nombreArchivo,
      showNotification: false,
      openFileFromNotification: false,
      //saveInPublicStorage: false,
      allowCellular: true,
    );
    // Callback is registered once in initDownloaderTask(), not here
    // ReceivePort _port = ReceivePort();
    // _port.listen((dynamic data) {
    //   String id = data[0];
    //   DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
    //   int progress = data[2];
    //   //print("_port = ReceivePort(); ======== [${id},${status},${progress}]");
    // });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _intentionalDisconnect = true;
    _throttleTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  /// Verify that a file is valid and can be read (especially for images)
  /// Returns true only if file is complete and can be decoded
  Future<bool> _verifyFileIsValid(String filePath, int fileLength) async {
    try {
      final file = File(filePath);

      // Basic checks
      if (fileLength == 0) {
        return false;
      }

      // Verify file actually exists
      if (!await file.exists()) {
        return false;
      }

      final actualLength = await file.length();
      if (actualLength == 0) {
        debugPrint('[SocketService] File has zero size: $filePath');
        return false;
      }

      // Verify file size is reasonable (not suspiciously small for images)
      if (_isImageFile(filePath) && actualLength < 100) {
        debugPrint(
            '[SocketService] Image file suspiciously small: $filePath ($actualLength bytes)');
        return false;
      }

      // For HTTP 416 cases: check if file appears incomplete
      // If file length doesn't match expected or is suspiciously small, it might be corrupted
      if (_isImageFile(filePath)) {
        // Images should typically be at least a few KB
        if (actualLength < 1024) {
          debugPrint(
              '[SocketService] Image file too small (likely incomplete): $filePath ($actualLength bytes)');
          return false;
        }
      }

      // For image files, use comprehensive validation
      if (_isImageFile(filePath)) {
        return await _verifyImageFile(file, filePath, actualLength);
      }

      // For non-image files, basic validation is sufficient
      return true;
    } catch (e) {
      debugPrint('[SocketService] Error validating file: $filePath - $e');
      return false;
    }
  }

  /// Verify image file integrity using production-ready validation
  Future<bool> _verifyImageFile(File file, String filePath, int length) async {
    try {
      // Minimum size check
      if (length < 100) {
        debugPrint(
            '[SocketService] Image file too small: $filePath ($length bytes)');
        return false;
      }

      // Lightweight header validation - only read first 100 bytes
      try {
        final stream = file.openRead(0, 100);
        final chunks = await stream.toList();
        final headerBytes = chunks.expand((x) => x).toList();

        if (headerBytes.isEmpty || headerBytes.length < 10) {
          debugPrint('[SocketService] Image header too small: $filePath');
          return false;
        }

        final ext = filePath.toLowerCase().split('.').last;

        // JPEG: FF D8 FF
        if (ext == 'jpg' || ext == 'jpeg') {
          if (headerBytes.length >= 3 &&
              headerBytes[0] == 0xFF &&
              headerBytes[1] == 0xD8 &&
              headerBytes[2] == 0xFF) {
            debugPrint('[SocketService] ✅ Valid JPEG header: $filePath');
            return true;
          }
        }

        // PNG: 89 50 4E 47
        if (ext == 'png') {
          if (headerBytes.length >= 4 &&
              headerBytes[0] == 0x89 &&
              headerBytes[1] == 0x50 &&
              headerBytes[2] == 0x4E &&
              headerBytes[3] == 0x47) {
            debugPrint('[SocketService] ✅ Valid PNG header: $filePath');
            return true;
          }
        }

        // For other formats or if header inconclusive, accept if size is reasonable
        if (length >= 1000) {
          debugPrint('[SocketService] ⚠️ Accepting file (size OK): $filePath');
          return true;
        }

        debugPrint('[SocketService] ❌ Image validation failed: $filePath');
        return false;
      } catch (e) {
        debugPrint('[SocketService] Error reading header: $filePath - $e');
        // If we can't read header but file exists with reasonable size, be lenient
        if (length >= 1000) {
          debugPrint(
              '[SocketService] ⚠️ Header read failed but accepting (size OK): $filePath');
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint(
          '[SocketService] Image file verification error: $filePath - $e');
      return false;
    }
  }

  /// Check if file is an image based on extension
  bool _isImageFile(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  initDownloaderTask() async {
    try {
      debugPrint('[SocketService] Initializing download task...');

      // Remove any existing port registration first (from previous sessions)
      try {
        IsolateNameServer.removePortNameMapping('downloader_send_port');
        debugPrint('[SocketService] Cleaned up existing port registration');
      } catch (e) {
        debugPrint(
            '[SocketService] No existing port to clean up (normal on first run)');
      }

      _port = ReceivePort();
      final registered = IsolateNameServer.registerPortWithName(
          _port.sendPort, 'downloader_send_port');

      if (!registered) {
        debugPrint(
            '[SocketService] ⚠️ Failed to register port - trying to clean and retry');
        IsolateNameServer.removePortNameMapping('downloader_send_port');
        final retryRegistered = IsolateNameServer.registerPortWithName(
            _port.sendPort, 'downloader_send_port');
        if (!retryRegistered) {
          throw Exception('Failed to register downloader port');
        }
      }

      debugPrint('[SocketService] Port registered successfully');

      _port.listen((dynamic data) async {
        try {
          String? id = data[0];
          int statusInt = data[1];
          int progress = data[2];

          debugPrint(
              '[SocketService] Download callback received: id=$id, status=$statusInt, progress=$progress%');

          // Handle progress updates
          if (progress < 100) {
            _cambiarDescargando(progress.toDouble());
            return;
          }

          // Handle download completion (status 3 = COMPLETE) and failures (status 4 = FAILED)
          DownloadTaskStatus status = DownloadTaskStatus.fromInt(statusInt);
          if (id != null) {
            // Get download task details
            List<DownloadTask>? tasks =
                await FlutterDownloader.loadTasksWithRawQuery(
              query: "SELECT * FROM task WHERE task_id='$id';",
            );

            if (tasks != null && tasks.isNotEmpty) {
              final task = tasks.first;
              final filePath = '${task.savedDir}/${task.filename}';

              if (status == DownloadTaskStatus.complete) {
                debugPrint(
                    '[SocketService] Download completed: taskId=$id, file=$filePath');

                // IMPORTANT: Even though status is "complete", HTTP 416 errors can leave corrupted files
                // Always verify file integrity before marking as available
                final file = File(filePath);
                if (await file.exists()) {
                  final length = await file.length();
                  debugPrint(
                      '[SocketService] File exists with length: $length bytes');

                  // Only mark as available if file has non-zero size AND can be validated
                  if (length > 0) {
                    // Verify file is actually valid - this catches HTTP 416 corrupted files
                    debugPrint('[SocketService] Validating file: $filePath');
                    final isValid = await _verifyFileIsValid(filePath, length);
                    if (isValid) {
                      debugPrint(
                          '[SocketService] ✅ File verified and marked as available: $filePath ($length bytes)');
                      FileCacheService().setFileExists(filePath, true);
                      // Remove task from FlutterDownloader database after successful download
                      await FlutterDownloader.remove(taskId: id);
                      debugPrint(
                          '[SocketService] Removed completed download task: $id');
                      notifyListeners(); // Notify UI that file is ready
                    } else {
                      debugPrint(
                          '[SocketService] ⚠️ File failed validation: $filePath');
                      FileCacheService().clearCache(filePath);
                      // Delete corrupted/incomplete file
                      try {
                        await file.delete();
                        debugPrint(
                            '[SocketService] Deleted corrupted file: $filePath');
                      } catch (e) {
                        debugPrint(
                            '[SocketService] Error deleting corrupted file: $e');
                      }
                      // CRITICAL: Remove the task from FlutterDownloader to prevent infinite retry loop
                      // This forces a fresh download instead of trying to resume from corrupted state
                      await FlutterDownloader.remove(taskId: id);
                      debugPrint(
                          '[SocketService] Removed corrupted download task to force fresh download: $id');
                    }
                  } else {
                    debugPrint(
                        '[SocketService] File has zero size, not marking as available: $filePath');
                    FileCacheService().clearCache(filePath);
                    // Delete zero-byte file
                    try {
                      await file.delete();
                    } catch (e) {
                      debugPrint(
                          '[SocketService] Error deleting zero-byte file: $e');
                    }
                    // Remove task to force fresh download
                    await FlutterDownloader.remove(taskId: id);
                  }
                } else {
                  debugPrint(
                      '[SocketService] File does not exist after download completion: $filePath');
                  FileCacheService().clearCache(filePath);
                  // Remove task to force fresh download
                  await FlutterDownloader.remove(taskId: id);
                }
              } else if (status == DownloadTaskStatus.failed) {
                debugPrint(
                    '[SocketService] ⚠️ Download failed: $id for file: $filePath');
                // Clear cache for failed downloads
                FileCacheService().clearCache(filePath);
                // Delete incomplete file if it exists
                final file = File(filePath);
                if (await file.exists()) {
                  try {
                    await file.delete();
                    debugPrint(
                        '[SocketService] Deleted incomplete file from failed download: $filePath');
                  } catch (e) {
                    debugPrint(
                        '[SocketService] Error deleting incomplete file: $e');
                  }
                }
                // Remove failed task from database to allow fresh retry
                await FlutterDownloader.remove(taskId: id);
                debugPrint('[SocketService] Removed failed download task: $id');
              }
            }
          }
        } catch (e) {
          debugPrint('[SocketService] Error handling download callback: $e');
        }
      });

      // Register the callback once here, not in addDownloadFile
      debugPrint('[SocketService] Registering FlutterDownloader callback...');
      try {
        await FlutterDownloader.registerCallback(downloadCallback);
        debugPrint(
            '[SocketService] ✅ Download callback registered successfully');
      } catch (callbackError) {
        debugPrint(
            '[SocketService] ❌ Error registering callback: $callbackError');
        rethrow;
      }
    } catch (e, stackTrace) {
      debugPrint('[SocketService] ❌ Error initializing downloader: $e');
      debugPrint('[SocketService] Stack trace: $stackTrace');
    }
  }

  /// Process message queue when connection is established
  Future<void> _processMessageQueue() async {
    if (_socket == null || !_socket!.connected) {
      print('[SocketService] Cannot process queue - socket not connected');
      return;
    }

    try {
      final queueService = MessageQueueService();
      final sentCount = await queueService.processQueue((event, payload) async {
        // Use emitAck to send the message
        final result = emitAck(event, payload);
        // emitAck always returns a Future, so await it
        final ackResult = await result;
        // Check if acknowledgment was received (null means timeout or error)
        if (ackResult != null) {
          return ackResult;
        }
        return null;
      });

      if (sentCount > 0) {
        print('[SocketService] ✅ Processed $sentCount queued messages');
        notifyListeners();
      }
    } catch (e) {
      print('[SocketService] Error processing message queue: $e');
    }
  }
}
