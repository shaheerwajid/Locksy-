import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';

import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';

import 'package:CryptoChat/models/usuario.dart';

import 'package:CryptoChat/providers/db_provider.dart';

import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';

import 'package:CryptoChat/widgets/bottonSheetContacto.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/toast_message.dart';

import 'package:provider/provider.dart';

import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:http/http.dart' as http;
import 'package:rive/rive.dart' as rive;

class ContactosPage extends StatefulWidget {
  const ContactosPage({super.key});

  @override
  _ContactosPageState createState() => _ContactosPageState();
}

class _ContactosPageState extends State<ContactosPage> {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: true);

  AuthService? authService;
  ChatService? chatService;
  SocketService? socketService;
  rive.Artboard? _riveArtboard;
  rive.RiveAnimationController? controller;
  List<Usuario> contactos = [];
  List<Usuario> _findContacto = [];
  List<Usuario> _allContactos = [];
  // List<Contacto> _contacto = [];

  Usuario? usuario;
  Usuario? usuarioPara;

  bool _isSearching = false;
  final searchCtrl = TextEditingController();
  String? pathLocal;

  @override
  void initState() {
    rootBundle.load('assets/rive/ninja.riv').then(
      (data) async {
        final file = rive.RiveFile.import(data);
        // if (file|) {
        final artboard = file.mainArtboard;
        artboard.addController(controller = rive.SimpleAnimation('alone'));
        setState(() => _riveArtboard = artboard);
        // }
      },
    );
    authService = Provider.of<AuthService>(context, listen: false);
    chatService = Provider.of<ChatService>(context, listen: false);
    socketService = Provider.of<SocketService>(context, listen: false);
    usuario = authService!.usuario;
    usuarioPara = chatService!.usuarioPara;
    _cargarContactos();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _cargarContactos() async {
    _allContactos.clear();
    await authService!.guardarContactosLocales(usuario!.codigoContacto);
    _allContactos = await DBProvider.db.getcontactos();

    if (_isSearching) {
      contactos = _findContacto;
    } else {
      contactos = _allContactos;
    }
    // this.contactos.sort((a, b) => a.nombre.compareTo(b.nombre));
    if (mounted) setState(() {});
  }

  _reload() {
    _cargarContactos();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(

        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: background,
          ),
          onTap: () => Navigator.pop(context, true),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('CONTACTS'),
          style: TextStyle(color: background),
        ),
        centerTitle: true,
        backgroundColor: header,
        shadowColor: sub_header,
        bottom: AppBar(
          shadowColor: sub_header,
          backgroundColor: header,
          leading: _isSearching
              ? GestureDetector(
                  child: Container(
                    child: Icon(Icons.cancel, color: background),
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    searchCtrl.clear();
                    setState(() {
                      _isSearching = false;
                    });
                    _cargarContactos();
                  },
                )
              : Container(),
          title: Container(
            height: 30,
            padding: const EdgeInsets.only(bottom: 3),
            width: MediaQuery.of(context).size.width * 0.65,
            decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: gris)),
            child: TextField(
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                _searchUser(_allContactos, value);
                _cargarContactos();
              },
              onTap: () {
                setState(() {
                  _isSearching = true;
                });
              },
              onEditingComplete: () {
                setState(() {
                  FocusScope.of(context).unfocus();
                });
              },
              controller: searchCtrl,
              style: TextStyle(
                color: negro.withOpacity(0.5),
                fontWeight: FontWeight.normal,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
              autocorrect: false,
              decoration: const InputDecoration(
                suffixIcon: Icon(
                  Icons.search,
                  size: 20,
                ),
                focusedBorder: InputBorder.none,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Flexible(child: __listUsers()),
            GestureDetector(
              child: Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.09,
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      color: blanco,
                    ),
                    Text(
                      AppLocalizations.of(context)!.translate('ADD'),
                      style: TextStyle(
                        color: blanco,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              onVerticalDragUpdate: (details) {
                FocusScope.of(context).unfocus();
                _launchModal();
              },
              onTap: () {
                FocusScope.of(context).unfocus();
                _launchModal();
              },
            ),
          ],
        ),
      ),
    );
  }

  _launchModal() {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: const BottomSheetContacto(),
        ),
      ),
    );
  }

  Widget __listUsers() {
    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      onRefresh: _reload,
      header: WaterDropHeader(
        complete: Icon(Icons.check, color: primary),
        waterDropColor: primary,
      ),
      child: _allContactos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 4,
                    child: _riveArtboard == null
                        ? const SizedBox()
                        : rive.Rive(
                            artboard: _riveArtboard!,
                          ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    flex: 2,
                    child: Text(
                      AppLocalizations.of(context)!.translate('NO_CONTACTS'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: gris,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : contactos.isEmpty
              ? Text(
                  AppLocalizations.of(context)!.translate('NO_RESULTS_FOUND'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: gris,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                  ),
                  itemBuilder: (_, i) => _usuariosGridTile(contactos[i]),
                  itemCount: contactos.length,
                ),
    );
  }

  GridTile _usuariosGridTile(Usuario contacto) {
    final contactName = capitalize(contacto.nombre!);
    final isOnline = contacto.online ?? false;
    final statusText = isOnline ? 'Online' : 'Offline';
    final semanticLabel = 'Contact $contactName, $statusText. Tap to open chat, long press to delete.';
    
    return GridTile(
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: InkResponse(
            enableFeedback: true,
            child: Container(
              // margin: EdgeInsets.all(10),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: gris.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    height: 100,
                    width: 100,
                    child: Stack(
                      children: [
                        Align(
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: blanco,
                            child: ClipOval(
                              child: Image.asset(
                                getAvatar(contacto.avatar!, 'user_'),
                                width: 60,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 20.0,
                            height: 20.0,
                            decoration: BoxDecoration(
                                color: blanco,
                                borderRadius: BorderRadius.circular(20.0)),
                            child: Icon(
                              Icons.circle,
                              color: contacto.online!
                                  ? verde
                                  : gris.withOpacity(0.7),
                              size: 20,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Text(contactName)
                ],
              ),
            ),
            onTap: () {
              chatService!.usuarioPara = contacto;
              Navigator.pushReplacementNamed(context, 'chat');
            },
            onLongPress: () {
              alertaConfirmar(
                context,
                AppLocalizations.of(context)!.translate('DELETE_CONTACT'),
                AppLocalizations.of(context)!.translateReplace(
                    'DELETE_PERMANENTLY',
                    '{ACTION}',
                    AppLocalizations.of(context)!
                        .translate('DELETE_MSG_CONTACT')),
              ).then((res) {
                if (res) {
                  deleteMyContacto(usuario!.codigoContacto!, contacto)
                      .then((value) => _reload());
                }
              });
            }),
      ),
    );
  }

  List<Usuario> _searchUser(List<Usuario> usersList, String txtSearch) {
    if (txtSearch.isEmpty) {
      _findContacto = _allContactos;
    } else {
      _findContacto = usersList
          .where((element) =>
              element.nombre!.toLowerCase().contains(txtSearch.toLowerCase()))
          .toList();
    }

    return _findContacto;
  }

  Future<dynamic> deleteMyContacto(String codeUsuario, Usuario contacto) async {
    print('Eliminando Contacto...');
    final data = {
      'codigoUsuario': codeUsuario,
      'codigoContacto': contacto.codigoContacto,
    };
    DBProvider.db.borrarMensajesContacto(contacto.uid);
    var eliminado = await DBProvider.db.borrarContacto(contacto.uid);
    if (eliminado != null && eliminado > 0) {
      String url = '${Environment.apiUrl}/contactos/dropContacto';
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
            AppLocalizations.of(context)!.translate('DELETED_CONTACT'),
            verde,
            Icons.check);
      } else {
        mostrarAlerta(context,
            AppLocalizations.of(context)!.translate('WARNING'), json['msg']);
      }

      socketService!.emit(
        'eliminar-para-todos',
        {
          'de': usuario!.uid,
          'para': contacto.uid,
        },
      );
    } else {
      mostrarAlerta(context, AppLocalizations.of(context)!.translate('WARNING'),
          AppLocalizations.of(context)!.translate('ERROR_DROP_CONTACT'));
    }
    return true;
  }
}
