import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/pages/solicitudes_page.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/avatars.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/pinInput_widget.dart';

class HomeDrawerWidget extends StatelessWidget {
  final Usuario usuario;
  final AuthService authService;
  final SocketService socketService;
  final String? myPin;
  final String? miPago;
  final TextEditingController pinPutController;
  final VoidCallback onRefresh;
  final Function(String) onSavePin;
  final VoidCallback onActivateNinjaMode;

  const HomeDrawerWidget({
    Key? key,
    required this.usuario,
    required this.authService,
    required this.socketService,
    required this.myPin,
    required this.miPago,
    required this.pinPutController,
    required this.onRefresh,
    required this.onSavePin,
    required this.onActivateNinjaMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final usuarioService = UsuariosService();

    return Drawer(
      backgroundColor: drawer_light_white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Drawer Header with Avatar
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, secondary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                // Exit button (top right)
                Align(
                  alignment: Alignment.topRight,
                  child: FloatingActionButton(
                    backgroundColor: background,
                    mini: true,
                    heroTag: 'exit',
                    tooltip: AppLocalizations.of(context)!
                        .translate('CLOSE_SESSION'),
                    child: Icon(Icons.exit_to_app, color: rojo),
                    onPressed: () async => await alertaConfirmar(
                            context,
                            AppLocalizations.of(context)!
                                .translate('INFORMATION'),
                            AppLocalizations.of(context)!.translateReplace(
                                'DELETE_PERMANENTLY',
                                '{ACTION}',
                                AppLocalizations.of(context)!
                                    .translate('DROP_ALL_MESSAGES')))
                        .then((res) {
                      Navigator.pop(context);
                      if (res) {
                        socketService.disconnect();
                        AuthService.deleteToken();
                        AuthService.deleteKeys();
                        Navigator.pushReplacementNamed(context, 'login');
                      }
                    }),
                  ),
                ),
                // Ninja Mode button (top left)
                Align(
                  alignment: Alignment.topLeft,
                  child: FloatingActionButton(
                    backgroundColor: background,
                    mini: true,
                    heroTag: 'calculate',
                    child: Icon(Icons.calculate_outlined, color: primary),
                    onPressed: () => _handleNinjaModeTap(context),
                  ),
                ),
                // Avatar (center)
                Center(
                  child: GestureDetector(
                    child: Hero(
                      tag: 'avatar',
                      child: !(usuario.avatar != null &&
                              File(usuario.avatar!).existsSync())
                          ? CircleAvatar(
                              radius: 40,
                              backgroundColor: blanco,
                              child: ClipOval(
                                child: Image.asset(
                                  getAvatar(usuario.avatar!, 'user_'),
                                  width: 70,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 40,
                              backgroundColor: blanco,
                              child: ClipOval(
                                child: Image.file(
                                  File(usuario.avatar!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                    ),
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AvatarPage(
                            lista: Environment.userAvatar,
                            tipo: 'user_',
                            avatar: authService.usuario!.avatar!,
                          ),
                        ),
                      ).then((res) {
                        if (res != '' && res != null && res != true) {
                          authService.usuario!.avatar = res;
                          usuarioService.infoUserChange(
                              res, 'avatar', authService.usuario!.uid);
                          onRefresh();
                        }
                      });
                    },
                  ),
                ),
                // User name (bottom)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    capitalize(usuario.nombre!),
                    style: TextStyle(
                      fontSize: 20,
                      color: text_color,
                      fontFamily: 'roboto-medium',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Communication Section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              AppLocalizations.of(context)!.translate('COMMUNICATION'),
              style: TextStyle(
                color: gris,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.person_pin, color: primary),
            title: Text(
              AppLocalizations.of(context)!.translate('MYACCOUNT'),
              style: TextStyle(
                color: text_color,
                fontFamily: 'roboto-medium',
                letterSpacing: 1.0,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, 'cuenta')
                  .then((value) => onRefresh());
            },
          ),
          ListTile(
            leading: Icon(Icons.contact_mail_rounded, color: primary),
            title: Text(
              AppLocalizations.of(context)!.translate('CONTACT_REQUEST'),
              style: TextStyle(
                color: text_color,
                fontFamily: 'roboto-medium',
                letterSpacing: 1.0,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SolicitudesPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.group_add_rounded, color: primary),
            title: Text(
              AppLocalizations.of(context)!.translate('GROUPS'),
              style: TextStyle(
                color: text_color,
                fontFamily: 'roboto-medium',
                letterSpacing: 1.0,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, 'grupos')
                  .then((value) => onRefresh());
            },
          ),

          Divider(indent: 20, endIndent: 20, color: gris),

          // Account Section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              AppLocalizations.of(context)!.translate('ACCOUNT'),
              style: TextStyle(
                color: gris,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          if (miPago == 'true')
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.translate('SPECIAL'),
                style: TextStyle(
                  color: text_color,
                  fontFamily: 'roboto-medium',
                  letterSpacing: 1.0,
                ),
              ),
              onTap: () => _handleSpecialTap(context),
            ),
          ListTile(
            leading: Icon(Icons.monetization_on_rounded, color: primary),
            dense: true,
            title: Text(
              AppLocalizations.of(context)!.translate('BILLING'),
              style: TextStyle(
                color: text_color,
                fontFamily: 'roboto-medium',
                letterSpacing: 1.0,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, 'payment');
            },
          ),

          Divider(indent: 20, endIndent: 20, color: gris),

          // App Section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              AppLocalizations.of(context)!.translate('APP'),
              style: TextStyle(
                color: gris,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.settings, color: primary),
            title: Text(
              AppLocalizations.of(context)!.translate('SETTINGS'),
              style: TextStyle(
                color: text_color,
                fontFamily: 'roboto-medium',
                letterSpacing: 1.0,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, 'config')
                  .then((value) => onRefresh());
            },
          ),

          const SizedBox(height: 30),

          // Footer
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "CopyRights",
                    style: TextStyle(
                      color: text_color,
                      fontFamily: 'roboto-black',
                      letterSpacing: 1.0,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.copyright_outlined, color: text_color, size: 15),
                  const SizedBox(width: 5),
                  Image.asset(
                    'assets/banner/icon_img.png',
                    width: 60,
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNinjaModeTap(BuildContext context) {
    if (myPin == null || myPin == '') {
      alertaConfirmar(
        context,
        AppLocalizations.of(context)!.translate('INFORMATION'),
        AppLocalizations.of(context)!.translate('DEFINE_NINJA_PIN'),
      ).then((res) {
        if (res) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PinPutView(
                titulo: 'NINJA_PIN',
                subtitulo: 'DEFINE_NINJA_PIN',
              ),
            ),
          ).then((codigo) {
            if (codigo != false) {
              onSavePin(codigo);
              if (myPin != null && myPin != '') {
                onActivateNinjaMode();
              }
            }
          });
        }
      });
    } else {
      alertaConfirmar(
        context,
        AppLocalizations.of(context)!.translate('INFORMATION'),
        AppLocalizations.of(context)!.translate('ALERT_NINJA_MODE'),
      ).then((value) {
        if (value) onActivateNinjaMode();
      });
    }
  }

  void _handleSpecialTap(BuildContext context) {
    Navigator.pop(context);
    if (myPin == null || myPin == '') {
      alertaConfirmar(
        context,
        AppLocalizations.of(context)!.translate('INFORMATION'),
        AppLocalizations.of(context)!.translate('DEFINE_NINJA_PIN'),
      ).then((res) {
        if (res) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PinPutView(
                titulo: 'NINJA_PIN',
                subtitulo: 'DEFINE_NINJA_PIN',
              ),
            ),
          ).then((codigo) {
            if (codigo != false) {
              onSavePin(codigo);
            }
          });
        }
      });
    } else {
      alertaWidget(
        context,
        AppLocalizations.of(context)!.translate('NINJA_PIN'),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinCodeTextField(
              appContext: context,
              length: 4,
              controller: pinPutController,
              showCursor: true,
              cursorColor: amarillo,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(15.0),
                fieldHeight: 40.0,
                fieldWidth: 40.0,
                activeFillColor: Colors.transparent,
                inactiveFillColor: Colors.transparent,
                selectedFillColor: Colors.transparent,
                activeColor: amarillo,
                inactiveColor: amarilloClaro,
                selectedColor: amarillo,
              ),
              enableActiveFill: false,
              onChanged: (value) {},
              onCompleted: (value) {},
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                decoration: BoxDecoration(
                  color: amarillo.withOpacity(0.5),
                ),
                padding: const EdgeInsets.all(10),
                child: Text(
                  AppLocalizations.of(context)!.translate('CONTINUE'),
                ),
              ),
              onTap: () {
                if (pinPutController.text.isNotEmpty &&
                    pinPutController.text.length == 4) {
                  if (myPin == pinPutController.text) {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, 'archivo')
                        .then((value) => onRefresh());
                  } else {
                    mostrarAlerta(
                      context,
                      AppLocalizations.of(context)!.translate('WARNING'),
                      AppLocalizations.of(context)!.translate('INVALID_CODE'),
                    );
                  }
                } else {
                  mostrarAlerta(
                    context,
                    AppLocalizations.of(context)!.translate('WARNING'),
                    AppLocalizations.of(context)!.translate('INVALID_CODE'),
                  );
                }
                pinPutController.clear();
              },
            ),
          ],
        ),
        'CANCEL',
      );
    }
  }
}
