import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/objPago.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/models/usuario_mensaje.dart';
import 'package:CryptoChat/pages/solicitudes_page.dart';

import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/providers/call_provider.dart';

import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/main.dart';
import 'package:CryptoChat/services/chat_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/services/telemetry_service.dart';
import 'package:CryptoChat/widgets/BlinkIcon.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/widgets/home/home_drawer_widget.dart';
import 'package:CryptoChat/widgets/home/chat_list_widget.dart';
import 'package:CryptoChat/widgets/home/welcome_overlay_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  SocketService? socketService;
  AuthService? authService;

  List<UsuarioMensaje> contactos = [];
  List<UsuarioMensaje> _findContacto = [];
  List<UsuarioMensaje> _allChats = [];
  bool _isLoading = true;
  Usuario? usuario;

  FocusNode? _focusNode;
  String? miPago;
  bool _isSearching = false;
  String? nuevo;
  final searchCtrl = TextEditingController();
  final usuarioService = UsuariosService();
  // StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription; // Reserved for future connectivity monitoring

  final _pinPutController = TextEditingController();
  var lang;

  String? myPin;

  Timer? _refreshDebounce;
  int _backgroundSyncTasks = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this); // Add this in your initState
    // Connectivity monitoring reserved for future use
    // _connectivitySubscription = Connectivity()
    //     .onConnectivityChanged
    //     .listen((List<ConnectivityResult> result) {
    //   if (result.last != ConnectivityResult.none) {
    //     socketService!.connect();
    //   } else {
    //     print("No connection available");
    //   }
    // });

    authService = Provider.of<AuthService>(context, listen: false);
    socketService = Provider.of<SocketService>(context, listen: false);
    usuario = authService!.usuario;

    authService?.getKeys();

    // Check if security questions have been skipped or completed
    _checkSecurityQuestionsStatus();

    miPago = 'load';

    setlintener();
    // Load chats immediately from local database
    _getContactosMensaje().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    // Initialize home in background
    _initHome();
    _initializeCallProvider();
    super.initState();
  }

  void _initializeCallProvider() {
    // Initialize CallProvider immediately if socket is already connected
    if (socketService!.serverStatus == ServerStatus.Online &&
        socketService!.socket != null &&
        socketService!.socket!.connected) {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!callProvider.isInitialized) {
        callProvider.initialize(socketService!, authService, navigatorKey);
        print(
            '[HomePage] CallProvider initialized immediately (socket already connected)');
      }
    }

    // Listen for socket connection events
    socketService!.connectionstatusstream.listen((event) {
      if (mounted &&
          (event['status'] == 'online' ||
              socketService!.serverStatus == ServerStatus.Online)) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        if (!callProvider.isInitialized) {
          callProvider.initialize(socketService!, authService, navigatorKey);
          print('[HomePage] CallProvider initialized from connection stream');
        }
      }
    });

    // Also set up direct socket listener for immediate initialization
    socketService!.socket?.once('connect', (_) {
      if (mounted) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        if (!callProvider.isInitialized) {
          callProvider.initialize(socketService!, authService, navigatorKey);
          print(
              '[HomePage] CallProvider initialized from socket connect event');
        }
      }
    });

    // Fallback: Check after a short delay if still not initialized
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        if (!callProvider.isInitialized &&
            socketService!.serverStatus == ServerStatus.Online) {
          final authService = Provider.of<AuthService>(context, listen: false);
          callProvider.initialize(socketService!, authService, navigatorKey);
          print('[HomePage] CallProvider initialized from fallback check');
        }
      }
    });
  }

  void _incrementBackgroundSync() {
    if (!mounted) return;
    setState(() {
      _backgroundSyncTasks++;
    });
  }

  void _decrementBackgroundSync() {
    if (!mounted) return;
    setState(() {
      if (_backgroundSyncTasks > 0) {
        _backgroundSyncTasks--;
      }
    });
  }

  @override
  void dispose() {
    // Unregister the observer
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      socketService?.connect();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint(
          '[HomePage] App moved to $state - keeping socket in current state');
    }
  }

  setlintener() {
    socketService!.refreshstream.listen((event) {
      // Debounce refresh events to avoid hammering network/database work
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 300), () async {
        print("[HomePage] Refresh triggered from socket stream");
        await _getContactosMensaje();
      });
    });
  }

  _validarPago() async {
    _incrementBackgroundSync();
    try {
      TelemetryService.log('payments_sync_start');
      var prefs = await SharedPreferences.getInstance();
      lang = prefs.getString('language_code');

      await authService!.pagosUsuario(usuario!);

      List<ObjPago> pagos = await DBProvider.db.getPagos();
      miPago = 'false';
      if (pagos.isNotEmpty) {
        var fechaPago = pagos[0].fecha!.substring(0, 10);
        var fechaActual = DateTime.now().toString().substring(0, 10);
        if (DateTime.parse(fechaPago).isAfter(DateTime.parse(fechaActual))) {
          miPago = 'true';
        }
      }
      if (mounted) setState(() {});
      TelemetryService.log('payments_sync_finish', data: {'status': miPago});
    } finally {
      _decrementBackgroundSync();
    }
  }

  _init1Home() async {
    // Load chats from local database first (fast, non-blocking)
    await _getContactosMensaje();

    // Load contacts in background and refresh chats when done
    Future.microtask(() async {
      try {
        await _syncContactsWithSocketGuard();
        // Refresh chats after contacts are loaded
        if (mounted) {
          await _getContactosMensaje();
        }
      } catch (e) {
        debugPrint('[init1Home] Error loading contacts: $e');
        // Chats are already loaded from local DB, so continue
      }
    });
  }

  _initHome() async {
    // Load chats from local database first (fast, non-blocking)
    await _getContactosMensaje();

    // Run other operations in background to avoid blocking UI
    Future.microtask(() async {
      try {
        // Run these in parallel - each handles its own errors
        await Future.wait<void>([
          _syncContactsWithSocketGuard(),
          usuarioService
              .getListGroup(usuario!.uid)
              .then((_) {})
              .catchError((e) {
            debugPrint('[initHome] Error loading groups: $e');
          }),
          usuarioService
              .getSolicitudes(usuario!.codigoContacto!)
              .then((_) {})
              .catchError((e) {
            debugPrint('[initHome] Error loading solicitudes: $e');
          }),
        ], eagerError: false); // Don't fail all if one fails

        // Refresh chats after contacts are loaded
        if (mounted) {
          await _getContactosMensaje();
        }
      } catch (e) {
        debugPrint('[initHome] Error in background tasks: $e');
      }
    });

    // These can run in parallel
    await Future.wait<void>([
      _validarPago(),
      _pinCryptoChat(),
    ], eagerError: false);
  }

  Future<void> _syncContactsWithSocketGuard() async {
    if (authService == null ||
        usuario == null ||
        usuario!.codigoContacto == null) {
      return;
    }
    _incrementBackgroundSync();
    TelemetryService.log('contacts_sync_start', data: {
      'delayed': socketService?.isReconnecting ?? false,
    });
    try {
      final service = socketService;
      final shouldDelay = service?.isReconnecting ?? false;
      if (!shouldDelay) {
        await authService!.guardarContactosLocales(usuario!.codigoContacto);
        return;
      }

      debugPrint(
          '[HomePage] Delaying contact sync while socket reconnects to avoid server load');
      try {
        await service!.connectionstatusstream
            .firstWhere((event) => event['status'] == 'online')
            .timeout(const Duration(seconds: 20));
      } on TimeoutException catch (_) {
        debugPrint(
            '[HomePage] Contact sync wait timed out - will proceed regardless');
      } catch (e) {
        debugPrint('[HomePage] Error while waiting for socket reconnect: $e');
      }

      if (!mounted) return;

      try {
        await authService!.guardarContactosLocales(usuario!.codigoContacto);
      } catch (e) {
        debugPrint('[HomePage] Error loading contacts after reconnect: $e');
      }
    } catch (e) {
      debugPrint('[HomePage] Unexpected error in contact sync guard: $e');
    } finally {
      TelemetryService.log('contacts_sync_finish');
      _decrementBackgroundSync();
    }
  }

  _getContactosMensaje() async {
    try {
      _allChats.clear();
      if (usuario?.uid != null) {
        _allChats = await DBProvider.db.getUsuarioMensaje(usuario!.uid!);

        // CRITICAL: Filter out self-chats and duplicates
        final seenUids = <String>{};
        _allChats.removeWhere((contact) {
          // Exclude if uid is current user (for individual chats)
          if (contact.esGrupo != 1 && contact.uid == usuario!.uid) {
            debugPrint('[HomePage] ⚠️ Removing self-chat: ${contact.nombre}');
            return true; // Remove self-chat
          }

          // Remove duplicates by uid
          if (seenUids.contains(contact.uid)) {
            debugPrint(
                '[HomePage] ⚠️ Removing duplicate chat: ${contact.nombre} (${contact.uid})');
            return true; // Remove duplicate
          }
          seenUids.add(contact.uid!);
          return false;
        });

        // Filter out deleted contacts (defensive check)
        _allChats.removeWhere((contact) {
          // Check if contact should be filtered (e.g., deleted flag if exists)
          return false; // For now, rely on database query filtering
        });
      }

      if (_isSearching) {
        contactos = _findContacto;
      } else {
        contactos = _allChats;
      }
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      debugPrint('[HomePage] Error loading contactos mensaje: $e');
      debugPrint('[HomePage] Stack trace: $stackTrace');
      // Show error state - keep existing contacts to avoid blank screen
      if (mounted) setState(() {});
    }
  }

  _pinCryptoChat() async {
    var prefs = await SharedPreferences.getInstance();
    myPin = prefs.getString('CryptoChatPIN');
    if (mounted) setState(() {});
  }

  _checkSecurityQuestionsStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSkippedOrCompletedSecurityQuestions =
        prefs.getBool('hasSkippedOrCompletedSecurityQuestions') ?? false;

    // Only show welcome screen if:
    // 1. User is new (nuevo == 'true') AND
    // 2. Security questions haven't been skipped/completed yet
    if (usuario!.nuevo == 'true' && !hasSkippedOrCompletedSecurityQuestions) {
      nuevo = 'true';
    } else {
      nuevo = 'false';
    }

    if (mounted) setState(() {});
  }

  // final isFile = avatar != null && File(avatar!).existsSync();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => InkWell(
            child: Icon(Icons.menu_open_rounded, color: background),
            onTap: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        //backgroundColor: grisClaro,
        backgroundColor: header,
        title: Container(
          padding: const EdgeInsets.only(right: 10, left: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                'assets/banner/text_img.png',
                color: background,
                height: 30,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: socketService!.solicitudesNuevas
                      ? BlinkIcon(
                          icono: Icons.person_sharp,
                          color: primary,
                        )
                      : Icon(
                          Icons.person_sharp,
                          color: background,
                        ),
                ),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (context) => const SolicitudesPage()))
                    .then((value) {
                  setState(() {});
                }),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.search,
                    color: background,
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
        ),
        bottom: _isSearching
            ? AppBar(
                backgroundColor: header,
                shadowColor: transparente,
                leading: GestureDetector(
                  child: Icon(
                    Icons.cancel,
                    color: background,
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
                      border: Border.all(color: background)),
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
                      fontFamily: 'roboto-regular',
                      letterSpacing: 1.0,
                    ),
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.of(context)!.translate('SEARCH'),
                      hintStyle: TextStyle(
                        color: gris.withOpacity(0.6),
                        fontFamily: 'roboto-regular',
                        letterSpacing: 1.0,
                      ),
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: nuevo == 'true'
          ? WelcomeOverlayWidget(
              authService: authService!,
              onComplete: () {
                setState(() {
                  nuevo = 'false';
                });
              },
            )
          : Column(
              children: [
                Card(
                  color: sub_header,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      AppLocalizations.of(context)!.translate('CHATS'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: background,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: Icon(
                      Icons.messenger_outline_rounded,
                      color: background,
                    ),
                    trailing: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.refresh,
                          color: background,
                          size: 30,
                        ),
                      ),
                      onTap: () => _init1Home(),
                    ),
                  ),
                ),
                _buildBackgroundSyncBanner(),
                Flexible(
                  child: ChatListWidget(
                    contactos: contactos,
                    isLoading: _isLoading,
                    isSearching: _isSearching,
                    onChatTap: (contacto) async {
                      var chat = _openChatPage(contacto);
                      if (chat != 1) {
                        Navigator.pushNamed(context, 'chat')
                            .then((value) => _init1Home());
                      } else {
                        Navigator.pushNamed(context, 'chatGrupal')
                            .then((value) => _init1Home());
                      }
                    },
                    onDeleteChat: (uid) async {
                      await DBProvider.db.borrarMensajesContacto(uid);
                      await DBProvider.db.borrarContacto(uid);
                      if (mounted) {
                        setState(() {
                          contactos.removeWhere((c) => c.uid == uid);
                          _allChats.removeWhere((c) => c.uid == uid);
                        });
                      }
                      await _getContactosMensaje();
                    },
                    onArchiveChat: (uid) async {
                      final contacto =
                          contactos.firstWhere((c) => c.uid == uid);
                      if (contacto.esGrupo != 1) {
                        await DBProvider.db.updateContactos(uid, 'especial', 1);
                      } else {
                        await DBProvider.db.updateGrupo(uid, 'especial', 1);
                      }
                      await _getContactosMensaje();
                    },
                  ),
                ),
              ],
            ),
      // ),

      //applying gradient

      floatingActionButton: Material(
        elevation: 3, // Set elevation to 0 for the initial state
        shape: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary, // Starting color
                secondary, // Ending color
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle, // Ensures the shape is circular
          ),
          child: FloatingActionButton(
            heroTag: 'contacts',
            backgroundColor: Colors.transparent, // Make background transparent
            elevation: 0, // No elevation for the FAB
            child: Icon(
              Icons.bolt,
              color: drawer_white,
            ),
            onPressed: () {
              Navigator.pushNamed(context, 'contactos').then((res) {
                if (res != false) {
                  _init1Home();
                }
              });
            },
          ),
        ),
      ),

      // old floating button

      // floatingActionButton: FloatingActionButton(
      //   heroTag: 'contacts',
      //   backgroundColor: amarillo,
      //   child: new Icon(
      //     Icons.bolt,
      //     color: blanco,
      //   ),
      //   onPressed: () {
      //     Navigator.pushNamed(context, 'contactos').then((res) {
      //       if (res != false) {
      //         _init1Home();
      //       }
      //     });
      //   },
      // ),
      //  nuevo == 'false' && miPago == 'true'
      //     ? new FloatingActionButton(
      //         heroTag: 'contacts',
      //         backgroundColor: amarillo,
      //         child: new Icon(
      //           Icons.bolt,
      //           color: blanco,
      //         ),
      //         onPressed: () {
      //           Navigator.pushNamed(context, 'contactos').then((res) {
      //             if (res != false) {
      //               _initHome();
      //             }
      //           });
      //         },
      //       )
      //     : null,
      drawer: HomeDrawerWidget(
        usuario: usuario!,
        authService: authService!,
        socketService: socketService!,
        myPin: myPin,
        miPago: miPago,
        pinPutController: _pinPutController,
        onRefresh: _init1Home,
        onSavePin: guardarPin,
        onActivateNinjaMode: activarModoNinja,
      ),
    );
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

  Widget _buildBackgroundSyncBanner() {
    return const SizedBox.shrink();
  }

  // Widget _home() {
  //   return this.contactos.isEmpty
  //       ? _isSearching
  //           ? Text(
  //               AppLocalizations.of(context)!.translate('NO_RESULTS_FOUND'),
  //               textAlign: TextAlign.center,
  //               style: TextStyle(
  //                 color: gris,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             )
  //           : Center(
  //               child: Column(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   Text(
  //                     AppLocalizations.of(context)!
  //                         .translate('HOME_TEXT_TITTLE'),
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 20,
  //                       color: gris,
  //                     ),
  //                   ),
  //                   SizedBox(height: 15),
  //                   Row(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Text(
  //                         AppLocalizations.of(context)!
  //                             .translate('HOME_TEXT_1'),
  //                         style: TextStyle(
  //                           color: gris,
  //                         ),
  //                       ),
  //                       Icon(
  //                         Icons.bolt,
  //                         color: gris,
  //                       ),
  //                     ],
  //                   ),
  //                   Text(
  //                     AppLocalizations.of(context)!.translate('HOME_TEXT_2'),
  //                     style: TextStyle(
  //                       color: gris,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             )
  //       : ListView.separated(
  //           physics: BouncingScrollPhysics(),
  //           separatorBuilder: (_, i) => Divider(),
  //           itemCount: contactos.length,
  //           itemBuilder: (_, i) => Dismissible(
  //             key: ValueKey(contactos[i]),
  //             background: Container(
  //               padding: EdgeInsets.only(left: 20),
  //               alignment: AlignmentDirectional.centerStart,
  //               child: Icon(
  //                 Icons.delete,
  //                 color: blanco,
  //               ),
  //               color: rojo,
  //             ),
  //             secondaryBackground: Container(
  //               padding: EdgeInsets.only(right: 20),
  //               alignment: AlignmentDirectional.centerEnd,
  //               child: Icon(
  //                 Icons.archive,
  //                 color: blanco,
  //               ),
  //               color: azul,
  //             ),
  //             direction: DismissDirection.horizontal,
  //             confirmDismiss: (DismissDirection direction) async {
  //               var res;
  //               if (direction.index == 3) {
  //                 res = await alertaConfirmar(
  //                   context,
  //                   AppLocalizations.of(context)!.translate('DELETE_MESSAGES'),
  //                   AppLocalizations.of(context)!.translateReplace(
  //                       'DELETE_PERMANENTLY',
  //                       '{ACTION}',
  //                       AppLocalizations.of(context)!
  //                           .translate('DELETE_MESSAGES_ACCEPT')),
  //                 );
  //               } else if (direction.index == 2) {
  //                 res = await alertaConfirmar(
  //                     context,
  //                     AppLocalizations.of(context)!.translate('MOVE_MESSAGES'),
  //                     AppLocalizations.of(context)!.translateReplace(
  //                         'MOVE_ACTION',
  //                         '{ACTION}',
  //                         AppLocalizations.of(context)!
  //                             .translate('TO_SPECIAL')));
  //               }
  //               return res;
  //             },
  //             onDismissed: (DismissDirection direction) async {
  //               if (direction.index == 3) {
  //                 await DBProvider.db.borrarMensajesContacto(contactos[i].uid);
  //                 await _getContactosMensaje();
  //               } else if (direction.index == 2) {
  //                 if (contactos[i].esGrupo != 1) {
  //                   await DBProvider.db
  //                       .updateContactos(contactos[i].uid, 'especial', 1);
  //                 } else {
  //                   await DBProvider.db
  //                       .updateGrupo(contactos[i].uid, 'especial', 1);
  //                 }
  //                 await _getContactosMensaje();
  //               }
  //               contactos.remove(i);
  //             },
  //             child: ListTile(
  //               title: Text(
  //                 capitalize(contactos[i].nombre!),
  //                 style: TextStyle(fontWeight: FontWeight.bold, color: gris),
  //               ),
  //               subtitle: contactos[i].deleted
  //                   ? Text(
  //                       'Message deleted',
  //                       style: TextStyle(
  //                         fontStyle: FontStyle
  //                             .italic, // Italic text to show it's a deleted message
  //                         color: negro, // Grey color to indicate deletion
  //                         fontSize: 13.0, // You can adjust the size as needed
  //                         letterSpacing:
  //                             1.1, // Adds spacing to make the italic effect more noticeable
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                     )
  //                   : Row(
  //                       children: [
  //                         Container(
  //                           child: getIconMsg(
  //                               jsonDecode(contactos[i].mensaje!)["type"]),
  //                         ),
  //                         Text(
  //                           getMessageText(
  //                               jsonDecode(contactos[i].mensaje!)["type"],
  //                               jsonDecode(contactos[i].mensaje!)["content"]),
  //                         ),
  //                       ],
  //                     ),
  //               leading: CircleAvatar(
  //                 child: Image.asset(getAvatar(contactos[i].avatar!,
  //                     contactos[i].esGrupo != 1 ? 'user_' : 'group_')),
  //                 backgroundColor: blanco,
  //               ),
  //               trailing: Text(
  //                 formatDate(
  //                     parseUTCFecha(jsonDecode(contactos[i].mensaje!)["fecha"])
  //                         .toLocal(),
  //                     [hh, ':', nn, ' ', am]),
  //                 style: TextStyle(
  //                   color: gris,
  //                   fontSize: 10,
  //                 ),
  //               ),
  //               onTap: () async {
  //                 var chat = _openChatPage(contactos[i]);
  //                 if (chat != 1) {
  //                   Navigator.pushNamed(context, 'chat')
  //                       .then((value) => _init1Home());
  //                 } else {
  //                   Navigator.pushNamed(context, 'chatGrupal')
  //                       .then((value) => _init1Home());
  //                 }
  //               },
  //             ),
  //           ),
  //         );
  // }

  _openChatPage(UsuarioMensaje contactoGrupo) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    if (contactoGrupo.esGrupo != 1) {
      //ta9wadiyt here
      Usuario newUsuario = Usuario(publicKey: contactoGrupo.publicKey);
      newUsuario.nombre = contactoGrupo.nombre;
      newUsuario.avatar = contactoGrupo.avatar;
      newUsuario.uid = contactoGrupo.uid;
      newUsuario.online = contactoGrupo.online == "1";
      newUsuario.codigoContacto = contactoGrupo.codigoContacto;
      newUsuario.email = contactoGrupo.email;
      newUsuario.lastSeen = contactoGrupo.lastSeen;
      chatService.usuarioPara = newUsuario;
      return contactoGrupo.esGrupo;
    } else {
      Grupo newGrupo = Grupo();
      // print("-------------------_openChatPage-----------------");
      // print("-----------------${contactoGrupo.privateKey}-------------------");
      // print("-----------------${contactoGrupo.publicKey}-------------------");
      newGrupo.nombre = contactoGrupo.nombre;
      newGrupo.avatar = contactoGrupo.avatar;
      newGrupo.codigo = contactoGrupo.uid;
      newGrupo.descripcion = contactoGrupo.email;
      newGrupo.fecha = contactoGrupo.codigoContacto;
      newGrupo.usuarioCrea = contactoGrupo.usuarioCrea;
      newGrupo.privateKey = contactoGrupo.privateKey;
      newGrupo.publicKey = contactoGrupo.publicKey;
      newGrupo.usuarioCrea = contactoGrupo.usuarioCrea;
      chatService.grupoPara = newGrupo;

      return contactoGrupo.esGrupo;
    }
  }

  // Widget _goPago() { // Reserved for future payment feature
  //   return Container(
  //     child: Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           CircleAvatar(
  //             radius: 100,
  //             backgroundColor: transparente,
  //             child: ClipOval(
  //               child: SizedBox(), // Rive animation reserved for future use
  //             ),
  //           ),
  //           RichText(
  //             textAlign: TextAlign.center,
  //             text: TextSpan(
  //               style: TextStyle(
  //                 color: gris,
  //                 fontSize: 22,
  //               ),
  //               children: [
  //                 TextSpan(
  //                   text: 'Oops! ',
  //                   style: TextStyle(fontWeight: FontWeight.bold),
  //                 ),
  //                 TextSpan(
  //                   text: AppLocalizations.of(context)!.translate('NO_PAYMENT'),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           SizedBox(height: 30),
  //           SizedBox.fromSize(
  //             size: Size(140, 40),
  //             child: Material(
  //               borderRadius: BorderRadius.circular(40),
  //               color: verde.withOpacity(0.8),
  //               child: InkWell(
  //                 borderRadius: BorderRadius.circular(40),
  //                 splashColor: grisClaro,
  //                 child: Center(
  //                   child: Text(
  //                     AppLocalizations.of(context)!.translate('PAY_NOW'),
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 20,
  //                       color: blanco,
  //                     ),
  //                   ),
  //                 ),
  //                 // onTap: () => Navigator.push(context,
  //                 //     MaterialPageRoute(builder: (context) => PaymentPage())),
  //               ),
  //             ),
  //           ),
  //           SizedBox(height: 20),
  //           Text(
  //             AppLocalizations.of(context)!.translate('ONLY_YOU'),
  //             textAlign: TextAlign.center,
  //             style: TextStyle(fontSize: 18, color: gris),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  activarModoNinja() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('PMSInitialRoute', "mainCalc");
    if (Platform.isAndroid) {
      // TO rEPLACE
      // FlutterIconSwitcher.updateIcon('ALT');
    } else {
      try {
        // Temporarily disabled - flutter_dynamic_icon incompatible with Flutter v2 embedding
        // if (await FlutterDynamicIcon.supportsAlternateIcons) {
        //   await FlutterDynamicIcon.setAlternateIconName("calc");
        //   print("App icon change successful");
        //   exit(1);
        // }
        // Dynamic icon feature temporarily disabled - functionality preserved for future re-enablement
        exit(1);
      } catch (e) {
        //   print(e);
      } finally {
        exit(0);
      }
    }
  }

  guardarPin(pin) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('CryptoChatPIN', pin);
    setState(() {
      myPin = pin;
    });
  }
}
