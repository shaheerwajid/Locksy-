import 'package:CryptoChat/pages/chat.dart';
import 'package:CryptoChat/providers/ChatProvider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatePage1 extends StatelessWidget {
  const ChatePage1({super.key});
  @override
  Widget build(BuildContext context) {
    var authService = Provider.of<AuthService>(context, listen: false);
    var chatService = Provider.of<ChatService>(context, listen: false);
    var soket = Provider.of<SocketService>(context, listen: false);

    return ChangeNotifierProvider(
      create: (context) => ChatProvider(
          uid: authService.usuario!.uid!,
          toUid: chatService.usuarioPara!.uid!,
          isOnline: chatService.usuarioPara!.online,
          groupUid: chatService.grupoPara,
          socketService: soket,
          chatService: chatService),

      child: const Chat(),
    );
  }
}
