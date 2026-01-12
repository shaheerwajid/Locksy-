import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/mensajes_response.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/imageView_widget.dart';
import 'package:CryptoChat/widgets/videoPlayer_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:CryptoChat/global/environment.dart';

// ignore: must_be_immutable
class Gallery extends StatefulWidget {
  Usuario data;
  Gallery(this.data, {super.key});
  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Usuario? usuarioPara;
  AuthService? authService;
  List<Mensaje> _listImages = [];
  List<Mensaje> _listVideos = [];
  List<Mensaje> _listAudios = [];
  List<Mensaje> _listOtros = [];

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    _tabController = TabController(vsync: this, length: 4);
    usuarioPara = widget.data;
    _getFiles();
    super.initState();
  }

  _getFiles() async {
    _listImages.clear();
    _listVideos.clear();
    _listAudios.clear();
    _listOtros.clear();
    if (authService?.usuario?.uid != null && usuarioPara?.uid != null) {
      _listImages = await DBProvider.db.getArchivosUsuario(
          'images', usuarioPara!.uid!, authService!.usuario!.uid!);
      _listVideos = await DBProvider.db.getArchivosUsuario(
          'video', usuarioPara!.uid!, authService!.usuario!.uid!);
      _listAudios = await DBProvider.db.getArchivosUsuario(
          'audio', usuarioPara!.uid!, authService!.usuario!.uid!);
      _listOtros = await DBProvider.db.getArchivosUsuario(
          'documents', usuarioPara!.uid!, authService!.usuario!.uid!);
    }
    setState(() {});
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
          AppLocalizations.of(context)!.translate('FILES'),
          style: TextStyle(color: gris),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.translate('IMAGES')),
            Tab(text: AppLocalizations.of(context)!.translate('VIDEOS')),
            Tab(text: AppLocalizations.of(context)!.translate('AUDIOS')),
            Tab(text: AppLocalizations.of(context)!.translate('OTHER')),
          ],
          indicatorColor: chat_color2,
          labelColor: chat_color2,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _imagenes(),
          _videos(),
          _audios(),
          _otros(),
        ],
      ),
    );
  }

  Widget _imagenes() {
    return Container(
      child: _listGalleryImages(),
    );
  }

  Widget _videos() {
    return Container(
      child: _listGalleryVideos(),
    );
  }

  Widget _audios() {
    return Container(
      child: _listGalleryAudio(),
    );
  }

  Widget _otros() {
    return Container(
      child: _listGalleryOtros(),
    );
  }

  Widget _listGalleryImages() {
    return _listImages.isNotEmpty
        ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemBuilder: (context, index) =>
                _listItem(_listImages[index], 'imagen'),
            itemCount: _listImages.length,
          )
        : Center(
            child: Text(AppLocalizations.of(context)!.translateReplace(
                'NOT_FOUND',
                "{FILE_TYPE}",
                AppLocalizations.of(context)!.translate("IMAGES"))),
          );
  }

  Widget _listGalleryVideos() {
    return _listVideos.isNotEmpty
        ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemBuilder: (context, index) =>
                _listItem(_listVideos[index], 'video'),
            itemCount: _listVideos.length,
          )
        : Center(
            child: Text(AppLocalizations.of(context)!.translateReplace(
                'NOT_FOUND',
                "{FILE_TYPE}",
                AppLocalizations.of(context)!.translate("VIDEOS"))),
          );
  }

  Widget _listGalleryAudio() {
    return _listAudios.isNotEmpty
        ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemBuilder: (context, index) =>
                _listItem(_listAudios[index], 'audio'),
            itemCount: _listAudios.length,
          )
        : Center(
            child: Text(AppLocalizations.of(context)!.translateReplace(
                'NOT_FOUND',
                "{FILE_TYPE}",
                AppLocalizations.of(context)!.translate("AUDIOS"))),
          );
  }

  Widget _listGalleryOtros() {
    return _listOtros.isNotEmpty
        ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemBuilder: (context, index) =>
                _listItem(_listOtros[index], 'documents'),
            itemCount: _listOtros.length,
          )
        : Center(
            child: Text(AppLocalizations.of(context)!.translateReplace(
                'NOT_FOUND',
                "{FILE_TYPE}",
                AppLocalizations.of(context)!.translate("OTHER"))),
          );
  }

  GridTile _listItem(Mensaje datos, tipo) {
    final mensajeJson = jsonDecode(datos.mensaje!);
    var fecha = mensajeJson['fecha'];
    var exte = mensajeJson['extension'];
    var content = mensajeJson['content'] ?? '';
    var path = authService!.localPath!;
    var ruta = '$path/$fecha$exte';
    final file = File(ruta);
    Widget? elemento;
    switch (tipo) {
      case 'imagen':
        final imageUrl = _resolveImageUrl(content);
        if (file.existsSync()) {
          elemento = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildNetworkOrPlaceholder(imageUrl),
          );
        } else {
          elemento = _buildNetworkOrPlaceholder(imageUrl);
        }
        break;
      case 'video':
        elemento = Image.asset(
          'assets/icon/media_video.png',
          color: amarillo,
        );
        break;
      case 'audio':
        elemento = Image.asset(
          'assets/icon/media_audio.png',
          color: amarillo,
        );
        break;
      case 'documents':
        elemento = Image.asset(
          'assets/icon/media_document.png',
          color: amarillo,
        );
        break;
    }
    return GridTile(
      child: InkWell(
        child: elemento,
        onTap: () {
          if (tipo == 'imagen') {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ImageWidget(url: file)));
          } else if (tipo == 'video') {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => VideoWidget(path: ruta)));
          } else if (tipo == 'audio') {
            OpenFile.open(ruta);
          } else if (tipo == 'documents') {
            OpenFile.open(ruta);
          }
        },
      ),
    );
  }

  Widget _buildNetworkOrPlaceholder(String imageUrl) {
    if (imageUrl.isEmpty) {
      return _placeholder();
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(isLoading: true),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder({bool isLoading = false}) {
    return Container(
      color: gris.withOpacity(0.1),
      child: Center(
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.broken_image, color: gris),
      ),
    );
  }

  String _resolveImageUrl(String content) {
    if (content.isEmpty || content == 'null') return '';
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return content;
    }
    // treat as hash
    String hash = content.startsWith('/') ? content.substring(1) : content;
    return '${Environment.urlArchivos}$hash';
  }
}
