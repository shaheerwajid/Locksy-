import 'dart:convert';

import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/pages/usuario_page.dart';
import 'package:CryptoChat/providers/ChatProvider.dart';
import 'package:CryptoChat/providers/call_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:CryptoChat/widgets/connection_banner.dart';
import 'package:CryptoChat/widgets/message_skeleton.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/replymsg.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loadmore/loadmore.dart';
import 'package:provider/provider.dart';
import 'package:swipe_to/swipe_to.dart';

import '../global/AppLocalizations.dart';
import '../widgets/displayImage.dart';
import '../widgets/input_text_row.dart';
import '../main.dart';

class Chat extends StatelessWidget {
  const Chat({super.key});
  final double carga = 0;

  @override
  Widget build(BuildContext context) {
    var authService = Provider.of<AuthService>(context, listen: false);
    var chatService = Provider.of<ChatService>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // chatProvider.init();
    return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          shadowColor: sub_header,
          backgroundColor: header,
          leading: InkWell(
            child: Icon(
              Icons.arrow_back_ios_rounded,
              color: background,
            ),
            onTap: () => Navigator.pop(context, true),
          ),
          title: Selector<ChatProvider, int>(
              selector: (_, provider) => provider.selectionVersion,
              builder: (context, selectionVersion, child) {
                return chatProvider.selectedItems.isEmpty
              ? Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: blanco.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Consumer<ChatProvider>(
                                        builder:
                                            (context, chatProvider, child) {
                                      return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          capitalize(
                                              chatService.usuarioPara!.nombre!),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: negro,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          calculateLastSeen(
                                              chatService.usuarioPara!.lastSeen,
                                              chatService.usuarioPara!.online,
                                              context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: negro,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        )
                                      ],
                                    );
                                  }),
                                  ),
                                  const SizedBox(width: 12),
                                  Hero(
                                    tag: 'avatar',
                                    child: CircleAvatar(
                                      backgroundImage: AssetImage(getAvatar(
                                          chatService.usuarioPara!.avatar!,
                                          "user_")),
                                      backgroundColor: blanco,
                                      maxRadius: 20,
                                    ),
                                  ),
                                ],
                              )),
                          onTap: () {
                            if (chatProvider.esContacto) {
                              Navigator.of(context, rootNavigator: true)
                                  .push(MaterialPageRoute(
                                      builder: (context) => UsuarioPage(
                                          chatService.usuarioPara!)))
                                  .then((res) {
                                print(res);
                                chatProvider.Clearhistory(res);
                                chatProvider.getIncognito();
                              });

                              // _cargarHistorial(usuarioPara.uid);
                            }
                          }),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final callProvider = Provider.of<CallProvider>(
                                  context,
                                  listen: false);
                              callProvider.initialize(
                                Provider.of<SocketService>(context,
                                    listen: false),
                                authService,
                                navigatorKey,
                              );
                              callProvider.makeCall(
                                chatService.usuarioPara!.uid!,
                                chatService.usuarioPara!.nombre!,
                                chatService.usuarioPara!.avatar,
                                CallType.audio,
                              );
                              Navigator.pushNamed(
                                context,
                                'activeCall',
                                arguments: {
                                  'isVideoCall': false,
                                },
                              );
                            },
                            icon: Icon(
                              Icons.call,
                              color: background,
                            )),
                        IconButton(
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final callProvider = Provider.of<CallProvider>(
                                  context,
                                  listen: false);
                              callProvider.initialize(
                                Provider.of<SocketService>(context,
                                    listen: false),
                                authService,
                                navigatorKey,
                              );
                              callProvider.makeCall(
                                chatService.usuarioPara!.uid!,
                                chatService.usuarioPara!.nombre!,
                                chatService.usuarioPara!.avatar,
                                CallType.video,
                              );
                              Navigator.pushNamed(
                                context,
                                'activeCall',
                                arguments: {
                                  'isVideoCall': true,
                                },
                              );
                            },
                            icon: Icon(
                              Icons.video_call,
                              color: background,
                            )),
                      ],
                    )
                  ],
                )
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: blanco.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 0),
                      Text(
                        chatProvider.selectedItems.length.toString(),
                        style: TextStyle(
                          color: gris,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          chatProvider.CopyMessages(
                              context,
                              chatService.usuarioPara!.nombre!,
                              authService.usuario!.nombre!);
                        },
                        child: Icon(
                          Icons.copy,
                          size: 20,
                          color: gris,
                        ),
                      ),
                      if (chatProvider.showImageSave)
                        GestureDetector(
                            onTap: () {
                              chatProvider.SaveImageToGallerie(context);
                            },
                            child: Icon(
                              Icons.save,
                              size: 22,
                              color: gris,
                            )),
                      GestureDetector(
                          onTap: () {
                            chatProvider.Forwarde(context);
                          },
                          child: Icon(
                            Icons.forward,
                            size: 22,
                            color: gris,
                          )),
                      GestureDetector(
                          child: Container(
                            child: Icon(
                              Icons.delete,
                              size: 22,
                              color: rojo,
                            ),
                          ),
                          onTap: () {
                            chatProvider.validarMensajesMios();

                            alertaWidget(
                                context,
                                AppLocalizations.of(context)!
                                    .translate('DROP_SELECTED_MESSAGES'),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    btnEliminar(
                                        context,
                                        AppLocalizations.of(context)!
                                            .translate('FOR_ME'),
                                        false,
                                        chatProvider),
                                    const SizedBox(width: 10),
                                    chatProvider.soloMios
                                        ? btnEliminar(
                                            context,
                                            AppLocalizations.of(context)!
                                                .translate('FOR_EVERYONE'),
                                            true,
                                            chatProvider)
                                        : const SizedBox(),
                                  ],
                                ),
                                'CANCEL');
                          }),
                    ],
                  ),
                );
              }),
        ),
        body: Column(
          children: [
            const ConnectionBanner(),
            Expanded(
              child: Container(
                child: SafeArea(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width,
                        child: Image.asset(
                          'assets/background/img_chat.png',
                          color: blanco.withOpacity(0.05),
                          fit: BoxFit.cover,
                        ),
                      ),
                      chatProvider.incognito
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: azul.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .translate('HIDDEN_MODE'),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(),
                      Column(
                        children: [
                          Flexible(
                            child: Selector<ChatProvider, int>(
                                selector: (_, provider) =>
                                    provider.msgsVersion,
                                builder: (context, msgsVersion, child) {
                                  return Selector<ChatProvider, int>(
                                      selector: (_, provider) =>
                                          provider.selectionVersion,
                                      builder:
                                          (context, selectionVersion, child) {
                                        return chatProvider.messajes.isEmpty &&
                                    chatProvider.isLoadingFinished == false
                                ? const ChatListSkeleton()
                                : LoadMore(
                                    textBuilder: (status) {
                                      print(status);
                                      if (status == LoadMoreStatus.nomore) {
                                        return "";
                                      } else if (status ==
                                          LoadMoreStatus.loading) {
                                        return "Loading";
                                      } else if (status ==
                                          LoadMoreStatus.fail) {
                                        return "Error";
                                      }
                                      return "";
                                    },
                                    isFinish: chatProvider.isLoadingFinished,
                                    onLoadMore: chatProvider.loadMore,
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: chatProvider.messajes.length,
                                      // Add cacheExtent for better scroll performance
                                      cacheExtent: 500.0,
                                      itemBuilder: (context, index) {
                                        final item =
                                            chatProvider.messajes[index];
                                        final fesha =
                                            jsonDecode(item.mensaje!)['fecha'];
                                        DateTime horaar1 = parseUTCFecha(fesha);
                                        DateTime horaar = horaar1.toLocal();
                                        // Use RepaintBoundary to prevent unnecessary repaints
                                        return RepaintBoundary(
                                          key: ValueKey(
                                              'msg_${fesha}_${item.de}_${item.para}'),
                                          child: GestureDetector(
                                            onTap: () {
                                              chatProvider.SelectM(
                                                index,
                                                ChatMessage(
                                                  selected: chatProvider
                                                      .selectedItems
                                                      .contains(index),
                                                  dir: authService.localPath ?? '',
                                                  exten:
                                                      jsonDecode(item.mensaje!)[
                                                          'extension'],
                                                  fecha: jsonDecode(
                                                      item.mensaje!)['fecha'],
                                                  texto: jsonDecode(
                                                      item.mensaje!)['content'],
                                                  type: jsonDecode(
                                                      item.mensaje!)['type'],
                                                  isReply: item.isReply,
                                                  forwarded: item.forwarded,
                                                  deleted: item.deleted,
                                                  parentmessage:
                                                      item.parentContent,
                                                  parenttype: item.parentType,
                                                  username: item.parentSender,
                                                  hora: DateFormat(
                                                          'yyyy-MM-dd HH:mm:ss')
                                                      .format(horaar),
                                                  incognito: item.incognito == 1
                                                      ? true
                                                      : false,
                                                  enviado: item.enviado == 1
                                                      ? true
                                                      : false,
                                                  recibido: item.recibido == 1
                                                      ? true
                                                      : false,
                                                  uid: item.de!,
                                                  // Add avatar for sent messages
                                                  avatar: item.de == authService.usuario!.uid
                                                      ? authService.usuario!.avatar
                                                      : chatService.usuarioPara!.avatar,
                                                  // Add retry callback if message failed and not sent
                                                  onRetry:
                                                      (item.enviado == 0 &&
                                                              item.de ==
                                                                  authService
                                                                      .usuario!
                                                                      .uid)
                                                          ? () {
                                                              // Extract fecha for retry
                                                              final fecha =
                                                                  jsonDecode(item.mensaje!)[
                                                                          'fecha']
                                                                      .split(
                                                                          'Z')[0];
                                                              chatProvider
                                                                  .retryFailedMessage(
                                                                      fecha);
                                                            }
                                                          : null,
                                                ),
                                              );
                                            },
                                            onLongPress: () {
                                              chatProvider.LongSelect(
                                                index,
                                                ChatMessage(
                                                  dir: authService.localPath ?? '',
                                                  selected: chatProvider
                                                      .selectedItems
                                                      .contains(index),
                                                  exten:
                                                      jsonDecode(item.mensaje!)[
                                                          'extension'],
                                                  fecha: jsonDecode(
                                                      item.mensaje!)['fecha'],
                                                  texto: jsonDecode(
                                                      item.mensaje!)['content'],
                                                  type: jsonDecode(
                                                      item.mensaje!)['type'],
                                                  deleted: item.deleted,
                                                  isReply: item.isReply,
                                                  forwarded: item.forwarded,
                                                  parentmessage:
                                                      item.parentContent,
                                                  parenttype: item.parentType,
                                                  username: item.parentSender,
                                                  hora: DateFormat(
                                                          'yyyy-MM-dd HH:mm:ss')
                                                      .format(horaar),
                                                  incognito: item.incognito == 1
                                                      ? true
                                                      : false,
                                                  enviado: item.enviado == 1
                                                      ? true
                                                      : false,
                                                  recibido: item.recibido == 1
                                                      ? true
                                                      : false,
                                                  uid: item.de!,
                                                  // Add avatar for sent messages
                                                  avatar: item.de == authService.usuario!.uid
                                                      ? authService.usuario!.avatar
                                                      : chatService.usuarioPara!.avatar,
                                                  // Add retry callback if message failed and not sent
                                                  onRetry:
                                                      (item.enviado == 0 &&
                                                              item.de ==
                                                                  authService
                                                                      .usuario!
                                                                      .uid)
                                                          ? () {
                                                              // Extract fecha for retry
                                                              final fecha =
                                                                  jsonDecode(item.mensaje!)[
                                                                          'fecha']
                                                                      .split(
                                                                          'Z')[0];
                                                              chatProvider
                                                                  .retryFailedMessage(
                                                                      fecha);
                                                            }
                                                          : null,
                                                ),
                                              );
                                            },
                                            child: Container(
                                              key: ValueKey(fesha),
                                              decoration: BoxDecoration(
                                                color: (chatProvider
                                                        .selectedItems
                                                        .contains(index))
                                                    ? blanco.withOpacity(0.1)
                                                    : transparente,
                                              ),
                                              child: Visibility(
                                                key: ValueKey(fesha),
                                                visible: item.de ==
                                                    authService.usuario!.uid,
                                                replacement: SwipeTo(
                                                  child: Row(
                                                    children: [
                                                      if (chatProvider
                                                          .selectedItems
                                                          .contains(index))
                                                        Container(
                                                          alignment:
                                                              Alignment.center,
                                                          height: 22,
                                                          width: 22,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color:
                                                                  chat_color2),
                                                          child: Icon(
                                                            Icons.check,
                                                            size: 15.0,
                                                            color: white,
                                                          ),
                                                        ),
                                                      Expanded(
                                                        child: ChatMessage(
                                                          key: ValueKey(fesha),
                                                          selected: chatProvider
                                                              .selectedItems
                                                              .contains(index),
                                                          upload: item.upload,
                                                          deleted: item.deleted,
                                                          dir: authService
                                                              .localPath,
                                                          exten: jsonDecode(item
                                                                  .mensaje!)[
                                                              'extension'],
                                                          fecha: jsonDecode(item
                                                                  .mensaje!)[
                                                              'fecha'],
                                                          texto: jsonDecode(item
                                                                  .mensaje!)[
                                                              'content'],
                                                          type: jsonDecode(item
                                                                  .mensaje!)[
                                                              'type'],
                                                          isReply: item.isReply,
                                                          forwarded:
                                                              item.forwarded,
                                                          parentmessage: item
                                                              .parentContent,
                                                          parenttype:
                                                              item.parentType,
                                                          username:
                                                              item.parentSender,
                                                          hora: DateFormat(
                                                                  'yyyy-MM-dd HH:mm:ss')
                                                              .format(horaar),
                                                          incognito:
                                                              item.incognito ==
                                                                      1
                                                                  ? true
                                                                  : false,
                                                          enviado:
                                                              item.enviado == 1
                                                                  ? true
                                                                  : false,
                                                          recibido:
                                                              item.recibido == 1
                                                                  ? true
                                                                  : false,
                                                          uid: item.de!,
                                                          // Add avatar for received messages
                                                          avatar: item.de == authService.usuario!.uid
                                                              ? authService.usuario!.avatar
                                                              : chatService.usuarioPara!.avatar,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  onRightSwipe: (test) {
                                                    chatProvider
                                                        .swipeWright(item);
                                                    // print(
                                                    //     '-----------onLeftSwipe mmmmmmmmm-----------------');
                                                  },
                                                ),
                                                child: SwipeTo(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      Expanded(
                                                        child: ChatMessage(
                                                          deleted: item.deleted,
                                                          key: ValueKey(fesha),
                                                          selected: chatProvider
                                                              .selectedItems
                                                              .contains(index),
                                                          upload: item.upload,
                                                          dir: authService
                                                              .localPath,
                                                          exten: jsonDecode(item
                                                                  .mensaje!)[
                                                              'extension'],
                                                          fecha: jsonDecode(item
                                                                  .mensaje!)[
                                                              'fecha'],
                                                          texto: jsonDecode(item
                                                                  .mensaje!)[
                                                              'content'],
                                                          type: jsonDecode(item
                                                                  .mensaje!)[
                                                              'type'],
                                                          isReply: item.isReply,
                                                          forwarded:
                                                              item.forwarded,
                                                          parentmessage: item
                                                              .parentContent,
                                                          parenttype:
                                                              item.parentType,
                                                          username:
                                                              item.parentSender,
                                                          hora: DateFormat(
                                                                  'yyyy-MM-dd HH:mm:ss')
                                                              .format(horaar),
                                                          incognito:
                                                              item.incognito ==
                                                                      1
                                                                  ? true
                                                                  : false,
                                                          enviado:
                                                              item.enviado == 1
                                                                  ? true
                                                                  : false,
                                                          recibido:
                                                              item.recibido == 1
                                                                  ? true
                                                                  : false,
                                                          uid: item.de!,
                                                          // Add avatar for sent messages  
                                                          avatar: item.de == authService.usuario!.uid
                                                              ? authService.usuario!.avatar
                                                              : chatService.usuarioPara!.avatar,
                                                        ),
                                                      ),
                                                      if (chatProvider
                                                          .selectedItems
                                                          .contains(index))
                                                        Container(
                                                          alignment:
                                                              Alignment.center,
                                                          height: 22,
                                                          width: 22,
                                                          decoration:
                                                              BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color:
                                                                      primary),
                                                          child: const Icon(
                                                            Icons.check,
                                                            size: 15.0,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  onLeftSwipe: (test) {
                                                    chatProvider
                                                        .swipeWright(item);
                                                    print(
                                                        "------------onRightSwipe-----------------");
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      reverse: true,
                                    ),
                                  );
                                });
                              }),
                          ),
                          authService.cargando
                              ? buildCardago()
                              : Selector<ChatProvider, bool>(
                                  selector: (_, provider) => provider.cargando,
                                  builder: (context, cargando, child) {
                                    return buildNotCardago(cargando);
                                  }),
                          // Typing indicator
                          Selector<ChatProvider, bool>(
                              selector: (_, provider) => provider.isTyping,
                              builder: (context, isTyping, child) {
                                return (isTyping && chatProvider.esContacto)
                                    ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Text(
                                    '${chatService.usuarioPara!.nombre} is typing...',
                                    style: TextStyle(
                                      color: gris,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                  ),
                                )
                                    : const SizedBox();
                              }),

                          Consumer<ChatProvider>(
                              builder: (context, chatProvider, child) {
                                return chatProvider.esContacto
                                    ? RepaintBoundary(
                                  child: _inputChatBar(context, chatProvider,
                                      authService, chatService),
                                )
                              : Container(
                                  width: MediaQuery.of(context).size.width,
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: blanco.withOpacity(0.5),
                                  ),
                                  child: Text(AppLocalizations.of(context)!
                                      .translate('CANT_SEND_MESSAGES')),
                                  );
                              }),
                        ],
                      )
                    ],
                  ),
                ),
              ), // Close Container
            ), // Close Expanded
          ],
        ),
      );
  }

  String calculateLastSeen(
      String? lastseen, bool? isOnline, BuildContext context) {
    var p = Provider.of<ChatProvider>(context, listen: true);

    if (p.isTyping) {
      return "Typing ...";
    } else if (getStatus(p.isOnline)) {
      return "Online";
    } else {
      if (lastseen == null) {
        return " ";
      } else if (lastseen == "false") {
        return " ";
      }
      // print(
      //     "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<${lastseen}>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
      DateTime lastSeenTime = DateTime.parse(lastseen);
      DateTime currentTime = DateTime.now();
      if (currentTime.isBefore(lastSeenTime.add(const Duration(days: 1))) &&
          currentTime.day == lastSeenTime.day) {
        // If last seen is less than a day ago and on the same day
        return 'last seen today at ${lastSeenTime.hour}:${lastSeenTime.minute.toString().padLeft(2, '0')}';
      } else {
        // You can format the date and time differently for older last seen timestamps if needed
        return 'last seen on ${lastSeenTime.year}-${lastSeenTime.month}-${lastSeenTime.day} at ${lastSeenTime.hour}:${lastSeenTime.minute.toString().padLeft(2, '0')}';
      }
    }
  }

  bool getStatus(bool? online) {
    if (online == null) {
      return false;
    } else {
      return online;
    }
  }

  DateTime parseFecha(String fecha) {
    return DateTime.parse(
        '${fecha.substring(0, 4)}-${fecha.substring(4, 6)}-${fecha.substring(6, 8)} '
        '${fecha.substring(8, 10)}:${fecha.substring(10, 12)}:${fecha.substring(12, 14)}.${fecha.substring(14, 17)}');
  }

  DateTime parseUTCFecha(String fecha) {
    return DateTime.utc(
        int.parse(fecha.substring(0, 4)),
        int.parse(fecha.substring(4, 6)),
        int.parse(fecha.substring(6, 8)),
        int.parse(fecha.substring(8, 10)),
        int.parse(fecha.substring(10, 12)),
        int.parse(fecha.substring(12, 14)),
        int.parse(fecha.substring(14, 17)));
  }

  buildCardago() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: CircularProgressIndicator(
          value: carga > 0 ? carga : null,
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(amarillo),
        ),
      ),
    );
  }

  buildNotCardago(cargando) {
    return cargando
        ? Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: CircularProgressIndicator(
                value: carga > 0 ? carga : null,
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(amarillo),
              ),
            ),
          )
        : const SizedBox();
  }

  Widget btnEliminar(
      BuildContext context, String texto, bool accion, ChatProvider p) {
    return SizedBox.fromSize(
      size: const Size(100, 40),
      child: Material(
        borderRadius: BorderRadius.circular(40),
        color: amarilloClaro,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          splashColor: amarillo,
          child: Center(
            child: Text(texto),
          ),
          onTap: () {
            // print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------btnEliminar ");
            Navigator.pop(context);
            p.deleteMensajes(context);
            // p.eliminarMensajesChat(context);

            if (accion) {
              p.eliminarParaTodos(context);
            }
          },
        ),
      ),
    );
  }

  Widget _inputChatBar(
      BuildContext context, ChatProvider pp, AuthService aa, ChatService cc) {
    var a = Provider.of<AuthService>(context, listen: false);
    var c = Provider.of<ChatService>(context, listen: false);
    var p = Provider.of<ChatProvider>(context, listen: false);

    return Container(
      // height: p.messagetoReply1 != null || p.filePath != null
      //     ? MediaQuery.of(context).size.height * 0.1
      //     : MediaQuery.of(context).size.height * 0.08,
      padding: const EdgeInsets.only(top: 5, left: 10, right: 10, bottom: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15), // No curve on the top left
          topRight: Radius.circular(15), // No curve on the top right
          bottomLeft: Radius.circular(0), // Curve on the bottom left
          bottomRight: Radius.circular(0), // Curve on the bottom right
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (p.messagetoReply1 != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: buildReply(context, p, c),
            ),
          if (p.filePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: buildImage(context, p.filePath!, p.fileType!, p, c),
            ),
          Align(
              alignment: Alignment.center,
              child: ChatInputRow(
                p: p,
                c: c,
                a: a,
              )),
        ],
      ),
    );
  }

  Widget buildReply(BuildContext context, ChatProvider p, ChatService c) {
    var chatProvider = Provider.of<ChatProvider>(context, listen: true);
    var auth = Provider.of<AuthService>(context, listen: false);
    // print(chatProvider.messagetoReply1!.mensaje!);
    // final String type =
    //     jsonDecode(chatProvider.messagetoReply1!.mensaje!)['type'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(24),
        ),
      ),
      child: ReplyMessageWidget(
        username: chatProvider.messagetoReply1!.de == auth.usuario!.uid
            ? auth.usuario!.nombre!
            : c.usuarioPara!.nombre!,
        type: jsonDecode(chatProvider.messagetoReply1!.mensaje!)['type'],
        message: jsonDecode(chatProvider.messagetoReply1!.mensaje!)['content'],
        onCancelReply: () {
          chatProvider.SkipReply();
        },
      ),
    );
  }

  Widget buildImage(BuildContext context, String path, String type,
      ChatProvider p, ChatService c) {
    var chatProvider = Provider.of<ChatProvider>(context, listen: true);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ImageWidget(
        path: path,
        type: type,
        onCancelReply: () {
          chatProvider.SkipReply();
        },
      ),
    );
  }
}
