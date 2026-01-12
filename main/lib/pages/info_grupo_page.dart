import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/grupo_usuario.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/avatars.dart';
import 'package:CryptoChat/widgets/lista_contactos.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';

enum OptionSelected { vaciar, eliminar }

class InfoGrupoPage extends StatefulWidget {
  final Grupo dataGrupoPara;
  const InfoGrupoPage(this.dataGrupoPara, {super.key});

  @override
  _InfoGrupoPageState createState() => _InfoGrupoPageState();
}

class _InfoGrupoPageState extends State<InfoGrupoPage> {
  ChatService? chatService;
  AuthService? authService;
  final usuarioService = UsuariosService();

  Grupo? grupoPara;
  Usuario? usuario;
  final List<ListTile> _listMembers = [];
  List<GrupoUsuario> _miembros = [];
  List<String> usuarioUID = [];

  bool esAdmin = false;

  @override
  void initState() {
    chatService = Provider.of<ChatService>(context, listen: false);
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
    grupoPara = widget.dataGrupoPara;
    esAdmin = jsonDecode(grupoPara!.usuarioCrea!)['uid'] == usuario!.uid;
    _miembrosGrupo();
    super.initState();
  }

  _miembrosGrupo() async {
    _listMembers.clear();
    _miembros.clear();
    await usuarioService.getGrupoUsuario(grupoPara!.codigo);
    var res = await DBProvider.db.getMiembrosGroup(grupoPara!.codigo);
    var creado = jsonDecode(grupoPara!.usuarioCrea!)['uid'];
    _miembros = res;
    for (var m in res) {
      usuarioUID.add(m.uidUsuario!);
      _listMembers.add(
        ListTile(
          tileColor: chat_color,
          leading: CircleAvatar(
            backgroundColor: blanco,
            child: Image.asset(getAvatar(m.avatarUsuario!, 'user_')),
          ),
          title: Text(capitalize(m.nombreUsuario!)),
          trailing: m.uidUsuario == creado
              ? Text(
                  AppLocalizations.of(context)!
                      .translate('ADMINISTRATOR'), //ADMINISTRATOR
                  style: TextStyle(
                    color: gris,
                  ),
                )
              : esAdmin
                  ? GestureDetector(
                      child: const Icon(Icons.more_vert),
                      onTap: () {
                        alertaConfirmar(
                                context,
                                AppLocalizations.of(context)!.translate(
                                    'DROP_MEMBER'), //DROP_MEMBER, DROP_ACTION
                                AppLocalizations.of(context)!
                                        .translate('DROP_ACTION') +
                                    m.nombreUsuario!)
                            .then((res) {
                          if (res) {
                            usuarioService.removeMemberGroup(
                                grupoPara!.codigo, m.uidUsuario);
                            DBProvider.db
                                .deleteMiembro(grupoPara!.codigo, m.uidUsuario);
                            _miembrosGrupo();
                            setState(() {});
                          }
                        });
                      })
                  : const SizedBox(),
        ),
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final nombreCtrl =
        TextEditingController(text: chatService!.grupoPara!.nombre);
    final desCtrl =
        TextEditingController(text: chatService!.grupoPara!.descripcion);

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
          onTap: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: PopupMenuButton<OptionSelected>(
              onSelected: (OptionSelected res) {
                switch (res.index) {
                  case 0:
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
                        DBProvider.db.borrarMensajesContacto(grupoPara!.codigo);
                        Navigator.pop(context, 'vaciar');
                      }
                    });
                    break;
                  case 1:
                    eliminarYsalir();
                    break;
                }
              },
              tooltip: AppLocalizations.of(context)!.translate('OPTIONS'),
              child: Icon(
                Icons.more_vert,
                size: 28,
                color: gris,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: OptionSelected.vaciar,
                  child: Text(
                    AppLocalizations.of(context)!.translate('EMPTY_CHAT'),
                    style:
                        TextStyle(color: negro.withOpacity(0.7), fontSize: 17),
                  ),
                ),
                if (esAdmin)
                  PopupMenuItem(
                    value: OptionSelected.eliminar,
                    child: Container(
                      child: Text(
                        AppLocalizations.of(context)!.translate('DELETE_GROUP'),
                        //"Eliminar grupo",
                        //DELETE_GROUP
                        style: TextStyle(
                          color: rojo,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          GestureDetector(
              child: Container(
                margin:
                    const EdgeInsets.only(bottom: 30, top: 30, left: 100, right: 100),
                height: 190,
                child: Hero(
                  tag: 'avatar',
                  child: Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.center,
                        child: ClipOval(
                          child: Image.asset(
                              getAvatar(grupoPara!.avatar!, 'group_')),
                        ),
                      ),
                      esAdmin
                          ? Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: gris.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: blanco,
                                  size: 20,
                                ),
                              ),
                            )
                          : const SizedBox()
                    ],
                  ),
                ),
              ),
              onTap: () {
                if (esAdmin) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AvatarPage(
                                lista: Environment.groupAvatar,
                                tipo: 'group_',
                                avatar: grupoPara!.avatar!,
                              ))).then((res) {
                    if (res != '' && res != null && res != true) {
                      usuarioService.updateGroup(
                          avatar: res, codigo: grupoPara!.codigo);
                      setState(() {
                        grupoPara!.avatar = res;
                      });
                      DBProvider.db.nuevoGrupo(grupoPara!);
                    }
                  });
                }
              }),
          Text(
            grupoPara!.nombre!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: negro,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          ListTile(
            title: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: AppLocalizations.of(context)!.translate('CREATE_BY'),
                    style: TextStyle(
                      color: negro,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: capitalize(
                        jsonDecode(grupoPara!.usuarioCrea!)['nombre']),
                    style: TextStyle(
                        color: negro,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: AppLocalizations.of(context)!.translate('ON_DATE'),
                    style: TextStyle(
                      color: negro,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: construirDateTime(grupoPara!.fecha!).split(' ')[0],
                    style: TextStyle(
                        color: negro,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            trailing: esAdmin
                ? GestureDetector(
                    child: const Icon(Icons.edit_outlined),
                    onTap: () {
                      alertaWidget(
                        context,
                        AppLocalizations.of(context)!.translate('EDIT_GROUP'),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width,
                              padding: const EdgeInsets.all(5),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: gris),
                              ),
                              child: TextField(
                                controller: nombreCtrl,
                                decoration: InputDecoration.collapsed(
                                  hintText: AppLocalizations.of(context)!
                                      .translate('NAME'),
                                  hintStyle: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: gris,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width,
                              padding: const EdgeInsets.all(5),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: gris),
                              ),
                              child: TextField(
                                minLines: 3,
                                maxLines: 5,
                                maxLength: 100,
                                controller: desCtrl,
                                decoration: InputDecoration.collapsed(
                                  hintText: AppLocalizations.of(context)!
                                      .translate('GROUP_DESCRIPTION'),
                                  //GROUP_DESCRIPTION
                                  hintStyle: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: gris,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox.fromSize(
                              size: Size(
                                  MediaQuery.of(context).size.width * 0.5, 50),
                              child: Material(
                                borderRadius: BorderRadius.circular(40),
                                color: amarilloClaro,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(40),
                                  splashColor: gris,
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .translate('SAVE'),
                                    ),
                                  ),
                                  onTap: () {
                                    usuarioService.updateGroup(
                                      codigo: grupoPara!.codigo,
                                      nombre: nombreCtrl.text,
                                      descripcion: desCtrl.text,
                                    );

                                    Navigator.pop(context, true);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        'CANCEL',
                      ).then((res) {
                        if (res) {
                          setState(() {
                            grupoPara!.nombre = nombreCtrl.text;
                            grupoPara!.descripcion = desCtrl.text;
                          });
                          DBProvider.db.nuevoGrupo(grupoPara!);
                        }
                      });
                    },
                  )
                : const SizedBox(),
          ),

          grupoPara!.descripcion != ''
              ? Container(
                  color: chat_color,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!
                            .translate('GROUP_DESCRIPTION'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        grupoPara!.descripcion!,
                        style: TextStyle(color: gris, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : const SizedBox(),
          Divider(
            color: gris,
            indent: 20,
            endIndent: 20,
          ),
          ListTile(
            tileColor: chat_color,
            leading: Icon(
              Icons.group_add_outlined,
              color: azul,
            ),
            title: Text(AppLocalizations.of(context)!.translate('ADD_USERS')),
            onTap: () {
              // if (_miembros.length >= 20) {
              //   mostrarAlerta(context, "",
              //       "CryptoChat permite máximo 20 participantes por grupo");
              // } else {
              // print("heeeeeeeeeeeeeeeeeeeere");
              print(usuarioUID);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => ListaContactos(
                      limite: 20,
                      usuarios: usuarioUID,
                    ),
                  )).then((res) {
                if (res != null && res != false) {
                  // print("zzzzzzzzzzzzeeeeeeeeeeeeeeb");
                  // print(res.runtimeType);
                  List<String> result =
                      res.where((item) => !usuarioUID.contains(item)).toList();

                  // print(result);
                  if (result.isNotEmpty) {
                    usuarioUID.addAll(result);
                    usuarioService.addMemberGroup(
                        grupoPara!.codigo, usuarioUID);
                    _miembrosGrupo();
                    setState(() {});
                  }
                }
              });
            },
          ),
          Divider(
            color: gris,
            indent: 20,
            endIndent: 20,
          ),
          ListTile(
            tileColor: chat_color,
            leading: Icon(
              Icons.exit_to_app_rounded,
              color: rojo,
            ),
            title: Text(AppLocalizations.of(context)!.translate('LEAVE_GROUP')),
            onTap: () async {
              // if (esAdmin) {
              //   if (_miembros.length > 2) {
              //     if (_miembros[0].uidUsuario ==
              //         jsonDecode(grupoPara.usuarioCrea)['uid']) {
              //       await usuarioService.updateGroup(
              //         codigo: grupoPara.codigo,
              //         usuario: _miembros[1].uidUsuario,
              //       );
              //     } else {
              //       await usuarioService.updateGroup(
              //         codigo: grupoPara.codigo,
              //         usuario: _miembros[0].uidUsuario,
              //       );
              //     }
              //   } else if (_miembros.length == 1) {
              //     await _eliminarYsalir();
              //   }
              // }

              if (_miembros.length == 1) {
                await eliminarYsalir();
              } else if (_miembros.length > 1) {
                usuarioService.removeMemberGroup(
                    grupoPara!.codigo, usuario!.uid);
              }
              DBProvider.db.deleteGroup(grupoPara!.codigo);
              Navigator.pushNamedAndRemoveUntil(
                  context, 'home', (route) => false);
            },
          ),
          Divider(
            color: gris,
            indent: 20,
            endIndent: 20,
          ),
          // Container(
          //   margin: EdgeInsets.all(10),
          //   child: ListTile(
          //     title: Text(
          //       AppLocalizations.of(context).translate('DELETE_GROUP'),
          //       textAlign: TextAlign.center,
          //       style: TextStyle(
          //         color: blanco,
          //         fontWeight: FontWeight.bold,
          //         fontSize: 15,
          //       ),
          //     ),
          //     tileColor: rojo,
          //     dense: true,
          //     onTap: () {
          //       eliminarYsalir();
          //     },
          //   ),
          // ),
          Container(
            color: chat_color,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${AppLocalizations.of(context)!.translate('MEMBER')}${_listMembers.length}/20',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Divider(
                  color: gris,
                )
              ],
            ),
          ),
          ..._listMembers,
        ],
      ),
    );
  }

  eliminarYsalir() async {
    await alertaConfirmar(
            context,
            AppLocalizations.of(context)!.translate('DELETE'),
            '${AppLocalizations.of(context)!.translateReplace(
                    'DELETE_PERMANENTLY',
                    '{ACTION}',
                    AppLocalizations.of(context)!.translate('ACTION_GROUP'))} ${grupoPara!.nombre}')
        .then((value) async {
      if (value) {
        await usuarioService.deleteGroup(grupoPara!.codigo);
        DBProvider.db.deleteGroup(grupoPara!.codigo);
        Navigator.pushNamedAndRemoveUntil(context, 'home', (route) => false);
      }
    });
  }
}
