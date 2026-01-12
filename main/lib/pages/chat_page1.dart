// import 'dart:async';
// import 'dart:io';
// import 'dart:convert';
// import 'dart:math';

// import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
// import 'package:date_format/date_format.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:image_picker/image_picker.dart';

// import 'package:file_picker/file_picker.dart';
// // import 'package:flutter_sound/flutter_sound.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:logger/logger.dart';

// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';

// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:swipe_to/swipe_to.dart';
// //import 'package:sound_recorder/sound_recorder.dart';
// import 'package:CryptoChat/global/AppLocalizations.dart';

// import 'package:CryptoChat/helpers/funciones.dart';
// import 'package:CryptoChat/helpers/style.dart';

// import 'package:CryptoChat/models/mensajes_response.dart';
// import 'package:CryptoChat/models/usuario.dart';
// import 'package:CryptoChat/pages/forwardeTo.dart';

// import 'package:CryptoChat/pages/usuario_page.dart';
// import 'package:CryptoChat/providers/db_provider.dart';

// import 'package:CryptoChat/services/auth_service.dart';
// import 'package:CryptoChat/services/chat_service.dart';
// import 'package:CryptoChat/services/socket_service.dart';

// import 'package:CryptoChat/widgets/cronometro.dart';
// import 'package:CryptoChat/widgets/chat_message.dart';
// import 'package:CryptoChat/widgets/mostrar_alerta.dart';
// import 'package:CryptoChat/widgets/replymsg.dart';
// import 'package:CryptoChat/widgets/toast_message.dart';

// class ChatPage extends StatefulWidget {
//   @override
//   _ChatPageState createState() => _ChatPageState();
// }

// class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
//   final _textController = new TextEditingController();
//   final _focusNode = new FocusNode();

//   ChatService? chatService;
//   SocketService? socketService;
//   AuthService? authService;

//   Usuario? usuario;
//   Usuario? usuarioPara;
//   String usuarioActual = "";
//   List<ChatMessage> _messages = [];
//   ChatMessage? _messagetoReply;
//   bool _estaEscribiendo = false;
//   bool _isRecording = false;
//   // FlutterSoundRecorder soundRecorder = new FlutterSoundRecorder();
//   //TO REPLACE
//   FlutterSoundRecorder flutterSound = new FlutterSoundRecorder();

//   CustomPopupMenuController _controller = CustomPopupMenuController();

//   Random random = new Random();
//   List<int> _selectedItems = [];
//   List<ChatMessage> _mensajeSelected = [];
//   bool soloMios = true;
//   bool esContacto = true;
//   bool _incognito = false;
//   bool _enviado = false;
//   bool _recibido = false;
//   String utc = DateTime.now().timeZoneName;
//   String? dirPath;
//   String? deration;
//   bool _cargando = false;
//   double carga = 0;

//   @override
//   void initState() {
//     this.authService = Provider.of<AuthService>(context, listen: false);
//     this.chatService = Provider.of<ChatService>(context, listen: false);

//     if (this.socketService == null)
//       this.socketService = Provider.of<SocketService>(context, listen: false);

//     //this.socketService!.socket!.on('mensaje-personal', _escucharMensaje);
//     this.socketService!.socket!.on('eliminar-para-todos', _escucharSolicitud);
//     this.socketService!.socket!.on('modo-incognito', _cambiarIncognito);
//     this.socketService!.socket!.on('recibido-cliente', _recibirAcuse);

//     this.usuario = authService!.usuario;
//     this.usuarioPara = chatService!.usuarioPara;
//     this.dirPath = authService!.localPath;

//     _cargarHistorial(usuarioPara!.uid!);
//     _onChatPageStateON();

//     this.socketService!.refreshDownloadFile();

//     super.initState();
//   }

//   void _cargarHistorial(String usuarioID) async {
//     _messages.clear();
//     usuarioActual = usuarioID;
//     var messajes = await DBProvider.db.getTodosMensajes(usuarioActual);
//     var res = await DBProvider.db.esContacto(usuarioActual);
//     esContacto = res != null ? true : false;
//     _incognito = res == 1 && res != null ? true : false;
//     final history = messajes.map((m) => ChatMessage(
//           selected: false,
//           deleted: false,
//           dir: dirPath!,
//           exten: jsonDecode(m.mensaje!)['extension'],
//           fecha: jsonDecode(m.mensaje!)['fecha'],
//           texto: jsonDecode(m.mensaje!)['content'],
//           type: jsonDecode(m.mensaje!)['type'],
//           isReply: m.isReply,
//           forwarded: m.forwarded,
//           parentmessage: m.parentContent,
//           parenttype: m.parentType,
//           username: m.parentSender,
//           hora: m.createdAt!,
//           incognito: m.incognito == 1 ? true : false,
//           enviado: m.enviado == 1 ? true : false,
//           recibido: m.recibido == 1 ? true : false,
//           uid: m.de!,
//         ));

//     if (mounted)
//       setState(() {
//         _messages.insertAll(0, history);
//       });
//   }

//   void _cambiarIncognito(dynamic payload) async {
//     var de = payload['de'];
//     if (de == usuarioPara!.uid) {
//       var value = payload['incognito'];
//       setState(() {
//         _incognito = value;
//       });
//     }
//   }

//   void _escucharSolicitud(dynamic payload) async {
//     print('Eliminando en ChatPage');
//     if (payload['mensaje'] != null) {
//       var texto = payload['mensaje']['texto'];
//       var fecha = payload['mensaje']['fecha'];
//       var type = payload['mensaje']['type'];
//       var exte = payload['mensaje']['ext'];
//       var uid = payload['de'];
//       _messages.removeWhere((element) =>
//           element.uid == uid &&
//           element.texto == texto &&
//           element.fecha == fecha &&
//           element.type == type &&
//           element.exten == exte);
//       // _cargarHistorial(usuarioPara.uid);
//       if (mounted) setState(() {});
//     } else {
//       if (mounted)
//         setState(() {
//           esContacto = false;
//         });
//       _cargarHistorial(usuarioPara!.uid!);
//     }
//   }

//   void _escucharMensaje(dynamic payload) async {
//     // setState(() {
//     //   _cargarHistorial(usuarioPara!.uid!);
//     // });
//     ChatMessage message;
//     print('Recibiendo Mensaje en Chat Page');

//     print("-----------------------PlayLoad---------------------------");
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
//             deleted: false,
//             selected: false,
//             exten: exte,
//             texto: content,
//             fecha: fechaM,
//             type: type,
//             forwarded: payload['forwarded'],
//             isReply: payload['reply'],
//             parentmessage: payload['parentContent'],
//             parenttype: payload['parentType'],
//             username: payload['parentSender'],
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
//         selected: false,
//         deleted: false,
//         dir: dirPath,
//         exten: exte,
//         texto: content,
//         fecha: fechaM,
//         type: type,
//         forwarded: payload['forwarded'],
//         isReply: payload['reply'],
//         parentmessage: payload['parentContent'],
//         parenttype: payload['parentType'],
//         username: payload['parentSender'],
//         incognito: incognito,
//         enviado: false,
//         recibido: false,
//         hora: new DateTime.now().toString(),
//         uid: payload['de'],
//       );
//       if (_descarga == '100%') {
//         if (mounted)
//           setState(() {
//             _messages.insert(0, message);
//           });
//       }
//       print('Descarga: $_descarga');
//       print('Descargando: $_descar');

//       if (type == "text") {
//         if (mounted)
//           setState(() {
//             _messages.insert(0, message);
//           });
//       } else if (_descarga == '100.0') {
//         if (mounted)
//           setState(() {
//             _messages.insert(0, message);
//           });
//       }

//       emitirAcuseRecibo(payload);
//     }
//   }

//   _onChatPageStateON() async {
//     var prefs = await SharedPreferences.getInstance();
//     prefs.setString('ChatPage', 'connectChat');
//   }

//   _onChatPageStateOFF() async {
//     var prefs = await SharedPreferences.getInstance();
//     prefs.setString('ChatPage', 'disconnectChat');
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
//                           capitalize(usuarioPara!.nombre!),
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
//                                 getAvatar(usuarioPara!.avatar!, "user_")),
//                             backgroundColor: blanco,
//                             maxRadius: 20,
//                           ),
//                         ),
//                       ],
//                     )),
//                 onTap: () {
//                   if (esContacto) {
//                     Navigator.of(context)
//                         .push(MaterialPageRoute(
//                             builder: (context) => UsuarioPage(usuarioPara!)))
//                         .then((res) {
//                       print(res);
//                       if (res == 'vaciar') {
//                         setState(() {
//                           _messages.clear();
//                         });
//                       } else {
//                         _cargarHistorial(usuarioPara!.uid!);
//                       }
//                     });

//                     // _cargarHistorial(usuarioPara.uid);
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
//                           validarMensajesMios();
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
//                                   SizedBox(width: 10),
//                                   soloMios
//                                       ? btnEliminar(
//                                           AppLocalizations.of(context)!
//                                               .translate('FOR_EVERYONE'),
//                                           true)
//                                       : SizedBox(),
//                                 ],
//                               ),
//                               'CANCEL');
//                         }),
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
//               _incognito
//                   ? Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Container(
//                           padding: EdgeInsets.all(10),
//                           decoration: BoxDecoration(
//                               color: azul.withOpacity(0.4),
//                               borderRadius: BorderRadius.circular(20)),
//                           child: Text(
//                             AppLocalizations.of(context)!
//                                 .translate('HIDDEN_MODE'),
//                           ),
//                         ),
//                       ],
//                     )
//                   : SizedBox(),
//               // this.socketService.descargando
//               //     ? Row(
//               //         mainAxisAlignment: MainAxisAlignment.center,
//               //         children: [
//               //           Container(
//               //             padding: EdgeInsets.all(10),
//               //             decoration: BoxDecoration(
//               //                 color: azul.withOpacity(0.4),
//               //                 borderRadius: BorderRadius.circular(20)),
//               //             child: Text(
//               //               this.socketService.porcentajeDescarga,
//               //             ),
//               //           ),
//               //         ],
//               //       )
//               //     : SizedBox(),
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
//                     esContacto
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
//       value: carga > 0 ? carga : null,
//       backgroundColor: transparente,
//       valueColor: AlwaysStoppedAnimation(amarillo),
//     );
//   }

//   buildNotCardago() {
//     if (reRender) _cargarHistorial(usuarioPara!.uid!);

//     reRender = false;

//     return _cargando
//         ? LinearProgressIndicator(
//             minHeight: 5,
//             value: carga > 0 ? carga : null,
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
//           username: usuarioPara!.nombre!,
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
//           : MediaQuery.of(context).size.height * 0.08,
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
//                             height: 15,
//                             width: MediaQuery.of(context).size.width * 0.8,
//                             child: Cronometro(),
//                           )
//                         : TextField(
//                             textInputAction: TextInputAction.send,
//                             keyboardType: TextInputType.multiline,
//                             minLines: 1,
//                             maxLines: 1,
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
//                             ? _handleSubmit(
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
//   _handleSubmit(String texto, {String type = 'text'}) {
//     String mifecha = deconstruirDateTime();
//     _selectedItems.clear();
//     if (texto.length == 0) return;

//     _textController.clear();
//     _focusNode.requestFocus();

//     final newMessage = ChatMessage(
//       uid: usuario!.uid!,
//       deleted: false,
//       selected: false,
//       texto: texto,
//       hora: DateTime.now().toString(),
//       type: type,
//       isReply: _messagetoReply != null,
//       parentmessage: _messagetoReply != null ? _messagetoReply!.texto : null,
//       parenttype: _messagetoReply != null ? _messagetoReply!.type : null,
//       username: _messagetoReply != null && _messagetoReply!.uid == usuario!.uid!
//           ? usuario!.nombre
//           : usuarioPara!.nombre,
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
//                     : usuarioPara!.nombre
//           };
//     persistMessajeLocal(type, texto, mifecha, '', msg);

//     setState(() {
//       _messages.insert(0, newMessage);

//       _estaEscribiendo = false;
//     });

//     var event = "mensaje-personal";

//     var data = {
//       'de': usuario!.uid,
//       'para': usuarioPara!.uid,
//       'incognito': _incognito,
//       'forwarded': false,
//       'reply': _messagetoReply != null,
//       'parentType': _messagetoReply != null ? _messagetoReply!.type : null,
//       'parentContent': _messagetoReply != null ? _messagetoReply!.texto : null,
//       'parentSender':
//           _messagetoReply != null && _messagetoReply!.uid == usuario!.uid
//               ? usuario!.nombre
//               : usuarioPara!.nombre,
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
//   // TO REPLACE{
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
//       // await flutterSound.openAudioSession(
//       //   mode: SessionMode.modeSpokenAudio,
//       //   focus:
//       //       AudioFocus.requestFocus, //requestFocus may be related to the issue
//       //   category: SessionCategory.playAndRecord,
//       // );
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
//       // List<File> result = await FilePicker.getMultiFile(
//       //     type: FileType.any,
//       //     // allowedExtensions: types,
//       //     allowCompression: true);
//       FilePickerResult? fresult = await FilePicker.platform.pickFiles();
//       List<File> result = [];

//       if (fresult != null) {
//         result = fresult.paths.map((path) => File(path!)).toList();
//       }

//       createMessage(result: result);

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
//     print('recibido.');
//     print(payload);
//     if (mounted) {
//       _messages[0].enviado = true;
//       _messages[0].recibido = true;
//       try {
//         setState(() {
//           // print(_messages.first.texto +
//           //     ' ::mounted:: ' +
//           //     _messages[0].recibido.toString());
//         });
//       } catch (e) {
//         print(e);
//       }
//     }
//     // _cargarHistorial(usuarioPara.uid);
//   }

//   /*
//    * Guarda mensaje
//    * Envia archivos seleccionados
//    */
//   persistMessajeLocal(type, content, datefecha, exte, replymsg) {
//     print('persist mensaje-personal en chat_page');
//     if (!_incognito) {
//       var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
//           [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);

//       Mensaje mensajeLocal = Mensaje(deleted: false);
//       mensajeLocal.mensaje = jsonEncode({
//         'type': type,
//         'content': content,
//         'fecha': datefecha,
//         'extension': exte
//       });
//       if (replymsg != null) {
//         mensajeLocal.isReply = true;
//         mensajeLocal.parentContent = replymsg['messageContent'];
//         mensajeLocal.parentType = replymsg['messageType'];
//         mensajeLocal.parentSender = replymsg['parentSender'];
//       }

//       mensajeLocal.de = usuario!.uid;
//       mensajeLocal.para = usuarioPara!.uid;
//       mensajeLocal.createdAt = fechaActual;
//       mensajeLocal.updatedAt = fechaActual;
//       mensajeLocal.uid = usuarioPara!.uid;
//       DBProvider.db.nuevoMensaje(mensajeLocal);
//     }

//     Usuario contactoNuevo = Usuario(publicKey: usuarioPara!.publicKey);
//     contactoNuevo.nombre = usuarioPara!.nombre;
//     contactoNuevo.avatar = usuarioPara!.avatar;
//     contactoNuevo.uid = usuarioPara!.uid;
//     contactoNuevo.online = usuarioPara!.online;
//     contactoNuevo.codigoContacto = usuarioPara!.codigoContacto;
//     contactoNuevo.email = usuarioPara!.email;
//     DBProvider.db.nuevoContacto(contactoNuevo);
//   }

//   /*
//    * Guarda los archivos
//    * @return file.path (Ubicacion del archivo en el dispositivo)
//    */
//   saveFile(ext, dataEncode, datafecha) async {
//     final decodedBytes = base64Decode(dataEncode);
//     String dir = (await getApplicationDocumentsDirectory()).path;

//     File file = File("$dir/" + datafecha + ext);
//     await file.writeAsBytes(decodedBytes);
//     return file.path;
//   }

//   createMessage({List<File>? result, String? value}) {
//     if (result != null && result.isNotEmpty) {
//       setState(() {
//         _cargando = true;
//       });
//       authService!
//           .cargarArchivo(
//               para: usuarioPara!.nombre,
//               messagetoReply: _messagetoReply,
//               result: result,
//               esGrupo: false,
//               userPara: usuarioPara!,
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
//       _cargarHistorial(usuarioPara!.uid!);
//       setState(() {});
//       _selectedItems.clear();
//       _mensajeSelected.clear();
//     }
//   }

//   eliminarParaTodos() {
//     _mensajeSelected.forEach((element) {
//       this.socketService!.emit(
//         'eliminar-para-todos',
//         {
//           'de': usuario!.uid,
//           'para': usuarioPara!.uid,
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

//   bool validarMensajesMios() {
//     soloMios = true;
//     _mensajeSelected.forEach((msj) {
//       if (msj.uid != usuario!.uid) {
//         setState(() {
//           soloMios = false;
//         });
//       }
//     });
//     return soloMios;
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

//   recibidoServidor(ack, data) async {
//     if (ack == "RECIBIDO_SERVIDOR") {
//       await DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);

//       // print(_messages[0].enviado);
//       ChatMessage toreplace = _messages[0];
//       // toreplace.key = UniqueKey()
//       // _messages[1].texto = "hello fuuck";
//       // if (_messages.length > 0) {
//       //   _messages[0] = toreplace;
//       // }
//       // print(_messages[0].texto);
//       setState(() {
//         // if (_messages.isNotEmpty) {
//         //   _messages.removeAt(0);
//         //   _messages.insert(0, toreplace);
//         // }
//         print("heloo");
//         _messages[0].enviado = true;
//         ChatMessage toreplace = _messages[0];
//         ChatMessage unique = ChatMessage(
//           key: UniqueKey(),
//           selected: false,
//           deleted: false,
//           texto: _messages[0].texto,
//           type: _messages[0].type,
//           fecha: _messages[0].fecha,
//           hora: _messages[0].hora,
//           enviado: true,
//           forwarded: _messages[0].forwarded,
//           parentmessage: _messages[0].parentmessage,
//           parenttype: _messages[0].parenttype,
//           isReply: _messages[0].isReply,
//           username: _messages[0].username,
//           recibido: _messages[0].recibido,
//           uid: _messages[0].uid,
//           dir: _messages[0].dir,
//           exten: _messages[0].exten,
//           emisor: _messages[0].emisor,
//           incognito: _messages[0].incognito,
//           cargando: _messages[0].cargando,
//         );
//         _messages.removeAt(0);
//         _messages.insert(0, unique);
//         print("ACK RECIBIDO_SERVIDOR::");
//       });
//       if (mounted) {
//         setState(() {});
//       }
//     }
//   }

//   @override
//   void dispose() {
//     DBProvider.db.eliminarIncognitos(usuarioPara!.uid);
//     _onChatPageStateOFF();
//     super.dispose();
//   }
// }
