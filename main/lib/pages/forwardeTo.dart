import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';
import 'package:date_format/date_format.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';

import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/mensajes_response.dart';

import 'package:CryptoChat/models/usuario.dart';

import 'package:CryptoChat/providers/db_provider.dart';

import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';

import 'package:CryptoChat/widgets/bottonSheetContacto.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/toast_message.dart';

import 'package:provider/provider.dart';

import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:http/http.dart' as http;
import 'package:rive/rive.dart' as rive;

class ForwardeTo extends StatefulWidget {
  ForwardeTo(
      {Key? key,
      required this.messgaes,
      required this.incognito,
      required this.recibido})
      : super(key: key);
  List<ChatMessage> messgaes;
  bool incognito;
  bool recibido;
  @override
  _ForwardeToState createState() => _ForwardeToState();
}

class _ForwardeToState extends State<ForwardeTo> with TickerProviderStateMixin {
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
  String utc = DateTime.now().timeZoneName;

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
      appBar: AppBar(
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: amarillo,
          ),
          onTap: () => Navigator.pop(context, true),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('CONTACTS'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
        backgroundColor: transparente,
        shadowColor: transparente,
        bottom: AppBar(
          shadowColor: transparente,
          backgroundColor: transparente,
          leading: _isSearching
              ? GestureDetector(
                  child: Container(
                    child: Icon(Icons.cancel, color: gris),
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
                color: blanco.withOpacity(0.8),
                borderRadius: BorderRadius.circular(50),
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
            Flexible(child: __listUsers()),
            GestureDetector(
              child: Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: amarillo,
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
        complete: Icon(Icons.check, color: amarillo),
        waterDropColor: amarillo,
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
    return GridTile(
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
                Text(capitalize(contacto.nombre!))
              ],
            ),
          ),
          onTap: () {
            chatService!.usuarioPara = contacto;
            forwardeMessages(widget.messgaes, contacto);
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
    );
  }

  forwardeMessages(List<ChatMessage> mensajeSelected, Usuario? para) async {
    // CRITICAL: Prevent forwarding to self
    final authService = Provider.of<AuthService>(context, listen: false);
    if (para != null && authService.usuario?.uid == para.uid) {
      debugPrint('[ForwardeTo] ⚠️ Cannot forward messages to self, ignoring');
      return;
    }
    String utc = DateTime.now().timeZoneName;
    String mifecha = deconstruirDateTime();
    for (ChatMessage m in mensajeSelected) {
      if (m.type == 'text') {
        final newMessage = ChatMessage(
          uid: usuario!.uid!,
          deleted: m.deleted,
          selected: false,
          texto: m.texto,
          hora: DateTime.now().toString(),
          type: m.type,
          isReply: false,
          parentmessage: null,
          parenttype: null,
          username: null,
          forwarded: false,
          fecha: mifecha,
          incognito: widget.incognito,
          enviado: m.enviado,
          recibido: m.recibido,
        );

        persistMessajeLocal(m.type, para, m.texto, mifecha, '', null);

        var event = "mensaje-personal";

        var data = {
          'de': usuario!.uid,
          'para': para!.uid,
          'incognito': false,
          'forwarded': true,
          'reply': false,
          'parentType': null,
          'parentContent': null,
          'parentSender': null,
          'mensaje': {
            'type': m.type,
            'content': m.texto,
            'fecha': '${mifecha}Z$utc',
          },
        };
        // print('---------------------data------------------------');
        // print(data);
        // print("--------------------------data -------------------");
        // this.socketService.emit('mensaje-personal', data);
        print("fuuuuuuck");

        socketService!.emitAck(event, data).then((ack) {
          // print(
          //     "(((((((((((((((((((((((((((((ack)))))))))))))))))))))))))))))");
          // recibidoServidor(ack, data);
          //   setState(() {});
          // });
          // print("done");
          // setState(() {
          //   _messagetoReply = null;
          // });
        }).catchError((error) {
          print('[ForwardeTo] Error sending message: $error');
        });
      } else {
        if (await io.File(m.texto!).exists()) {
          File file = File(m.texto!);
          createMessage(result: [file], to: para);
        }
        // print(m.texto);
        // print(m.dir);
        // print(m.recibido);
        // print(m.type);
        // print(m.fecha);
        // print("after testing");
      }
    }
  }

  createMessage({List<File>? result, Usuario? to, String? value}) {
    if (result != null && result.isNotEmpty) {
      authService!
          .cargarArchivo(
              para: to!.uid,
              messagetoReply: null,
              result: result,
              esGrupo: false,
              userPara: to,
              incognito: widget.incognito,
              enviado: false,
              recibido: widget.recibido,
              isforwarded: true,
              animacion: AnimationController(
                  vsync: this, duration: const Duration(milliseconds: 100)),
              utc: utc,
              val: value)
          .then((newMessage) {
        if (mounted) setState(() {});
      });
    } else {}
  }

  persistMessajeLocal(type, para, content, datefecha, exte, replymsg) {
    print('persist mensaje-personal en chat_page');
    if (!widget.incognito) {
      var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
          [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);

      Mensaje mensajeLocal = Mensaje(deleted: false);
      mensajeLocal.mensaje = jsonEncode({
        'type': type,
        'content': content,
        'fecha': datefecha,
        'extension': exte
      });
      if (replymsg != null) {
        mensajeLocal.isReply = true;
        mensajeLocal.parentContent = replymsg['messageContent'];
        mensajeLocal.parentType = replymsg['messageType'];
        mensajeLocal.parentSender = replymsg['parentSender'];
      }
      // CRITICAL: Double-check to prevent self-chat
      if (usuario!.uid == para!.uid) {
        debugPrint('[ForwardeTo] ⚠️ Cannot forward message to self, skipping');
        return; // Skip this message
      }

      mensajeLocal.forwarded = true;
      mensajeLocal.de = usuario!.uid;
      mensajeLocal.para = para!.uid;
      mensajeLocal.createdAt = fechaActual;
      mensajeLocal.updatedAt = fechaActual;
      mensajeLocal.uid = para!.uid;  // Fixed: should be para.uid, not usuarioPara.uid
      DBProvider.db.nuevoMensaje(mensajeLocal);
    }
    // CRITICAL: Ensure contact UID is not current user
    if (para != null && para!.uid == usuario!.uid) {
      debugPrint('[ForwardeTo] ⚠️ Cannot create contact with own UID');
      return;
    }

    Usuario contactoNuevo = Usuario(publicKey: usuarioPara!.publicKey);
    contactoNuevo.nombre = usuarioPara!.nombre;
    contactoNuevo.avatar = usuarioPara!.avatar;
    contactoNuevo.uid = usuarioPara!.uid;
    contactoNuevo.online = usuarioPara!.online;
    contactoNuevo.codigoContacto = usuarioPara!.codigoContacto;
    contactoNuevo.email = usuarioPara!.email;
    DBProvider.db.nuevoContacto(contactoNuevo);
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
