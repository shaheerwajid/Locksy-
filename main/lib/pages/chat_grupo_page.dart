// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';

// import 'package:CryptoChat/pages/forwardeTo.dart';
// import 'package:CryptoChat/widgets/replymsg.dart';
// import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
// import 'package:date_format/date_format.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// // import 'package:flutter_sound/flutter_sound.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:logger/logger.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// //import 'package:sound_recorder/sound_recorder.dart';
// import 'package:CryptoChat/global/AppLocalizations.dart';
// import 'package:CryptoChat/helpers/funciones.dart';
// import 'package:CryptoChat/helpers/style.dart';
// import 'package:CryptoChat/models/grupo.dart';
// import 'package:CryptoChat/models/mensajes_response.dart';
// import 'package:CryptoChat/models/usuario.dart';
// import 'package:CryptoChat/pages/info_grupo_page.dart';
// import 'package:CryptoChat/providers/db_provider.dart';
// import 'package:CryptoChat/services/auth_service.dart';
// import 'package:CryptoChat/services/chat_service.dart';
// import 'package:CryptoChat/services/socket_service.dart';
// import 'package:CryptoChat/services/usuarios_service.dart';
// import 'package:CryptoChat/widgets/chat_message.dart';
// import 'package:CryptoChat/widgets/cronometro.dart';
// import 'package:CryptoChat/widgets/mostrar_alerta.dart';
// import 'package:CryptoChat/widgets/toast_message.dart';
// import 'package:swipe_to/swipe_to.dart';

// class ChatGrupoPage extends StatefulWidget {
//   @override
//   _ChatGrupoPageState createState() => _ChatGrupoPageState();
// }

// class _ChatGrupoPageState extends State<ChatGrupoPage>
//     with TickerProviderStateMixin {
//   final _textController = new TextEditingController();
//   final _focusNode = new FocusNode();

//   ChatService? chatService;
//   SocketService? socketService;
//   AuthService? authService;
//   final usuarioService = new UsuariosService();

//   Usuario? usuario;
//   Grupo? grupoPara;
//   List<ChatMessage> _messages = [];
//   bool _estaEscribiendo = false;
//   bool _isRecording = false;
//   // FlutterSoundRecorder soundRecorder = new FlutterSoundRecorder();
//   // SoundRecorder _recorder;
//   CustomPopupMenuController _controller = CustomPopupMenuController();

//   Random random = new Random();
//   List<int> _selectedItems = [];
//   List<ChatMessage> _mensajeSelected = [];
//   bool _incognito = false;
//   bool _enviado = false;
//   String? deration;

//   bool _recibido = false;
//   String utc = DateTime.now().timeZoneName;
//   FlutterSoundRecorder flutterSound = FlutterSoundRecorder();
//   String? dirPath;
//   ChatMessage? _messagetoReply;

//   bool _cargando = false;
//   double _carga = 0;

//   bool esMiembro = true;

//   @override
//   void initState() {
//     this.authService = Provider.of<AuthService>(context, listen: false);
//     this.chatService = Provider.of<ChatService>(context, listen: false);
//     this.socketService = Provider.of<SocketService>(context, listen: false);

//     this.usuario = authService!.usuario;
//     this.grupoPara = chatService!.grupoPara;
//     this.dirPath = authService!.localPath;
//     getGroups();

//     this.socketService!.socket!.on('mensaje-grupal', _escucharMensaje1);
//     this.socketService!.socket!.on('recibido-cliente', _recibirAcuse);
//     this.socketService!.socket!.on('grupo-borrado', _recibirBorrado);
//     this.socketService!.socket!.on('usuario-borrado-grupo', (payload) {
//       print('payload usuario borrado Chat'); //
//       var grupo = payload['grupousuario']['grupo']['codigo'];
//       var usuario = payload['grupousuario']['usuarioContacto'];
//       DBProvider.db.deleteMiembro(grupo, usuario);
//       if (usuario == this.usuario!.uid) {
//         DBProvider.db.deleteGroup(grupo);
//       }
//       if (mounted)
//         setState(() {
//           esMiembro = false;
//         });
//     });

//     _cargarHistorial(grupoPara!.codigo!);
//     _onChatGrupoPageStateON();

//     super.initState();
//   }

//   void _cargarHistorial(String usuarioUID) async {
//     _messages.clear();
//     await usuarioService.getGrupoUsuario(grupoPara!.codigo);
//     var messajes = await DBProvider.db.getTodosMensajes(usuarioUID);
//     messajes.forEach((m) => print('${m.nombreEmisor}: ${m.mensaje}: ${m.uid}'));

//     var res = await DBProvider.db.esContacto(grupoPara!.codigo, tipo: 'grupo');
//     // print('esMiembro: $res');
//     esMiembro = res != null && res != 0 ? true : false;
//     final history = messajes.map((m) => ChatMessage(
//           dir: dirPath!,
//           exten: jsonDecode(m.mensaje!)['extension'],
//           fecha: jsonDecode(m.mensaje!)['fecha'],
//           texto: jsonDecode(m.mensaje!)['content'],
//           type: jsonDecode(m.mensaje!)['type'],
//           selected: false,
//           deleted: m.deleted,
//           isReply: m.isReply,
//           forwarded: m.forwarded,
//           parentmessage: m.parentContent,
//           parenttype: m.parentType,
//           username: m.parentSender,
//           hora: m.createdAt!,
//           emisor: m.nombreEmisor != null
//               ? m.nombreEmisor!.split(' ')[0]
//               : 'Desconocido',
//           incognito: m.incognito == 1 ? true : false,
//           enviado: m.enviado == 1 ? true : false,
//           recibido: m.recibido == 1 ? true : false,
//           uid: m.de!,
//         ));
//     if (mounted)
//       setState(() {
//         _messages.insertAll(0, history);
//       });
//     if (!mounted) return;
//   }

//   void _recibirBorrado(dynamic payload) {
//     if (mounted)
//       setState(() {
//         esMiembro = false;
//       });
//   }

//   void _escucharMensaje(dynamic payload) {
//     print('Recibiendo Mensaje en Chat Page');

//     var type = jsonDecode(payload['mensaje'])['type'];
//     var content = jsonDecode(payload['mensaje'])['content'];
//     var fechaM = jsonDecode(payload['mensaje'])['fecha'].split('Z')[0];
//     var ext = jsonDecode(payload['mensaje'])['extension'];
//     var incognito = payload['incognito'];
//     // var _descarga = this.socketService.porcentajeDescarga;

//     ChatMessage message = ChatMessage(
//       selected: false,
//       dir: dirPath!,
//       exten: ext,
//       texto: content,
//       fecha: fechaM,
//       type: type,
//       deleted: false,
//       forwarded: payload['forwarded'],
//       isReply: payload['reply'],
//       parentmessage: payload['parentContent'],
//       parenttype: payload['parentType'],
//       username: payload['parentSender'],
//       emisor: payload['usuario']['nombre'].split(' ')[0],
//       incognito: incognito,
//       enviado: false,
//       recibido: false,
//       hora: new DateTime.now().toString(),
//       uid: payload['de'],
//     );

//     emitirAcuseRecibo(payload);
//     // if (type == "text") {
//     if (message.uid == grupoPara!.codigo) {
//       if (mounted)
//         setState(() {
//           _messages.insert(0, message);
//         });
//     }
//     // } else {
//     //   if (_descarga == '100%') {
//     //     if (message.uid == grupoPara.codigo) {
//     //       if (mounted)
//     //         setState(() {
//     //           _messages.insert(0, message);
//     //         });
//     //     }
//     //   }
//     // }
//   }

//   void _escucharMensaje1(dynamic payload) async {
//     // setState(() {
//     //   _cargarHistorial(usuarioPara!.uid!);
//     // });
//     ChatMessage message;
//     print('Recibiendo Mensaje en Chat Page 1');

//     print(
//         "-----------------------PlayLoad222222222222222222222222222222222---------------------------");
//     print(payload);
//     print("-----------------------PlayLoad---------------------------");
//     var ext = '';
//     var type = jsonDecode(payload['mensaje'])['type'];
//     var content = jsonDecode(payload['mensaje'])['content'];
//     var fechaM = jsonDecode(payload['mensaje'])['fecha'].split('Z')[0];
//     var exte = jsonDecode(payload['mensaje'])['extension'];
//     var incognito = payload['incognito'];
//     var _descarga = this.socketService!.porcentajeDescarga;
//     var _descar = this.socketService!.descargando;
//     if (type == 'images' ||
//         type == 'recording' ||
//         type == 'video' ||
//         type == 'documents' ||
//         type == 'audio') {
//       ext = jsonDecode(payload['mensaje'])['extension'];
//       socketService!.saveFile(type, content, fechaM, ext).then(
//         (value) {
//           print(value);
//           socketService!.persistMessajeLocal(type, value, fechaM, ext, payload);
//           print("---------------------------------------------------------");
//           print(value);
//           print("here hhhhhhhhhhhhhhhhh");
//           message = ChatMessage(
//             dir: dirPath,
//             selected: false,
//             exten: exte,
//             texto: content,
//             fecha: fechaM,
//             type: type,
//             deleted: false,
//             forwarded: payload['forwarded'],
//             isReply: payload['reply'],
//             parentmessage: payload['parentContent'],
//             parenttype: payload['parentType'],
//             username: payload['parentSender'],
//             emisor: payload['usuario']['nombre'].split(' ')[0],
//             incognito: incognito,
//             enviado: false,
//             recibido: false,
//             hora: new DateTime.now().toString(),
//             uid: payload['de'],
//           );

//           setState(() {
//             _messages.insert(0, message);
//           });
//           emitirAcuseRecibo(payload);
//           //socketService!.emitirAcuseRecibo(payload);
//         },
//       );
//     } else {
//       print(
//           "------------------------------${payload['reply']}--------------------------");

//       message = ChatMessage(
//         dir: dirPath,
//         exten: exte,
//         selected: false,
//         texto: content,
//         fecha: fechaM,
//         deleted: false,
//         type: type,
//         forwarded: payload['forwarded'],
//         isReply: payload['reply'],
//         parentmessage: payload['parentContent'],
//         parenttype: payload['parentType'],
//         emisor: payload['usuario']['nombre'].split(' ')[0],
//         username: payload['parentSender'],
//         incognito: incognito,
//         enviado: false,
//         recibido: false,
//         hora: DateTime.now().toString(),
//         uid: payload['de'],
//       );

//       print('Descarga: $_descarga');
//       print('Descargando: $_descar');

//       if (message.uid == grupoPara!.codigo) {
//         if (mounted)
//           setState(() {
//             _messages.insert(0, message);
//           });
//       }
//       emitirAcuseRecibo(payload);
//     }
//   }

//   _onChatGrupoPageStateON() async {
//     var prefs = await SharedPreferences.getInstance();
//     prefs.setString('ChatGrupoPage', 'connectChat');
//   }

//   _onChatGrupoPageStateOFF() async {
//     var prefs = await SharedPreferences.getInstance();
//     prefs.setString('ChatGrupoPage', 'disconnectChat');
//   }

//   bool reRender = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: gris,
//       appBar: AppBar(
//         shadowColor: transparente,
//         backgroundColor: transparente,
//         leading: InkWell(
//           child: Icon(
//             Icons.arrow_back_ios_rounded,
//             color: blanco,
//           ),
//           onTap: () => Navigator.pop(context, true),
//         ),
//         title: _selectedItems.isEmpty
//             ? GestureDetector(
//                 child: Container(
//                     padding:
//                         EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
//                     decoration: BoxDecoration(
//                       color: blanco.withOpacity(0.7),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         SizedBox(width: 0),
//                         Text(
//                           grupoPara!.nombre!,
//                           style: TextStyle(
//                             color: negro,
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Hero(
//                           tag: 'avatar',
//                           child: CircleAvatar(
//                             backgroundImage: AssetImage(
//                                 getAvatar(grupoPara!.avatar!, 'group_')),
//                             backgroundColor: blanco,
//                             maxRadius: 20,
//                           ),
//                         ),
//                       ],
//                     )),
//                 onTap: () async {
//                   if (esMiembro) {
//                     Navigator.of(context)
//                         .push(MaterialPageRoute(
//                             builder: (context) => InfoGrupoPage(grupoPara!)))
//                         .then((value) {
//                       _cargarHistorial(grupoPara!.codigo!);
//                     });
//                   }
//                 },
//               )
//             : Container(
//                 padding: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: blanco.withOpacity(0.7),
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     SizedBox(width: 0),
//                     Text(
//                       _selectedItems.length.toString(),
//                       style: TextStyle(
//                         color: negro,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     GestureDetector(
//                         child: Container(
//                           child: Icon(
//                             Icons.copy,
//                             size: 30,
//                             color: gris,
//                           ),
//                         ),
//                         onTap: () async {
//                           List<String> messagesToCopy = [];
//                           for (ChatMessage m in _mensajeSelected) {
//                             if (m.type == "text" && m.texto != null) {
//                               messagesToCopy.add(m
//                                   .texto!); // Add the message text to the new list
//                             }
//                           }

//                           String messagetocopy = messagesToCopy.join("\n");

//                           if (messagetocopy != "") {
//                             Clipboard.setData(ClipboardData(
//                                     text: messagetocopy.toString()))
//                                 .then((_) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                   const SnackBar(
//                                       content:
//                                           Text('Copied to your clipboard !')));
//                             });
//                             setState(() {
//                               _selectedItems = [];
//                               _mensajeSelected = [];
//                             });
//                           } else {
//                             setState(() {
//                               _selectedItems = [];
//                               _mensajeSelected = [];
//                             });
//                           }
//                         }),
//                     GestureDetector(
//                         child: Container(
//                           child: Icon(
//                             Icons.forward,
//                             size: 30,
//                             color: gris,
//                           ),
//                         ),
//                         onTap: () async {
//                           if (_mensajeSelected.isNotEmpty) {
//                             Navigator.of(context).push(MaterialPageRoute(
//                                 builder: (context) => ForwardeTo(
//                                       messgaes: _mensajeSelected,
//                                       incognito: _incognito,
//                                       recibido: _recibido,
//                                     )));
//                           }
//                         }),
//                     GestureDetector(
//                         child: Container(
//                           child: Icon(
//                             Icons.delete,
//                             size: 30,
//                             color: rojo,
//                           ),
//                         ),
//                         onTap: () {
//                           alertaWidget(
//                               context,
//                               AppLocalizations.of(context)!
//                                   .translate('DROP_SELECTED_MESSAGES'),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   btnEliminar(
//                                       AppLocalizations.of(context)!
//                                           .translate('FOR_ME'),
//                                       false),
//                                 ],
//                               ),
//                               'CANCEL');
//                         })
//                   ],
//                 ),
//               ),
//       ),
//       body: Container(
//         child: SafeArea(
//           child: Stack(
//             children: [
//               Container(
//                 height: MediaQuery.of(context).size.height,
//                 width: MediaQuery.of(context).size.width,
//                 child: Image.asset(
//                   'assets/background/img_chat.png',
//                   color: blanco.withOpacity(0.05),
//                   fit: BoxFit.cover,
//                 ),
//               ),
//               // Column(
//               //   children: [
//               //     Flexible(
//               //       child: ListView.builder(
//               //         physics: BouncingScrollPhysics(),
//               //         itemCount: _messages.length,
//               //         itemBuilder: (_, i) => GestureDetector(
//               //           child: Container(
//               //             margin: EdgeInsets.only(top: 2),
//               //             decoration: BoxDecoration(
//               //               color: (_selectedItems.contains(i))
//               //                   ? blanco.withOpacity(0.5)
//               //                   : transparente,
//               //             ),
//               //             child: _messages[i],
//               //           ),
//               //           onLongPress: () {
//               //             if (!_selectedItems.contains(i)) {
//               //               setState(() {
//               //                 _selectedItems.add(i);
//               //                 _mensajeSelected.add(_messages[i]);
//               //               });
//               //             }
//               //           },
//               //           onTap: () {
//               //             if (_selectedItems.isNotEmpty) {
//               //               if (!_selectedItems.contains(i)) {
//               //                 setState(() {
//               //                   _selectedItems.add(i);
//               //                   _mensajeSelected.add(_messages[i]);
//               //                 });
//               //               } else {
//               //                 setState(() {
//               //                   _selectedItems.removeWhere((val) => val == i);
//               //                   _mensajeSelected.remove(_messages[i]);
//               //                 });
//               //               }
//               //             }
//               //           },
//               //         ),
//               //         reverse: true,
//               //       ),
//               //     ),
//               //     Container(
//               //       margin: EdgeInsets.all(5),
//               //       child: _cargando
//               //           ? LinearProgressIndicator(
//               //               minHeight: 5,
//               //               value: _carga > 0 ? _carga : null,
//               //               backgroundColor: transparente,
//               //               valueColor: AlwaysStoppedAnimation(amarillo),
//               //             )
//               //           : SizedBox(),
//               //     ),
//               //     esMiembro
//               //         ? _inputChatBar()
//               //         : Container(
//               //             width: MediaQuery.of(context).size.width,
//               //             padding: EdgeInsets.all(15),
//               //             decoration: BoxDecoration(
//               //               color: blanco.withOpacity(0.5),
//               //             ),
//               //             child: Text(AppLocalizations.of(context)!
//               //                 .translate('CANT_SEND_MESSAGES')),
//               //           )
//               //   ],
//               // ),

//               Consumer<AuthService>(builder: (context, provider, _) {
//                 return Column(
//                   children: [
//                     Flexible(
//                       child: ListView.builder(
//                         physics: BouncingScrollPhysics(),
//                         itemCount: _messages.length,
//                         itemBuilder: (_, i) => GestureDetector(
//                           child: Container(
//                             margin: EdgeInsets.only(top: 2),
//                             decoration: BoxDecoration(
//                               color: (_selectedItems.contains(i))
//                                   ? blanco.withOpacity(0.5)
//                                   : transparente,
//                             ),
//                             child: Visibility(
//                               visible:
//                                   _messages[i].uid == authService!.usuario!.uid,
//                               replacement: SwipeTo(
//                                 child: _messages[i],
//                                 onRightSwipe: (test) {
//                                   setState(() {
//                                     _messagetoReply = _messages[i];
//                                   });
//                                   print(
//                                       '-----------onLeftSwipe mmmmmmmmm-----------------');
//                                 },
//                               ),
//                               child: SwipeTo(
//                                 child: _messages[i],
//                                 onLeftSwipe: (test) {
//                                   setState(() {
//                                     _messagetoReply = _messages[i];
//                                   });
//                                   print(
//                                       "------------onRightSwipe-----------------");
//                                 },
//                               ),
//                             ),
//                           ),
//                           onLongPress: () {
//                             if (!_selectedItems.contains(i)) {
//                               setState(() {
//                                 _selectedItems.add(i);
//                                 _mensajeSelected.add(_messages[i]);
//                               });
//                             }
//                           },
//                           onTap: () {
//                             if (_selectedItems.isNotEmpty) {
//                               if (!_selectedItems.contains(i)) {
//                                 setState(() {
//                                   _selectedItems.add(i);
//                                   _mensajeSelected.add(_messages[i]);
//                                 });
//                               } else {
//                                 setState(() {
//                                   _selectedItems.removeWhere((val) => val == i);
//                                   _mensajeSelected.remove(_messages[i]);
//                                 });
//                               }
//                             }
//                           },
//                         ),
//                         reverse: true,
//                       ),
//                     ),
//                     provider.cargando ? buildCardago() : buildNotCardago(),
//                     esMiembro
//                         ? _inputChatBar()
//                         : Container(
//                             width: MediaQuery.of(context).size.width,
//                             padding: EdgeInsets.all(15),
//                             decoration: BoxDecoration(
//                               color: blanco.withOpacity(0.5),
//                             ),
//                             child: Text(AppLocalizations.of(context)!
//                                 .translate('CANT_SEND_MESSAGES')),
//                           ),
//                   ],
//                 );
//               }),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   buildCardago() {
//     if (mounted) reRender = true;

//     return LinearProgressIndicator(
//       minHeight: 5,
//       value: _carga > 0 ? _carga : null,
//       backgroundColor: transparente,
//       valueColor: AlwaysStoppedAnimation(amarillo),
//     );
//   }

//   buildNotCardago() {
//     if (reRender) _cargarHistorial(grupoPara!.codigo!);

//     reRender = false;

//     return _cargando
//         ? LinearProgressIndicator(
//             minHeight: 5,
//             value: _carga > 0 ? _carga : null,
//             backgroundColor: transparente,
//             valueColor: AlwaysStoppedAnimation(amarillo),
//           )
//         : SizedBox();
//   }

//   Widget buildReply() => Container(
//         padding: EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: Colors.grey.withOpacity(0.2),
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(12),
//             topRight: Radius.circular(24),
//           ),
//         ),
//         child: ReplyMessageWidget(
//           username: _messagetoReply!.emisor!,
//           type: _messagetoReply!.type!,
//           message: _messagetoReply!.texto!,
//           onCancelReply: () {
//             _messagetoReply = null;
//             setState(() {});
//             print("shiiiiiiiiiit");
//           },
//         ),
//       );

//   Widget _inputChatBar() {
//     return Container(
//       height: _messagetoReply != null
//           ? MediaQuery.of(context).size.height * 0.16
//           : MediaQuery.of(context).size.height * 0.06,
//       padding: const EdgeInsets.only(top: 5, left: 10, right: 10, bottom: 5),
//       decoration: BoxDecoration(
//         color: blanco,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(5),
//           topRight: Radius.circular(5),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           if (_messagetoReply != null)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 5.0),
//               child: buildReply(),
//             ),
//           Align(
//             alignment: Alignment.center,
//             child: Row(
//               children: [
//                 !_isRecording
//                     ? CustomPopupMenu(
//                         showArrow: false,
//                         verticalMargin: Platform.isAndroid
//                             //  -MediaQuery.of(context).size.height * 0.35,
//                             ? 5
//                             : 0,
//                         barrierColor: transparente,
//                         pressType: PressType.singleClick,
//                         controller: _controller,
//                         menuBuilder: () => ClipRRect(
//                           borderRadius: BorderRadius.circular(2),
//                           child: Container(
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(25),
//                               color: azul,
//                             ),
//                             child: IntrinsicWidth(
//                                 child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.stretch,
//                               children: [
//                                 btnPopUpMenu(
//                                   Icons.camera_alt_rounded,
//                                   accion: 1,
//                                 ),
//                                 btnPopUpMenu(
//                                   Icons.videocam_rounded,
//                                   accion: 2,
//                                 ),
//                                 btnPopUpMenu(
//                                   Icons.attach_file_rounded,
//                                   accion: 3,
//                                 )
//                               ],
//                             )),
//                           ),
//                         ),
//                         child: Container(
//                           padding: const EdgeInsets.all(2),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(30),
//                             border: Border.all(color: gris),
//                           ),
//                           child: Icon(
//                             Icons.add,
//                             color: gris,
//                             size: 20,
//                           ),
//                         ),
//                       )
//                     : GestureDetector(
//                         child: Container(
//                           padding: const EdgeInsets.all(5),
//                           decoration: BoxDecoration(
//                             color: rojo,
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                           child: Icon(
//                             Icons.delete,
//                             color: blanco,
//                             size: 20,
//                           ),
//                         ),
//                         onTap: () {
//                           _cancelRecording();
//                         }),
//                 const SizedBox(width: 10),
//                 Flexible(
//                   child: Container(
//                     padding: const EdgeInsets.all(2),
//                     decoration: BoxDecoration(
//                       color: blanco.withOpacity(0.8),
//                       borderRadius: BorderRadius.circular(30),
//                       border: Border.all(color: gris),
//                     ),
//                     child: _isRecording
//                         ? SizedBox(
//                             height: 9,
//                             width: MediaQuery.of(context).size.width * 0.8,
//                             child: Cronometro(),
//                           )
//                         : TextField(
//                             textInputAction: TextInputAction.send,
//                             keyboardType: TextInputType.multiline,
//                             minLines: 1,
//                             maxLines: 5,
//                             style: TextStyle(
//                               fontWeight: FontWeight.normal,
//                               color: negro,
//                               fontSize: 18,
//                             ),
//                             controller: _textController,
//                             onSubmitted: _handleSubmit,
//                             onChanged: (texto) {
//                               setState(() {
//                                 if (texto.trim().isNotEmpty) {
//                                   _estaEscribiendo = true;
//                                 } else {
//                                   _estaEscribiendo = false;
//                                 }
//                               });
//                             },
//                             decoration: InputDecoration.collapsed(
//                               hintText: AppLocalizations.of(context)!
//                                   .translate('SEND_MESSAGE'),
//                               hintStyle: TextStyle(
//                                 fontWeight: FontWeight.normal,
//                                 color: gris,
//                                 fontSize: 18,
//                               ),
//                             ),
//                             focusNode: _focusNode,
//                           ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 !_estaEscribiendo
//                     ? GestureDetector(
//                         child: Container(
//                           padding: const EdgeInsets.all(2),
//                           decoration: BoxDecoration(
//                             color: azul,
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                           child: Icon(
//                             !_isRecording
//                                 ? Icons.mic
//                                 : Icons.double_arrow_rounded,
//                             color: blanco,
//                             size: 20,
//                           ),
//                         ),
//                         onTap: () {
//                           _isRecording ? _stopRecording() : _startRecording();
//                         })
//                     : GestureDetector(
//                         child: Container(
//                           padding: const EdgeInsets.all(5),
//                           decoration: BoxDecoration(
//                             color: azul,
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                           child: Icon(
//                             Icons.double_arrow_rounded,
//                             color: blanco,
//                             size: 20,
//                           ),
//                         ),
//                         onTap: () => _estaEscribiendo
//                             ? _handleSubmit1(
//                                 _textController.text.trim(),
//                               )
//                             : null),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /*
//     * Envia mensaje de texto
//   */
//   _handleSubmit1(String texto, {String type = 'text'}) {
//     String mifecha = deconstruirDateTime();
//     _selectedItems.clear();
//     if (texto.length == 0) return;

//     _textController.clear();
//     _focusNode.requestFocus();

//     final newMessage = ChatMessage(
//       selected: false,
//       deleted: false,
//       uid: usuario!.uid!,
//       texto: texto,
//       hora: DateTime.now().toString(),
//       type: type,
//       isReply: _messagetoReply != null,
//       parentmessage: _messagetoReply != null ? _messagetoReply!.texto : null,
//       parenttype: _messagetoReply != null ? _messagetoReply!.type : null,
//       username: _messagetoReply != null && _messagetoReply!.uid == usuario!.uid!
//           ? usuario!.nombre
//           : _messagetoReply != null
//               ? _messagetoReply!.emisor!
//               : null,
//       forwarded: false,
//       fecha: mifecha,
//       incognito: _incognito,
//       enviado: _enviado,
//       recibido: _recibido,
//     );
//     var msg;
//     _messagetoReply == null
//         ? msg = null
//         : msg = {
//             'messageType': _messagetoReply!.type,
//             'messageContent': _messagetoReply!.texto,
//             'parentSender':
//                 _messagetoReply != null && _messagetoReply!.uid == usuario!.uid!
//                     ? usuario!.nombre
//                     : _messagetoReply != null
//                         ? _messagetoReply!.emisor!
//                         : null,
//           };
//     persistMessajeLocal(type, texto, mifecha, '', msg);

//     setState(() {
//       _messages.insert(0, newMessage);

//       _estaEscribiendo = false;
//     });

//     var event = "mensaje-grupal";

//     var data = {
//       'de': usuario!.uid,
//       'para': grupoPara!.codigo!,
//       'incognito': _incognito,
//       'forwarded': false,
//       'reply': _messagetoReply != null,
//       'parentType': _messagetoReply != null ? _messagetoReply!.type : null,
//       'parentContent': _messagetoReply != null ? _messagetoReply!.texto : null,
//       'parentSender':
//           _messagetoReply != null && _messagetoReply!.uid == usuario!.uid
//               ? usuario!.nombre
//               : _messagetoReply != null
//                   ? _messagetoReply!.emisor!
//                   : null,
//       'mensaje': {
//         'type': type,
//         'content': texto,
//         'fecha': mifecha + 'Z' + utc,
//       },
//     };
//     print('---------------------data------------------------');
//     print(data);
//     print("--------------------------data -------------------");
//     // this.socketService.emit('mensaje-personal', data);
//     print("fuuuuuuck");

//     this.socketService!.emitAck(event, data, ack: (ack) {
//       print("(((((((((((((((((((((((((((((ack)))))))))))))))))))))))))))))");
//       recibidoServidor(ack, data);
//     });
//     print("done");
//     setState(() {
//       _messagetoReply = null;
//     });
//     if (!mounted) return;
//   }

//   /*
//     * Envia mensaje de texto
//   */
//   _handleSubmit(String texto, {String type = 'text'}) {
//     String mifecha = deconstruirDateTime();
//     _selectedItems.clear();
//     if (texto.length == 0) return;

//     _textController.clear();
//     _focusNode.requestFocus();

//     final newMessage = ChatMessage(
//       selected: false,
//       uid: usuario!.uid!,
//       deleted: false,
//       texto: texto,
//       hora: new DateTime.now().toString(),
//       type: type,
//       isReply: _messagetoReply != null,
//       parentmessage: _messagetoReply != null ? _messagetoReply!.texto : null,
//       parenttype: _messagetoReply != null ? _messagetoReply!.type : null,
//       username: usuario!.nombre,
//       forwarded: false,
//       fecha: mifecha,
//       incognito: _incognito,
//       enviado: _enviado,
//       recibido: _recibido,
//     );

//     var msg;
//     _messagetoReply == null
//         ? msg = null
//         : msg = {
//             'messageType': _messagetoReply!.type,
//             'messageContent': _messagetoReply!.texto,
//             'parentSender': _messagetoReply!.emisor
//           };

//     persistMessajeLocal(type, texto, mifecha, '', msg);

//     _messages.insert(0, newMessage);

//     setState(() {
//       _estaEscribiendo = false;
//     });

//     var event = "mensaje-grupal";
//     var data = {
//       'de': usuario!.uid!,
//       'para': grupoPara!.codigo!,
//       'incognito': _incognito,
//       'forwarded': false,
//       'reply': _messagetoReply != null,
//       'parentType': _messagetoReply != null ? _messagetoReply!.type : null,
//       'parentContent': _messagetoReply != null ? _messagetoReply!.texto : null,
//       'parentSender': _messagetoReply != null ? _messagetoReply!.emisor : null,
//       'mensaje': {
//         'type': type,
//         'content': texto,
//         'fecha': mifecha + 'Z' + utc,
//       },
//     };
//     print(data);

//     // this.socketService.emit('mensaje-personal', data);

//     this.socketService!.emitAck(event, data, ack: (ack) async {
//       recibidoServidor(ack, data);
//     });
//     setState(() {
//       _messagetoReply = null;
//     });

//     if (!mounted) return;
//   }

//   /*
//     * Captura imagen de la camara
//     * Envia mensaje de imagen
//   */
//   takePhoto() async {
//     try {
//       final ImagePicker _picker = ImagePicker();
//       XFile? pickedFile = await _picker.pickImage(
//         source: ImageSource.camera,
//         imageQuality: 50,
//       );
//       File image = File(pickedFile!.path);
//       List<File> result = [];
//       result.add(image);
//       createMessage(result: result);
//     } catch (e) {
//       print(e);
//     }
//   }

//   /*
//     * Captura video de la camara
//     * Envia mensaje de video
//   */
//   takeVideo() async {
//     try {
//       ImagePicker _picker = ImagePicker();
//       XFile? pickedFile = await _picker.pickVideo(
//         source: ImageSource.camera,
//         maxDuration: Duration(seconds: 30),
//       );
//       File video = File(pickedFile!.path);
//       List<File> result = [];
//       result.add(video);
//       createMessage(result: result);
//     } catch (e) {
//       print(e);
//     }
//   }

//   /*
//     * Inicia la grabacion de audio
//   */

//   _startRecording() async {
//     print('--==_startRecording==--');
//     String mifecha = deconstruirDateTime();

//     var status = await Permission.microphone.request();

//     if (status.isGranted) {
//       bool isRecording;
//       String path = '';
//       Directory appDocDirectory = await getApplicationDocumentsDirectory();
//       path = appDocDirectory.path + '/' + mifecha;
//       flutterSound.setLogLevel(Level.error);
//       print(
//           "----------------------------1------------------------------------");
//       // await flutterSound.startRecorder();

//       print(
//           "-----------------------------2-----------------------------------");

//       await flutterSound.startRecorder(
//           codec: Codec.aacMP4, toFile: '$path.aac');
//       print(
//           "----------------------------------3------------------------------");
//       await flutterSound.setSubscriptionDuration(
//         const Duration(milliseconds: 100),
//       );
//       flutterSound.onProgress!.listen((e) {
//         print("listenr is set on recorder");
//         var date = DateTime.fromMillisecondsSinceEpoch(
//             e.duration.inMilliseconds,
//             isUtc: true);
//         //var txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
//         print(e.duration);
//         setState(() {
//           deration = e.duration.toString();
//         });

//         // setState(() {
//         //   recorderTxt = txt.substring(0, 8);
//         // });
//       });
//       print(
//           "---------------------------4-------------------------------------");
//       // await _recorder.initialized;
//       // await _recorder.start();
//       //  var recording = await _recorder.current(channel: 0);

//       isRecording = flutterSound.isRecording;

//       setState(() {
//         _isRecording = isRecording;
//       });
//     } else {
//       showToast(
//           context,
//           AppLocalizations.of(context)!
//               .translate('NO_PERMISION_FOR_MICROPHONE'),
//           amarillo,
//           Icons.warning_amber_rounded);
//     }
//   }

//   /*
//     * Detiene la grabacion de audio
//     * Envia mensaje de audio
//   */
//   _stopRecording() async {
//     print('--==_stopRecording==--');
//     bool isRecording;
//     File file;
//     List<File> result = [];

//     var duracion;

//     var recording = await flutterSound.stopRecorder();
//     print("------------------------------5---------------------------------");
//     //await flutterSound.closeRecorder();
//     print("----------------------------------6------------------------------");

//     print("-------------------------------7---------------------------------");
//     print('--==_stopRec${deration}o----------------------------ing==--');
//     var tiempo = deration;
//     duracion = (tiempo.toString().split('.')[0]).split(':')[1] +
//         ':' +
//         (tiempo.toString().split('.')[0]).split(':')[2];
//     file = strtoFile(recording!);
//     print("-------------------------------7---------------------------------");
//     isRecording = flutterSound.isRecording;

//     setState(() {
//       _isRecording = isRecording;
//       deration = null;
//     });

//     result.add(file);
//     createMessage(result: result, value: duracion);
//   }

//   /*
//     * Cancela la grabacion de audio
//   */
//   _cancelRecording() async {
//     bool isRecording;

//     var recording = await flutterSound.stopRecorder();

//     isRecording = flutterSound.isRecording;

//     setState(() {
//       _isRecording = isRecording;
//     });
//   }

//   /*
//     * Abre la carpeta de archivos del telefono
//     * Envia archivos seleccionados
//   */
//   searchFiles() async {
//     try {
//       FilePickerResult? fresult = await FilePicker.platform.pickFiles();
//       List<File> result = [];

//       if (fresult != null) {
//         result = fresult.paths.map((path) => File(path!)).toList();
//       }

//       if (result.length > 0) createMessage(result: result);

//       if (!mounted) return 'error';
//     } on Exception catch (e) {
//       print(e);
//     }
//   }

//   emitirAcuseRecibo(payload) {
//     this.socketService!.emit("recibido-cliente", {
//       "de": payload["para"],
//       "para": payload["de"],
//       "mensaje": payload["mensaje"],
//       "forwarded": payload["forwarded"],
//       "reply": payload["reply"],
//       "parentType": payload["reply"],
//       "parentSender": payload["parentSender"],
//       "parentContent": payload["parentContent"],
//     });
//   }

//   _recibirAcuse(payload) {
//     if (mounted) {
//       _messages[0].enviado = true;
//       _messages[0].recibido = true;
//       setState(() {});
//     }
//   }

//   /*
//     * Guarda mensaje
//     * Envia archivos seleccionados
//   */
//   persistMessajeLocal(type, content, datefecha, ext, replymsg) {
//     print('persist mensaje-grupal en chat_page');
//     if (!_incognito) {
//       var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
//           [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);
//       Mensaje mensajeLocal = Mensaje(deleted: false);
//       mensajeLocal.mensaje = jsonEncode({
//         'type': type,
//         'content': content,
//         'fecha': datefecha,
//         'extension': ext
//       });
//       if (replymsg != null) {
//         mensajeLocal.isReply = true;
//         mensajeLocal.parentContent = replymsg['messageContent'];
//         mensajeLocal.parentType = replymsg['messageType'];
//         mensajeLocal.parentSender = replymsg['parentSender'];
//       }

//       mensajeLocal.de = usuario!.uid;
//       mensajeLocal.para = grupoPara!.codigo;
//       mensajeLocal.createdAt = fechaActual;
//       mensajeLocal.updatedAt = fechaActual;
//       mensajeLocal.uid = grupoPara!.codigo;
//       mensajeLocal.nombreEmisor = usuario!.nombre;
//       DBProvider.db.nuevoMensaje(mensajeLocal);
//     }
//     Grupo grupoNuevo = new Grupo();
//     grupoNuevo.nombre = grupoPara!.nombre;
//     grupoNuevo.avatar = grupoPara!.avatar;
//     grupoNuevo.codigo = grupoPara!.codigo;
//     grupoNuevo.descripcion = grupoPara!.descripcion;
//     grupoNuevo.fecha = grupoPara!.fecha;
//     grupoNuevo.privateKey = grupoPara!.privateKey;
//     grupoNuevo.publicKey = grupoPara!.publicKey;
//     grupoNuevo.usuarioCrea = grupoPara!.usuarioCrea;
//     DBProvider.db.nuevoGrupo(grupoNuevo);
//   }

//   /*
//     * Guarda los archivos
//     * @return file.path (Ubicacion del archivo en el dispositivo)
//   */
//   saveFile(ext, dataEncode, datafecha) async {
//     final decodedBytes = base64Decode(dataEncode);
//     String dir = (await getApplicationDocumentsDirectory()).path;

//     File file = File("$dir/" + datafecha + ext);
//     await file.writeAsBytes(decodedBytes);
//     return file.path;
//   }

//   eliminarMensajesChat() async {
//     final res = await DBProvider.db.deleteMensajesByMenseje(_mensajeSelected);
//     if (res != 0) {
//       showToast(
//           context,
//           _selectedItems.length > 1
//               ? _selectedItems.length.toString() +
//                   ' ' +
//                   AppLocalizations.of(context)!.translate('MESSAGES_DELETED')
//               : capitalize(
//                   AppLocalizations.of(context)!.translate('MESSAGE_DELETED')),
//           verde,
//           Icons.check);
//       _cargarHistorial(grupoPara!.codigo!);
//       _selectedItems.clear();
//       _mensajeSelected.clear();
//     }
//   }

//   eliminarParaTodos() {
//     _mensajeSelected.forEach((element) {
//       this.socketService!.emit(
//         'eliminar-para-todos',
//         {
//           'de': usuario!.uid!,
//           'para': grupoPara!.codigo!,
//           'mensaje': {
//             'texto': element.texto,
//             'fecha': element.fecha,
//             'type': element.type,
//             'ext': element.exten,
//           },
//         },
//       );
//     });
//   }

//   Widget btnEliminar(String texto, bool accion) {
//     return new SizedBox.fromSize(
//       size: Size(100, 40),
//       child: Material(
//         borderRadius: BorderRadius.circular(40),
//         color: amarilloClaro,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(40),
//           splashColor: amarillo,
//           child: Center(
//             child: Text(texto),
//           ),
//           onTap: () {
//             Navigator.pop(context);
//             eliminarMensajesChat();
//             if (accion) {
//               eliminarParaTodos();
//             }
//           },
//         ),
//       ),
//     );
//   }

//   Widget btnPopUpMenu(IconData icono, {required int accion}) {
//     return GestureDetector(
//       behavior: HitTestBehavior.translucent,
//       onTap: () {
//         _controller.hideMenu();
//         switch (accion) {
//           case 1:
//             takePhoto();
//             break;
//           case 2:
//             takeVideo();
//             break;
//           case 3:
//             searchFiles();
//             break;
//         }
//       },
//       child: Container(
//         padding: EdgeInsets.all(15),
//         child: Icon(
//           icono,
//           size: 35,
//           color: blanco,
//         ),
//       ),
//     );
//   }

//   getGroups() async {
//     esMiembro = false;
//     var res = await usuarioService.getListGroup(usuario!.uid);
//     if (res.length > 0) {
//       var i;
//       for (i = 0; i < res.length; i++) {
//         var grupo = res[i];
//         // var grupo = element['grupo'];
//         if (grupo.codigo == grupoPara!.codigo) {
//           esMiembro = true;
//           break;
//         }
//       }
//     }
//     // res.forEach((element) {
//     //   var grupo = element['grupo'];
//     //   if (grupo['codigo'] == grupoPara.codigo) {
//     //     esMiembro = true;
//     //   }
//     // });
//     print("esMiembroesMiembro::" + esMiembro.toString());
//     if (!esMiembro) {
//       await DBProvider.db.deleteGroup(grupoPara!.codigo);
//       if (mounted)
//         setState(() {
//           esMiembro = false;
//         });
//     }
//   }

//   recibidoServidor(ack, data) async {
//     if (ack == "RECIBIDO_SERVIDOR") {
//       await DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
//       if (mounted) {
//         setState(() {
//           print("heloo");
//           _messages[0].enviado = true;
//           ChatMessage toreplace = _messages[0];
//           ChatMessage unique = ChatMessage(
//             deleted: false,
//             selected: false,
//             key: UniqueKey(),
//             texto: _messages[0].texto,
//             type: _messages[0].type,
//             fecha: _messages[0].fecha,
//             hora: _messages[0].hora,
//             enviado: true,
//             forwarded: _messages[0].forwarded,
//             parentmessage: _messages[0].parentmessage,
//             parenttype: _messages[0].parenttype,
//             isReply: _messages[0].isReply,
//             username: _messages[0].username,
//             recibido: _messages[0].recibido,
//             uid: _messages[0].uid,
//             dir: _messages[0].dir,
//             exten: _messages[0].exten,
//             emisor: _messages[0].emisor,
//             incognito: _messages[0].incognito,
//             cargando: _messages[0].cargando,
//           );
//           _messages.removeAt(0);
//           _messages.insert(0, unique);
//           print("ACK RECIBIDO_SERVIDOR::");
//           print("ACK RECIBIDO_SERVIDOR::");
//           _messages[0].enviado = true;
//         });
//       }
//     }
//   }

//   createMessage({List<File>? result, String? value}) {
//     if (result != null && result.isNotEmpty) {
//       setState(() {
//         _cargando = true;
//       });
//       authService!
//           .cargarArchivo(
//               result: result,
//               esGrupo: true,
//               grupoPara: grupoPara!,
//               incognito: _incognito,
//               enviado: _enviado,
//               recibido: _recibido,
//               animacion: AnimationController(
//                   vsync: this, duration: Duration(milliseconds: 100)),
//               utc: utc,
//               val: value)
//           .then((newMessage) {
//         if (mounted)
//           setState(() {
//             _messages.insert(0, newMessage!);

//             _cargando = false;
//           });
//       });
//     } else {
//       setState(() {
//         _cargando = false;
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _onChatGrupoPageStateOFF();
//     super.dispose();
//   }
// }
