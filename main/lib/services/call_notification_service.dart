import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Robust call notification service using flutter_local_notifications
/// with full-screen intent for incoming calls when app is in background/terminated
class CallNotificationService {
  static final CallNotificationService _instance =
      CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  static FlutterLocalNotificationsPlugin? _notificationsPlugin;
  static const String _callChannelId = 'incoming_calls_channel';
  static const String _callChannelName = 'Incoming Calls';
  static const String _callChannelDescription =
      'Notifications for incoming calls';

  // Notification IDs
  static const int _callNotificationId = 888888;

  // Stream for call actions
  static final _callActionController = StreamController<CallAction>.broadcast();
  static Stream<CallAction> get callActions => _callActionController.stream;

  // Current call state
  static String? _currentCallId;
  static String? _currentCallerId; // Track caller ID for better deduplication
  static bool _isCallActive = false;
  static bool _isShowingNotification =
      false; // Lock to prevent duplicate notifications
  // Track recent notifications to prevent duplicates within short time window
  static final Map<String, DateTime> _recentNotifications = {};
  static const Duration _deduplicationWindow = Duration(seconds: 5);

  // COLD START: Store launch details for retrieval by main.dart
  static bool _didLaunchFromCallNotification = false;
  static Map<String, dynamic>? _launchCallData;

  /// Check if app was launched from a call notification (for cold start)
  static bool get didLaunchFromCallNotification =>
      _didLaunchFromCallNotification;

  /// Get the call data from launch notification (if any)
  static Map<String, dynamic>? get launchCallData => _launchCallData;

  /// Reset launch state (call after handling)
  static void clearLaunchState() {
    _didLaunchFromCallNotification = false;
    _launchCallData = null;
  }

  /// Initialize the notification service
  static Future<void> initialize() async {
    debugPrint('[CallNotificationService] Initializing...');

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization (for completeness)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Create the call notification channel with high priority
    await _createCallChannel();

    debugPrint('[CallNotificationService] ✅ Initialized successfully');

    // CRITICAL: Check if app was launched by tapping a notification (cold start)
    // This is the ONLY way to detect notification taps when app is terminated
    await _checkNotificationLaunchDetails();
  }

  /// Check if the app was launched by tapping a notification (cold start scenario)
  /// This is CRITICAL for handling call notifications when app is terminated
  static Future<void> _checkNotificationLaunchDetails() async {
    try {
      debugPrint(
          '[CallNotificationService] Checking notification launch details...');

      final launchDetails =
          await _notificationsPlugin!.getNotificationAppLaunchDetails();

      debugPrint(
          '[CallNotificationService] Launch details received: ${launchDetails != null}');

      if (launchDetails == null) {
        debugPrint('[CallNotificationService] No launch details available');
        // FALLBACK: Check SharedPreferences for pending call data
        await _checkSharedPrefsForPendingCall();
        return;
      }

      debugPrint(
          '[CallNotificationService] didNotificationLaunchApp: ${launchDetails.didNotificationLaunchApp}');

      if (!launchDetails.didNotificationLaunchApp) {
        debugPrint(
            '[CallNotificationService] App was NOT launched by flutter_local_notifications');
        // FALLBACK: Check SharedPreferences for pending call data
        // This handles cases where FCM or other systems showed the notification
        await _checkSharedPrefsForPendingCall();
        return;
      }

      final response = launchDetails.notificationResponse;
      if (response == null) {
        debugPrint(
            '[CallNotificationService] ⚠️ App launched by notification but no response data');
        await _checkSharedPrefsForPendingCall();
        return;
      }

      debugPrint(
          '[CallNotificationService] 📱 App was launched by notification tap!');
      debugPrint(
          '[CallNotificationService] Launch notification - actionId: ${response.actionId}, payload: ${response.payload}');

      // Check if this is a call notification
      if (response.payload != null && response.payload!.isNotEmpty) {
        try {
          final payloadData =
              jsonDecode(response.payload!) as Map<String, dynamic>;
          final type = payloadData['type']?.toString() ?? '';
          final hasCallId = payloadData['callId'] != null;
          final hasCallerId = payloadData['callerId'] != null;

          debugPrint(
              '[CallNotificationService] Launch payload type: $type, hasCallId: $hasCallId, hasCallerId: $hasCallerId');

          if (type == 'incoming_call' || hasCallId || hasCallerId) {
            debugPrint(
                '[CallNotificationService] ✅ COLD START: Call notification tap detected from launch details!');

            // Store in static variables for immediate access by main.dart
            _didLaunchFromCallNotification = true;
            _launchCallData = payloadData;

            // Store pending call data for the main handler to pick up
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pending_call_data', response.payload!);
            await prefs.setInt('pending_call_timestamp',
                DateTime.now().millisecondsSinceEpoch);

            // Mark that this is a cold start launch so main.dart knows to navigate
            await prefs.setBool('cold_start_call_launch', true);

            debugPrint(
                '[CallNotificationService] ✅ Cold start call data stored for navigation');

            // ALSO handle the notification action directly (for Accept/Decline buttons)
            // Use a longer delay to ensure the stream listeners are set up in main.dart
            Future.delayed(const Duration(milliseconds: 500), () {
              _handleNotificationAction(response.actionId, response.payload);
            });
          } else {
            debugPrint(
                '[CallNotificationService] Launch notification is not a call notification');
          }
        } catch (e) {
          debugPrint(
              '[CallNotificationService] Error parsing launch notification payload: $e');
        }
      } else {
        debugPrint(
            '[CallNotificationService] Launch notification has no payload, checking SharedPreferences...');
        await _checkSharedPrefsForPendingCall();
      }
    } catch (e, stackTrace) {
      debugPrint(
          '[CallNotificationService] ❌ Error checking launch details: $e');
      debugPrint('[CallNotificationService] Stack trace: $stackTrace');
      // FALLBACK: Try SharedPreferences
      await _checkSharedPrefsForPendingCall();
    }
  }

  /// Fallback: Check SharedPreferences for pending call data
  /// This handles cases where the notification wasn't shown by flutter_local_notifications
  /// or when getNotificationAppLaunchDetails fails
  static Future<void> _checkSharedPrefsForPendingCall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString('pending_call_data');
      final storedTimestamp = prefs.getInt('pending_call_timestamp') ?? 0;

      if (storedData == null || storedData.isEmpty) {
        debugPrint(
            '[CallNotificationService] No pending call data in SharedPreferences');
        return;
      }

      // Check if the data is recent (within 60 seconds)
      final now = DateTime.now().millisecondsSinceEpoch;
      final ageMs = now - storedTimestamp;
      if (ageMs > 60000) {
        debugPrint(
            '[CallNotificationService] Pending call data is too old (${ageMs}ms), clearing');
        await prefs.remove('pending_call_data');
        await prefs.remove('pending_call_timestamp');
        return;
      }

      debugPrint(
          '[CallNotificationService] ✅ Found recent pending call data in SharedPreferences (age: ${ageMs}ms)');

      try {
        final payloadData = jsonDecode(storedData) as Map<String, dynamic>;
        final type = payloadData['type']?.toString() ?? '';
        final hasCallId = payloadData['callId'] != null;
        final hasCallerId = payloadData['callerId'] != null;

        if (type == 'incoming_call' ||
            type == 'call' ||
            hasCallId ||
            hasCallerId) {
          debugPrint(
              '[CallNotificationService] ✅ COLD START: Call data found in SharedPreferences!');

          // Store in static variables for immediate access
          _didLaunchFromCallNotification = true;
          _launchCallData = payloadData;

          // Mark as cold start launch
          await prefs.setBool('cold_start_call_launch', true);

          debugPrint(
              '[CallNotificationService] ✅ Cold start call launch marked');
        }
      } catch (e) {
        debugPrint(
            '[CallNotificationService] Error parsing stored call data: $e');
      }
    } catch (e) {
      debugPrint(
          '[CallNotificationService] Error checking SharedPreferences: $e');
    }
  }

  /// Create the incoming calls notification channel
  static Future<void> _createCallChannel() async {
    const channel = AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      description: _callChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await _notificationsPlugin!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('[CallNotificationService] Call notification channel created');
  }

  /// Handle notification tap/action when app is in foreground
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
        '[CallNotificationService] Notification response: ${response.actionId}');
    _handleNotificationAction(response.actionId, response.payload);
  }

  /// Handle notification tap/action when app is in background
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint(
        '[CallNotificationService] Background notification response: ${response.actionId}');
    _handleNotificationAction(response.actionId, response.payload);
  }

  /// Public method to handle notification response (called by PushNotifications when it intercepts call notifications)
  static Future<void> handleNotificationResponse(
      String? actionId, String? payload) async {
    await _handleNotificationAction(actionId, payload);
  }

  /// Process notification action
  static Future<void> _handleNotificationAction(
      String? actionId, String? payload) async {
    Map<String, dynamic>? payloadData;

    // Parse payload if available
    if (payload != null && payload.isNotEmpty) {
      try {
        payloadData = jsonDecode(payload);
        debugPrint(
            '[CallNotificationService] Payload parsed: ${payloadData?.keys}');
      } catch (e) {
        debugPrint('[CallNotificationService] Error parsing payload: $e');
      }
    }

    // If no payload but we have current call state, use it as fallback
    if (payloadData == null && _currentCallId != null) {
      payloadData = {
        'callId': _currentCallId,
      };
    }

    if (actionId == null) {
      // Notification was tapped (not an action button)
      debugPrint(
          '[CallNotificationService] 📱 Notification tapped (actionId is null)');
      debugPrint('[CallNotificationService] Payload data: $payloadData');
      debugPrint('[CallNotificationService] Current call ID: $_currentCallId');

      // CRITICAL: Always emit tap action, even if payload is incomplete
      // Use fallback data from current call state if payload is missing
      if (payloadData == null || payloadData.isEmpty) {
        debugPrint(
            '[CallNotificationService] ⚠️ Payload is null/empty, using fallback or current state');
        // Try to reconstruct from current call state or SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final storedCallData = prefs.getString('pending_call_data');
          if (storedCallData != null) {
            payloadData = jsonDecode(storedCallData) as Map<String, dynamic>;
            debugPrint(
                '[CallNotificationService] ✅ Retrieved call data from SharedPreferences');
          }
        } catch (e) {
          debugPrint(
              '[CallNotificationService] ⚠️ Could not retrieve call data from SharedPreferences: $e');
        }
      }

      // Emit tap action with whatever data we have
      _callActionController.add(CallAction(
        type: CallActionType.tap,
        callId:
            payloadData?['callId'] ?? payloadData?['uuid'] ?? _currentCallId,
        callerId: payloadData?['callerId'],
        callerName: payloadData?['callerName'],
        isVideoCall: payloadData?['isVideoCall'] == true ||
            payloadData?['isVideoCall'] == 'true' ||
            false,
        payload: payloadData,
      ));
      debugPrint('[CallNotificationService] ✅ Tap action emitted to stream');
      return;
    }

    switch (actionId) {
      case 'accept_call':
        debugPrint('[CallNotificationService] ✅ Call ACCEPTED');
        if (payloadData != null) {
          _callActionController.add(CallAction(
            type: CallActionType.accept,
            callId:
                payloadData['callId'] ?? payloadData['uuid'] ?? _currentCallId,
            callerId: payloadData['callerId'],
            callerName: payloadData['callerName'],
            isVideoCall: payloadData['isVideoCall'] == true ||
                payloadData['isVideoCall'] == 'true',
            payload: payloadData,
          ));
        } else {
          debugPrint(
              '[CallNotificationService] ⚠️ Accept action but no payload data available');
        }
        cancelCallNotification();
        break;
      case 'decline_call':
        debugPrint('[CallNotificationService] ❌ Call DECLINED');
        if (payloadData != null) {
          _callActionController.add(CallAction(
            type: CallActionType.decline,
            callId:
                payloadData['callId'] ?? payloadData['uuid'] ?? _currentCallId,
            callerId: payloadData['callerId'],
            callerName: payloadData['callerName'],
            isVideoCall: payloadData['isVideoCall'] == true ||
                payloadData['isVideoCall'] == 'true',
            payload: payloadData,
          ));
        } else {
          debugPrint(
              '[CallNotificationService] ⚠️ Decline action but no payload data available');
        }
        cancelCallNotification();
        break;
    }
  }

  /// Show incoming call notification with full-screen intent
  static Future<void> showIncomingCallNotification({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    bool isVideoCall = false,
    String? sdp,
    String? rtcType,
  }) async {
    debugPrint(
        '[CallNotificationService] 📞 Showing incoming call notification');
    debugPrint(
        '[CallNotificationService] Caller: $callerName, Video: $isVideoCall');

    // CRITICAL: Prevent concurrent notification showing (lock mechanism)
    if (_isShowingNotification) {
      debugPrint(
          '[CallNotificationService] ⚠️ Already showing a notification, waiting...');
      // Wait for current notification to finish showing
      int waitAttempts = 0;
      while (_isShowingNotification && waitAttempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitAttempts++;
      }
      if (_isShowingNotification) {
        debugPrint(
            '[CallNotificationService] ⚠️ Timeout waiting for notification lock, skipping duplicate');
        return;
      }
    }

    // CRITICAL: Enhanced deduplication - prevent duplicate notifications
    final callKey = '${callerId}_$callId';
    
    // Check recent notifications cache (prevents duplicates within short time window)
    final now = DateTime.now();
    if (_recentNotifications.containsKey(callKey)) {
      final lastShown = _recentNotifications[callKey]!;
      final timeSince = now.difference(lastShown);
      if (timeSince < _deduplicationWindow) {
        debugPrint(
            '[CallNotificationService] ⚠️ DUPLICATE: Call shown recently (${timeSince.inSeconds}s ago) - callKey: $callKey');
        return;
      }
    }
    
    // Check if same call is already active
    if (_isCallActive) {
      if (_currentCallId == callId || 
          (_currentCallerId == callerId && _currentCallId == callId)) {
        // Exact same call ID or same caller+call combo - definitely duplicate
        debugPrint(
            '[CallNotificationService] ⚠️ DUPLICATE: Call already active - callId: $callId, callerId: $callerId');
        return;
      }
      // Different call received, cancel previous
      debugPrint(
          '[CallNotificationService] Different call received, cancelling previous');
      await cancelCallNotification();
    }
    
    // Add to recent notifications cache
    _recentNotifications[callKey] = now;
    
    // Clean up old entries from cache (older than deduplication window)
    _recentNotifications.removeWhere((key, timestamp) => 
        now.difference(timestamp) > _deduplicationWindow);

    // Set lock to prevent concurrent shows
    _isShowingNotification = true;

    if (_notificationsPlugin == null) {
      debugPrint(
          '[CallNotificationService] ⚠️ Plugin not initialized, initializing now...');
      await initialize();
    }

    // CRITICAL: Cancel any existing notifications (including Android's automatic one)
    // This prevents duplicate notifications when Android auto-shows one from FCM payload
    // Cancel aggressively in multiple passes to ensure we catch all duplicates
    try {
      // First pass: Cancel call notification ID specifically
      await _notificationsPlugin!.cancel(_callNotificationId);
      debugPrint('[CallNotificationService] ✅ Cancelled call notification ID');

      // Second pass: Cancel all notifications (catches any auto-shown ones)
      await _notificationsPlugin!.cancelAll();
      debugPrint(
          '[CallNotificationService] ✅ Cancelled all existing notifications');

      // Wait to ensure cancellation completes and Android processes it
      await Future.delayed(const Duration(milliseconds: 200));

      // Third pass: Cancel again to catch any that were queued during the delay
      await _notificationsPlugin!.cancelAll();
      debugPrint('[CallNotificationService] ✅ Final cancellation pass completed');
      
      // Small additional delay before showing new notification
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint(
          '[CallNotificationService] ⚠️ Error cancelling notifications: $e');
    }

    _currentCallId = callId;
    _currentCallerId = callerId; // Track caller ID for better deduplication
    _isCallActive = true;

    // Create payload with call data
    // CRITICAL: Include 'type' field for easier detection by other handlers
    final payloadMap = {
      'type':
          'incoming_call', // CRITICAL: This helps other handlers detect call notifications
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideoCall': isVideoCall,
      'sdp': sdp,
      'rtcType': rtcType,
    };
    final payload = jsonEncode(payloadMap);

    // CRITICAL: Store call data in SharedPreferences for retrieval during cold starts
    // This ensures the payload is available even if the notification payload is lost
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_call_data', payload);
      await prefs.setInt(
          'pending_call_timestamp', DateTime.now().millisecondsSinceEpoch);
      debugPrint(
          '[CallNotificationService] ✅ Call data stored in SharedPreferences');
    } catch (e) {
      debugPrint(
          '[CallNotificationService] ⚠️ Error storing call data in SharedPreferences: $e');
    }

    // Android notification details with full-screen intent
    // CRITICAL: Full-screen intent requires USE_FULL_SCREEN_INTENT permission
    // and proper channel configuration for Android 10+
    final androidDetails = AndroidNotificationDetails(
      _callChannelId,
      _callChannelName,
      channelDescription: _callChannelDescription,
      importance:
          Importance.max, // CRITICAL: Must be max for full-screen intent
      priority: Priority.max, // CRITICAL: Must be max for full-screen intent
      category: AndroidNotificationCategory
          .call, // CRITICAL: Required for call notifications
      fullScreenIntent: true, // CRITICAL: Shows on lock screen and wakes device
      ongoing: true, // Can't be swiped away
      autoCancel: false, // Don't auto-cancel call notifications
      playSound: true,
      enableVibration: true,
      vibrationPattern:
          Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Ring pattern
      visibility: NotificationVisibility.public, // Show on lock screen
      ticker: 'Incoming call from $callerName',
      subText: isVideoCall ? 'Video Call' : 'Audio Call',
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: false,
      colorized: true,
      color: const Color(0xFF0955FA),
      largeIcon: _buildLargeIcon(callerAvatar),
      styleInformation: BigTextStyleInformation(
        isVideoCall ? 'Incoming video call' : 'Incoming audio call',
        contentTitle: callerName,
        summaryText: 'Tap to answer',
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'decline_call',
          'Decline',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface:
              false, // Don't show UI when declined (app stays closed)
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'accept_call',
          'Accept',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true, // Show UI when accepted (opens app)
          cancelNotification: true,
        ),
      ],
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin!.show(
        _callNotificationId,
        callerName,
        isVideoCall ? 'Incoming video call' : 'Incoming audio call',
        notificationDetails,
        payload: payload,
      );

      debugPrint(
          '[CallNotificationService] ✅ Incoming call notification shown');

      // Release lock after successful show
      _isShowingNotification = false;
    } catch (e, stackTrace) {
      debugPrint('[CallNotificationService] ❌ Error showing notification: $e');
      debugPrint('[CallNotificationService] Stack trace: $stackTrace');

      // Release lock on error
      _isShowingNotification = false;

      // Re-throw to let caller know it failed
      rethrow;
    }
  }

  /// Cancel the current call notification
  static Future<void> cancelCallNotification() async {
    debugPrint('[CallNotificationService] Cancelling call notification');
    _isCallActive = false;
    _currentCallId = null;
    _currentCallerId = null; // Clear caller ID tracking
    _isShowingNotification = false; // Release lock

    try {
      await _notificationsPlugin?.cancel(_callNotificationId);
    } catch (e) {
      debugPrint('[CallNotificationService] Error cancelling notification: $e');
    }
  }

  static AndroidBitmap<Object> _buildLargeIcon(String? callerAvatar) {
    if (callerAvatar == null || callerAvatar.isEmpty) {
      return const DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
    }

    if (callerAvatar.startsWith('@')) {
      return DrawableResourceAndroidBitmap(callerAvatar);
    }

    final normalizedPath = callerAvatar.startsWith('file://')
        ? callerAvatar.replaceFirst('file://', '')
        : callerAvatar;

    if (normalizedPath.startsWith('/')) {
      final file = File(normalizedPath);
      if (file.existsSync()) {
        return FilePathAndroidBitmap(normalizedPath);
      }
    }

    // Fallback to default launcher icon to avoid missing resource crashes
    return const DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
  }

  /// Check if there's an active call notification
  static bool get hasActiveCall => _isCallActive;
  static String? get currentCallId => _currentCallId;

  /// Handle FCM data message for incoming call (call from background handler)
  static Future<void> handleFCMCallData(Map<String, dynamic> data) async {
    debugPrint('[CallNotificationService] Handling FCM call data');
    debugPrint('[CallNotificationService] Data: $data');

    final type = data['type']?.toString() ?? '';
    if (type != 'incoming_call' && type != 'call') {
      debugPrint('[CallNotificationService] Not a call notification, skipping');
      return;
    }

    final callId = data['uuid']?.toString() ??
        data['callkit_id']?.toString() ??
        data['callId']?.toString() ??
        '${data['callerId']}_${DateTime.now().millisecondsSinceEpoch}';
    final callerId =
        data['callerId']?.toString() ?? data['codigo']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ??
        data['nombre']?.toString() ??
        'Incoming Call';
    final callerAvatar =
        data['callerAvatar']?.toString() ?? data['avatar']?.toString();
    final isVideoCall =
        data['isVideoCall'] == 'true' || data['isVideoCall'] == true;
    final sdp = data['sdp']?.toString();
    final rtcType = data['rtcType']?.toString() ?? 'offer';

    await showIncomingCallNotification(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      isVideoCall: isVideoCall,
      sdp: sdp,
      rtcType: rtcType,
    );
  }

  /// Dispose resources
  static void dispose() {
    _callActionController.close();
  }
}

/// Represents a call action (accept, decline, tap)
class CallAction {
  final CallActionType type;
  final String? callId;
  final String? callerId;
  final String? callerName;
  final bool isVideoCall;
  final Map<String, dynamic>? payload;

  CallAction({
    required this.type,
    this.callId,
    this.callerId,
    this.callerName,
    this.isVideoCall = false,
    this.payload,
  });
}

/// Type of call action
enum CallActionType {
  accept,
  decline,
  tap,
  timeout,
}
