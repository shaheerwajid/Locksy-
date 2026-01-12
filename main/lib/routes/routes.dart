import 'package:CryptoChat/pages/Chat_pageV1.dart';
import 'package:CryptoChat/pages/GroupChat.dart';
import 'package:flutter/material.dart';
import 'package:CryptoChat/pages/account_page.dart';
import 'package:CryptoChat/pages/archivo_page.dart';
import 'package:CryptoChat/pages/ayuda_page.dart';
// import 'package:CryptoChat/pages/chat_grupo_page.dart';
import 'package:CryptoChat/pages/grupos_page.dart';
import 'package:CryptoChat/pages/db_page.dart';
import 'package:CryptoChat/pages/idiomas_page.dart';
import 'package:CryptoChat/pages/loading_page.dart';
import 'package:CryptoChat/pages/login_page.dart';
import 'package:CryptoChat/pages/opciones_page.dart';
import 'package:CryptoChat/pages/preguntas_page.dart';
import 'package:CryptoChat/pages/recovery_page.dart';
import 'package:CryptoChat/pages/register_page.dart';
import 'package:CryptoChat/pages/change_password_page.dart';
import 'package:CryptoChat/pages/contactos_page.dart';
import 'package:CryptoChat/pages/search_page.dart';
import 'package:CryptoChat/pages/feed_page.dart';
import 'package:CryptoChat/pages/notifications_page.dart';
import 'package:CryptoChat/widgets/pinInput_widget.dart';
import 'package:CryptoChat/widgets/qrviewer.dart';

import 'package:CryptoChat/calc/mainCalc.dart';

import '../pages/dissapearing_messages.dart';
import '../pages/tabbar_page.dart';
import '../pages/incoming_call_page.dart';
import '../pages/active_call_page.dart';
import '../pages/payment_page.dart';

final Map<String, Widget Function(BuildContext)> appRoutes = {
  'loading': (_) => const LoadingPage(),
  'home': (_) => const TabBarPage(),
  'login': (_) => const LoginPage(),
  'register': (_) => const RegisterPage(),
  'recovery': (_) => const RecoveryPage(),
  'change_password': (_) => const ChangePasswordPage(),
  'contactos': (_) => const ContactosPage(),
  'chat': (_) => const ChatePage1(),
  'chatGrupal': (_) => const GChatePage1(),
  // 'chatGrupal1': (_) => ChatGrupoPage(),
  'cuenta': (_) => const AccountPage(),
  'preguntas': (_) => const PreguntasPage(),
  'database': (_) => const DBPage(),
  'idiomas': (_) => const IdiomaPage(),
  'ayuda': (_) => const AyudaPage(),
  'grupos': (_) => const GruposPage(),
  'config': (_) => const TabBarPage(
        initialIndex: 3,
      ),
  'disapearing_messages': (_) => const DissapearingMessagesPage(),
  'archivo': (_) => const ArchivoPage(),
  'opciones': (_) => const OpcionesPage(),
  'qrviewer': (_) => const QRViewer(),
  'search': (_) => const SearchPage(),
  'feed': (_) => const FeedPage(),
  'notifications': (_) => const NotificationsPage(),
  'mainCalc': (_) => const CalculatorApp(),
  'pinput': (_) => const PinPutView(titulo: '', subtitulo: ''),
  'payment': (_) => PaymentPage(),
  'incomingCall': (context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    return IncomingCallPage(
      callerName: args?['callerName'] ?? 'Unknown',
      callerAvatar: args?['callerAvatar'],
      isVideoCall: args?['isVideoCall'] ?? false,
    );
  },
  'activeCall': (context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    return ActiveCallPage(
      isVideoCall: args?['isVideoCall'] ?? false,
    );
  },
};
