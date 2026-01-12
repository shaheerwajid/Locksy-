import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/models/usuario_mensaje.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';

class ArchivoPage extends StatefulWidget {
  const ArchivoPage({super.key});

  @override
  _ArchivoPageState createState() => _ArchivoPageState();
}

class _ArchivoPageState extends State<ArchivoPage> {
  AuthService? authService;
  List<UsuarioMensaje> contactos = [];
  List<UsuarioMensaje> _allChats = [];
  List<UsuarioMensaje> _findContacto = [];

  Usuario? usuario;
  FocusNode? _focusNode;

  final searchCtrl = TextEditingController();

  bool _isSearching = false;

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
    _getContactosMensaje();
    super.initState();
  }

  _getContactosMensaje() async {
    _allChats.clear();
    if (usuario?.uid != null) {
      _allChats = await DBProvider.db.getUsuarioMensajeEsp(usuario!.uid!);
    }

    if (_isSearching) {
      contactos = _findContacto;
    } else {
      contactos = _allChats;
    }
    if (mounted) {
      setState(() {});
    }
  }

  _reload() {
    _getContactosMensaje();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: grisClaro,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: amarillo,
          ),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('SPECIAL'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
        bottom: _isSearching
            ? AppBar(
                backgroundColor: grisClaro,
                shadowColor: transparente,
                leading: GestureDetector(
                  child: Icon(
                    Icons.cancel,
                    color: gris,
                  ),
                  onTap: () {
                    setState(() {
                      _isSearching = false;
                      _getContactosMensaje();
                    });
                    searchCtrl.clear();
                  },
                ),
                title: Container(
                  height: 35,
                  padding: const EdgeInsets.only(left: 10),
                  width: MediaQuery.of(context).size.width * 0.65,
                  decoration: BoxDecoration(
                      color: blanco.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: gris)),
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      _searchChat(_allChats, value);
                      _getContactosMensaje();
                    },
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                    },
                    controller: searchCtrl,
                    style: TextStyle(
                      color: negro.withOpacity(0.5),
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                    ),
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.of(context)!.translate('SEARCH'),
                      hintStyle: TextStyle(color: gris.withOpacity(0.6)),
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              )
            : null,
        actions: [
          GestureDetector(
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              child: Icon(
                Icons.search,
                color: gris,
              ),
            ),
            onTap: () {
              if (!_isSearching) {
                setState(() {
                  _isSearching = true;
                  _focusNode = FocusNode();
                });
                _focusNode!.requestFocus();
              } else {
                setState(() {
                  _isSearching = false;
                  _getContactosMensaje();
                });
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SmartRefresher(
          controller: _refreshController,
          enablePullDown: true,
          onRefresh: _reload,
          header: WaterDropHeader(
            complete: Icon(Icons.check, color: amarillo),
            waterDropColor: amarillo,
          ),
          child: contactos.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.translate('HOME_TEXT_TITTLE'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: gris,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : _listChat(),
        ),
      ),
    );
  }

  Widget _listChat() {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, i) => const Divider(),
      itemCount: contactos.length,
      itemBuilder: (_, i) => Dismissible(
        key: ValueKey(contactos[i]),
        background: Container(
          padding: const EdgeInsets.only(left: 20),
          alignment: AlignmentDirectional.centerStart,
          color: rojo,
          child: Icon(
            Icons.delete,
            color: blanco,
          ),
        ),
        secondaryBackground: Container(
          padding: const EdgeInsets.only(right: 20),
          alignment: AlignmentDirectional.centerEnd,
          color: azul,
          child: Icon(
            Icons.unarchive,
            color: blanco,
          ),
        ),
        direction: DismissDirection.horizontal,
        confirmDismiss: (DismissDirection direction) async {
          var res;
          if (direction.index == 3) {
            res = await alertaConfirmar(
              context,
              AppLocalizations.of(context)!.translate('DELETE_MESSAGES'),
              AppLocalizations.of(context)!.translateReplace(
                  'DELETE_PERMANENTLY',
                  '{ACTION}',
                  AppLocalizations.of(context)!
                      .translate('DELETE_MESSAGES_ACCEPT')),
            );
          } else if (direction.index == 2) {
            res = await alertaConfirmar(
                context,
                AppLocalizations.of(context)!.translate('MOVE_MESSAGES'),
                AppLocalizations.of(context)!.translateReplace(
                    'MOVE_ACTION',
                    '{ACTION}',
                    AppLocalizations.of(context)!.translate('TO_HOME')));
          }
          return res;
        },
        onDismissed: (DismissDirection direction) async {
          if (direction.index == 3) {
            await DBProvider.db.borrarMensajesContacto(contactos[i].uid);
            await _getContactosMensaje();
          } else if (direction.index == 2) {
            if (contactos[i].esGrupo != 1) {
              await DBProvider.db
                  .updateContactos(contactos[i].uid, 'especial', 0);
            } else {
              await DBProvider.db.updateGrupo(contactos[i].uid, 'especial', 0);
            }
            await _getContactosMensaje();
          }
          contactos.remove(i);
          //deleteIndex = 3
          //unsaveIndex = 2
        },
        child: ListTile(
          title: Text(
            capitalize(contactos[i].nombre!),
            style: TextStyle(fontWeight: FontWeight.bold, color: gris),
          ),
          subtitle: Row(
            children: [
              Container(
                child: getIconMsg(jsonDecode(contactos[i].mensaje!)["type"]),
              ),
              Text(
                getMessageText(jsonDecode(contactos[i].mensaje!)["type"],
                    jsonDecode(contactos[i].mensaje!)["content"]),
              ),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: blanco,
            child: Image.asset(getAvatar(contactos[i].avatar!,
                contactos[i].esGrupo != 1 ? 'user_' : 'group_')),
          ),
          trailing: Text(
            formatDate(
                DateTime.parse(contactos[i].fecha!), [hh, ':', nn, ' ', am]),
            style: TextStyle(
              color: gris,
              fontSize: 10,
            ),
          ),
          onTap: () async {
            var chat = _openChatPage(contactos[i]);
            if (chat != 1) {
              Navigator.pushNamed(context, 'chat')
                  .then((value) => _getContactosMensaje());
            } else {
              Navigator.pushNamed(context, 'chatGrupal')
                  .then((value) => _getContactosMensaje());
            }
          },
        ),
      ),
    );
  }

  _openChatPage(UsuarioMensaje contactoGrupo) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    if (contactoGrupo.esGrupo != 1) {
      //ta9wadiyt here
      Usuario newUsuario = Usuario(publicKey: contactoGrupo.publicKey);
      newUsuario.nombre = contactoGrupo.nombre;
      newUsuario.avatar = contactoGrupo.avatar;
      newUsuario.uid = contactoGrupo.uid;

      newUsuario.codigoContacto = contactoGrupo.codigoContacto;
      newUsuario.email = contactoGrupo.email;
      chatService.usuarioPara = newUsuario;
      return contactoGrupo.esGrupo;
    } else {
      Grupo newGrupo = Grupo();
      newGrupo.nombre = contactoGrupo.nombre;
      newGrupo.avatar = contactoGrupo.avatar;
      newGrupo.codigo = contactoGrupo.uid;
      newGrupo.descripcion = contactoGrupo.email;
      newGrupo.fecha = contactoGrupo.codigoContacto;
      newGrupo.usuarioCrea = contactoGrupo.usuarioCrea;
      chatService.grupoPara = newGrupo;

      return contactoGrupo.esGrupo;
    }
  }

  List<UsuarioMensaje> _searchChat(
      List<UsuarioMensaje> contactoList, String txtSearch) {
    if (txtSearch == '') {
      _findContacto = _allChats;
    } else {
      _findContacto = contactoList
          .where((element) =>
              element.nombre!.toLowerCase().contains(txtSearch.toLowerCase()))
          .toList();
    }
    return _findContacto;
  }
}
