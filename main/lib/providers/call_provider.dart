import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../services/call_notification_service.dart';

// Debug logging helper - logs to both file (if accessible) and print for release APK
void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
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

enum CallState {
  idle,
  calling,
  ringing,
  connected,
  ended,
}

enum CallType {
  audio,
  video,
}

class CallProvider extends ChangeNotifier {
  SocketService? _socketService;
  AuthService? _authService;
  GlobalKey<NavigatorState>? _navigatorKey;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallState _callState = CallState.idle;
  CallType? _callType;
  String? _callerId;
  String? _recipientId;
  String? _callerName;
  String? _callerAvatar;
  String? _recipientName;
  String? _recipientAvatar;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = false;

  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  bool _isInitialized = false;

  // CRITICAL: WebRTC buffering system for race conditions (especially cold start)
  bool _isWebRTCReady = false;
  final List<Map<String, dynamic>> _pendingSignals =
      []; // Buffer offer/answer until WebRTC is ready
  final List<Map<String, dynamic>> _pendingIceCandidates =
      []; // Buffer ICE candidates until WebRTC is ready
  String? _roomId; // Store room ID for call-accepted event

  // Getters
  CallState get callState => _callState;
  CallType? get callType => _callType;
  String? get callerId => _callerId;
  String? get recipientId => _recipientId;
  String? get callerName => _callerName;
  String? get callerAvatar => _callerAvatar;
  String? get recipientName => _recipientName;
  String? get recipientAvatar => _recipientAvatar;

  // Helper to get the other party's name (caller if we're receiver, recipient if we're caller)
  String? get otherPartyName {
    if (_callerId != null && _recipientId == null) {
      // We're receiving a call - show caller name
      return _callerName;
    } else if (_recipientId != null && _callerId == null) {
      // We're making a call - show recipient name
      return _recipientName;
    }
    return _callerName ?? _recipientName;
  }

  // Helper to get the other party's avatar
  String? get otherPartyAvatar {
    if (_callerId != null && _recipientId == null) {
      // We're receiving a call - show caller avatar
      return _callerAvatar;
    } else if (_recipientId != null && _callerId == null) {
      // We're making a call - show recipient avatar
      return _recipientAvatar;
    }
    return _callerAvatar ?? _recipientAvatar;
  }

  // Check if we're the caller (initiated the call)
  bool get isCaller => _recipientId != null && _callerId == null;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  Duration get callDuration => _callDuration;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isInitialized => _isInitialized;

  void initialize(SocketService socketService, AuthService authService,
      GlobalKey<NavigatorState> navigatorKey) {
    if (_isInitialized) {
      print(
          '[CallProvider] ⚠️ Already initialized, skipping duplicate initialization');
      return; // Prevent duplicate initialization
    }
    _socketService = socketService;
    _authService = authService;
    _navigatorKey = navigatorKey;
    _isInitialized = true;
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    if (_socketService == null || _socketService!.socket == null) {
      // If not connected, wait for connection
      _socketService?.socket?.once('connect', (_) {
        _setupSocketListeners();
      });
      return;
    }

    if (!_socketService!.socket!.connected) {
      // Wait for connection
      _socketService!.socket?.once('connect', (_) {
        _setupSocketListeners();
      });
      return;
    }

    // Remove existing listeners to avoid duplicates
    _socketService!.socket?.off('newOffer');
    _socketService!.socket?.off('answer');
    _socketService!.socket?.off('candidate');
    _socketService!.socket?.off('acceptNewCall');
    _socketService!.socket?.off('call-accepted');
    _socketService!.socket?.off('endCall');
    _socketService!.socket
        ?.off('call-ended'); // Also remove call-ended listener

    // Listen for incoming offer
    _socketService!.socket?.on('newOffer', (data) {
      print('[CallProvider] Received newOffer event: $data');
      _handleIncomingOffer(data);
      // Note: _handleIncomingOffer will trigger the callback
    });

    // Listen for answer
    _socketService!.socket?.on('answer', (data) {
      print('[CallProvider] Received answer: $data');
      _handleAnswer(data);
    });

    // Listen for ICE candidates
    _socketService!.socket?.on('candidate', (data) {
      print('[CallProvider] 🧊 Received ICE candidate from remote peer');
      print(
          '[CallProvider] Candidate data: ${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}...');
      _handleIceCandidate(data);
    });

    // Listen for call acceptance (backward compatibility)
    _socketService!.socket?.on('acceptNewCall', (data) {
      print('[CallProvider] Received acceptNewCall: $data');
      _handleCallAccepted(data);
    });

    // CRITICAL: Listen for call-accepted event (new standard event name)
    _socketService!.socket?.on('call-accepted', (data) {
      print('[CallProvider] Received call-accepted: $data');
      _handleCallAccepted(data);
    });

    // CRITICAL: Listen for call end events (backend uses 'endCall')
    // Also listen for 'call-ended' for backward compatibility
    _socketService!.socket?.on('endCall', (data) {
      print('[CallProvider] Received endCall event: $data');
      _handleCallEnded();
    });

    _socketService!.socket?.on('call-ended', (data) {
      print('[CallProvider] Received call-ended event: $data');
      _handleCallEnded();
    });

    // Also listen for reconnect to re-establish listeners
    _socketService!.socket?.once('reconnect', (_) {
      print('[CallProvider] Socket reconnected, re-establishing listeners');
      _setupSocketListeners();
    });
  }

  Future<void> makeCall(String recipientId, String recipientName,
      String? recipientAvatar, CallType type) async {
    if (_callState != CallState.idle) return;

    _recipientId = recipientId;
    _recipientName = recipientName;
    _recipientAvatar = recipientAvatar;
    _callType = type;
    _callState = CallState.calling;
    notifyListeners();

    try {
      // Request permissions
      if (type == CallType.video) {
        await _requestPermissions([Permission.camera, Permission.microphone]);
      } else {
        await _requestPermissions([Permission.microphone]);
      }

      // Get local media stream
      await _getLocalStream(type == CallType.video);

      // CRITICAL: Ensure audio and video tracks are enabled for outgoing calls
      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enabled = true;
          print(
              '[CallProvider] Outgoing call - Audio track enabled: ${track.label}');
        });

        if (type == CallType.video) {
          _localStream!.getVideoTracks().forEach((track) {
            track.enabled = true;
            print(
                '[CallProvider] Outgoing call - Video track enabled: ${track.label}');
          });
        }
      }

      // Create peer connection
      await _createPeerConnection();

      // Add local stream tracks
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection?.addTrack(track, _localStream!);
          print('[CallProvider] Added ${track.kind} track to peer connection');
        });
      }

      // Create and set local description
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // CRITICAL: Generate or use roomId for call tracking
      _roomId =
          '${_authService?.usuario?.uid}_${recipientId}_${DateTime.now().millisecondsSinceEpoch}';

      // IMPORTANT: Emit startCall FIRST to trigger FCM notification
      // This ensures the recipient gets a push notification even if app is closed
      // Backend should send DATA-only message (no notification block) for calls
      _socketService!.socket?.emit('startCall', {
        'recipientId': recipientId,
        'callerId': _authService?.usuario?.uid,
        'isVideoCall': type == CallType.video,
        'roomId': _roomId, // Include roomId for call tracking
      });
      print(
          '[CallProvider] ✅ startCall event emitted for FCM notification (roomId: $_roomId)');

      // CRITICAL: Send offer through socket for WebRTC connection
      // Backend expects: recipientId, sdp, type, callerId, isVideoCall
      _socketService!.socket?.emit('newOffer', {
        'recipientId': recipientId, // CRITICAL: Backend routes to this user
        'sdp': offer.sdp,
        'type': offer.type,
        'callerId': _authService?.usuario?.uid,
        'isVideoCall': type == CallType.video,
        'roomId': _roomId, // Include roomId for call tracking
      });
      print(
          '[CallProvider] ✅ newOffer event emitted for WebRTC (recipientId: $recipientId)');

      _callState = CallState.ringing;
      notifyListeners();
    } catch (e) {
      print('[CallProvider] Error making call: $e');
      _endCall();
    }
  }

  void _handleIncomingOffer(Map<String, dynamic> data) {
    // CRITICAL: Prevent duplicate handling - check FIRST before any processing
    // This prevents both FCM and socket from triggering duplicate calls
    final incomingCallerId = data['callerId']?.toString();
    if (_callState != CallState.idle) {
      if (_callerId == incomingCallerId && _callState == CallState.ringing) {
        print(
            '[CallProvider] ⚠️ DUPLICATE: Already handling call from $incomingCallerId, ignoring');
        return;
      }
      print(
          '[CallProvider] ⚠️ Call state not idle ($_callState), ignoring new offer');
      return;
    }

    // CRITICAL: Buffer offer if WebRTC is not ready yet (race condition prevention)
    if (!_isWebRTCReady || _peerConnection == null) {
      print('[CallProvider] ⚠️ WebRTC not ready, buffering offer...');
      _pendingSignals.add({'type': 'offer', 'data': data});
      // Still update call state and UI even if WebRTC isn't ready
      _callerId = incomingCallerId;
      _callType = data['isVideoCall'] == true ? CallType.video : CallType.audio;
      _callState = CallState.ringing;
      if (data['callerName'] != null) {
        _callerName = data['callerName'].toString();
      }
      if (data['callerAvatar'] != null) {
        _callerAvatar = data['callerAvatar'].toString();
      }
      _roomId = data['roomId']?.toString();
      notifyListeners();

      // Navigate to incoming call page using global navigator
      _navigateToIncomingCallPage(data);
      return;
    }

    print('[CallProvider] Handling incoming offer from: ${data['callerId']}');
    _callerId = data['callerId']?.toString();
    _callType = data['isVideoCall'] == true ? CallType.video : CallType.audio;
    _callState = CallState.ringing;
    _roomId = data['roomId']?.toString();

    // Get caller name and avatar from backend data
    if (data['callerName'] != null) {
      _callerName = data['callerName'].toString();
    }
    if (data['callerAvatar'] != null) {
      _callerAvatar = data['callerAvatar'].toString();
    }

    // Store offer SDP for later use
    _pendingOfferSdp = data['sdp']?.toString();
    _pendingOfferType = data['type']?.toString();

    print(
        '[CallProvider] Incoming call - Caller: $_callerName, Type: $_callType, State: $_callState');
    notifyListeners();

    // Navigate to incoming call page using global navigator
    _navigateToIncomingCallPage(data);
  }

  String? _pendingOfferSdp;
  String? _pendingOfferType;

  // Navigate to incoming call page with route guards
  void _navigateToIncomingCallPage(Map<String, dynamic> data) {
    if (_navigatorKey?.currentState == null) {
      print('[CallProvider] ⚠️ Navigator not available, cannot navigate');
      return;
    }

    try {
      // CRITICAL: Check if already on incoming call page (prevent duplicate navigation)
      final context = _navigatorKey!.currentState!.context;
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute == 'incomingCall') {
        print(
            '[CallProvider] ⚠️ Already on incoming call page, skipping navigation');
        return;
      }

      // Navigate to incoming call page
      print('[CallProvider] Navigating to incoming call page');
      _navigatorKey!.currentState!.pushNamed(
        'incomingCall',
        arguments: {
          'callerId': data['callerId'],
          'callerName': data['callerName'] ?? _callerName ?? 'Unknown',
          'callerAvatar': data['callerAvatar'] ?? _callerAvatar,
          'isVideoCall':
              data['isVideoCall'] == true || data['isVideoCall'] == 'true',
          'sdp': data['sdp'],
          'rtcType': data['type'] ?? 'offer',
        },
      );
      print('[CallProvider] ✅ Navigation to incoming call page successful');
    } catch (e) {
      print('[CallProvider] ❌ Error navigating to incoming call page: $e');
    }
  }

  Future<void> acceptCall() async {
    // #region agent log
    _debugLog('call_provider.dart:391', 'acceptCall called', {
      'callState': _callState.toString(),
      'callerId': _callerId,
      'hasPendingOffer': _pendingOfferSdp != null,
      'socketConnected': _socketService?.socket?.connected,
    }, 'A');
    // #endregion
    if (_callState != CallState.ringing || _callerId == null) {
      print(
          '[CallProvider] ⚠️ Cannot accept call - state: $_callState, callerId: $_callerId');
      // #region agent log
      _debugLog('call_provider.dart:395', 'acceptCall rejected', {
        'callState': _callState.toString(),
        'callerId': _callerId,
      }, 'A');
      // #endregion
      return;
    }

    try {
      print('[CallProvider] Starting accept call process...');

      // CRITICAL: Cancel any active call notification when accepting via socket
      try {
        await CallNotificationService.cancelCallNotification();
        print('[CallProvider] ✅ Call notification cancelled on accept');
      } catch (e) {
        print('[CallProvider] ⚠️ Error cancelling notification: $e');
      }

      // CRITICAL: Ensure socket is connected before accepting
      await _ensureSocketConnected();

      // Request permissions
      print('[CallProvider] Requesting permissions...');
      if (_callType == CallType.video) {
        await _requestPermissions([Permission.camera, Permission.microphone]);
      } else {
        await _requestPermissions([Permission.microphone]);
      }

      // Get local media stream
      print('[CallProvider] Getting local media stream...');
      await _getLocalStream(_callType == CallType.video);

      // CRITICAL: Ensure audio and video tracks are enabled
      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enabled = true;
          print('[CallProvider] Audio track enabled: ${track.label}');
        });

        if (_callType == CallType.video) {
          _localStream!.getVideoTracks().forEach((track) {
            track.enabled = true;
            print('[CallProvider] Video track enabled: ${track.label}');
          });
        }
      }

      // Create peer connection BEFORE setting remote description
      print('[CallProvider] Creating peer connection...');
      await _createPeerConnection();

      // Add local stream tracks
      if (_localStream != null) {
        print('[CallProvider] Adding local stream tracks...');
        _localStream!.getTracks().forEach((track) {
          _peerConnection?.addTrack(track, _localStream!);
        });
      }

      // Set remote description from offer
      if (_socketService!.socket != null && _pendingOfferSdp != null) {
        print('[CallProvider] Setting remote description from offer...');
        print('[CallProvider] Offer SDP length: ${_pendingOfferSdp!.length}');

        // Set the remote description from the pending offer
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
              _pendingOfferSdp!, _pendingOfferType ?? 'offer'),
        );
        print('[CallProvider] ✅ Remote description set');

        // Create and set local description (answer)
        print('[CallProvider] Creating answer...');
        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        print('[CallProvider] ✅ Answer created and set');

        // Ensure socket is still connected before sending
        if (_socketService!.socket == null ||
            !_socketService!.socket!.connected) {
          print(
              '[CallProvider] ⚠️ Socket disconnected, attempting to reconnect...');
          await _ensureSocketConnected();
        }

        // CRITICAL: Send answer to caller with correct structure matching backend
        // Backend expects: recipientId (the caller), sdp, type
        print('[CallProvider] Sending answer to caller...');
        print('[CallProvider] Answer SDP length: ${answer.sdp?.length ?? 0}');
        print('[CallProvider] Caller ID (recipientId): $_callerId');
        print(
            '[CallProvider] Socket connected: ${_socketService!.socket?.connected}');
        // #region agent log
        _debugLog('call_provider.dart:485', 'Sending answer to caller', {
          'callerId': _callerId,
          'socketConnected': _socketService!.socket?.connected,
          'answerSdpLength': answer.sdp?.length,
        }, 'B');
        // #endregion

        _socketService!.socket?.emit('answer', {
          'recipientId': _callerId, // Backend routes answer to caller
          'sdp': answer.sdp,
          'type': answer.type,
        });
        print(
            '[CallProvider] ✅ Answer emitted to socket for callerId: $_callerId');
        // #region agent log
        _debugLog('call_provider.dart:492', 'Answer emitted successfully', {
          'callerId': _callerId,
        }, 'B');
        // #endregion

        // CRITICAL: Notify caller using both event names for compatibility
        print('[CallProvider] Notifying caller of acceptance...');

        // Send call-accepted event (new standard)
        _socketService!.socket?.emit('call-accepted', {
          'roomId': _roomId ?? _callerId,
          'receiverId': _authService?.usuario?.uid,
          'callerId': _callerId,
          'isVideoCall': _callType == CallType.video,
        });
        print('[CallProvider] ✅ call-accepted event sent');

        // Also send acceptNewCall for backward compatibility
        _socketService!.socket?.emit('acceptNewCall', {
          'recipientId': _authService?.usuario?.uid,
          'callerId': _callerId,
          'isVideoCall': _callType == CallType.video,
        });
        print(
            '[CallProvider] ✅ acceptNewCall event sent (backward compatibility)');

        _pendingOfferSdp = null;
        _pendingOfferType = null;

        // CRITICAL: Don't set state to connected yet - wait for WebRTC connection
        // Set state to "connecting" to show proper UI state
        // The connection state callback will set it to connected when WebRTC is actually connected
        _callState = CallState.ringing; // Keep as ringing until WebRTC connects
        notifyListeners();
        print('[CallProvider] ✅ Answer sent, waiting for WebRTC connection...');
        // #region agent log
        _debugLog('call_provider.dart:521', 'Answer sent, waiting for WebRTC', {
          'callState': _callState.toString(),
          'hasPeerConnection': _peerConnection != null,
        }, 'E');
        // #endregion
      } else {
        print(
            '[CallProvider] ⚠️ Cannot accept - socket: ${_socketService!.socket != null}, hasSDP: ${_pendingOfferSdp != null}');
        if (_pendingOfferSdp == null) {
          print('[CallProvider] ⚠️ No pending offer SDP available!');
          print('[CallProvider] ⚠️ Will wait for newOffer to arrive with SDP...');
          // Don't set call state to connected yet - wait for SDP
          // The newOffer handler will process it when it arrives
        }
      }
    } catch (e, stackTrace) {
      print('[CallProvider] ❌ Error accepting call: $e');
      print('[CallProvider] Stack trace: $stackTrace');
      _endCall();
    }
  }

  /// Ensure socket is connected before accepting call
  Future<void> _ensureSocketConnected() async {
      // #region agent log
      _debugLog('call_provider.dart:556', '_ensureSocketConnected called', {
        'hasSocketService': _socketService != null,
        'socketConnected': _socketService?.socket?.connected,
      }, 'C');
      // #endregion
    if (_socketService == null) {
      print('[CallProvider] ⚠️ SocketService is null!');
      // #region agent log
      _debugLog('call_provider.dart:560', 'SocketService is null', {}, 'C');
      // #endregion
      return;
    }

    // If already connected, return immediately
    if (_socketService!.socket != null && _socketService!.socket!.connected) {
      print('[CallProvider] ✅ Socket already connected');
      // #region agent log
      _debugLog('call_provider.dart:567', 'Socket already connected', {}, 'C');
      // #endregion
      return;
    }

    print('[CallProvider] Socket not connected, attempting to connect...');
    // #region agent log
    _debugLog('call_provider.dart:574', 'Attempting socket connection', {}, 'C');
    // #endregion

    // Try to connect
    try {
      _socketService!.connect();
    } catch (e) {
      print('[CallProvider] Error initiating socket connection: $e');
      // #region agent log
      _debugLog('call_provider.dart:578', 'Socket connection error', {'error': e.toString()}, 'C');
      // #endregion
    }

    // Wait for connection (with timeout)
    const maxWaitTime = Duration(seconds: 10);
    const checkInterval = Duration(milliseconds: 500);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      if (_socketService!.socket != null && _socketService!.socket!.connected) {
        print('[CallProvider] ✅ Socket connected!');
        // #region agent log
        _debugLog('call_provider.dart:588', 'Socket connected successfully', {
          'waitTime': DateTime.now().difference(startTime).inMilliseconds,
        }, 'C');
        // #endregion
        return;
      }
      await Future.delayed(checkInterval);
    }

    print('[CallProvider] ⚠️ Socket connection timeout, continuing anyway...');
    // #region agent log
    _debugLog('call_provider.dart:595', 'Socket connection timeout', {
      'finalSocketState': _socketService?.socket?.connected,
    }, 'C');
    // #endregion
  }

  void rejectCall() {
    print('[CallProvider] Rejecting call...');

    // CRITICAL: Cancel any active call notification when rejecting via socket
    try {
      CallNotificationService.cancelCallNotification();
      print('[CallProvider] ✅ Call notification cancelled on reject');
    } catch (e) {
      print('[CallProvider] ⚠️ Error cancelling notification: $e');
    }

    if (_callState == CallState.ringing && _callerId != null) {
      // CRITICAL: Ensure socket is connected before sending reject
      // Backend expects: to (caller), from (us), reason
      if (_socketService != null &&
          _socketService!.socket != null &&
          _socketService!.socket!.connected) {
        _socketService!.socket!.emit('endCall', {
          'to': _callerId, // Backend routes to caller
          'from': _authService?.usuario?.uid, // Our user ID
          'reason': 'declined',
        });
        print('[CallProvider] ✅ Call rejection sent to callerId: $_callerId');
      } else {
        print(
            '[CallProvider] ⚠️ Socket not connected, cannot send reject notification');
      }
    }
    _endCall();
  }

  void _handleAnswer(Map<String, dynamic> data) {
      // #region agent log
      _debugLog('call_provider.dart:632', '_handleAnswer called', {
        'callState': _callState.toString(),
        'isWebRTCReady': _isWebRTCReady,
        'hasPeerConnection': _peerConnection != null,
      }, 'B');
      // #endregion
    // CRITICAL: Buffer answer if WebRTC is not ready yet
    if (!_isWebRTCReady || _peerConnection == null) {
      print('[CallProvider] ⚠️ WebRTC not ready, buffering answer...');
      // #region agent log
      _debugLog('call_provider.dart:636', 'Answer buffered - WebRTC not ready', {
        'isWebRTCReady': _isWebRTCReady,
        'hasPeerConnection': _peerConnection != null,
      }, 'E');
      // #endregion
      _pendingSignals.add({'type': 'answer', 'data': data});
      return;
    }

    if (_callState != CallState.ringing && _callState != CallState.calling) {
      print(
          '[CallProvider] ⚠️ Cannot handle answer - call state is not ringing/calling: $_callState');
      // #region agent log
      _debugLog('call_provider.dart:643', 'Answer rejected - wrong call state', {
        'callState': _callState.toString(),
      }, 'B');
      // #endregion
      return;
    }

    try {
      _peerConnection?.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      // #region agent log
      _debugLog('call_provider.dart:651', 'Remote description set from answer', {
        'answerSdpLength': data['sdp']?.toString().length,
      }, 'B');
      // #endregion

      // CRITICAL: Don't set to connected immediately - wait for WebRTC connection state
      // The onConnectionState callback will set it to connected when WebRTC is actually connected
      // Keep state as ringing/calling until WebRTC connection is established
      notifyListeners();
      print('[CallProvider] ✅ Answer processed, waiting for WebRTC connection...');
    } catch (e) {
      print('[CallProvider] ❌ Error processing answer: $e');
      // #region agent log
      _debugLog('call_provider.dart:658', 'Error processing answer', {
        'error': e.toString(),
      }, 'B');
      // #endregion
    }
  }

  void _handleCallAccepted(Map<String, dynamic> data) {
    // #region agent log
    _debugLog('call_provider.dart:661', '_handleCallAccepted called', {
      'callState': _callState.toString(),
      'dataKeys': data.keys.toList(),
    }, 'D');
    // #endregion
    // CRITICAL: Handle call-accepted event on caller side
    // This indicates the recipient accepted, but wait for WebRTC connection before setting to connected
    if (_callState == CallState.ringing || _callState == CallState.calling) {
      print('[CallProvider] ✅ Call accepted by recipient - waiting for WebRTC connection');
      _stopRinging(); // Stop any ringing sound/vibration
      // Don't set to connected yet - wait for WebRTC connection state callback
      // The connection state will be updated when WebRTC actually connects
      notifyListeners();
      print(
          '[CallProvider] ✅ Call accepted, waiting for WebRTC connection...');
      // #region agent log
      _debugLog('call_provider.dart:672', 'Call accepted, waiting for WebRTC', {
        'callState': _callState.toString(),
      }, 'D');
      // #endregion
    } else {
      print(
          '[CallProvider] ⚠️ Received call-accepted but call state is: $_callState');
      // #region agent log
      _debugLog('call_provider.dart:676', 'Call accepted ignored - wrong state', {
        'callState': _callState.toString(),
      }, 'D');
      // #endregion
    }
  }

  /// Stop ringing sound/vibration (to be implemented if needed)
  void _stopRinging() {
    // TODO: Stop any ringing sound/vibration if implemented
    print('[CallProvider] Stopping ringing...');
  }

  void _handleIceCandidate(Map<String, dynamic> data) {
    // CRITICAL: Buffer ICE candidate if WebRTC is not ready yet
    if (!_isWebRTCReady || _peerConnection == null) {
      print('[CallProvider] ⚠️ WebRTC not ready, buffering ICE candidate...');
      _pendingIceCandidates.add(data);
      return;
    }

    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      _peerConnection!.addCandidate(candidate);
      print('[CallProvider] ✅ ICE candidate added successfully');
    } catch (e) {
      print('[CallProvider] ❌ Error adding ICE candidate: $e');
      print('[CallProvider] Candidate data: $data');
    }
  }

  void _handleCallEnded() {
    _endCall();
  }

  void endCall() {
    // CRITICAL: Notify the other party when ending call
    // If we're the caller, notify the recipient. If we're the receiver, notify the caller.
    final otherPartyId = _recipientId ?? _callerId;
    if (otherPartyId != null && _socketService?.socket != null && _socketService!.socket!.connected) {
      _socketService!.socket!.emit('endCall', {
        'to': otherPartyId,
        'from': _authService?.usuario?.uid,
      });
      print('[CallProvider] ✅ endCall event sent to: $otherPartyId');
    } else {
      print('[CallProvider] ⚠️ Cannot send endCall - otherPartyId: $otherPartyId, socket: ${_socketService?.socket?.connected}');
    }
    _endCall();
  }

  void _endCall() {
    print('[CallProvider] Ending call and cleaning up...');

    // CRITICAL: Cancel any active call notification
    try {
      CallNotificationService.cancelCallNotification();
      print('[CallProvider] ✅ Call notification cancelled on end');
    } catch (e) {
      print('[CallProvider] ⚠️ Error cancelling notification: $e');
    }

    _callTimer?.cancel();
    _callTimer = null;

    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;

    // CRITICAL: Reset WebRTC ready flag and clear buffers
    _isWebRTCReady = false;
    _pendingSignals.clear();
    _pendingIceCandidates.clear();
    _roomId = null;
    _pendingOfferSdp = null;
    _pendingOfferType = null;

    // CRITICAL: Clear pending call data from SharedPreferences to prevent phantom call UI
    // Do this asynchronously but don't block - clear immediately
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.remove('pending_call_data');
      await prefs.remove('pending_call_timestamp');
      await prefs.setBool('cold_start_call_launch', false);
      await prefs.remove('call_state'); // Also clear saved call state
      print('[CallProvider] ✅ Cleared pending call data from SharedPreferences');
      
      // Also clear CallNotificationService launch state
      CallNotificationService.clearLaunchState();
    }).catchError((e) {
      print('[CallProvider] ⚠️ Error clearing pending call data: $e');
    });

    // Set state to ended first (before clearing data) so UI can show "Call Ended" screen
    _callState = CallState.ended;
    notifyListeners(); // Notify to show "Call Ended" screen

    // After showing "Call Ended" screen for 2 seconds, reset everything to idle
    // CRITICAL: Preserve caller/recipient names until UI is dismissed to prevent "Unknown" showing
    Timer(const Duration(seconds: 2), () {
      _callDuration = Duration.zero;
      _callState = CallState.idle;
      _callType = null;
      _callerId = null;
      _recipientId = null;
      // Don't clear names immediately - let UI navigate back first
      // Names will be cleared on next call or app restart
      notifyListeners();
      _recipientName = null;
      _recipientAvatar = null;
      _isMuted = false;
      _isVideoEnabled = true;
      _isSpeakerEnabled = false;

      // Clear persisted call state
      _clearCallState();

      notifyListeners();
    });
  }

  void toggleMute() {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = _isMuted;
      });
      _isMuted = !_isMuted;
      notifyListeners();
    }
  }

  void toggleVideo() {
    if (_localStream != null && _callType == CallType.video) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = !_isVideoEnabled;
      });
      _isVideoEnabled = !_isVideoEnabled;
      notifyListeners();
    }
  }

  void toggleSpeaker() async {
    _isSpeakerEnabled = !_isSpeakerEnabled;

    // CRITICAL: Actually enable/disable speaker on mobile
    try {
      if (_localStream != null) {
        // Use flutter_webrtc Helper to enable speakerphone
        await Helper.setSpeakerphoneOn(_isSpeakerEnabled);
        print(
            '[CallProvider] Speaker ${_isSpeakerEnabled ? "enabled" : "disabled"}');
      }
    } catch (e) {
      print('[CallProvider] Error toggling speaker: $e');
    }

    notifyListeners();
  }

  Future<void> _requestPermissions(List<Permission> permissions) async {
    for (var permission in permissions) {
      var status = await permission.status;
      if (!status.isGranted) {
        await permission.request();
      }
    }
  }

  Future<void> _getLocalStream(bool includeVideo) async {
    final Map<String, dynamic> constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': includeVideo
          ? {
              'facingMode': 'user',
              'width': {'min': 640},
              'height': {'min': 480},
              'frameRate': {'min': 30},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    notifyListeners();
  }

  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        // STUN servers for NAT discovery
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        // Free TURN servers for relay when direct connection fails
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      // CRITICAL: Enable more aggressive ICE candidate gathering
      'iceTransportPolicy': 'all',
      'iceCandidatePoolSize': 10,
    };

    _peerConnection = await createPeerConnection(configuration);

    // Handle remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('[CallProvider] 📥 onTrack event received');
      print(
          '[CallProvider] Track kind: ${event.track.kind}'); // "audio" or "video"
      print('[CallProvider] Track enabled: ${event.track.enabled}');
      print('[CallProvider] Number of streams: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        print(
            '[CallProvider] ✅ Remote stream set with ${_remoteStream!.getTracks().length} tracks');

        // Log each track
        _remoteStream!.getTracks().forEach((track) {
          print(
              '[CallProvider] Remote track - kind: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}');
        });

        notifyListeners();
      } else {
        print('[CallProvider] ⚠️ onTrack event has no streams!');
      }
    };

    // CRITICAL: Handle ICE candidates with correct recipientId
    // If we're calling someone: send to recipientId
    // If we're receiving a call: send to callerId
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        // Determine correct recipient: recipientId if calling, callerId if receiving
        final targetId = _recipientId ?? _callerId;
        print('[CallProvider] 🧊 Generated LOCAL ICE candidate');
        print('[CallProvider] Sending ICE candidate to: $targetId');
        print(
            '[CallProvider] Role: ${_recipientId != null ? "CALLER" : "RECEIVER"}');

        if (_socketService?.socket == null ||
            !_socketService!.socket!.connected) {
          print(
              '[CallProvider] ⚠️ Socket not connected! Cannot send ICE candidate');
          return;
        }

        _socketService!.socket?.emit('candidate', {
          'recipientId': targetId, // Backend routes to this user
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
        print('[CallProvider] ✅ ICE candidate sent via socket');
      }
    };

    // CRITICAL: Handle connection state changes - update call state when actually connected
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('[CallProvider] 🔗 WebRTC Connection state: $state');
      // #region agent log
      _debugLog('call_provider.dart:934', 'WebRTC connection state changed', {
        'state': state.toString(),
        'currentCallState': _callState.toString(),
      }, 'E');
      // #endregion

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print(
            '[CallProvider] 🎉 WebRTC CONNECTED! Audio/video should now flow.');
        // #region agent log
        _debugLog('call_provider.dart:937', 'WebRTC connected', {
          'previousCallState': _callState.toString(),
        }, 'E');
        // #endregion
        // CRITICAL: Only set to connected when WebRTC is actually connected
        if (_callState == CallState.ringing || _callState == CallState.calling) {
          _callState = CallState.connected;
          _startCallTimer(); // Start timer only when actually connected
          notifyListeners();
          print('[CallProvider] ✅ Call state updated to CONNECTED - timer started');
          // #region agent log
          _debugLog('call_provider.dart:944', 'Call state set to connected', {
            'callState': _callState.toString(),
          }, 'E');
          // #endregion
        }
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print(
            '[CallProvider] ⚠️ WebRTC disconnected/failed/closed: $state - ending call');
        _endCall();
      }
    };

    // CRITICAL: Also listen to ICE connection state for debugging
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('[CallProvider] 🧊 ICE Connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print(
            '[CallProvider] ❌ ICE connection FAILED - connection cannot be established');
        print(
            '[CallProvider] This usually means firewall/NAT issues or STUN/TURN server problems');
      } else if (state ==
          RTCIceConnectionState.RTCIceConnectionStateConnected) {
        print(
            '[CallProvider] ✅ ICE connection established - media should flow');
      }
    };

    // CRITICAL: Enable speakerphone by default for audio calls on mobile
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Helper.setSpeakerphoneOn(true);
        _isSpeakerEnabled = true;
        print('[CallProvider] ✅ Speakerphone enabled by default');
      } catch (e) {
        print('[CallProvider] ⚠️ Could not enable speakerphone: $e');
      }
    }

    // CRITICAL: Mark WebRTC as ready and process buffered signals
    _isWebRTCReady = true;
    print(
        '[CallProvider] ✅ WebRTC is now ready - processing buffered signals...');

    // Process buffered signals (offer/answer)
    for (var signal in _pendingSignals) {
      print('[CallProvider] Processing buffered signal: ${signal['type']}');
      if (signal['type'] == 'offer') {
        _processBufferedOffer(signal['data']);
      } else if (signal['type'] == 'answer') {
        _processBufferedAnswer(signal['data']);
      }
    }
    _pendingSignals.clear();

    // Process buffered ICE candidates
    for (var candidate in _pendingIceCandidates) {
      print('[CallProvider] Processing buffered ICE candidate...');
      try {
        _peerConnection!.addCandidate(
          RTCIceCandidate(
            candidate['candidate'],
            candidate['sdpMid'],
            candidate['sdpMLineIndex'],
          ),
        );
      } catch (e) {
        print('[CallProvider] ❌ Error processing buffered ICE candidate: $e');
      }
    }
    _pendingIceCandidates.clear();

    print('[CallProvider] ✅ All buffered signals processed');
  }

  /// Process buffered offer when WebRTC becomes ready
  void _processBufferedOffer(Map<String, dynamic> data) {
    print('[CallProvider] Processing buffered offer...');
    // Store offer SDP for later use in acceptCall
    _pendingOfferSdp = data['sdp']?.toString();
    _pendingOfferType = data['type']?.toString();
    _callerId = data['callerId']?.toString();
    _callType = data['isVideoCall'] == true ? CallType.video : CallType.audio;
    _roomId = data['roomId']?.toString();
    if (data['callerName'] != null) {
      _callerName = data['callerName'].toString();
    }
    if (data['callerAvatar'] != null) {
      _callerAvatar = data['callerAvatar'].toString();
    }
    _callState = CallState.ringing;
    notifyListeners();
  }

  /// Process buffered answer when WebRTC becomes ready
  void _processBufferedAnswer(Map<String, dynamic> data) {
    print('[CallProvider] Processing buffered answer...');
    try {
      _peerConnection?.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      // CRITICAL: Don't set to connected yet - wait for WebRTC connection state
      // The onConnectionState callback will set it to connected when WebRTC is actually connected
      notifyListeners();
      print(
          '[CallProvider] ✅ Buffered answer processed - waiting for WebRTC connection');
    } catch (e) {
      print('[CallProvider] ❌ Error processing buffered answer: $e');
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = Duration.zero;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
      notifyListeners();
    });
  }

  void setCallerInfo(String name, String? avatar) {
    _callerName = name;
    _callerAvatar = avatar;
    notifyListeners();
  }

  // Handle incoming call from FCM notification (when app is in background/closed)
  void handleIncomingCallFromFCM(Map<String, dynamic> data,
      {bool autoAccept = false}) async {
    print(
        '[CallProvider] handleIncomingCallFromFCM called (autoAccept: $autoAccept)');

    // CRITICAL: Prevent duplicate handling - check if already ringing for same caller
    final incomingCallerId = data['callerId']?.toString();
    if (_callState != CallState.idle) {
      if (_callerId == incomingCallerId && _callState == CallState.ringing) {
        print(
            '[CallProvider] ⚠️ DUPLICATE FCM: Already handling call from $incomingCallerId, ignoring');
        return;
      }
      print('[CallProvider] ⚠️ FCM call ignored - state not idle: $_callState');
      return;
    }

    // CRITICAL: Store roomId if provided
    if (data['roomId'] != null) {
      _roomId = data['roomId'].toString();
    }

    print('[CallProvider] Handling incoming call from FCM');

    // CRITICAL: Ensure socket is connected before processing call
    if (_socketService != null) {
      await _ensureSocketConnected();
      // Re-setup socket listeners to ensure they're active
      _setupSocketListeners();
    }

    _callerId = data['callerId']?.toString();
    _callType = data['isVideoCall'] == true || data['isVideoCall'] == 'true'
        ? CallType.video
        : CallType.audio;
    _callState = CallState.ringing;

    // Get caller name and avatar from FCM data
    if (data['callerName'] != null) {
      _callerName = data['callerName'].toString();
    }
    if (data['callerAvatar'] != null) {
      _callerAvatar = data['callerAvatar'].toString();
    }

    // Store offer SDP for later use
    _pendingOfferSdp = data['sdp']?.toString();
    _pendingOfferType =
        data['rtcType']?.toString() ?? data['type']?.toString() ?? 'offer';

    // CRITICAL: Save call state to SharedPreferences for persistence
    await _saveCallState(data);

    print(
        '[CallProvider] FCM call - Caller: $_callerName, Type: $_callType, State: $_callState');
    print('[CallProvider] FCM call - Has SDP: ${_pendingOfferSdp != null}');
    notifyListeners();

    // Navigate to incoming call page using global navigator (unless auto-accepting)
    if (!autoAccept) {
      _navigateToIncomingCallPage(data);
    } else {
      print(
          '[CallProvider] Skipping navigation to incoming call page (auto-accept mode)');
    }
  }

  /// Save call state to SharedPreferences
  Future<void> _saveCallState(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'call_state',
          jsonEncode({
            'callerId': _callerId,
            'callerName': _callerName,
            'callerAvatar': _callerAvatar,
            'callType': _callType == CallType.video ? 'video' : 'audio',
            'callState': _callState.toString(),
            'pendingOfferSdp': _pendingOfferSdp,
            'pendingOfferType': _pendingOfferType,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'fcmData': data, // Store full FCM data for recovery
          }));
      print('[CallProvider] ✅ Call state saved to SharedPreferences');
    } catch (e) {
      print('[CallProvider] ⚠️ Error saving call state: $e');
    }
  }

  /// Restore call state from SharedPreferences
  Future<void> restoreCallState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callStateJson = prefs.getString('call_state');
      if (callStateJson == null) return;

      final callState = jsonDecode(callStateJson) as Map<String, dynamic>;
      final timestamp = callState['timestamp'] as int? ?? 0;

      // Only restore if call is recent (within last 5 minutes)
      final callTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(callTime).inMinutes > 5) {
        print('[CallProvider] Call state too old, clearing...');
        await _clearCallState();
        return;
      }

      _callerId = callState['callerId']?.toString();
      _callerName = callState['callerName']?.toString();
      _callerAvatar = callState['callerAvatar']?.toString();
      _callType =
          callState['callType'] == 'video' ? CallType.video : CallType.audio;
      _callState = CallState.ringing; // Restore as ringing
      _pendingOfferSdp = callState['pendingOfferSdp']?.toString();
      _pendingOfferType = callState['pendingOfferType']?.toString();

      print('[CallProvider] ✅ Call state restored from SharedPreferences');
      notifyListeners();
    } catch (e) {
      print('[CallProvider] ⚠️ Error restoring call state: $e');
    }
  }

  /// Clear call state from SharedPreferences
  Future<void> _clearCallState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('call_state');
      await prefs.remove('pending_call_data');
      await prefs.remove('pending_call_timestamp');
      print('[CallProvider] ✅ Call state cleared from SharedPreferences');
    } catch (e) {
      print('[CallProvider] ⚠️ Error clearing call state: $e');
    }
  }

  @override
  void dispose() {
    _endCall();
    super.dispose();
  }
}
