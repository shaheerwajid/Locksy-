import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/pages/crear_grupo_page.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';

class GruposPage extends StatefulWidget {
  const GruposPage({super.key});

  @override
  _GruposPageState createState() => _GruposPageState();
}

class _GruposPageState extends State<GruposPage> {
  AuthService? authService;
  List<Grupo> listGrupos = [];

  final usuarioService = UsuariosService();

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);

    _getGrupo();
    super.initState();
  }

  _getGrupo() async {
    listGrupos.clear();
    await usuarioService.getListGroup(authService!.usuario!.uid);
    listGrupos = await DBProvider.db.getGrupos();
    await authService!
        .guardarContactosLocales(authService!.usuario!.codigoContacto);
    if (mounted) setState(() {});
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
          AppLocalizations.of(context)!.translate('GROUPS'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Card(
            child: ListTile(
              tileColor: blanco,
              leading: const Icon(Icons.group),
              title:
                  Text(AppLocalizations.of(context)!.translate('CREATE_GROUP')),
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (context) => const CrearGrupoPage()))
                    .then((res) {
                  if (res) {
                    setState(() {
                      _getGrupo();
                    });
                  }
                });
              },
            ),
          ),
          // Card(
          //   child: ListTile(
          //     tileColor: blanco,
          //     leading: Icon(Icons.group_add),
          //     title: Text(AppLocalizations.of(context)!.translate('JOIN_GROUP')),
          //     onTap: () => alertaWidget(
          //         context,
          //         AppLocalizations.of(context)!.translate('JOIN_GROUP'),
          //         SizedBox(
          //           child: Column(
          //             mainAxisSize: MainAxisSize.min,
          //             children: [
          //               Container(
          //                 padding: EdgeInsets.only(top: 5, bottom: 5, left: 10),
          //                 margin: EdgeInsets.only(bottom: 10),
          //                 decoration: BoxDecoration(
          //                   borderRadius: BorderRadius.circular(10),
          //                   border: Border.all(color: gris),
          //                 ),
          //                 child: TextField(
          //                   controller: _textCodController,
          //                   decoration: InputDecoration.collapsed(
          //                     hintText: 'Codigo de grupo',
          //                     hintStyle: TextStyle(
          //                       fontWeight: FontWeight.normal,
          //                       color: gris,
          //                     ),
          //                   ),
          //                 ),
          //               ),
          //               SizedBox.fromSize(
          //                 size: Size(100, 40),
          //                 child: Material(
          //                   borderRadius: BorderRadius.circular(40),
          //                   color: amarilloClaro,
          //                   child: InkWell(
          //                     borderRadius: BorderRadius.circular(40),
          //                     splashColor: amarillo,
          //                     child: Center(
          //                       child: Text(AppLocalizations.of(context)
          //                           !.translate('JOIN')),
          //                     ),
          //                     onTap: () {
          //                       _entrarGrupo(_textCodController.text,
          //                           authService.usuario.uid);
          //                       Navigator.pop(context);
          //                     },
          //                   ),
          //                 ),
          //               )
          //             ],
          //           ),
          //         ),
          //         'CANCEL'),
          //   ),
          // ),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 20, bottom: 20),
            color: primary,
            width: MediaQuery.of(context).size.width,
            child: Text(
              AppLocalizations.of(context)!.translate('GROUP_LIST'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: drawer_white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          listGrupos.isNotEmpty
              ? Flexible(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: listGrupos.length,
                    itemBuilder: (_, i) => listaGrupos(listGrupos[i]),
                  ),
                )
              : Text(
                  AppLocalizations.of(context)!.translate('GROUP_NONE'),
                )
        ],
      ),
    );
  }

  ListTile listaGrupos(Grupo misGrupos) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: blanco,
        child: Image.asset(getAvatar(misGrupos.avatar!, 'group_')),
      ),
      tileColor: drawer_light_white,
      title: Text(misGrupos.nombre!),
      subtitle: Text(misGrupos.descripcion!),
      trailing: Text(
        AppLocalizations.of(context)!.translate('SEE_GROUP'),
        style: TextStyle(
          color: gris,
          fontSize: 10,
        ),
      ),
      onTap: () {
        final chatService = Provider.of<ChatService>(context, listen: false);
        Grupo newGrupo = Grupo();
        newGrupo.avatar = misGrupos.avatar;
        newGrupo.codigo = misGrupos.codigo;
        newGrupo.descripcion = misGrupos.descripcion;
        newGrupo.fecha = misGrupos.fecha;
        newGrupo.nombre = misGrupos.nombre;
        newGrupo.privateKey = misGrupos.privateKey;
        newGrupo.publicKey = misGrupos.publicKey;
        newGrupo.usuarioCrea = misGrupos.usuarioCrea.toString();
        chatService.grupoPara = newGrupo;
        Navigator.pushReplacementNamed(context, 'chatGrupal');
      },
    );
  }

  // _entrarGrupo(grupo, usuario) async {
  //   final data = {
  //     'codGrupo': grupo,
  //     'codUsuario': usuario,
  //   };
  //   String url = '${Environment.apiUrl}/grupo_usuario';
  //   final res = await http.post(
  //     url,
  //     headers: <String, String>{
  //       'Content-Type': 'application/json; charset=UTF-8',
  //       'x-token': await AuthService.getToken()
  //     },
  //     body: jsonEncode(data),
  //   );
  //   var json = jsonDecode(res.body);
  //   print(json);

  //   // var resdb = await DBProvider.db.nuevoGrupo(json);
  // }
}
