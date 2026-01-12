import 'dart:convert';

import 'package:CryptoChat/services/crypto.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/api.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/lista_contactos.dart';

class CrearGrupoPage extends StatefulWidget {
  const CrearGrupoPage({super.key});

  @override
  _CrearGrupoPageState createState() => _CrearGrupoPageState();
}

class _CrearGrupoPageState extends State<CrearGrupoPage> {
  final _textNameController = TextEditingController();
  final _textDescController = TextEditingController();

  AuthService? authService;
  final usuarioService = UsuariosService();

  List<String> usuarioUID = [];
  bool busy = false;

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    print("crear_grupo_page.dart");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          AppLocalizations.of(context)!.translate('CREATE_GROUP'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 20, left: 10),
            margin: const EdgeInsets.only(bottom: 10, left: 30, right: 30),
            decoration: BoxDecoration(
              color: blanco,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gris),
            ),
            // child: TextField(
            //   Text(AppLocalizations.of(context).translate('PASSWORD')),

            // )
            child: TextField(
              controller: _textNameController,
              decoration: InputDecoration.collapsed(
                hintText:
                    (AppLocalizations.of(context)!.translate('GROUP_NAME')),
                hintStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 20, left: 10),
            margin: const EdgeInsets.only(bottom: 30, left: 30, right: 30),
            decoration: BoxDecoration(
                color: blanco,
                border: Border.all(color: gris),
                borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: _textDescController,
              minLines: 5,
              maxLines: 5,
              decoration: InputDecoration.collapsed(
                hintText: (AppLocalizations.of(context)!
                    .translate('GROUP_DESCRIPTION')),
                hintStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Text(
              AppLocalizations.of(context)!.translate('SELECTED_CONTACTS') +
                  usuarioUID.length.toString(),
              style: const TextStyle(fontSize: 17),
            ),
          ),
          SizedBox.fromSize(
            size: Size(MediaQuery.of(context).size.width * 0.5, 50),
            child: Material(
              borderRadius: BorderRadius.circular(40),
              color: azul.withOpacity(0.8),
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                splashColor: amarillo,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.translate('ADD'),
                    style: TextStyle(color: blanco),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (BuildContext context) => const ListaContactos(
                                limite: 20,
                              ))).then((res) {
                    if (res != null && res != false) {
                      setState(() {
                        usuarioUID = res;
                      });
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox.fromSize(
            size: Size(MediaQuery.of(context).size.width * 0.5, 50),
            child: Material(
              borderRadius: BorderRadius.circular(40),
              color: amarilloClaro,
              child: busy
                  ? Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(40),
                      splashColor: amarillo,
                      child: Center(
                        child: Text(
                            AppLocalizations.of(context)!.translate('CREATE')),
                      ),
                      onTap: () async {
                        final chatService =
                            Provider.of<ChatService>(context, listen: false);
                        Grupo newGrupo = await _createGrupo(
                            _textNameController.text,
                            _textDescController.text,
                            authService!.usuario!.uid);

                        chatService.grupoPara = newGrupo;
                        Navigator.pop(context, true);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 20),
          //
        ],
      ),
    );
  }

  _createGrupo(nombre, descripcion, uid) async {
    if (busy) {
      return;
    } else {
      setState(() {
        busy = true;
      });

      Set<String> keys = LocalCrypto().generatePaireKey();
      String publicKeyString = keys.first;

      String encryptedprivateKeyString =
          LocalCrypto().encrypt('Cryp16Zbqc@#4D%8', keys.last);

      usuarioUID.add(uid);
      final data = {
        'nombre': nombre,
        'descripcion': descripcion,
        'uid': uid,
        'fecha': deconstruirDateTime(),
        'codigoUsuario': usuarioUID,
        'publicKey': publicKeyString,
        'privateKey': encryptedprivateKeyString,
      };
      String url = '${Environment.apiUrl}/grupos/addGroup';
      final res = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      );
      var grupo = jsonDecode(res.body)['grupo'];
      var usuarioCrea = jsonEncode({
        'uid': grupo['usuarioCrea']['_id'],
        'nombre': grupo['usuarioCrea']['nombre'],
        'avatar': grupo['usuarioCrea']['avatar'],
        'codigoContacto': grupo['usuarioCrea']['codigoContacto'],
      });

      Grupo newGrupo = Grupo();
      newGrupo.codigo = grupo['codigo'];
      newGrupo.nombre = grupo['nombre'];
      newGrupo.descripcion = grupo['descripcion'];
      newGrupo.avatar = grupo['avatar'];
      newGrupo.fecha = grupo['fecha'];
      newGrupo.publicKey = grupo['publicKey'];

      newGrupo.privateKey = keys.last;
      newGrupo.usuarioCrea = usuarioCrea.toString();
      await DBProvider.db.nuevoGrupo(newGrupo);
      await usuarioService.getGrupoUsuario(grupo['codigo']);
      setState(() {
        busy = false;
      });
      return newGrupo;
    }
  }
}
