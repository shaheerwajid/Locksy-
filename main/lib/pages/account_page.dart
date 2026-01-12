import 'dart:io';

import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/objPago.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/avatars.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';

import 'package:CryptoChat/widgets/toast_message.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  SocketService? socketService;
  AuthService? authService;
  Usuario? usuario;
  final usuariosService = UsuariosService();

  List<ObjPago> pagos = [];
  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
    socketService = Provider.of<SocketService>(context, listen: false);
    super.initState();
  }

  bool isLocalFile(String path) {
    return Uri.tryParse(path)?.isAbsolute == false && File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    var server = socketService!.serverStatus == ServerStatus.Online;
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
          onTap: () {
            Navigator.pop(context, true);
            // return true;
          },
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('MYACCOUNT'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                child: Hero(
                  tag: 'avatar',
                  child: CircleAvatar(
                    radius: 90,
                    backgroundColor: drawer_light_white,
                    child: ClipOval(
                      child: usuario!.avatar != null &&
                              isLocalFile(usuario!.avatar!)
                          ? Image.file(
                              File(usuario!.avatar!),
                              width: 150,
                              height: 150,
                              fit: BoxFit.fill,
                            )
                          : Image.asset(
                              getAvatar(usuario!.avatar!, 'user_'),
                              width: 150,
                              height: 150,
                              fit: BoxFit.fill,
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
                                avatar: authService!.usuario!.avatar!,
                              ))).then((res) {
                    if (res != '' && res != null && res != true) {
                      usuarioService.infoUserChange(
                          res, 'avatar', authService!.usuario!.uid);
                      setState(() {
                        authService!.usuario!.avatar = res;
                      });
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          ListTile(
            tileColor: drawer_white,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(AppLocalizations.of(context)!.translate('NAME')),
            subtitle: Text(capitalize(usuario!.nombre!)),
            trailing: GestureDetector(
              child: const Icon(Icons.cached_rounded),
              onTap: () => server
                  ? mostrarEdit(
                      context,
                      AppLocalizations.of(context)!.translate('CHANGE_NAME'),
                      AppLocalizations.of(context)!.translate('NAME'),
                      usuario!.nombre!,
                      usuario!.uid)
                  : showToast(
                      context,
                      AppLocalizations.of(context)!.translate('NO_CONECTION'),
                      rojo.withOpacity(0.8),
                      Icons.cancel_outlined),
            ),
          ),
          ListTile(
            tileColor: drawer_white,
            leading: const Icon(Icons.mail_outline_rounded),
            title: Text(AppLocalizations.of(context)!.translate('EMAIL')),
            subtitle: Text(usuario!.email!),
            trailing: GestureDetector(
              child: const Icon(Icons.cached_rounded),
              onTap: () => server
                  ? mostrarEdit(
                      context,
                      '${AppLocalizations.of(context)!.translate('CHANGE')} ${AppLocalizations.of(context)!.translate('EMAIL')}',
                      AppLocalizations.of(context)!.translate('EMAIL'),
                      usuario!.email!,
                      usuario!.uid)
                  : showToast(
                      context,
                      AppLocalizations.of(context)!.translate('NO_CONECTION'),
                      rojo.withOpacity(0.8),
                      Icons.cancel_outlined),
            ),
          ),
          ListTile(
            tileColor: drawer_white,
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(AppLocalizations.of(context)!.translate('PASSWORD')),
            subtitle: Text(AppLocalizations.of(context)!.translate('CHANGE')),
            trailing: GestureDetector(
              child: const Icon(Icons.cached_rounded),
              onTap: () => server
                  ? mostrarEdit(
                      context,
                      '${AppLocalizations.of(context)!.translate('CHANGE')} ${AppLocalizations.of(context)!.translate('PASSWORD')}',
                      AppLocalizations.of(context)!.translate('PASSWORD'),
                      '',
                      usuario!.uid)
                  : showToast(
                      context,
                      AppLocalizations.of(context)!.translate('NO_CONECTION'),
                      rojo.withOpacity(0.8),
                      Icons.cancel_outlined),
            ),
          ),
          ListTile(
            tileColor: drawer_white,
            leading: const Icon(Icons.local_attraction_outlined),
            title: Text(
                AppLocalizations.of(context)!.translate('PROMOTIONAL_CODE')),
            subtitle: Text(usuario!.referido != null ? usuario!.referido! : ''),
            // title: Text(AppLocalizations.of(context).translate('PASSWORD')),
            // subtitle: Text(AppLocalizations.of(context).translate('CHANGE')),
            trailing: usuario!.referido == ""
                ? GestureDetector(
                    child: const Icon(Icons.arrow_forward_ios_rounded),
                    onTap: () => server
                        ? mostrarEdit(
                            context,
                            AppLocalizations.of(context)!.translate('ADD'),
                            AppLocalizations.of(context)!
                                .translate('PROMOTIONAL_CODE'),
                            '',
                            usuario!.uid)
                        : showToast(
                            context,
                            AppLocalizations.of(context)!
                                .translate('NO_CONECTION'),
                            rojo.withOpacity(0.8),
                            Icons.cancel_outlined),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
