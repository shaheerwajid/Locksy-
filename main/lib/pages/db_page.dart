import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLanguage.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:provider/provider.dart';

import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';

class DBPage extends StatefulWidget {
  const DBPage({super.key});

  @override
  _DBPageState createState() => _DBPageState();
}

class _DBPageState extends State<DBPage> with SingleTickerProviderStateMixin {
  AppLanguage? language;

  SocketService? socketService;
  AuthService? authService;
  dynamic maptDB;

  List mensajes = [];

  @override
  void initState() {
    language = Provider.of<AppLanguage>(context, listen: false);
    socketService = Provider.of<SocketService>(context, listen: false);
    authService = Provider.of<AuthService>(context, listen: false);
    _getDB();
    super.initState();
  }

  _getDB() async {
    maptDB = await DBProvider.db.getDataDB();
    if (authService?.usuario?.uid != null) {
      var res = await DBProvider.db.getmensajes(authService!.usuario!.uid!);

      for (var m in res) {
        mensajes.add(Text('${m.mensaje}\n${m.uid}\n${m.createdAt}'));
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: amarillo,
          ),
          onTap: () => Navigator.pop(context),
        ),
        backgroundColor: blanco,
        title: Text(
          AppLocalizations.of(context)!.translate('LOCAL_DATABASE'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Card(
            child: ListTile(
              dense: true,
              title: Text('${AppLocalizations.of(context)!.translate('MSN_SEND')} ${maptDB != null ? maptDB['mensaje'] : 0} '),
            ),
          ),
          Card(
            child: ListTile(
              dense: true,
              title: Text(
                  '${AppLocalizations.of(context)!.translate('CONTACT_REGISTER')} ${maptDB != null ? maptDB['contacto'] : 0}'),
            ),
          ),
          Card(
            child: ListTile(
              dense: true,
              title: Text(
                  '${AppLocalizations.of(context)!.translate('GROUP_REGISTER')} ${maptDB != null ? maptDB['grupo'] : 0}'),
            ),
          ),
          // Card(
          //   child: ListTile(
          //     dense: true,
          //     title: Text('Facturacion'),
          //     onTap: () => Navigator.push(context,
          //         MaterialPageRoute(builder: (context) => PaymentPage())),
          //   ),
          // ),
          // ...mensajes,
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: rojo,
        heroTag: 'db-delete',
        child: const Icon(Icons.delete),
        onPressed: () {
          alertaConfirmar(
                  context,
                  AppLocalizations.of(context)!.translate('INFORMATION'),
                  AppLocalizations.of(context)!.translateReplace(
                      'DELETE_PERMANENTLY',
                      '{ACTION}',
                      AppLocalizations.of(context)!
                          .translate('DROP_ALL_MESSAGES')))
              .then((res) {
            if (res) DBProvider.db.borrarALL();
            setState(() {
              _getDB();
            });
          });
        },
      ),
    );
  }
}
