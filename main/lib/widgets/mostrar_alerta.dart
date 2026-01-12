import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/toast_message.dart';

final usuarioService = UsuariosService();

/*
  * Show success message via SnackBar (non-blocking)
  * Use for success confirmations and non-critical feedback
*/
void mostrarExito(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: colorSuccess,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/*
  * Show info message via SnackBar (non-blocking)
  * Use for informational messages
*/
void mostrarInfo(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: colorInfo,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/*
  * Mostrar alerta, (titulo y subtitulo), Boton 'Ok'
  * Use for CRITICAL errors that require user acknowledgment
  * @author Jhoan Silva
  * @since 2021/04/05
*/
mostrarAlerta(BuildContext context, String titulo, String subtitulo) {
  if (Platform.isAndroid) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Text(subtitulo),
        actions: <Widget>[
          MaterialButton(
              elevation: 5,
              textColor: azul,
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.translate('OK')))
        ],
      ),
    );
  } else {
    return showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Text(subtitulo),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(AppLocalizations.of(context)!.translate('OK')),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }
}

/*
  * Alerta, (titulo  subtitulo), Boton 'Aceptar' y 'Cancelar'
  * @author Jhoan Silva
  * @since 2021/04/05
*/
Future<dynamic> alertaConfirmar(
    BuildContext context, String titulo, String subtitulo) {
  if (Platform.isAndroid) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Text(subtitulo),
        actions: <Widget>[
          MaterialButton(
              elevation: 5,
              textColor: negro,
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text(AppLocalizations.of(context)!.translate('DONE'))),
          MaterialButton(
              elevation: 5,
              textColor: negro,
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(AppLocalizations.of(context)!.translate('CANCEL'))),
        ],
      ),
    );
  } else {
    return showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Text(subtitulo),
        actions: <Widget>[
          CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.translate('DONE')),
              onPressed: () {
                Navigator.pop(context, true);
              }),
          CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.translate('CANCEL')),
              onPressed: () {
                Navigator.pop(context, false);
              })
        ],
      ),
    );
  }
}

/*
  * Mostrar solicitud (avatar, nombre, codigoUsuario, codigoContacto), Boton 'Aceptar' y 'Cancelar'
  * @author Jhoan Silva
  * @since 2021/04/05
*/
Future<dynamic> mostrarSolicitud(BuildContext context, String avatar,
    String nombre, String codigoUsuario, String codigoContacto) {
  SocketService socketService =
      Provider.of<SocketService>(context, listen: false);
  var server = socketService.serverStatus == ServerStatus.Online;

  if (Platform.isAndroid) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      barrierColor: transparente,
      builder: (_) => AlertDialog(
        elevation: 0,
        backgroundColor: transparente,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(40.0))),
        content: Container(
          color: transparente,
          height: 300,
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: amarillo,
                  borderRadius: BorderRadius.circular(30),
                ),
                height: 150,
                width: 150,
                child: Align(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: blanco,
                    child: ClipOval(
                      child: Image.asset(
                        avatar,
                        width: 100,
                      ),
                    ),
                  ),
                ),
              ),
              Text(nombre),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox.fromSize(
                    size: const Size(100, 40), // button width and height
                    child: Material(
                      borderRadius: BorderRadius.circular(40),
                      color: verde.withOpacity(0.5), // button color
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        splashColor: blanco, // splash color// splash color
                        onTap: () {
                          if (server) {
                            usuarioService.aceptarSolicitud(
                                codigoUsuario, codigoContacto);
                            Navigator.pop(context, true);
                          } else {
                            showToast(
                                context,
                                AppLocalizations.of(context)!
                                    .translate('NO_CONECTION'),
                                rojo.withOpacity(0.8),
                                Icons.cancel_outlined);
                          }
                        }, // button pressed
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              AppLocalizations.of(context)!.translate('ACCEPT'),
                              style: TextStyle(
                                  color: blanco, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox.fromSize(
                    size: const Size(100, 40), // button width and height
                    child: Container(
                      child: Material(
                        borderRadius: BorderRadius.circular(40),
                        color: rojo.withOpacity(0.5), // button color
                        child: InkWell(
                          borderRadius: BorderRadius.circular(40),
                          splashColor: blanco, // splash color// splash color
                          onTap: () {
                            if (server) {
                              usuarioService.rechazarSolicitud(
                                  codigoUsuario, codigoContacto);
                              Navigator.pop(context, true);
                            } else {
                              showToast(
                                  context,
                                  AppLocalizations.of(context)!
                                      .translate('NO_CONECTION'),
                                  rojo.withOpacity(0.8),
                                  Icons.cancel_outlined);
                            }
                          }, // button pressed
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              Text(
                                AppLocalizations.of(context)!.translate('DENY'),
                                style: TextStyle(
                                    color: blanco, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  } else {
    return showCupertinoDialog(
      context: context,
      //     title: Text(titulo),
      // content: Text(subtitulo),
      builder: (_) => CupertinoAlertDialog(
        actions: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: amarillo,
            ),
            height: 150,
            width: 150,
            child: Align(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: blanco,
                child: ClipOval(
                  child: Image.asset(
                    avatar,
                    width: 100,
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 10, top: 10),
            child: Text(
              nombre,
              textAlign: TextAlign.center,
              style: TextStyle(
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w500,
                color: negro.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
          ),
          CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.translate('ACCEPT')),
              onPressed: () {
                if (server) {
                  usuarioService.aceptarSolicitud(
                      codigoUsuario, codigoContacto);
                  Navigator.pop(context, true);
                } else {
                  showToast(
                      context,
                      AppLocalizations.of(context)!.translate('NO_CONECTION'),
                      rojo.withOpacity(0.8),
                      Icons.cancel_outlined);
                }
              }),
          CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.translate('DENY')),
              onPressed: () {
                if (server) {
                  usuarioService.rechazarSolicitud(
                      codigoUsuario, codigoContacto);
                  Navigator.pop(context, true);
                } else {
                  showToast(
                      context,
                      AppLocalizations.of(context)!.translate('NO_CONECTION'),
                      rojo.withOpacity(0.8),
                      Icons.cancel_outlined);
                }
              })
        ],
      ),
    );
  }
}

/*
  * Alerta editar, (titulo, subtitulo, data, uid), Boton 'Cancelar' y 'Guardar'
  * @author Jhoan Silva
  * @since 2021/04/05
*/
mostrarEdit(
    BuildContext context, String titulo, String subtitulo, String data, uid) {
  AuthService authService = Provider.of<AuthService>(context, listen: false);
  final textController = TextEditingController(text: data);
  final textController2 = TextEditingController(text: data);
  final textController3 = TextEditingController(text: data);
  final usuarioService = UsuariosService();
  bool passwd = subtitulo == AppLocalizations.of(context)!.translate('PASSWORD')
      ? true
      : false;
  if (Platform.isAndroid) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: drawer_white,
        title: Text(titulo),
        content: SizedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gris),
                ),
                child: TextField(
                  // maxLength: 15,
                  controller: textController,
                  obscureText: passwd,
                  decoration: InputDecoration.collapsed(
                    hintText: passwd
                        ? '$subtitulo ${AppLocalizations.of(context)!.translate('CURRENT')}'
                        : subtitulo,
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: gris,
                    ),
                  ),
                ),
              ),
              passwd
                  ? Container(
                      padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gris),
                      ),
                      child: TextField(
                        controller: textController2,
                        obscureText: passwd,
                        decoration: InputDecoration.collapsed(
                          hintText:
                              '${AppLocalizations.of(context)!.translate('NEWa')} $subtitulo',
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: gris,
                          ),
                        ),
                      ),
                    )
                  : Container(),
              passwd
                  ? Container(
                      padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gris),
                      ),
                      child: TextField(
                        controller: textController3,
                        obscureText: passwd,
                        decoration: InputDecoration.collapsed(
                          hintText: '${AppLocalizations.of(context)!
                                  .translate('REPEAT')} $subtitulo',
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: gris,
                          ),
                        ),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
        actions: <Widget>[
          MaterialButton(
              elevation: 5,
              textColor: negro,
              onPressed: () {
                Navigator.pop(context, false);
                return;
              },
              child: Text(AppLocalizations.of(context)!.translate('CANCEL'))),
          MaterialButton(
              elevation: 5,
              textColor: negro,
              onPressed: () async {
                if (textController.text != '') {
                  if (subtitulo ==
                      AppLocalizations.of(context)!.translate('NAME')) {
                    authService.usuario!.nombre = textController.text;
                    await usuarioService.infoUserChange(
                        textController.text, 'name', uid);
                    Navigator.pop(context, true);
                    return;
                  } else if (subtitulo ==
                      AppLocalizations.of(context)!.translate('EMAIL')) {
                    if (validateEmail(textController.text)) {
                      authService.usuario!.email = textController.text;
                      await usuarioService.infoUserChange(
                          textController.text, 'email', uid);
                      Navigator.pop(context, true);
                      return;
                    } else {
                      showToast(
                          context,
                          AppLocalizations.of(context)!.translateReplace(
                            'THE_FIELD_IS_NOT_VALID',
                            '{subtitulo}',
                            subtitulo,
                          ),
                          rojo.withOpacity(0.8),
                          Icons.cancel_outlined);
                      // duration: Toast.LENGTH_LONG);
                    }
                  } else if (subtitulo ==
                      AppLocalizations.of(context)!.translate('PASSWORD')) {
                    List claves = [textController.text, textController2.text];
                    if (textController2.text == textController3.text) {
                      final res = await usuarioService.infoUserChange(
                          claves, 'password', uid);
                      showToast(
                          context,
                          AppLocalizations.of(context)!.translate(res),
                          rojo.withOpacity(0.8),
                          Icons.check);
                      Navigator.pop(context, true);
                      return;
                    } else {
                      showToast(
                          context,
                          AppLocalizations.of(context)!
                              .translate('MSG_EMPTY_FIELDS'),
                          rojo.withOpacity(0.8),
                          Icons.cancel_outlined);
                      // duration: Toast.LENGTH_LONG);
                    }
                  } else if (subtitulo ==
                      AppLocalizations.of(context)!
                          .translate('PROMOTIONAL_CODE')) {
                    authService.usuario!.referido = textController.text;
                    await usuarioService.infoUserChange(
                        textController.text, 'referido', uid);
                    Navigator.pop(context, true);
                    return;
                  }
                } else {
                  showToast(
                      context,
                      AppLocalizations.of(context)!.translateReplace(
                          'THE_FIELD_CANT_BE_EMPTY', '{subtitulo}', subtitulo),
                      rojo.withOpacity(0.8),
                      Icons.cancel_outlined);
                  // duration: Toast.LENGTH_LONG);
                }
              },
              child: Text(AppLocalizations.of(context)!.translate('SAVE'))),
        ],
      ),
    );
  }
}

/*
  * Mostrar alerta, (titulo y Widget), Boton 'Cancelar'
  * @author Jhoan Silva
  * @since 2021/04/05
*/
Future<dynamic> alertaWidget(
    BuildContext context, String titulo, Widget widget, String btn) {
  if (Platform.isAndroid) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: widget,
        actions: <Widget>[
          MaterialButton(
              elevation: 5,
              textColor: azul,
              onPressed: () {
                Navigator.pop(context);
                return;
              },
              child: Text(AppLocalizations.of(context)!.translate(btn)))
        ],
      ),
    );
  } else {
    return showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(titulo),
        content: widget,
        actions: <Widget>[
          CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.translate(btn)),
              onPressed: () {
                Navigator.pop(context, true);
                return;
              }),
        ],
      ),
    );
  }
}
