import 'dart:convert';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/usuario_mensaje.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:shimmer/shimmer.dart';

class ChatListWidget extends StatelessWidget {
  final List<UsuarioMensaje> contactos;
  final bool isLoading;
  final bool isSearching;
  final Function(UsuarioMensaje) onChatTap;
  final Function(String) onDeleteChat;
  final Function(String) onArchiveChat;

  const ChatListWidget({
    Key? key,
    required this.contactos,
    required this.isLoading,
    required this.isSearching,
    required this.onChatTap,
    required this.onDeleteChat,
    required this.onArchiveChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingSkeleton();
    }

    if (contactos.isEmpty) {
      return isSearching
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.translate('NO_RESULTS_FOUND'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gris,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : _buildEmptyState(context);
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500.0,
      separatorBuilder: (_, i) => const Divider(),
      itemCount: contactos.length,
      itemBuilder: (_, i) => _buildChatTile(context, contactos[i]),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _ChatSkeletonTile(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.translate('HOME_TEXT_TITTLE'),
            style: TextStyle(
              fontFamily: 'roboto-bold',
              letterSpacing: 1.0,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: gris,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context)!.translate('HOME_TEXT_1'),
                style: TextStyle(
                  fontFamily: 'roboto-regular',
                  letterSpacing: 1.0,
                  color: gris,
                ),
              ),
              Icon(Icons.bolt, color: gris),
            ],
          ),
          Text(
            AppLocalizations.of(context)!.translate('HOME_TEXT_2'),
            style: TextStyle(
              fontFamily: 'roboto-regular',
              letterSpacing: 1.0,
              color: gris,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, UsuarioMensaje contacto) {
    final mensajeData = jsonDecode(contacto.mensaje!);
    final fecha = parseUTCFecha(mensajeData["fecha"]).toLocal();

    return RepaintBoundary(
      key: ValueKey('chat_${contacto.uid}_${contacto.fecha}'),
      child: Dismissible(
        key: ValueKey('chat_${contacto.uid}_${contacto.fecha}'),
        background: Container(
          padding: const EdgeInsets.only(left: 20),
          alignment: AlignmentDirectional.centerStart,
          color: rojo,
          child: Icon(Icons.delete, color: blanco),
        ),
        secondaryBackground: Container(
          padding: const EdgeInsets.only(right: 20),
          alignment: AlignmentDirectional.centerEnd,
          color: azul,
          child: Icon(Icons.archive, color: blanco),
        ),
        direction: DismissDirection.horizontal,
        confirmDismiss: (DismissDirection direction) async {
          if (direction == DismissDirection.endToStart) {
            // Delete
            return await alertaConfirmar(
              context,
              AppLocalizations.of(context)!.translate('DELETE_MESSAGES'),
              AppLocalizations.of(context)!.translateReplace(
                'DELETE_PERMANENTLY',
                '{ACTION}',
                AppLocalizations.of(context)!
                    .translate('DELETE_MESSAGES_ACCEPT'),
              ),
            );
          } else if (direction == DismissDirection.startToEnd) {
            // Archive
            return await alertaConfirmar(
              context,
              AppLocalizations.of(context)!.translate('MOVE_MESSAGES'),
              AppLocalizations.of(context)!.translateReplace(
                'MOVE_ACTION',
                '{ACTION}',
                AppLocalizations.of(context)!.translate('TO_SPECIAL'),
              ),
            );
          }
          return false;
        },
        onDismissed: (DismissDirection direction) {
          if (direction == DismissDirection.endToStart) {
            onDeleteChat(contacto.uid!);
          } else if (direction == DismissDirection.startToEnd) {
            onArchiveChat(contacto.uid!);
          }
        },
        child: ListTile(
          tileColor: chat_home_color,
          title: Text(
            capitalize(contacto.nombre!),
            style: TextStyle(fontWeight: FontWeight.bold, color: gris),
          ),
          subtitle: contacto.deleted
              ? Text(
                  'Message deleted',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: negro,
                    fontSize: 13.0,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      child: getIconMsg(mensajeData["type"]),
                    ),
                    Text(
                      getMessageText(
                          mensajeData["type"], mensajeData["content"]),
                    ),
                  ],
                ),
          leading: CircleAvatar(
            backgroundColor: blanco,
            child: Image.asset(
              getAvatar(
                  contacto.avatar!, contacto.esGrupo != 1 ? 'user_' : 'group_'),
            ),
          ),
          trailing: Text(
            formatDate(fecha, [hh, ':', nn, ' ', am]),
            style: TextStyle(
              color: gris,
              fontSize: 10,
            ),
          ),
          onTap: () => onChatTap(contacto),
        ),
      ),
    );
  }

  DateTime parseUTCFecha(String fecha) {
    return DateTime.utc(
      int.parse(fecha.substring(0, 4)),
      int.parse(fecha.substring(4, 6)),
      int.parse(fecha.substring(6, 8)),
      int.parse(fecha.substring(8, 10)),
      int.parse(fecha.substring(10, 12)),
      int.parse(fecha.substring(12, 14)),
      int.parse(fecha.substring(14, 17)),
    );
  }
}

class _ChatSkeletonTile extends StatelessWidget {
  const _ChatSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonCircle(size: 48),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(widthFactor: 0.7),
              SizedBox(height: 8),
              _SkeletonLine(widthFactor: 0.45),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;
  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
