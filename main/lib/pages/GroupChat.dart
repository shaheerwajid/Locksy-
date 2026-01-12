import 'package:CryptoChat/pages/Gchat.dart';
import 'package:CryptoChat/providers/GroupProvider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GChatePage1 extends StatelessWidget {
  const GChatePage1({super.key});
  @override
  Widget build(BuildContext context) {
    var authService = Provider.of<AuthService>(context, listen: false);
    var chatService = Provider.of<ChatService>(context, listen: false);
    var soket = Provider.of<SocketService>(context, listen: false);

    return ChangeNotifierProvider(
      create: (context) => GroupChatProvider(
          uid: authService.usuario!.uid!,
          // toUid: chatService.usuarioPara!.uid!,
          groupUid: chatService.grupoPara,
          socketService: soket),
      // update: (_, auth, myNotifier) => ChatProvider(
      //   uid: authService.usuario!.uid!,
      //   toUid: chatService.usuarioPara!.uid!,
      //   groupUid: chatService.grupoPara,
      //   socketService: soket,
      // ),
      child: const GChat(),
    );
  }
}
