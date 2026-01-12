import 'dart:convert';
import 'dart:io';

import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/pages/forwardeTo.dart';
import 'package:CryptoChat/pages/info_grupo_page.dart';
import 'package:CryptoChat/pages/usuario_page.dart';
import 'package:CryptoChat/providers/GroupProvider.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:CryptoChat/widgets/connection_banner.dart';
import 'package:CryptoChat/widgets/cronometro.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/replymsg.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:loadmore/loadmore.dart';
import 'package:provider/provider.dart';
import 'package:swipe_to/swipe_to.dart';

import '../global/AppLocalizations.dart';
import '../widgets/displayImage.dart';

class GChat extends StatelessWidget {
  const GChat({super.key});
  final double carga = 0;

  @override
  Widget build(BuildContext context) {
    var authService = Provider.of<AuthService>(context, listen: false);
    var chatService = Provider.of<ChatService>(context, listen: false);
    // var chatProvider = Provider.of<ChatProvider>(context, listen: false);
    return Consumer<GroupChatProvider>(builder: (context, chatProvider, child) {
      return Scaffold(
        backgroundColor: drawer_white,
        appBar: AppBar(
          shadowColor: drawer_light_white,
          backgroundColor: drawer_light_white,
          leading: InkWell(
            child: Icon(
              Icons.arrow_back_ios_rounded,
              color: gris,
            ),
            onTap: () => Navigator.pop(context, true),
          ),
          title: chatProvider.selectedItems.isEmpty
              ? GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.only(
                          left: 10, right: 10, top: 5, bottom: 5),
                      decoration: BoxDecoration(
                        color: blanco.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 0),
                          Text(
                            capitalize(chatService.grupoPara!.nombre!),
                            style: TextStyle(
                              color: negro,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Hero(
                            tag: 'avatar',
                            child: CircleAvatar(
                              backgroundImage: AssetImage(getAvatar(
                                  chatService.grupoPara!.avatar!, "group_")),
                              backgroundColor: blanco,
                              maxRadius: 20,
                            ),
                          ),
                        ],
                      )),
                  onTap: () {
                    if (chatProvider.esContacto) {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (context) =>
                                  InfoGrupoPage(chatService.grupoPara!)))
                          .then((res) {
                        print(res);
                        chatProvider.Clearhistory(res);
                      });

                      // _cargarHistorial(usuarioPara.uid);
                    }
                  })
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
                          color: negro,
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
                ),
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
                            child: LoadMore(
                              textBuilder: (status) {
                                // print(status);
                                if (status == LoadMoreStatus.nomore) {
                                  return "";
                                } else if (status == LoadMoreStatus.loading) {
                                  return "Loading";
                                } else if (status == LoadMoreStatus.fail) {
                                  return "Error";
                                }
                                return "";
                              },
                              isFinish: chatProvider.isLoadingFinished,
                              onLoadMore: chatProvider.loadMore,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: chatProvider.messajes.length,
                                itemBuilder: (context, index) {
                                  final item = chatProvider.messajes[index];
                                  // Build UI for each item.
                                  // print("zeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeb");
                                  // print(item.mensaje.toString());
                                  //      return ChatMessage(enviado: null, fecha: '', hora: '', isReply: null, recibido: null, texto: '', type: '', uid: '',

                                  //  )

                                  DateTime horaar1 = parseUTCFecha(
                                      jsonDecode(item.mensaje!)['fecha']);
                                  DateTime horaar = horaar1.toLocal();

                                  print(
                                      "========================Date transformation ${horaar1.isUtc}===========================");
                                  print(
                                      "========================{Date Local} $horaar,===========================");
                                  print(
                                      "========================{Date UTC} $horaar1,===========================");
                                  return GestureDetector(
                                    onTap: () {
                                      chatProvider.SelectM(
                                        index,
                                        ChatMessage(
                                          dir: authService.localPath!,
                                          selected: chatProvider.selectedItems
                                              .contains(index),
                                          exten: jsonDecode(
                                              item.mensaje!)['extension'],
                                          fecha: jsonDecode(
                                              item.mensaje!)['fecha'],
                                          texto: jsonDecode(
                                              item.mensaje!)['content'],
                                          type:
                                              jsonDecode(item.mensaje!)['type'],
                                          isReply: item.isReply,
                                          deleted: item.deleted,
                                          forwarded: item.forwarded,
                                          parentmessage: item.parentContent,
                                          parenttype: item.parentType,
                                          username: item.parentSender,
                                          hora:
                                              DateFormat('yyyy-MM-dd HH:mm:ss')
                                                  .format(horaar),
                                          incognito: item.incognito == 1
                                              ? true
                                              : false,
                                          enviado:
                                              item.enviado == 1 ? true : false,
                                          recibido:
                                              item.recibido == 1 ? true : false,
                                          uid: item.de!,
                                          // Add retry callback if message failed and not sent
                                          onRetry: (item.enviado == 0 &&
                                                  item.de ==
                                                      authService.usuario!.uid)
                                              ? () {
                                                  // Extract fecha for retry
                                                  final fecha =
                                                      jsonDecode(item.mensaje!)[
                                                              'fecha']
                                                          .split('Z')[0];
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
                                          dir: authService.localPath!,
                                          selected: chatProvider.selectedItems
                                              .contains(index),
                                          deleted: item.deleted,
                                          exten: jsonDecode(
                                              item.mensaje!)['extension'],
                                          fecha: jsonDecode(
                                              item.mensaje!)['fecha'],
                                          texto: jsonDecode(
                                              item.mensaje!)['content'],
                                          type:
                                              jsonDecode(item.mensaje!)['type'],
                                          isReply: item.isReply,
                                          forwarded: item.forwarded,
                                          parentmessage: item.parentContent,
                                          parenttype: item.parentType,
                                          username: item.parentSender,
                                          hora:
                                              DateFormat('yyyy-MM-dd HH:mm:ss')
                                                  .format(horaar),
                                          incognito: item.incognito == 1
                                              ? true
                                              : false,
                                          enviado:
                                              item.enviado == 1 ? true : false,
                                          recibido:
                                              item.recibido == 1 ? true : false,
                                          uid: item.de!,
                                          // Add retry callback if message failed and not sent
                                          onRetry: (item.enviado == 0 &&
                                                  item.de ==
                                                      authService.usuario!.uid)
                                              ? () {
                                                  // Extract fecha for retry
                                                  final fecha =
                                                      jsonDecode(item.mensaje!)[
                                                              'fecha']
                                                          .split('Z')[0];
                                                  chatProvider
                                                      .retryFailedMessage(
                                                          fecha);
                                                }
                                              : null,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: (chatProvider.selectedItems
                                                .contains(index))
                                            ? blanco.withOpacity(0.1)
                                            : transparente,
                                      ),
                                      child: Visibility(
                                        visible:
                                            item.de == authService.usuario!.uid,
                                        replacement: SwipeTo(
                                          child: ChatMessage(
                                            deleted: item.deleted,
                                            isGroup: true,
                                            selected: chatProvider.selectedItems
                                                .contains(index),
                                            upload: item.upload,
                                            dir: authService.localPath!,
                                            exten: jsonDecode(
                                                item.mensaje!)['extension'],
                                            fecha: jsonDecode(
                                                item.mensaje!)['fecha'],
                                            texto: jsonDecode(
                                                item.mensaje!)['content'],
                                            type: jsonDecode(
                                                item.mensaje!)['type'],
                                            isReply: item.isReply,
                                            forwarded: item.forwarded,
                                            parentmessage: item.parentContent,
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
                                            emisor: item.nombreEmisor != null
                                                ? item.nombreEmisor!
                                                    .split(' ')[0]
                                                : 'Desconocido',
                                            // Add retry callback if message failed and not sent
                                            onRetry: (item.enviado == 0 &&
                                                    item.de ==
                                                        authService
                                                            .usuario!.uid)
                                                ? () {
                                                    // Extract fecha for retry
                                                    final fecha = jsonDecode(
                                                                item.mensaje!)[
                                                            'fecha']
                                                        .split('Z')[0];
                                                    chatProvider
                                                        .retryFailedMessage(
                                                            fecha);
                                                  }
                                                : null,
                                          ),
                                          onRightSwipe: (test) {
                                            chatProvider.swipeWright(item);
                                            print(
                                                '-----------onLeftSwipe mmmmmmmmm-----------------');
                                          },
                                        ),
                                        child: SwipeTo(
                                          child: ChatMessage(
                                            isGroup: true,
                                            deleted: item.deleted,
                                            selected: chatProvider.selectedItems
                                                .contains(index),
                                            upload: item.upload,
                                            dir: authService.localPath!,
                                            exten: jsonDecode(
                                                item.mensaje!)['extension'],
                                            fecha: jsonDecode(
                                                item.mensaje!)['fecha'],
                                            texto: jsonDecode(
                                                item.mensaje!)['content'],
                                            type: jsonDecode(
                                                item.mensaje!)['type'],
                                            isReply: item.isReply,
                                            forwarded: item.forwarded,
                                            parentmessage: item.parentContent,
                                            emisor: item.nombreEmisor != null
                                                ? item.nombreEmisor!
                                                    .split(' ')[0]
                                                : 'Desconocido',
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
                                            // Add retry callback if message failed and not sent
                                            onRetry: (item.enviado == 0 &&
                                                    item.de ==
                                                        authService
                                                            .usuario!.uid)
                                                ? () {
                                                    // Extract fecha for retry
                                                    final fecha = jsonDecode(
                                                                item.mensaje!)[
                                                            'fecha']
                                                        .split('Z')[0];
                                                    chatProvider
                                                        .retryFailedMessage(
                                                            fecha);
                                                  }
                                                : null,
                                          ),
                                          onLeftSwipe: (test) {
                                            chatProvider.swipeWright(item);
                                            print(
                                                "------------onRightSwipe-----------------");
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                reverse: true,
                              ),
                            ),
                          ),
                          authService.cargando
                              ? buildCardago()
                              : buildNotCardago(chatProvider.cargando),
                          chatProvider.esContacto
                              ? _inputChatBar(context, chatProvider,
                                  authService, chatService)
                              : Container(
                                  width: MediaQuery.of(context).size.width,
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: blanco.withOpacity(0.5),
                                  ),
                                  child: Text(AppLocalizations.of(context)!
                                      .translate('CANT_SEND_MESSAGES')),
                                ),
                        ],
                      )
                    ],
                  ),
                ), // Close SafeArea
              ), // Close Container
            ), // Close Expanded
          ],
        ),
      );
    });
  }

  buildCardago() {
    return LinearProgressIndicator(
      minHeight: 5,
      value: carga > 0 ? carga : null,
      backgroundColor: transparente,
      valueColor: AlwaysStoppedAnimation(amarillo),
    );
  }

  buildNotCardago(cargando) {
    return cargando
        ? LinearProgressIndicator(
            minHeight: 5,
            value: carga > 0 ? carga : null,
            backgroundColor: transparente,
            valueColor: AlwaysStoppedAnimation(amarillo),
          )
        : const SizedBox();
  }

  Widget btnEliminar(
      BuildContext context, String texto, bool accion, GroupChatProvider p) {
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
            Navigator.pop(context);
            p.eliminarMensajesChat(context);
            if (accion) {
              p.eliminarParaTodos(context);
            }
          },
        ),
      ),
    );
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

  Widget _inputChatBar(BuildContext context, GroupChatProvider pp,
      AuthService aa, ChatService cc) {
    var a = Provider.of<AuthService>(context, listen: false);
    var c = Provider.of<ChatService>(context, listen: false);
    var p = Provider.of<GroupChatProvider>(context, listen: true);

    return Container(
      // height: p.messagetoReply1 != null || p.filePath != null
      //     ? MediaQuery.of(context).size.height * 0.1
      //     : MediaQuery.of(context).size.height * 0.08,
      padding: const EdgeInsets.only(top: 5, left: 10, right: 10, bottom: 5),
      decoration: BoxDecoration(
        color: drawer_light_white,
        borderRadius: const BorderRadius.all(
          Radius.circular(5),
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
            child: Row(
              children: [
                !p.isRecording
                    ? CustomPopupMenu(
                        showArrow: false,
                        verticalMargin: Platform.isAndroid
                            //  -MediaQuery.of(context).size.height * 0.35,
                            ? 10
                            : 0,
                        barrierColor: transparente,
                        pressType: PressType.singleClick,
                        controller: p.controller,
                        menuBuilder: () => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: drawer_light_white,
                            ),
                            child: IntrinsicWidth(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                btnPopUpMenu(
                                    Icons.camera_alt_rounded,
                                    accion: 1,
                                    p,
                                    c,
                                    a),
                                btnPopUpMenu(
                                    Icons.videocam_rounded, accion: 2, p, c, a),
                                btnPopUpMenu(
                                    Icons.attach_file_rounded,
                                    accion: 3,
                                    p,
                                    c,
                                    a)
                              ],
                            )),
                          ),
                        ),
                        child: Container(
                          height: 38, // Set the height of the container
                          width: 38,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: gris),
                          ),
                          child: Icon(
                            Icons.arrow_drop_up_rounded,
                            color: gris,
                            size: 30,
                          ),
                        ),
                      )
                    : GestureDetector(
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: rojo,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: blanco,
                            size: 30,
                          ),
                        ),
                        onTap: () {
                          p.cancelRecording();
                        }),
                const SizedBox(width: 10),
                Flexible(
                  child: Container(
                    height: 44,
                    width: 290,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: blanco.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: gris),
                    ),
                    child: p.isRecording
                        ? SizedBox(
                            // height: 9,
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: Cronometro(),
                          )
                        : TextField(
                            textInputAction: TextInputAction.send,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 5,
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: negro,
                              fontSize: 15,
                            ),
                            controller: p.textController,
                            onSubmitted: (texto) {
                              p.handleSubmit(texto, a.usuario!, c.grupoPara!,
                                  aa, cc, context);
                            },
                            onChanged: (texto) {
                              p.onchangeTextfield(texto);
                            },
                            decoration: InputDecoration.collapsed(
                              hintText: AppLocalizations.of(context)!
                                  .translate('SEND_MESSAGE'),
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: gris,
                                fontSize: 15,
                              ),
                            ),
                            focusNode: p.focusNode,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                !p.estaEscribiendo && p.filePath == null
                    ? GestureDetector(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(
                                30), // You can adjust the radius as needed
                          ),
                          height: 38, // Set the height of the container
                          width: 38, // Set the width of the container
                          alignment: Alignment
                              .center, // Center the icon inside the container
                          child: Icon(
                            !p.isRecording
                                ? FontAwesomeIcons.microphoneLines
                                : FontAwesomeIcons.paperPlane,
                            color: blanco,
                            size: 20, // Size for the icon
                          ),
                        ),
                        onTap: () {
                          p.isRecording
                              ? p.stopRecording(a, c, context)
                              : p.startRecording();
                        })
                    : GestureDetector(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(
                                30), // You can adjust the radius as needed
                          ),
                          height: 38, // Set the height of the container
                          width: 38, // Set the width of the container
                          alignment: Alignment
                              .center, // Center the icon inside the container
                          child: Icon(
                            FontAwesomeIcons.paperPlane,
                            color: blanco,
                            size: 20,
                          ),
                        ),
                        onTap: () => p.estaEscribiendo || p.filePath != null
                            ? p.handleSubmit(p.textController.text, a.usuario!,
                                c.grupoPara!, aa, cc, context)
                            : print(" ")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget btnPopUpMenu(
      IconData icono, GroupChatProvider p, ChatService c, AuthService a,
      {required int accion}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        p.controller.hideMenu();
        switch (accion) {
          case 1:
            p.takePhoto(a, c);
            break;
          case 2:
            p.takeVideo(a, c);
            break;
          case 3:
            p.searchFiles(a, c);
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        child: Icon(
          icono,
          size: 20,
          color: gris,
        ),
      ),
    );
  }

  Widget buildReply(BuildContext context, GroupChatProvider p, ChatService c) {
    var chatProvider = Provider.of<GroupChatProvider>(context, listen: true);
    var auth = Provider.of<AuthService>(context, listen: false);
    print(chatProvider.messagetoReply1!.nombreEmisor);

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
        username: chatProvider.messagetoReply1!.nombreEmisor!,
        type: jsonDecode(chatProvider.messagetoReply1!.mensaje!)['type'],
        message: jsonDecode(chatProvider.messagetoReply1!.mensaje!)['content'],
        onCancelReply: () {
          chatProvider.SkipReply();
        },
      ),
    );
  }

  Widget buildImage(BuildContext context, String path, String type,
      GroupChatProvider p, ChatService c) {
    var chatProvider = Provider.of<GroupChatProvider>(context, listen: true);
    var auth = Provider.of<AuthService>(context, listen: false);

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
