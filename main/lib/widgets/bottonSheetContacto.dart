import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/toast_message.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class BottomSheetContacto extends StatefulWidget {
  const BottomSheetContacto({super.key});

  @override
  _BottomSheetContactoState createState() => _BottomSheetContactoState();
}

class _BottomSheetContactoState extends State<BottomSheetContacto> {
  bool teclado = true;
  late AuthService authService;
  late Usuario usuario;
  GlobalKey globalKey = GlobalKey();

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService.usuario!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final contacthCtrl = TextEditingController();
    return Container(
      color: const Color(0xff757575),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary,
              drawer_white,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: grisClaro,
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
                          getAvatar(usuario.avatar!, 'user_'),
                          width: 100,
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  child: Container(
                    decoration: BoxDecoration(
                      color: grisClaro,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    height: 150,
                    width: 150,
                    child: Align(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: blanco,
                        child: RepaintBoundary(
                          key: globalKey,
                          child: QrImageView(
                            data: usuario.codigoContacto!,
                            version: QrVersions.auto,
                            size: 1000,
                            backgroundColor: blanco,
                            foregroundColor: negro,
                          ),
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    _launchQRScanner(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 70),
                  child: Text(
                    capitalize(usuario.nombre!),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: negro.withOpacity(0.5)),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 50),
                  child: Text(
                    AppLocalizations.of(context)!.translate('SCAN_CODE'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: negro.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.only(left: 20, top: 30, right: 20),
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                color: blanco,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.translate('ADD_CONTACTS'),
                    style: TextStyle(color: gris, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.translate('TEXT_ADD'),
                    style: TextStyle(color: gris, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          height: 35,
                          padding: const EdgeInsets.all(0),
                          margin: const EdgeInsets.only(
                              bottom: 10, left: 30, right: 30, top: 10),
                          decoration: BoxDecoration(
                            color: grisClaro,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: TextField(
                            onSubmitted: (value) {
                              if (contacthCtrl.text.length < 10) {
                                mostrarAlerta(
                                    context,
                                    AppLocalizations.of(context)!
                                        .translate('ERROR'),
                                    AppLocalizations.of(context)!
                                        .translate('MSN_ERROR'));
                              } else {
                                _sendContacto(contacthCtrl.text);
                                contacthCtrl.clear();
                                FocusScope.of(context).unfocus();
                              }
                            },
                            keyboardType: TextInputType.text,
                            controller: contacthCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              color: negro.withOpacity(0.5),
                              fontWeight: FontWeight.normal,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                            autocorrect: false,
                            decoration: InputDecoration(
                                hintText: 'A1B2C3D4E5',
                                focusedBorder: InputBorder.none,
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                    color: gris,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    child: Container(
                      padding: EdgeInsets.zero,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Icon(
                        Icons.arrow_circle_up_rounded,
                        color: verde,
                        size: 45,
                      ),
                    ),
                    onTap: () {
                      if (contacthCtrl.text.length < 9) {
                        mostrarAlerta(
                            context,
                            AppLocalizations.of(context)!.translate('ERROR'),
                            AppLocalizations.of(context)!
                                .translate('MSN_ERROR'));
                      } else {
                        _sendContacto(contacthCtrl.text);
                        contacthCtrl.clear();
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(
              indent: 20,
              endIndent: 20,
              color: negro,
              height: 40,
            ),
            SizedBox.fromSize(
              size: const Size(200, 40), // button width and height
              child: Container(
                child: Material(
                  borderRadius: BorderRadius.circular(40),
                  color: azul, // button color
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    // splashColor: gris, // splash color
                    onTap: () {
                      share();
                      FocusScope.of(context).unfocus();
                    }, // button pressed
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Icon(Icons.ios_share, color: blanco), // icon
                        Text(
                            AppLocalizations.of(context)!
                                .translate('SHARE_CODE'),
                            style: TextStyle(color: blanco)), // text
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              usuario.codigoContacto!,
              style: TextStyle(
                  color: negro.withOpacity(0.5),
                  fontSize: 25,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox.fromSize(
              size: const Size(200, 40), // button width and height
              child: Container(
                child: Material(
                  borderRadius: BorderRadius.circular(40),
                  color: grisClaro, // button color
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    // splashColor: blanco, // splash color// splash color
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      Clipboard.setData(
                          ClipboardData(text: usuario.codigoContacto!));
                      showToast(
                        context,
                        AppLocalizations.of(context)!.translate('COPIED_CODE'),
                        verde,
                        Icons.check,
                      );
                      // gravity: Toast.CENTER, duration: Toast.LENGTH_LONG);
                    }, // button pressed
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Icon(Icons.copy_rounded, color: gris), // icon
                        Text(
                          AppLocalizations.of(context)!.translate('COPY_CODE'),
                          style: TextStyle(color: gris),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _launchQRScanner(BuildContext context) {
    Navigator.pushNamed(context, 'qrviewer').then((code) {
      _sendContacto(code.toString());
    });
  }

  _sendContacto(String codeContacto) async {
    if (usuario.codigoContacto != codeContacto) {
      final data = {
        'codigoUsuario': usuario.codigoContacto,
        'codigoContacto': codeContacto,
        'fecha': deconstruirDateTime(),
        'activo': 0
      };
      print(data);
      String url = '${Environment.apiUrl}/contactos';
      final res = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      );
      var json = jsonDecode(res.body);
      if (json['ok']) {
        showToast(
          context,
          AppLocalizations.of(context)!.translate('REQUEST_SENT'),
          verde,
          Icons.check,
        );
        // duration: Toast.LENGTH_LONG);
      } else {
        mostrarAlerta(context,
            AppLocalizations.of(context)!.translate('WARNING'), json['msg']);
      }
      // print(res.body);
    } else {
      mostrarAlerta(context, AppLocalizations.of(context)!.translate('WARNING'),
          AppLocalizations.of(context)!.translate('INVALID_CODE'));
    }
  }

  Future<void> share() async {
    RenderRepaintBoundary? boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    var image = await boundary.toImage();
    var byteData = await image.toByteData(format: ImageByteFormat.png);
    var bytes = byteData!.buffer.asUint8List();

    var tempDir = (await getTemporaryDirectory()).path;
    var qrcodeFile = File('$tempDir/qr_code.png');
    await qrcodeFile.writeAsBytes(bytes);
    await Share.shareXFiles([XFile((qrcodeFile.path))],
        text:
            '${AppLocalizations.of(context)!.translate('MSN_SHARED')} ${usuario.codigoContacto}',
        subject: Environment.urlWebPage);
  }
}
