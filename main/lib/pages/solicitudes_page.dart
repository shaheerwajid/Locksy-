import 'dart:async';
import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/contacto.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class SolicitudesPage extends StatefulWidget {
  const SolicitudesPage({super.key});

  @override
  _SolicitudesPageState createState() => _SolicitudesPageState();
}

class _SolicitudesPageState extends State<SolicitudesPage> {
  AuthService? authService;
  SocketService? socketService;
  List<Contacto> solicitudes = [];

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  Usuario? usuario;
  final usuarioService = UsuariosService();

  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    socketService = Provider.of<SocketService>(context, listen: false);
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
    _cargarSolicitudes();
    _setupSocketListeners();
    super.initState();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    // Listen for contact activation events that might come via socket
    // This is a fallback - we'll also implement optimistic UI updates
    if (socketService?.socket != null) {
      socketService!.socket!.on('contact-activated', (data) {
        _handleContactActivated(data);
      });
      socketService!.socket!.on('contact-deleted', (data) {
        _handleContactDeleted(data);
      });
    }

    // Also listen to refresh stream in case contact updates come through
    _socketSubscription = socketService?.refreshstream.listen((event) {
      // When contact list updates, reload requests
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _cargarSolicitudes();
        }
      });
    });
  }

  void _handleContactActivated(Map<String, dynamic> data) {
    final contactId = data['contactId']?.toString();
    final codigoContacto = data['codigoContacto']?.toString();
    
    if (contactId != null || codigoContacto != null) {
      _removeRequestFromList(codigoContacto);
    }
  }

  void _handleContactDeleted(Map<String, dynamic> data) {
    final codigoContacto = data['codigoContacto']?.toString();
    if (codigoContacto != null) {
      _removeRequestFromList(codigoContacto);
    }
  }

  void _removeRequestFromList(String? codigoContacto) {
    if (codigoContacto == null) return;
    
    setState(() {
      solicitudes.removeWhere((contacto) => 
        contacto.contacto?.codigoContacto == codigoContacto ||
        contacto.usuario?.codigoContacto == codigoContacto
      );
    });

    // Update socket service flag if no more requests
    if (solicitudes.isEmpty) {
      socketService!.solicitudesNuevas = false;
    }
  }

  _cargarSolicitudes() async {
    solicitudes.clear();
    solicitudes =
        await usuarioService.getSolicitudes(usuario!.codigoContacto!);
    setState(() {});
  }

  _reload() {
    _cargarSolicitudes();
    _refreshController.refreshCompleted();
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
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('CONTACT_REQUEST'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              child: SmartRefresher(
                controller: _refreshController,
                enablePullDown: true,
                onRefresh: _reload,
                header: WaterDropHeader(
                  complete: Icon(Icons.check, color: amarillo),
                  waterDropColor: amarillo,
                ),
                child: __listSolicitud(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget __listSolicitud() {
    return solicitudes.isEmpty
        ? Center(
            child: Text(
              AppLocalizations.of(context)!.translate('NO_CONTACT_REQUEST'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gris,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, i) => _solicitudListTile(solicitudes[i]),
            separatorBuilder: (_, i) => Divider(
                  height: 0,
                  indent: 20,
                  endIndent: 25,
                  color: negro,
                ),
            itemCount: solicitudes.length);
  }

  ListTile _solicitudListTile(Contacto contacto) {
    return ListTile(
        leading: CircleAvatar(
          backgroundImage:
              AssetImage(getAvatar(contacto.usuario!.avatar!, 'user_')),
          backgroundColor: amarillo,
          maxRadius: 20,
        ),
        title: Text(capitalize(contacto.usuario!.nombre!)),
        subtitle: Text(contacto.fecha!),
        trailing:
            Text(AppLocalizations.of(context)!.translate('ANSWER_REQUEST')),
        onTap: () {
          final codigoContacto = contacto.contacto!.codigoContacto;
          
          // Optimistic UI update: Remove from list immediately
          setState(() {
            solicitudes.removeWhere((c) => 
              c.contacto?.codigoContacto == codigoContacto ||
              c.usuario?.codigoContacto == contacto.usuario!.codigoContacto
            );
          });

          mostrarSolicitud(
                  context,
                  getAvatar(contacto.usuario!.avatar!, 'user_'),
                  capitalize(contacto.usuario!.nombre!),
                  contacto.usuario!.codigoContacto!,
                  codigoContacto!)
              .then((value) {
                // If user cancelled (value == false), add back to list
                if (value == false || value == null) {
                  setState(() {
                    solicitudes.insert(0, contacto);
                  });
                } else {
                  // Request was accepted/declined, reload to get updated list from server
                  _reload();
                }
              })
              .catchError((error) {
                // On error, restore the request in the list
                setState(() {
                  solicitudes.insert(0, contacto);
                });
              });

          if (solicitudes.isEmpty) {
            socketService!.solicitudesNuevas = false;
          }
        });
  }
}
