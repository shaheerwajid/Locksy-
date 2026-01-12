import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/call_provider.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../services/call_notification_service.dart';
import '../global/environment.dart';
import '../services/telemetry_service.dart';

class PushNotifications {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  AndroidNotificationChannel? channel;

  // Track permission request state to prevent concurrent requests
  // Use Future-based locking to ensure only one request happens
  static Future<NotificationSettings>? _permissionRequestFuture;
  static NotificationSettings? _cachedPermissionSettings;
  static GlobalKey<NavigatorState>? navigatorKey;

  // Notification deduplication: Track displayed notification IDs
  static const String _notificationIdsKey = 'displayed_notification_ids';
  static const int _maxStoredNotificationIds =
      1000; // Keep last 1000 notification IDs
  static Set<String>? _cachedNotificationIds;

  /// Get or load notification IDs from SharedPreferences
  Future<Set<String>> _getNotificationIds() async {
    if (_cachedNotificationIds != null) {
      return _cachedNotificationIds!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final idsJson = prefs.getString(_notificationIdsKey);
      if (idsJson != null) {
        final List<dynamic> idsList = jsonDecode(idsJson);
        _cachedNotificationIds = idsList.cast<String>().toSet();
      } else {
        _cachedNotificationIds = <String>{};
      }
    } catch (e) {
      debugPrint('[FCM] Error loading notification IDs: $e');
      _cachedNotificationIds = <String>{};
    }

    return _cachedNotificationIds!;
  }

  /// Save notification IDs to SharedPreferences
  Future<void> _saveNotificationIds(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Limit stored IDs to prevent unbounded growth
      final idsList = ids.take(_maxStoredNotificationIds).toList();
      await prefs.setString(_notificationIdsKey, jsonEncode(idsList));
      _cachedNotificationIds = ids.toSet();
    } catch (e) {
      debugPrint('[FCM] Error saving notification IDs: $e');
    }
  }

  /// Check if notification was already displayed (deduplication)
  Future<bool> _isNotificationDuplicate(String notificationId) async {
    if (notificationId.isEmpty) {
      // If no ID provided, generate one from message content
      return false; // Can't deduplicate without ID
    }

    final ids = await _getNotificationIds();
    return ids.contains(notificationId);
  }

  /// Mark notification as displayed
  Future<void> _markNotificationAsDisplayed(String notificationId) async {
    if (notificationId.isEmpty) return;

    final ids = await _getNotificationIds();
    ids.add(notificationId);

    // Clean up old IDs if we exceed the limit
    if (ids.length > _maxStoredNotificationIds) {
      final idsList = ids.toList();
      idsList
          .sort(); // Sort to keep most recent (assuming IDs are timestamp-based)
      ids.clear();
      ids.addAll(idsList.skip(idsList.length - _maxStoredNotificationIds));
    }

    await _saveNotificationIds(ids);
  }

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  String? _buildLocalNotificationPayload(RemoteMessage message) {
    if (message.data.isEmpty) return null;
    try {
      return jsonEncode({
        'route': 'chat',
        'data': message.data,
      });
    } catch (e) {
      debugPrint('[FCM] Error building notification payload: $e');
      return null;
    }
  }

  static void _navigateFromPayload(String? payload, {String? actionId}) {
    if (payload == null || payload.isEmpty) {
      debugPrint('[FCM] ⚠️ Payload is null or empty, skipping navigation');
      return;
    }

    debugPrint(
        '[FCM] _navigateFromPayload called with payload: $payload, actionId: $actionId');

    try {
      final decoded = jsonDecode(payload);
      debugPrint('[FCM] Decoded payload keys: ${decoded.keys.toList()}');

      // CRITICAL: Check if this is a call notification - if so, skip navigation
      // CallNotificationService handles call notifications separately
      final notificationType = decoded['data']?['type']?.toString() ??
          decoded['type']?.toString() ??
          '';

      // ALSO check for CallNotificationService payload format (has callId/callerId but no type field)
      final hasCallId = decoded['callId'] != null;
      final hasCallerId = decoded['callerId'] != null;
      final hasCallFields = hasCallId || hasCallerId;

      debugPrint(
          '[FCM] Payload check - type: $notificationType, hasCallId: $hasCallId, hasCallerId: $hasCallerId, hasCallFields: $hasCallFields');

      // CRITICAL: If it's a call action or a call notification, let CallNotificationService handle it.
      // This prevents PushNotifications from navigating to chat when Accept/Decline is pressed.
      if (actionId == 'accept_call' ||
          actionId == 'decline_call' ||
          notificationType == 'incoming_call' ||
          notificationType == 'call' ||
          hasCallFields) {
        debugPrint(
            '[FCM] ⚠️ Call notification/action detected (type=$notificationType, hasCallFields=$hasCallFields, actionId=$actionId), skipping navigation in PushNotifications (handled by CallNotificationService)');
        return;
      }

      final route = decoded['route']?.toString() ?? 'chat';
      final arguments = decoded['data'];
      debugPrint('[FCM] Navigating to route: $route');
      TelemetryService.log('notification_tap', data: {
        'route': route,
        'hasArgs': arguments != null,
      });
      if (navigatorKey?.currentState != null) {
        navigatorKey!.currentState!
            .pushNamed(route, arguments: arguments ?? {});
      } else {
        debugPrint('[FCM] Navigator key not set, cannot navigate');
      }
    } catch (e, stackTrace) {
      debugPrint('[FCM] Error handling notification tap: $e');
      debugPrint('[FCM] Stack trace: $stackTrace');
    }
  }

  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(
      NotificationResponse response) {
    debugPrint(
        '[FCM-BG] Background notification response received - actionId: ${response.actionId}');

    // CRITICAL: Check if this is a call notification action (Accept/Decline)
    // If so, skip navigation - CallNotificationService handles it
    if (response.actionId == 'accept_call' ||
        response.actionId == 'decline_call') {
      debugPrint(
          '[FCM-BG] ⚠️ Call notification action detected (${response.actionId}), CallNotificationService will handle');
      // CallNotificationService's own callback should handle this
      return;
    }

    // Check payload for call notification type
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.payload!);
        debugPrint('[FCM-BG] Decoded payload keys: ${decoded.keys.toList()}');

        final notificationType = decoded['data']?['type']?.toString() ??
            decoded['type']?.toString() ??
            '';

        // CRITICAL: Also check for CallNotificationService payload format
        // CallNotificationService uses callId/callerId fields, not type field
        final hasCallId = decoded['callId'] != null;
        final hasCallerId = decoded['callerId'] != null;
        final hasCallFields = hasCallId || hasCallerId;

        debugPrint(
            '[FCM-BG] Payload check - type: $notificationType, hasCallId: $hasCallId, hasCallerId: $hasCallerId');

        if (notificationType == 'incoming_call' ||
            notificationType == 'call' ||
            hasCallFields) {
          debugPrint(
              '[FCM-BG] ⚠️ Call notification detected (type=$notificationType, hasCallFields=$hasCallFields), delegating to CallNotificationService');
          // CRITICAL: Delegate to CallNotificationService to handle the tap
          // This ensures proper navigation to incoming call page
          CallNotificationService.handleNotificationResponse(
            response.actionId,
            response.payload,
          );
          return;
        }
      } catch (e) {
        // If payload parsing fails, continue with normal navigation
        debugPrint('[FCM-BG] Could not parse payload: $e');
      }
    }

    _navigateFromPayload(response.payload, actionId: response.actionId);
  }

  // Helper function to translate Spanish notification text to English
  String _translateToEnglish(String text) {
    if (text.isEmpty) return text;

    final lowerText = text.toLowerCase().trim();

    // Common Spanish phrases to English
    final translations = {
      'nueva llamada': 'Incoming Call',
      'llamada entrante': 'Incoming Call',
      'llamada de video entrante': 'Incoming video call',
      'llamada de video': 'Incoming video call',
      'llamada de audio entrante': 'Incoming audio call',
      'llamada de audio': 'Incoming audio call',
      'nuevo mensaje': 'New Message',
      'tienes un nuevo mensaje': 'You have a new message',
      'mensaje nuevo': 'New Message',
      'solicitud enviada': 'Request sent',
      'solicitud recibida': 'Request received',
      'nueva solicitud': 'New Request',
    };

    // Check for exact matches first
    if (translations.containsKey(lowerText)) {
      return translations[lowerText]!;
    }

    // Check for partial matches
    for (var entry in translations.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }

    // If no translation found, return original (might be user message content)
    return text;
  }

  Future<String?> initNotifications() async {
    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'Notifications for calls and messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        debugPrint(
            '[FCM] onDidReceiveNotificationResponse called - actionId: ${response.actionId}, payload: ${response.payload}');

        // CRITICAL: Check if this is a call notification action (Accept/Decline)
        // If so, skip navigation - CallNotificationService handles it
        if (response.actionId == 'accept_call' ||
            response.actionId == 'decline_call') {
          debugPrint(
              '[FCM] ⚠️ Call notification action detected (${response.actionId}), skipping default navigation');
          return; // CallNotificationService will handle this
        }

        // Check payload for call notification type
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.payload!);
            debugPrint(
                '[FCM] Decoded response payload keys: ${decoded.keys.toList()}');

            final notificationType = decoded['data']?['type']?.toString() ??
                decoded['type']?.toString() ??
                '';

            // ALSO check for CallNotificationService payload format
            final hasCallId = decoded['callId'] != null;
            final hasCallerId = decoded['callerId'] != null;
            final hasCallFields = hasCallId || hasCallerId;

            debugPrint(
                '[FCM] Response payload check - type: $notificationType, hasCallId: $hasCallId, hasCallerId: $hasCallerId');

            if (notificationType == 'incoming_call' ||
                notificationType == 'call' ||
                hasCallFields) {
              debugPrint(
                  '[FCM] ⚠️ Call notification detected in response payload (type=$notificationType, hasCallFields=$hasCallFields), delegating to CallNotificationService');
              // CRITICAL: Forward to CallNotificationService to handle properly
              // Since PushNotifications initializes after CallNotificationService, we need to manually delegate
              try {
                // Manually trigger CallNotificationService handler
                await CallNotificationService.handleNotificationResponse(
                  response.actionId,
                  response.payload,
                );
                debugPrint(
                    '[FCM] ✅ Delegated call notification tap to CallNotificationService');
              } catch (e, stackTrace) {
                debugPrint(
                    '[FCM] ❌ Error delegating to CallNotificationService: $e');
                debugPrint('[FCM] Stack trace: $stackTrace');
              }
              return; // Don't navigate, CallNotificationService will handle it
            }
          } catch (e, stackTrace) {
            // If payload parsing fails, continue with normal navigation
            debugPrint('[FCM] Could not parse payload: $e');
            debugPrint('[FCM] Stack trace: $stackTrace');
          }
        }

        _navigateFromPayload(response.payload, actionId: response.actionId);
      },
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
    );

    // Create notification channel
    await flutterLocalNotificationsPlugin!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel!);

    debugPrint('[FCM] Notification channel created');

    // Request permission safely using Future-based locking
    // This ensures all concurrent calls await the same permission request
    NotificationSettings settings;

    // Check current permission status first (this is safe to call multiple times)
    final currentSettings = await _firebaseMessaging.getNotificationSettings();

    // If permission is already determined, use cached or current settings
    if (currentSettings.authorizationStatus !=
            AuthorizationStatus.notDetermined &&
        currentSettings.authorizationStatus !=
            AuthorizationStatus.provisional) {
      // Use cached settings if available, otherwise use current
      settings = _cachedPermissionSettings ?? currentSettings;
      _cachedPermissionSettings ??= settings;
      debugPrint('[FCM] Permission already determined, using current settings');
    } else {
      // Permission not determined - need to request
      // Use Future-based locking to prevent concurrent requests
      if (_permissionRequestFuture != null) {
        debugPrint(
            '[FCM] ⚠️ Permission request already in progress, waiting...');
        try {
          settings = await _permissionRequestFuture!;
          debugPrint(
              '[FCM] ✅ Waited for existing permission request to complete');
        } catch (e) {
          debugPrint('[FCM] ⚠️ Error waiting for permission request: $e');
          // If waiting failed, use current settings as fallback
          settings = currentSettings;
        }
      } else {
        // Create a shared Future for concurrent calls
        // This Future will be awaited by all concurrent callers
        debugPrint('[FCM] Requesting notification permission...');
        _permissionRequestFuture = _requestPermissionSafely();

        try {
          // All concurrent calls will await the same Future
          settings = await _permissionRequestFuture!;
          _cachedPermissionSettings = settings;
        } finally {
          // Clear the Future after completion so we can request again if needed
          _permissionRequestFuture = null;
        }
      }
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[FCM] ✅ User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('[FCM] ⚠️ User granted provisional permission');
    } else {
      debugPrint('[FCM] ❌ User declined or has not accepted permission');
      debugPrint('[FCM] Authorization status: ${settings.authorizationStatus}');
    }

    return await _getFCMTokenAfterPermission(settings);
  }

  // Helper method to safely request permission (used as shared Future)
  Future<NotificationSettings> _requestPermissionSafely() async {
    try {
      debugPrint('[FCM] Requesting notification permission...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] ✅ Permission request completed');
      return settings;
    } catch (e) {
      debugPrint('[FCM] ❌ Error requesting permission: $e');
      // If request fails, get current settings as fallback
      return await _firebaseMessaging.getNotificationSettings();
    }
  }

  // Helper method to get FCM token after permission is handled
  Future<String?> _getFCMTokenAfterPermission(
      NotificationSettings settings) async {
    String? result;

    final token = await _firebaseMessaging.getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint(
          '[FCM] ✅ Initial token obtained: ${token.substring(0, 20)}...');
      debugPrint('[FCM] Full token length: ${token.length}');
      debugPrint('[FCM] Full token: $token');
      result = token;
    } else {
      debugPrint('[FCM] ❌ Failed to get FCM token - token is null or empty');
      debugPrint('[FCM] This will prevent notifications from working!');
    }

    // Handle token refresh - send to backend when token changes
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] 🔄 Token refreshed: ${newToken.substring(0, 20)}...');
      debugPrint('[FCM] Full new token: $newToken');

      // Send updated token to backend immediately
      try {
        // Check if user is logged in
        final token = await AuthService.getToken();
        if (token.isNotEmpty && token.trim().isNotEmpty) {
          // Use the dedicated endpoint
          final response = await http.post(
            Uri.parse('${Environment.apiUrl}/usuarios/register-fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'x-token': token,
            },
            body: jsonEncode({'fcmToken': newToken}),
          );

          if (response.statusCode == 200) {
            final respBody = jsonDecode(response.body);
            if (respBody['ok'] == true) {
              debugPrint('[FCM] ✅ Updated token sent to backend successfully');
            } else {
              debugPrint('[FCM] ⚠️ Token update failed: ${respBody['msg']}');
            }
          } else {
            debugPrint(
                '[FCM] ❌ Token update failed with status: ${response.statusCode}');
          }
        } else {
          debugPrint('[FCM] ⚠️ User not logged in, cannot update token');
          debugPrint('[FCM] Token will be sent on next login');
        }
      } catch (e) {
        debugPrint('[FCM] ❌ Error updating token: $e');
      }

      // Also update socket connection header (will be sent on reconnect)
      debugPrint('[FCM] Socket will send new token on next connection');
    });

    // IMPORTANT: This setting only affects iOS
    // For Android, we always show notifications manually
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle messages when app is in FOREGROUND (open and visible)
    // NOTE: When app is in BACKGROUND (not terminated), Android automatically shows notifications
    // if they have a notification payload. Data-only messages won't show automatically.
    // We handle all cases here to ensure notifications always show.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        debugPrint('[FCM-FG] ========================================');
        debugPrint('[FCM-FG] Foreground message received');
        debugPrint('[FCM-FG] Message ID: ${message.messageId}');
        debugPrint(
            '[FCM-FG] Notification: ${notification != null ? "YES" : "NO"}');
        debugPrint('[FCM-FG] Data: ${message.data}');
        debugPrint('[FCM-FG] Notification type: ${message.data['type']}');

        // Generate notification ID for deduplication
        // Use messageId if available, otherwise generate from data
        String notificationId = message.messageId ??
            '${message.data['type']}_${message.data['fecha'] ?? message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

        // Check for duplicate notification
        final isDuplicate = await _isNotificationDuplicate(notificationId);
        if (isDuplicate) {
          debugPrint(
              '[FCM-FG] ⚠️ Duplicate notification detected and skipped: $notificationId');
          return; // Skip displaying duplicate notification
        }

        // Mark as displayed before showing (to prevent race conditions)
        await _markNotificationAsDisplayed(notificationId);

        final localNotificationPayload =
            _buildLocalNotificationPayload(message);

        // Check if it's a call notification
        final notificationType = message.data['type'] ?? 'message';
        final isCall =
            notificationType == 'incoming_call' || notificationType == 'call';

        // Ensure plugin is initialized
        if (flutterLocalNotificationsPlugin == null) {
          debugPrint('[FCM-FG] ❌ Plugin not initialized, initializing now...');
          flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
          const AndroidInitializationSettings initializationSettingsAndroid =
              AndroidInitializationSettings('@mipmap/ic_launcher');
          const InitializationSettings initializationSettings =
              InitializationSettings(android: initializationSettingsAndroid);
          await flutterLocalNotificationsPlugin!.initialize(
            initializationSettings,
            onDidReceiveNotificationResponse: (response) async {
              debugPrint(
                  '[FCM-FG-REINIT] Notification response - actionId: ${response.actionId}');

              // CRITICAL: Check if this is a call notification action (Accept/Decline)
              // If so, skip navigation - CallNotificationService handles it
              if (response.actionId == 'accept_call' ||
                  response.actionId == 'decline_call') {
                debugPrint(
                    '[FCM-FG-REINIT] ⚠️ Call notification action detected (${response.actionId}), delegating to CallNotificationService');
                await CallNotificationService.handleNotificationResponse(
                  response.actionId,
                  response.payload,
                );
                return;
              }

              // Check payload for call notification type
              if (response.payload != null && response.payload!.isNotEmpty) {
                try {
                  final decoded = jsonDecode(response.payload!);
                  final notificationType =
                      decoded['data']?['type']?.toString() ??
                          decoded['type']?.toString() ??
                          '';

                  // CRITICAL: Also check for CallNotificationService payload format
                  final hasCallId = decoded['callId'] != null;
                  final hasCallerId = decoded['callerId'] != null;
                  final hasCallFields = hasCallId || hasCallerId;

                  if (notificationType == 'incoming_call' ||
                      notificationType == 'call' ||
                      hasCallFields) {
                    debugPrint(
                        '[FCM-FG-REINIT] ⚠️ Call notification detected, delegating to CallNotificationService');
                    await CallNotificationService.handleNotificationResponse(
                      response.actionId,
                      response.payload,
                    );
                    return;
                  }
                } catch (e) {
                  // If payload parsing fails, continue with normal navigation
                  debugPrint('[FCM-FG-REINIT] Could not parse payload: $e');
                }
              }

              _navigateFromPayload(response.payload,
                  actionId: response.actionId);
            },
            onDidReceiveBackgroundNotificationResponse:
                _handleBackgroundNotificationResponse,
          );
        }

        if (isCall) {
          // CRITICAL: Handle call notifications ONLY via CallNotificationService
          // This ensures ONE notification with Accept/Decline buttons
          debugPrint(
              '[FCM-FG] 📞 Incoming call detected - delegating to CallNotificationService');
          debugPrint(
              '[FCM-FG] ⚠️ IGNORING notification block - using ONLY data block');

          // CRITICAL: Cancel any auto-shown notifications from FCM/Android first
          // This prevents duplicate notifications - cancel multiple times to ensure it works
          try {
            if (flutterLocalNotificationsPlugin != null) {
              // Cancel call notification ID specifically first
              await flutterLocalNotificationsPlugin!.cancel(1001);
              // Then cancel all notifications
              await flutterLocalNotificationsPlugin!.cancelAll();
              debugPrint('[FCM-FG] ✅ Cancelled any auto-shown notifications');
              // Longer delay to ensure Android processes cancellation before showing new notification
              await Future.delayed(const Duration(milliseconds: 200));
              // Cancel again after delay to catch any that were queued
              await flutterLocalNotificationsPlugin!.cancelAll();
            }
          } catch (e) {
            debugPrint('[FCM-FG] ⚠️ Error cancelling notifications: $e');
          }

          // Handle call notification using CallNotificationService
          // Shows full-screen intent notification with Accept/Decline buttons
          // ONLY use data block, ignore notification block
          final callerName = message.data['nombre'] ??
              message.data['callerName'] ??
              'Incoming Call';
          final callerAvatar =
              message.data['avatar'] ?? message.data['callerAvatar'];
          final isVideoCall = message.data['isVideoCall'] == true ||
              message.data['isVideoCall'] == 'true';
          final callerId = message.data['callerId'] ?? message.data['codigo'];
          final sdp = message.data['sdp'];
          final rtcType = message.data['rtcType'] ?? 'offer';

          debugPrint(
              '[FCM-FG] 📞 Incoming call from: $callerName (video: $isVideoCall)');

          // Delegate to CallNotificationService - it handles all deduplication
          try {
            await CallNotificationService.handleFCMCallData(message.data);
            debugPrint(
                '[FCM-FG] ✅ Call notification handled by CallNotificationService');
            // Return early to prevent ANY other notification processing
            return;
          } catch (e) {
            debugPrint('[FCM-FG] ⚠️ CallNotificationService error: $e');

            // Fallback: navigate directly if notification fails (shouldn't happen)
            if (navigatorKey?.currentState != null) {
              navigatorKey!.currentState!.pushNamed(
                'incomingCall',
                arguments: {
                  'callerName': callerName,
                  'callerAvatar': callerAvatar,
                  'isVideoCall': isVideoCall,
                  'callerId': callerId,
                  'sdp': sdp,
                  'rtcType': rtcType,
                },
              );
            }
            return; // Still exit early even on error
          }
        } else if (notification != null && android != null) {
          // Regular message notification with notification payload
          // CRITICAL: When app is in background, Android automatically shows notifications
          // from the notification block. We should NOT show another one manually to avoid duplicates.
          // Only show manually when app is in FOREGROUND (Android doesn't auto-show in foreground).
          // For background, Android handles it automatically, so skip manual showing.
          // CRITICAL: Always use English only for notifications to prevent duplicate languages
          // Translate any non-English text to English
          String notificationBody =
              _translateToEnglish(notification.body ?? '');
          String notificationTitle =
              _translateToEnglish(notification.title ?? 'New Message');
          
          // CRITICAL: If notification body/title contains non-English text, ensure we use only English
          // This prevents duplicate notifications (one English, one in another language)

          // If notification body is generic, try to get actual message from data
          if (notificationBody.isEmpty ||
              notificationBody.toLowerCase() == 'new message' ||
              notificationBody.toLowerCase() == 'you have a new message') {
            final dataBody = message.data['body'] ??
                message.data['message'] ??
                message.data['text'] ??
                message.data['mensaje'] ??
                message.data['content'] ??
                '';
            // Translate if it's a system message, otherwise keep original (user content)
            if (dataBody.isNotEmpty) {
              // Check if it's a system message that needs translation
              final lowerDataBody = dataBody.toLowerCase();
              if (lowerDataBody.contains('nuevo mensaje') ||
                  lowerDataBody.contains('mensaje nuevo') ||
                  lowerDataBody.contains('solicitud')) {
                notificationBody = _translateToEnglish(dataBody);
              } else {
                // It's actual user message content, keep as is
                notificationBody = dataBody;
              }
              debugPrint('[FCM-FG] Using message content from data payload');
            }
          }

          // CRITICAL: Check for duplicate before showing
          // If notification was already shown (Android auto-showed it), skip manual showing
          final wasAlreadyShown = await _isNotificationDuplicate(notificationId);
          if (wasAlreadyShown) {
            debugPrint(
                '[FCM-FG] ⚠️ Notification $notificationId already shown (likely auto-shown by Android), skipping duplicate');
            return;
          }
          
          // Mark as shown before displaying
          await _markNotificationAsDisplayed(notificationId);
          
          // Use notificationId hash for consistent notification ID
          final notificationHash = notificationId.hashCode;
          await flutterLocalNotificationsPlugin!.show(
            notificationHash,
            notificationTitle,
            notificationBody,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel!.id,
                channel!.name,
                importance: Importance.high,
                priority: Priority.high,
                icon: "@mipmap/ic_launcher",
                playSound: true,
                enableVibration: true,
                styleInformation: BigTextStyleInformation(
                  notificationBody,
                  contentTitle: notificationTitle,
                  summaryText: notificationBody,
                ),
              ),
            ),
            payload: localNotificationPayload,
          );
          debugPrint(
              '[FCM-FG] ✅ Message notification shown (ID: $notificationId)');
        } else if (message.data.isNotEmpty) {
          // Data-only message (no notification payload)
          // These MUST be shown manually, even when app is in background
          final title = _translateToEnglish(message.data['title'] ??
              message.data['nombreEmisor'] ??
              'New Message');
          final rawBody = message.data['body'] ??
              message.data['message'] ??
              message.data['text'] ??
              message.data['mensaje'] ??
              message.data['content'] ??
              '';
          // Translate system messages, but keep user message content as is
          final lowerBody = rawBody.toLowerCase();
          final body = (lowerBody.contains('nuevo mensaje') ||
                  lowerBody.contains('mensaje nuevo') ||
                  lowerBody.contains('solicitud'))
              ? _translateToEnglish(rawBody)
              : rawBody;

          if (title.isNotEmpty || body.isNotEmpty) {
            // CRITICAL: Check for duplicate before showing
            final wasAlreadyShown = await _isNotificationDuplicate(notificationId);
            if (wasAlreadyShown) {
              debugPrint(
                  '[FCM-FG] ⚠️ Data-only notification $notificationId already shown, skipping duplicate');
              return;
            }
            
            // Mark as shown before displaying
            await _markNotificationAsDisplayed(notificationId);
            
            // Use notificationId hash for consistent notification ID
            final notificationHash = notificationId.hashCode;
            await flutterLocalNotificationsPlugin!.show(
              notificationHash,
              title,
              body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel!.id,
                  channel!.name,
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: "@mipmap/ic_launcher",
                  playSound: true,
                  enableVibration: true,
                  styleInformation: BigTextStyleInformation(
                    body,
                    contentTitle: title,
                    summaryText: body,
                  ),
                ),
              ),
              payload: localNotificationPayload,
            );
            debugPrint(
                '[FCM-FG] ✅ Data-only notification shown (ID: $notificationId)');
          } else {
            debugPrint('[FCM-FG] ⚠️ Data-only message has no title or body');
          }
        } else {
          debugPrint(
              '[FCM-FG] ⚠️ Message has no notification payload and no data');
        }
        debugPrint('[FCM-FG] ========================================');
      } catch (e, stackTrace) {
        debugPrint('[FCM-FG] ❌ Error handling foreground message: $e');
        debugPrint('[FCM-FG] Stack trace: $stackTrace');
      }
    });

    // Handle notification when app is opened from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FCM] App opened from terminated state via notification');
        _handleRemoteMessageTap(message);
      }
    });

    // Handle notification when app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification tapped while app in background');
      _handleRemoteMessageTap(message);
    });

    return result;
  }

  // Handle notification tap - navigate to appropriate page
  void _handleRemoteMessageTap(RemoteMessage message) {
    try {
      final notificationType = message.data['type'] ?? '';
      debugPrint('[FCM] Handling notification tap - type: $notificationType');

      if (notificationType == 'incoming_call' || notificationType == 'call') {
        // Handle call notification tap - CallKit handles this via its own event system
        // We just need to navigate to the call page when the user accepts
        final callerName = message.data['nombre'] ??
            message.data['callerName'] ??
            message.notification?.title ??
            'Unknown';
        final callerAvatar =
            message.data['avatar'] ?? message.data['callerAvatar'];
        final isVideoCall = message.data['isVideoCall'] == true ||
            message.data['isVideoCall'] == 'true';
        final callerId = message.data['callerId'] ?? message.data['codigo'];
        final sdp = message.data['sdp'];
        final rtcType = message.data['rtcType'] ?? 'offer';

        debugPrint(
            '[FCM] Call notification tapped - Caller: $callerName, Video: $isVideoCall');
        debugPrint(
            '[FCM] Call data - callerId: $callerId, hasSDP: ${sdp != null}');

        // Navigate directly to incoming call page when notification is tapped
        if (navigatorKey?.currentState != null) {
          // Set up CallProvider first
          Future.delayed(const Duration(milliseconds: 300), () {
            try {
              final context = navigatorKey!.currentContext;
              if (context != null) {
                final callProvider =
                    Provider.of<CallProvider>(context, listen: false);
                final socketService =
                    Provider.of<SocketService>(context, listen: false);
                final authService =
                    Provider.of<AuthService>(context, listen: false);

                if (!callProvider.isInitialized) {
                  debugPrint('[FCM] Initializing CallProvider');
                  callProvider.initialize(
                      socketService, authService, navigatorKey!);
                }

                // CRITICAL: Check if already on incoming call page before navigating
                try {
                  final navContext = navigatorKey!.currentState?.context;
                  if (navContext != null) {
                    final currentRoute =
                        ModalRoute.of(navContext)?.settings.name;
                    if (currentRoute == 'incomingCall') {
                      debugPrint(
                          '[FCM] ⚠️ Already on incoming call page, skipping duplicate navigation');
                      return;
                    }
                  }
                } catch (e) {
                  debugPrint('[FCM] Could not check current route: $e');
                }

                // Check if call is already ringing
                if (callProvider.callState == CallState.ringing) {
                  debugPrint(
                      '[FCM] ⚠️ Call is already ringing, skipping duplicate setup');
                  return;
                }

                if (callerId != null) {
                  final callData = {
                    'callerId': callerId,
                    'callerName': callerName,
                    'callerAvatar': callerAvatar,
                    'isVideoCall': isVideoCall,
                    'sdp': sdp,
                    'type': rtcType,
                  };
                  callProvider.handleIncomingCallFromFCM(callData);
                  debugPrint('[FCM] ✅ CallProvider set up with FCM data');
                }

                // Navigate to incoming call page
                // Double-check route before navigating
                try {
                  final navContext = navigatorKey!.currentState?.context;
                  if (navContext != null) {
                    final route = ModalRoute.of(navContext)?.settings.name;
                    if (route == 'incomingCall') {
                      debugPrint(
                          '[FCM] ⚠️ Already on incoming call page, skipping');
                      return;
                    }
                  }
                } catch (e) {
                  debugPrint(
                      '[FCM] Could not check route before navigation: $e');
                }

                // Navigate if not already on the page
                try {
                  navigatorKey!.currentState!.pushNamed(
                    'incomingCall',
                    arguments: {
                      'callerName': callerName,
                      'callerAvatar': callerAvatar,
                      'isVideoCall': isVideoCall,
                      'callerId': callerId,
                      'sdp': sdp,
                      'rtcType': rtcType,
                    },
                  );
                  debugPrint('[FCM] ✅ Navigated to incoming call page');
                } catch (navError) {
                  debugPrint('[FCM] ❌ Error navigating: $navError');
                }
              }
            } catch (e) {
              debugPrint('[FCM] ⚠️ Error handling call tap: $e');
            }
          });
        }
      } else if (notificationType == 'message') {
        // Handle message notification tap - navigate to chat
        final uid = message.data['uid'] ?? message.data['de'];
        if (uid != null && navigatorKey?.currentState != null) {
          navigatorKey!.currentState!.pushNamed(
            'chat',
            arguments: {'uid': uid},
          );
          debugPrint('[FCM] ✅ Navigated to chat');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[FCM] ❌ Error handling notification tap: $e');
      debugPrint('[FCM] Stack trace: $stackTrace');
    }
  }
}
