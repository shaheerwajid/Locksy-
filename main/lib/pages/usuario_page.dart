import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/widgets/gallery.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/toast_message.dart';
import '../providers/db_provider.dart';

import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';

import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:provider/provider.dart';

class UsuarioPage extends StatefulWidget {
  final Usuario dataUsuarioPara;
  const UsuarioPage(this.dataUsuarioPara, {super.key});

  @override
  _UsuarioPageState createState() => _UsuarioPageState();
}

class _UsuarioPageState extends State<UsuarioPage> {
  SocketService? socketService;
  ChatService? chatService;
  AuthService? authService;

  Usuario? usuarioPara;
  Usuario? usuario;

  // bool _selections = false;
  bool _incognito = false;

  @override
  void initState() {
    socketService = Provider.of<SocketService>(context, listen: false);

    chatService = Provider.of<ChatService>(context, listen: false);
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
    usuarioPara = widget.dataUsuarioPara;
    _getIncognito();
    super.initState();
  }

  _getIncognito() async {
    var res = await DBProvider.db.esContacto(usuarioPara!.uid);
    _incognito = res == 1 ? true : false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var server = socketService!.serverStatus == ServerStatus.Online;
    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        shadowColor: transparente,
        backgroundColor: transparente,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: blanco,
          ),
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  capitalize(usuarioPara!.nombre!),
                  style: TextStyle(
                    color: negro,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Hero(
                    tag: 'avatar',
                    child: CircleAvatar(
                      backgroundColor: blanco,
                      maxRadius: 150,
                      child:
                          Image.asset(getAvatar(usuarioPara!.avatar!, 'user_')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          onVerticalDragUpdate: (details) => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 10),
        height: 320,
        decoration: BoxDecoration(
          color: drawer_white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _incognito
                    ? Icon(
                        Icons.visibility_off,
                        color: verde,
                        size: 30.0,
                      )
                    : Icon(
                        Icons.visibility,
                        color: gris,
                        size: 30.0,
                      ),
                Container(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppLocalizations.of(context)!
                            .translate('HIDDEN_MODE'))
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  child: _incognito
                      ? Icon(
                          Icons.toggle_on,
                          size: 50,
                          color: verde,
                        )
                      : Icon(
                          Icons.toggle_off,
                          size: 50,
                          color: gris,
                        ),
                  onTap: () async {
                    if (server) {
                      setState(() {
                        _incognito = !_incognito;
                      });
                      socketService!.emit('modo-incognito', {
                        'de': usuario!.uid,
                        'para': usuarioPara!.uid,
                        'incognito': _incognito
                      });
                      await DBProvider.db.updateContactos(
                          usuarioPara!.uid, 'incognito', _incognito);
                    } else {
                      showToast(
                          context,
                          AppLocalizations.of(context)!
                              .translate('NO_CONECTION'),
                          rojo.withOpacity(0.8),
                          Icons.cancel_outlined);
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(
                  Icons.folder,
                  color: azul,
                  size: 30.0,
                ),
                Container(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.translate('FILES'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  child: Icon(
                    Icons.double_arrow_rounded,
                    size: 40,
                    color: azul,
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Gallery(usuarioPara!))),
                ),
              ],
            ),
            const Divider(),
            // DISAPPEARING MESSAGES BUTTON
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(
                  Icons.timelapse,
                  color: naranja,
                  size: 30.0,
                ),
                Container(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!
                              .translate('Disapperaing_messages'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  child: Icon(
                    Icons.double_arrow_rounded,
                    size: 40,
                    color: naranja,
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    'disapearing_messages',
                  ),
                ),
              ],
            ),
            const Divider(),
            SizedBox.fromSize(
              size: const Size(200, 45),
              child: Material(
                borderOnForeground: true,
                borderRadius: BorderRadius.circular(40),
                color: rojo,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () {
                    alertaConfirmar(
                      context,
                      AppLocalizations.of(context)!
                          .translate('DELETE_MESSAGES'),
                      AppLocalizations.of(context)!.translateReplace(
                          'DELETE_PERMANENTLY',
                          '{ACTION}',
                          AppLocalizations.of(context)!
                              .translate('DELETE_MESSAGES_ACCEPT')),
                    ).then((res) {
                      if (res) {
                        DBProvider.db.borrarMensajesContacto(usuarioPara!.uid);
                        Navigator.pop(context, 'vaciar');
                        return 'vaciar';
                      }
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        AppLocalizations.of(context)!.translate('EMPTY_CHAT'),
                        style: TextStyle(
                            color: blanco,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
