// import 'dart:io';
//
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/services.dart';
// import 'package:no_screenshot/no_screenshot.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// //import 'package:in_app_purchase_android/in_app_purchase_android.dart';
//
// import 'package:flutter_downloader/flutter_downloader.dart';
//
// import 'package:CryptoChat/global/AppLanguage.dart';
// import 'package:CryptoChat/global/AppLocalizations.dart';
// import 'package:CryptoChat/routes/routes.dart';
// import 'package:CryptoChat/services/auth_service.dart';
// import 'package:CryptoChat/services/chat_service.dart';
// import 'package:CryptoChat/services/socket_service.dart';
//
// import 'helpers/style.dart';
//
// @pragma('vm:entry-point')
// Future<void> _handler(RemoteMessage message) async {
//   RemoteNotification? notification = message.notification;
//   AndroidNotification? android = message.notification?.android;
//   FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//
//   print("Background message received: ${message.messageId}");
//   if (notification != null && android != null) {
//     await flutterLocalNotificationsPlugin.show(
//       notification.hashCode,
//       notification.title,
//       notification.body ?? "",
//       NotificationDetails(
//         android: AndroidNotificationDetails(
//           'high_importance_channel',
//           'High Importance Notifications',
//           importance: Importance.high,
//           priority: Priority.high,
//           icon: '@mipmap/ic_launcher',
//           styleInformation: BigTextStyleInformation(
//             notification.body ?? "",
//             contentTitle: notification.title,
//             summaryText: notification.body,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// String initialRoute = "loading";
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   inicializarApp();
// }
//
// @pragma('vm:entry-point')
// void downloadCallback(String id, int status, int progress) {
//   // print(id);
//   // print(progress);
//   // print(status);
//   // print("downloading ...");
// }
//
// void inicializarApp() async {
//   AppLanguage appLanguage = AppLanguage();
//   await appLanguage.fetchLocale();
//   initialRoute = await getInitialRoute();
//   if (initialRoute == "loading") {
//     await Firebase.initializeApp();
//     FirebaseMessaging.onBackgroundMessage(_handler);
//   }
//   await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
//   if (Platform.isAndroid) {
//     //InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
//   }
//   await NoScreenshot.instance.screenshotOff();
//
//   runApp(
//     MyApp(appLanguage: appLanguage),
//   );
// }
//
// Future<String> getInitialRoute() async {
//   var prefs = await SharedPreferences.getInstance();
//
//   String? ind = prefs.getString('PMSInitialRoute');
//
//   if (ind == null) {
//     prefs.setString('PMSInitialRoute', "loading");
//     ind = "loading";
//   }
//
//   return ind;
// }
//
// class MyApp extends StatelessWidget {
//   final AppLanguage? appLanguage;
//   MyApp({this.appLanguage});
//
//   @override
//   Widget build(BuildContext context) {
//     // debugPrint("INICIA CryptoChat");
//     getPermisos();
//
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => this.appLanguage),
//         ChangeNotifierProvider(create: (_) => AuthService()),
//         ChangeNotifierProvider(create: (_) => SocketService()),
//         ChangeNotifierProvider(create: (_) => ChatService()),
//       ],
//       child: MaterialApp(
//         themeMode: ThemeMode.system,
//         supportedLocales: [
//           const Locale('en'),
//           const Locale('es'),
//         ],
//         localizationsDelegates: [
//           AppLocalizations.delegate,
//           GlobalMaterialLocalizations.delegate,
//           GlobalWidgetsLocalizations.delegate,
//           GlobalCupertinoLocalizations.delegate,
//         ],
//         color: amarillo,
//         debugShowCheckedModeBanner: false,
//         title: 'CryptoChat',
//         initialRoute: initialRoute,
//         routes: appRoutes,
//       ),
//     );
//   }
//
//   getPermisos() async {
//     try {
//       if (Platform.isIOS && await Permission.mediaLibrary.status.isDenied)
//         await Permission.mediaLibrary.request();
//     } catch (e) {
//       // print("ERROR PERMISOS");
//       // print(e);
//     }
//   }
// }
import 'dart:io';
import 'dart:convert';
import 'package:CryptoChat/pages/login_page.dart';
import 'package:CryptoChat/pages/onboarding_screen.dart';
import 'package:CryptoChat/pages/loading_page.dart'; // Import LoadingPage here
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
// Removed no_screenshot - not actively used (was commented out)
// import 'package:no_screenshot/no_screenshot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'package:CryptoChat/global/AppLanguage.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/routes/routes.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/providers/call_provider.dart';
import 'package:CryptoChat/push_providers/push_notifications.dart';
import 'package:CryptoChat/services/call_notification_service.dart';
import 'package:CryptoChat/services/telemetry_service.dart';
import 'helpers/style.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Helper function to translate Spanish notification text to English
String _translateNotificationToEnglish(String text) {
  if (text.isEmpty) return text;

  final lowerText = text.toLowerCase().trim();

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

  if (translations.containsKey(lowerText)) {
    return translations[lowerText]!;
  }

  for (var entry in translations.entries) {
    if (lowerText.contains(entry.key)) {
      return entry.value;
    }
  }

  return text;
}

@pragma('vm:entry-point')
Future<void> _handler(RemoteMessage message) async {
  debugPrint('[FCM-BG] ========================================');
  debugPrint('[FCM-BG] Background message received!');
  debugPrint('[FCM-BG] Message ID: ${message.messageId}');
  debugPrint('[FCM-BG] Notification type: ${message.data['type']}');
  debugPrint('[FCM-BG] Data: ${message.data}');
  debugPrint('[FCM-BG] Notification title: ${message.notification?.title}');
  debugPrint('[FCM-BG] Notification body: ${message.notification?.body}');

  // Get notification type from data
  final notificationType = message.data['type'] ?? 'message';
  final isCall =
      notificationType == 'incoming_call' || notificationType == 'call';

  // CRITICAL: Handle call notifications - ONLY use data block, ignore notification block
  if (isCall) {
    debugPrint('[FCM-BG] 📞 Incoming call notification detected!');
    debugPrint(
        '[FCM-BG] ⚠️ IGNORING notification block - using ONLY data block');
    debugPrint(
        '[FCM-BG] Caller: ${message.data['callerName'] ?? message.data['nombre'] ?? 'Unknown'}');
    debugPrint('[FCM-BG] CallerId: ${message.data['callerId']}');
    debugPrint('[FCM-BG] IsVideoCall: ${message.data['isVideoCall']}');

    try {
      // CRITICAL: Store call data in SharedPreferences for later retrieval
      // This ensures we have all call data even if app is terminated
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_call_data', jsonEncode(message.data));
        await prefs.setInt(
            'pending_call_timestamp', DateTime.now().millisecondsSinceEpoch);
        debugPrint('[FCM-BG] ✅ Call data stored in SharedPreferences');
      } catch (e) {
        debugPrint('[FCM-BG] ⚠️ Error storing call data: $e');
      }

      // Use CallNotificationService for robust call handling
      // This shows the custom notification with Accept/Decline buttons
      await CallNotificationService.handleFCMCallData(message.data);
      debugPrint('[FCM-BG] ✅ Call notification shown successfully');
      debugPrint('[FCM-BG] ========================================');
      // CRITICAL: Return IMMEDIATELY to prevent ANY other notification processing
      // We've handled the call notification via CallNotificationService
      // Do NOT process notification block or data-only block for calls
      return;
    } catch (e, stackTrace) {
      debugPrint('[FCM-BG] ❌ Call notification error: $e');
      debugPrint('[FCM-BG] Stack trace: $stackTrace');
      // Even on error, return early to prevent duplicate notifications
      return;
    }
  }

  // For non-call notifications (or if CallKit failed), use regular notifications
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  // CRITICAL: Skip showing notification for calls - we already handled it above
  // This prevents duplicate notifications when FCM shows one from backend payload
  // Note: Backend should only send DATA messages for calls (no notification block)
  if (notification != null && android != null && !isCall) {
    // Use a unique ID for each notification
    final notificationId = message.hashCode;

    // Try to get actual message content from data if notification.body is generic
    String notificationBody =
        _translateNotificationToEnglish(notification.body ?? '');
    String notificationTitle = _translateNotificationToEnglish(
        notification.title ?? (isCall ? 'Incoming Call' : 'New Message'));

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
        final lowerDataBody = dataBody.toLowerCase();
        if (lowerDataBody.contains('nuevo mensaje') ||
            lowerDataBody.contains('mensaje nuevo') ||
            lowerDataBody.contains('solicitud')) {
          notificationBody = _translateNotificationToEnglish(dataBody);
        } else {
          // It's actual user message content, keep as is
          notificationBody = dataBody;
        }
        debugPrint('[FCM-BG] Using message content from data payload');
      }
    }

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      notificationTitle,
      notificationBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          ongoing:
              false, // Not a call notification (we already handled calls above)
          autoCancel: true, // Auto-cancel regular notifications
          styleInformation: BigTextStyleInformation(
            notificationBody,
            contentTitle: notificationTitle,
            summaryText: notificationBody,
          ),
          // Add sound for calls
          sound: isCall
              ? const RawResourceAndroidNotificationSound('notification')
              : null,
        ),
      ),
    );

    debugPrint('[FCM-BG] ✅ Notification shown: $notificationTitle');

    // For call notifications, log the call data for debugging
    if (isCall) {
      final callerId = message.data['callerId'] ?? message.data['codigo'];
      final callerName = message.data['nombre'] ?? notificationTitle;
      final isVideoCall = message.data['isVideoCall'] == true ||
          message.data['isVideoCall'] == 'true';
      final hasSDP = message.data['sdp'] != null;
      debugPrint(
          '[FCM-BG] Call notification - Caller: $callerName, ID: $callerId, Video: $isVideoCall, HasSDP: $hasSDP');
    }
  } else if (message.data.isNotEmpty) {
    // Handle data-only messages (no notification payload)
    debugPrint('[FCM-BG] Data-only message received');
    debugPrint('[FCM-BG] Data: ${message.data}');

    // Check if it's a call notification
    final notificationType = message.data['type'] ?? 'message';
    final isDataCall =
        notificationType == 'incoming_call' || notificationType == 'call';

    // CRITICAL: If it's a call, we already handled it at the top of the function
    // Do NOT process it again here to prevent duplicate notifications
    if (isDataCall) {
      debugPrint(
          '[FCM-BG] ⚠️ Call notification already handled at top, skipping data-only block');
      return;
    }

    final title = _translateNotificationToEnglish(
        message.data['title'] ?? message.data['nombreEmisor'] ?? 'New Message');
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
        ? _translateNotificationToEnglish(rawBody)
        : rawBody;

    if (title.isNotEmpty || body.isNotEmpty) {
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            ongoing: isCall,
            autoCancel: !isCall,
          ),
        ),
      );
      debugPrint('[FCM-BG] ✅ Data-only notification shown');
    } else {
      debugPrint('[FCM-BG] ⚠️ Data-only message has no title or body');
    }
  } else {
    debugPrint('[FCM-BG] ⚠️ Message has no notification payload and no data');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  inicializarApp(prefs); // Pass prefs to inicializarApp
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {}

void inicializarApp(SharedPreferences prefs) async {
  AppLanguage appLanguage = AppLanguage();
  await appLanguage.fetchLocale();

  // Initialize Firebase BEFORE setting background message handler
  await Firebase.initializeApp();
  debugPrint('[FCM] Firebase initialized');

  // Register background message handler - MUST be top-level function
  FirebaseMessaging.onBackgroundMessage(_handler);
  debugPrint('[FCM] Background message handler registered');

  // Initialize call notification service for incoming call handling
  await CallNotificationService.initialize();
  _setupCallActionListeners();
  debugPrint('[CallNotification] Call notification service initialized');

  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  if (Platform.isAndroid) {
    // Enable pending purchases for Android In-App Purchases
    // InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
  }

  runApp(MyApp(appLanguage: appLanguage, prefs: prefs)); // Pass prefs here

  // CRITICAL: After the app is up, check for pending call data (cold start tap)
  // and navigate to call UI if a call is pending.
  // Use a longer delay to ensure widget tree and providers are fully ready.
  Future.delayed(const Duration(milliseconds: 1500), () async {
    debugPrint('[CallNotification] App started, bootstrapping pending call...');
    await _bootstrapPendingCallFromPrefs();
  });
}

/// On cold start, if a call notification was tapped, use stored pending_call_data
/// to navigate into the call UI (incomingCall).
/// This is called AFTER the app has started and widget tree is ready.
Future<void> _bootstrapPendingCallFromPrefs() async {
  try {
    debugPrint('[CallNotification] Checking for cold start call launch...');

    // CRITICAL: Check call state first - if call is NOT idle, don't bootstrap
    // This prevents phantom call UI after ending a call or when call is already active
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        if (callProvider.callState != CallState.idle &&
            callProvider.callState != CallState.ended) {
          debugPrint(
              '[CallNotification] ⚠️ Call state is not idle (${callProvider.callState}), skipping bootstrap to prevent conflicts');
          // Clear any stale data since call is already active
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_call_data');
          await prefs.remove('pending_call_timestamp');
          await prefs.setBool('cold_start_call_launch', false);
          CallNotificationService.clearLaunchState();
          return;
        }
      }
    } catch (e) {
      debugPrint(
          '[CallNotification] Could not check call state (context not ready): $e');
      // Continue with bootstrap check if context isn't ready yet
    }

    // FIRST: Check static variable from CallNotificationService (most reliable)
    if (CallNotificationService.didLaunchFromCallNotification) {
      debugPrint(
          '[CallNotification] ✅ CallNotificationService reports cold start from call!');
      final launchData = CallNotificationService.launchCallData;
      if (launchData != null) {
        // CRITICAL: Clear launch state BEFORE navigating to prevent re-triggering
        CallNotificationService.clearLaunchState();
        await _navigateToCallFromData(launchData);

        // Clear SharedPreferences data after handling
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_call_data');
        await prefs.remove('pending_call_timestamp');
        await prefs.setBool('cold_start_call_launch', false);
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();

    // SECOND: Check SharedPreferences flag
    final isColdStartCallLaunch =
        prefs.getBool('cold_start_call_launch') ?? false;
    final storedCallData = prefs.getString('pending_call_data');
    final pendingTimestamp = prefs.getInt('pending_call_timestamp') ?? 0;

    debugPrint(
        '[CallNotification] isColdStartCallLaunch: $isColdStartCallLaunch');
    debugPrint(
        '[CallNotification] storedCallData exists: ${storedCallData != null && storedCallData.isNotEmpty}');

    // Check if we have pending call data
    if (storedCallData == null || storedCallData.isEmpty) {
      debugPrint('[CallNotification] No pending call data found');
      // Clear stale flags
      await prefs.setBool('cold_start_call_launch', false);
      // THIRD: Try FCM getInitialMessage as last resort
      await _checkFCMInitialMessage();
      return;
    }

    // Check if the pending call data is recent (within 10 seconds for cold start)
    final now = DateTime.now().millisecondsSinceEpoch;
    final ageMs = now - pendingTimestamp;

    // CRITICAL: Only proceed if this was a cold start launch AND data is very recent (within 5 seconds)
    // This prevents phantom call UI after ending a call or app restarts
    if (!isColdStartCallLaunch) {
      debugPrint(
          '[CallNotification] Not a cold start launch, clearing stale data to prevent phantom call UI');
      await prefs.remove('pending_call_data');
      await prefs.remove('pending_call_timestamp');
      await prefs.setBool('cold_start_call_launch', false);
      return;
    }

    // Also check that data is very recent (within 5 seconds for cold start)
    if (ageMs > 5000) {
      debugPrint(
          '[CallNotification] Cold start call data is too old (${ageMs}ms), clearing stale data');
      await prefs.remove('pending_call_data');
      await prefs.remove('pending_call_timestamp');
      await prefs.setBool('cold_start_call_launch', false);
      return;
    }

    // Clear the cold start flag immediately to prevent re-triggering
    await prefs.setBool('cold_start_call_launch', false);
    CallNotificationService.clearLaunchState();

    final payload = jsonDecode(storedCallData) as Map<String, dynamic>;
    debugPrint(
        '[CallNotification] ✅ Processing cold start call launch from SharedPreferences!');

    await _navigateToCallFromData(payload);

    // Clear pending data after handling
    await prefs.remove('pending_call_data');
    await prefs.remove('pending_call_timestamp');
  } catch (e, st) {
    debugPrint('[CallNotification] ❌ Bootstrap pending call failed: $e');
    debugPrint('[CallNotification] Stack: $st');
    // Ensure data is cleared on error
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_call_data');
      await prefs.remove('pending_call_timestamp');
      await prefs.setBool('cold_start_call_launch', false);
      CallNotificationService.clearLaunchState();
    } catch (clearError) {
      debugPrint('[CallNotification] Error clearing data: $clearError');
    }
  }
}

/// Check FCM getInitialMessage for call notifications (fallback for FCM-shown notifications)
Future<void> _checkFCMInitialMessage() async {
  try {
    debugPrint('[CallNotification] Checking FCM getInitialMessage...');
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage == null) {
      debugPrint('[CallNotification] No FCM initial message');
      return;
    }

    debugPrint(
        '[CallNotification] FCM initial message found: ${initialMessage.data}');

    final notificationType = initialMessage.data['type'] ?? '';
    if (notificationType == 'incoming_call' || notificationType == 'call') {
      debugPrint(
          '[CallNotification] ✅ FCM initial message is a call notification!');
      await _navigateToCallFromData(initialMessage.data);
    }
  } catch (e) {
    debugPrint('[CallNotification] Error checking FCM initial message: $e');
  }
}

/// Navigate to call UI from call data
Future<void> _navigateToCallFromData(Map<String, dynamic> payload) async {
  debugPrint('[CallNotification] Navigating to call UI with payload: $payload');

  final callerId =
      payload['callerId']?.toString() ?? payload['codigo']?.toString();
  final callerName = payload['callerName']?.toString() ??
      payload['nombre']?.toString() ??
      'Unknown Caller';
  final isVideoCall =
      payload['isVideoCall'] == true || payload['isVideoCall'] == 'true';
  final callerAvatar =
      payload['callerAvatar']?.toString() ?? payload['avatar']?.toString();
  final sdp = payload['sdp']?.toString();
  final rtcType = payload['rtcType']?.toString() ?? 'offer';

  // CRITICAL: Wait for navigation to be ready
  await _waitForAppInitialization();

  debugPrint('[CallNotification] App initialized, navigating to call UI...');

  final action = CallAction(
    type: CallActionType.tap,
    callId: payload['callId']?.toString() ?? payload['uuid']?.toString(),
    callerId: callerId,
    callerName: callerName,
    isVideoCall: isVideoCall,
    payload: {
      ...payload,
      'callerAvatar': callerAvatar,
      'sdp': sdp,
      'rtcType': rtcType,
    },
  );

  // Handle the call tap
  _handleCallTap(action);

  debugPrint('[CallNotification] ✅ Cold start call navigation triggered');
}

/// Set up listeners for call notification actions (Accept/Decline)
void _setupCallActionListeners() {
  try {
    debugPrint('[CallNotification] Setting up call action listeners...');

    CallNotificationService.callActions.listen((action) {
      debugPrint('[CallNotification] Action received: ${action.type}');

      switch (action.type) {
        case CallActionType.accept:
          debugPrint('[CallNotification] ✅ Call ACCEPTED');
          _handleCallAccepted(action);
          break;

        case CallActionType.decline:
          debugPrint('[CallNotification] ❌ Call DECLINED');
          _handleCallDeclined(action);
          break;

        case CallActionType.tap:
          debugPrint('[CallNotification] 📱 Notification tapped');
          _handleCallTap(action);
          break;

        case CallActionType.timeout:
          debugPrint('[CallNotification] ⏰ Call timeout');
          break;
      }
    });

    debugPrint('[CallNotification] ✅ Call action listeners set up');
  } catch (e, stackTrace) {
    debugPrint('[CallNotification] ❌ Error setting up listeners: $e');
    debugPrint('[CallNotification] Stack trace: $stackTrace');
  }
}

/// Handle when user accepts an incoming call
void _handleCallAccepted(CallAction action) async {
  try {
    final payload = action.payload ?? {};
    final callerId = payload['callerId']?.toString() ?? action.callerId;
    final callerName =
        payload['callerName']?.toString() ?? action.callerName ?? 'Unknown';
    final callerAvatar = payload['callerAvatar']?.toString();
    final isVideoCall = payload['isVideoCall'] == true ||
        payload['isVideoCall'] == 'true' ||
        action.isVideoCall;
    final sdp = payload['sdp']?.toString();
    final rtcType = payload['rtcType']?.toString() ?? 'offer';
    final callId = payload['callId']?.toString() ??
        payload['uuid']?.toString() ??
        action.callId;

    debugPrint(
        '[CallNotification] ✅ Call ACCEPTED - Caller: $callerName, Video: $isVideoCall, CallId: $callId');

    // Log telemetry
    TelemetryService.log('call_notification_accepted', data: {
      'callerId': callerId,
      'callerName': callerName,
      'isVideoCall': isVideoCall,
      'callId': callId,
    });

    // CRITICAL: Wait for app initialization if cold start
    await _waitForAppInitialization();

    // CRITICAL: Try to retrieve stored call data if payload is incomplete
    Map<String, dynamic> finalPayload = Map<String, dynamic>.from(payload);
    if (finalPayload['sdp'] == null || finalPayload['callerId'] == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedCallData = prefs.getString('pending_call_data');
        if (storedCallData != null) {
          final storedData = jsonDecode(storedCallData) as Map<String, dynamic>;
          debugPrint('[CallNotification] Retrieved stored call data');
          // Merge stored data with payload (payload takes precedence)
          finalPayload = {...storedData, ...finalPayload};
        }
      } catch (e) {
        debugPrint('[CallNotification] Error retrieving stored call data: $e');
      }
    }

    // Update variables from final payload
    final finalCallerId = finalPayload['callerId']?.toString() ?? callerId;
    final finalCallerName =
        finalPayload['callerName']?.toString() ?? callerName;
    final finalCallerAvatar =
        finalPayload['callerAvatar']?.toString() ?? callerAvatar;
    final finalIsVideoCall = finalPayload['isVideoCall'] == true ||
        finalPayload['isVideoCall'] == 'true' ||
        isVideoCall;
    final finalSdp = finalPayload['sdp']?.toString() ?? sdp;
    final finalRtcType = finalPayload['rtcType']?.toString() ?? rtcType;

    // Get providers safely (with retries for cold start)
    final providers = await _getProvidersSafely();
    if (providers == null) {
      debugPrint('[CallNotification] ❌ Cannot get providers, retrying...');
      Future.delayed(
          const Duration(milliseconds: 500), () => _handleCallAccepted(action));
      return;
    }

    final callProvider = providers['callProvider'] as CallProvider;
    final socketService = providers['socketService'] as SocketService;
    final authService = providers['authService'] as AuthService;

    // Initialize CallProvider if needed
    if (!callProvider.isInitialized) {
      debugPrint('[CallNotification] Initializing CallProvider...');
      callProvider.initialize(socketService, authService, navigatorKey);
      // Wait a bit for initialization
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Ensure socket is connected
    debugPrint('[CallNotification] Ensuring socket connection...');
    final socketConnected = await _ensureSocketConnected(socketService);
    if (!socketConnected) {
      debugPrint(
          '[CallNotification] ❌ Socket connection failed, cannot accept call');
      return;
    }

    // Set up call data in CallProvider (with autoAccept flag to skip incoming call page)
    debugPrint('[CallNotification] Setting up call data...');
    callProvider.handleIncomingCallFromFCM({
      'callerId': finalCallerId,
      'callerName': finalCallerName,
      'callerAvatar': finalCallerAvatar,
      'isVideoCall': finalIsVideoCall,
      'sdp': finalSdp,
      'rtcType': finalRtcType,
    }, autoAccept: true);

    // CRITICAL: Wait longer for socket and WebRTC initialization when app was closed
    // The socket connection and WebRTC setup need more time when starting from cold
    await Future.delayed(const Duration(milliseconds: 1000));

    // Accept the call
    debugPrint('[CallNotification] Accepting call...');
    await callProvider.acceptCall();

    // Wait for call to connect (with longer timeout for cold start)
    debugPrint('[CallNotification] Waiting for call to connect...');
    bool callConnected = false;
    for (int i = 0; i < 60; i++) {
      // 60 attempts = 30 seconds max (increased for cold start scenarios)
      await Future.delayed(const Duration(milliseconds: 500));
      if (callProvider.callState == CallState.connected) {
        callConnected = true;
        debugPrint('[CallNotification] ✅ Call connected!');
        break;
      }
      debugPrint(
          '[CallNotification] Call state: ${callProvider.callState}, attempt ${i + 1}/60...');
    }

    if (!callConnected) {
      debugPrint(
          '[CallNotification] ⚠️ Call did not connect within timeout, navigating anyway...');
    }

    // Navigate to active call page
    debugPrint('[CallNotification] Navigating to active call page...');
    _retryNavigation(
      maxAttempts: 5,
      initialDelay: const Duration(milliseconds: 300),
      route: 'activeCall',
      arguments: {
        'isVideoCall': finalIsVideoCall,
      },
      onSuccess: () {
        debugPrint('[CallNotification] ✅ Navigated to active call page');
      },
    );
  } catch (e, stackTrace) {
    debugPrint('[CallNotification] ❌ Error handling accept: $e');
    debugPrint('[CallNotification] Stack trace: $stackTrace');
  }
}

/// Wait for app initialization (useful for cold start)
Future<void> _waitForAppInitialization() async {
  int attempts = 0;
  const maxAttempts = 20; // 10 seconds max
  const delay = Duration(milliseconds: 500);

  while (attempts < maxAttempts) {
    if (navigatorKey.currentState != null) {
      final context = navigatorKey.currentState?.context;
      if (context != null) {
        // CRITICAL: Also verify that Providers are available in the context
        try {
          // Try to access a Provider to ensure the widget tree is ready
          Provider.of<AuthService>(context, listen: false);
          debugPrint(
              '[CallNotification] ✅ App initialized and Providers are ready');
          return;
        } catch (e) {
          // Provider not available yet, continue waiting
          debugPrint(
              '[CallNotification] Providers not ready yet, waiting... ($attempts/$maxAttempts)');
        }
      }
    }
    attempts++;
    debugPrint(
        '[CallNotification] Waiting for app initialization... ($attempts/$maxAttempts)');
    await Future.delayed(delay);
  }
  debugPrint('[CallNotification] ⚠️ App initialization timeout');
}

/// Safely get Providers from context with retries (for cold start scenarios)
Future<Map<String, dynamic>?> _getProvidersSafely() async {
  int attempts = 0;
  const maxAttempts = 20; // 10 seconds max
  const delay = Duration(milliseconds: 500);

  while (attempts < maxAttempts) {
    try {
      final context = navigatorKey.currentState?.context;
      if (context == null) {
        attempts++;
        await Future.delayed(delay);
        continue;
      }

      // Try to access all required providers
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      final socketService = Provider.of<SocketService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      debugPrint('[CallNotification] ✅ Successfully retrieved all Providers');
      return {
        'callProvider': callProvider,
        'socketService': socketService,
        'authService': authService,
      };
    } catch (e) {
      attempts++;
      debugPrint(
          '[CallNotification] Providers not ready yet (attempt $attempts/$maxAttempts): $e');
      if (attempts >= maxAttempts) {
        debugPrint(
            '[CallNotification] ❌ Failed to get Providers after $maxAttempts attempts');
        return null;
      }
      await Future.delayed(delay);
    }
  }

  return null;
}

/// Ensure socket is connected, wait if needed
Future<bool> _ensureSocketConnected(SocketService socketService) async {
  // If already connected, return immediately
  if (socketService.socket != null && socketService.socket!.connected) {
    debugPrint('[CallNotification] ✅ Socket already connected');
    return true;
  }

  debugPrint(
      '[CallNotification] Socket not connected, attempting to connect...');

  // Try to connect
  try {
    socketService.connect();
  } catch (e) {
    debugPrint('[CallNotification] Error initiating socket connection: $e');
  }

  // Wait for connection (with timeout)
  const maxWaitTime = Duration(seconds: 10);
  const checkInterval = Duration(milliseconds: 500);
  final startTime = DateTime.now();

  while (DateTime.now().difference(startTime) < maxWaitTime) {
    if (socketService.socket != null && socketService.socket!.connected) {
      debugPrint('[CallNotification] ✅ Socket connected!');
      return true;
    }
    await Future.delayed(checkInterval);
  }

  debugPrint('[CallNotification] ❌ Socket connection timeout');
  return false;
}

/// Retry navigation with exponential backoff
void _retryNavigation({
  required int maxAttempts,
  required Duration initialDelay,
  required String route,
  required Map<String, dynamic> arguments,
  required VoidCallback onSuccess,
}) {
  int attempts = 0;
  Duration delay = initialDelay;

  void attemptNavigation() {
    attempts++;

    // CRITICAL: Wait for app initialization before navigating
    if (navigatorKey.currentState == null) {
      if (attempts < maxAttempts) {
        debugPrint(
            '[CallNotification] Navigator not ready, retrying in ${delay.inMilliseconds}ms (attempt $attempts/$maxAttempts)');
        Future.delayed(delay, attemptNavigation);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
        return;
      } else {
        debugPrint(
            '[CallNotification] ❌ Navigator not ready after $maxAttempts attempts');
        return;
      }
    }

    try {
      final context = navigatorKey.currentState!.context;

      // CRITICAL: Check if already on the target route before navigating
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == route) {
        debugPrint(
            '[CallNotification] ⚠️ Already on $route, skipping duplicate navigation');
        onSuccess();
        return;
      }

      // Navigate
      navigatorKey.currentState!.pushNamed(route, arguments: arguments);
      debugPrint('[CallNotification] ✅ Navigation successful to $route');
      onSuccess();
      return;
    } catch (e) {
      debugPrint('[CallNotification] Navigation attempt $attempts failed: $e');

      if (attempts < maxAttempts) {
        debugPrint(
            '[CallNotification] Retrying navigation in ${delay.inMilliseconds}ms (attempt $attempts/$maxAttempts)');
        Future.delayed(delay, attemptNavigation);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
      } else {
        debugPrint(
            '[CallNotification] ❌ Failed to navigate after $maxAttempts attempts');
      }
    }
  }

  attemptNavigation();
}

/// Handle when user declines an incoming call
void _handleCallDeclined(CallAction action) async {
  try {
    final payload = action.payload ?? {};
    final callerId = payload['callerId']?.toString() ?? action.callerId;
    final callId = payload['callId']?.toString() ??
        payload['uuid']?.toString() ??
        action.callId;

    debugPrint(
        '[CallNotification] ❌ Call DECLINED - callerId: $callerId, callId: $callId');

    // Log telemetry
    TelemetryService.log('call_notification_declined', data: {
      'callerId': callerId,
      'callId': callId,
    });

    // Cancel the notification
    await CallNotificationService.cancelCallNotification();

    // Try to notify caller via socket
    await _notifyCallDeclined(callerId, callId);

    // CRITICAL: Don't open app if declined from notification (when app was terminated)
    // Only navigate if app is already running
    final providers = await _getProvidersSafely();
    if (providers != null) {
      // App is running, we can use CallProvider to reject properly
      try {
        final callProvider = providers['callProvider'] as CallProvider;
        if (callProvider.callState == CallState.ringing) {
          callProvider.rejectCall();
        }
      } catch (e) {
        debugPrint('[CallNotification] Could not access CallProvider: $e');
      }
    } else {
      debugPrint(
          '[CallNotification] App not running, decline handled via notification only');
    }
  } catch (e, stackTrace) {
    debugPrint('[CallNotification] ❌ Error handling decline: $e');
    debugPrint('[CallNotification] Stack trace: $stackTrace');
  }
}

/// Notify caller that call was declined via socket
Future<void> _notifyCallDeclined(String? callerId, String? callId) async {
  if (callerId == null || callerId.isEmpty) {
    debugPrint(
        '[CallNotification] ⚠️ Cannot notify decline - callerId is null/empty');
    return;
  }

  // Try to get socket service from context (safely)
  final providers = await _getProvidersSafely();
  if (providers != null) {
    try {
      final socketService = providers['socketService'] as SocketService;
      final authService = providers['authService'] as AuthService;

      // Ensure socket is connected
      if (socketService.socket == null || !socketService.socket!.connected) {
        debugPrint(
            '[CallNotification] Socket not connected, attempting to connect...');
        socketService.connect();
        // Wait for connection with timeout
        int attempts = 0;
        while (attempts < 10 &&
            (socketService.socket == null ||
                !socketService.socket!.connected)) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }
      }

      // Send decline notification via socket
      if (socketService.socket != null && socketService.socket!.connected) {
        socketService.socket!.emit('endCall', {
          'to': callerId,
          'from': authService.usuario?.uid,
          'reason': 'declined',
        });
        debugPrint('[CallNotification] ✅ Decline notification sent via socket');
        return;
      }
    } catch (e) {
      debugPrint('[CallNotification] Error accessing providers: $e');
    }
  }

  // Fallback: Try to send via API if socket is not available
  debugPrint(
      '[CallNotification] Socket not available, decline handled via notification only');
  // Note: Backend should handle call timeout if no response is received
}

/// Handle when user taps on call notification
/// This mirrors the EXACT logic from _handleRemoteMessageTap to ensure consistent behavior
void _handleCallTap(CallAction action) async {
  try {
    final payload = action.payload ?? {};
    final callerId = payload['callerId']?.toString() ?? action.callerId;
    final callerName =
        payload['callerName']?.toString() ?? action.callerName ?? 'Unknown';
    final callerAvatar = payload['callerAvatar']?.toString();
    final isVideoCall = payload['isVideoCall'] == true || action.isVideoCall;
    final sdp = payload['sdp']?.toString();
    final rtcType = payload['rtcType']?.toString() ?? 'offer';

    debugPrint(
        '[CallNotification] 📱 Call notification tapped - Opening incoming call page');
    debugPrint('[CallNotification] Caller: $callerName, Video: $isVideoCall');
    debugPrint(
        '[CallNotification] Call data - callerId: $callerId, hasSDP: ${sdp != null}');

    // CRITICAL: Wait for app initialization (for cold start scenarios)
    await _waitForAppInitialization();

    // Navigate directly to incoming call page (EXACT same logic as _handleRemoteMessageTap)
    if (navigatorKey.currentState != null) {
      // Set up CallProvider first (CRITICAL - same as old notification handler)
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          // Get providers safely
          final providers = await _getProvidersSafely();
          if (providers == null) {
            debugPrint(
                '[CallNotification] ❌ Cannot get providers, retrying...');
            Future.delayed(const Duration(milliseconds: 500),
                () => _handleCallTap(action));
            return;
          }

          final callProvider = providers['callProvider'] as CallProvider;
          final socketService = providers['socketService'] as SocketService;
          final authService = providers['authService'] as AuthService;

          // Initialize CallProvider if needed
          if (!callProvider.isInitialized) {
            debugPrint('[CallNotification] Initializing CallProvider');
            callProvider.initialize(socketService, authService, navigatorKey);
            await Future.delayed(const Duration(milliseconds: 200));
          }

          // CRITICAL: Check if already on incoming call page before navigating
          try {
            final navContext = navigatorKey.currentState?.context;
            if (navContext != null) {
              final currentRoute = ModalRoute.of(navContext)?.settings.name;
              if (currentRoute == 'incomingCall') {
                debugPrint(
                    '[CallNotification] ⚠️ Already on incoming call page, skipping duplicate navigation');
                return;
              }
            }
          } catch (e) {
            debugPrint('[CallNotification] Could not check current route: $e');
          }

          // Check if call is already ringing
          if (callProvider.callState == CallState.ringing) {
            debugPrint(
                '[CallNotification] ⚠️ Call is already ringing, navigating to incoming call page');
          } else if (callerId != null) {
            // Set up call data in CallProvider (EXACT same as old handler)
            final callData = {
              'callerId': callerId,
              'callerName': callerName,
              'callerAvatar': callerAvatar,
              'isVideoCall': isVideoCall,
              'sdp': sdp,
              'type': rtcType,
            };
            callProvider.handleIncomingCallFromFCM(callData);
            debugPrint(
                '[CallNotification] ✅ CallProvider set up with call data');
          }

          // Navigate to incoming call page (EXACT same as old handler)
          // Double-check route before navigating
          try {
            final navContext = navigatorKey.currentState?.context;
            if (navContext != null) {
              final route = ModalRoute.of(navContext)?.settings.name;
              if (route == 'incomingCall') {
                debugPrint(
                    '[CallNotification] ⚠️ Already on incoming call page, skipping');
                return;
              }
            }
          } catch (e) {
            debugPrint(
                '[CallNotification] Could not check route before navigation: $e');
          }

          // Navigate if not already on the page
          try {
            navigatorKey.currentState!.pushNamed(
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
            debugPrint('[CallNotification] ✅ Navigated to incoming call page');
          } catch (navError) {
            debugPrint('[CallNotification] ❌ Error navigating: $navError');
            // Retry navigation
            Future.delayed(const Duration(milliseconds: 500),
                () => _handleCallTap(action));
          }
        } catch (e) {
          debugPrint('[CallNotification] ⚠️ Error handling call tap: $e');
          // Retry on error
          Future.delayed(
              const Duration(milliseconds: 500), () => _handleCallTap(action));
        }
      });
    } else {
      debugPrint('[CallNotification] ❌ Navigator not available, retrying...');
      Future.delayed(
          const Duration(milliseconds: 500), () => _handleCallTap(action));
    }
  } catch (e, stackTrace) {
    debugPrint('[CallNotification] ❌ Error handling tap: $e');
    debugPrint('[CallNotification] Stack trace: $stackTrace');
  }
}

class MyApp extends StatelessWidget {
  final AppLanguage? appLanguage;
  final SharedPreferences prefs;

  const MyApp({super.key, required this.appLanguage, required this.prefs});

  @override
  Widget build(BuildContext context) {
    getPermisos();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appLanguage!),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: Consumer<AppLanguage>(
        builder: (context, appLanguage, child) {
          // Set navigator key for notification navigation
          PushNotifications.setNavigatorKey(navigatorKey);

          return MaterialApp(
            navigatorKey: navigatorKey,
            locale: appLanguage.appLocal, // Use the current locale
            themeMode: ThemeMode.system,
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            color: amarillo,
            debugShowCheckedModeBanner: false,
            title: 'CryptoChat',
            home: LoadingPage(),
            routes: {
              'onboarding': (context) => OnboardingScreen(),
              'login': (context) => LoginPage(),
              ...appRoutes,
            },
          );
        },
      ),
    );
  }

  getPermisos() async {
    try {
      if (Platform.isIOS && await Permission.mediaLibrary.status.isDenied) {
        await Permission.mediaLibrary.request();
      }
    } catch (e) {
      // Handle permission errors
    }
  }
}
