import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:CryptoChat/providers/GroupProvider.dart';
import 'package:CryptoChat/widgets/video_player/VideoPlayer.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';

import 'package:CryptoChat/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/widgets/imageView_widget.dart';
import 'package:CryptoChat/widgets/player_widget.dart';
import 'package:CryptoChat/widgets/replymsg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart' show DataSourceType;

import '../providers/ChatProvider.dart';
import '../services/file_cache_service.dart';
import '../global/environment.dart';

class ChatMessage extends StatelessWidget {
  final String? texto;
  final String? uid;
  final String? type;
  final String? hora;
  final String? fecha;
  final String? dir;
  final String? exten;
  final String? emisor;
  final bool? incognito;
  final bool enviado;
  final bool recibido;
  final bool isReply;
  final bool forwarded;
  final String? username;
  final String? parentmessage;
  final String? parenttype;
  final bool? cargando;
  final double? upload;
  final String? thumburl;
  final bool isGroup;
  final bool selected;
  final bool deleted;
  final VoidCallback? onRetry; // Callback for retry functionality
  final String? avatar; // Avatar for displaying next to message (like WhatsApp)

  const ChatMessage({
    Key? key,
    required this.texto,
    required this.type,
    required this.fecha,
    required this.hora,
    required this.selected,
    this.dir,
    this.exten,
    this.emisor,
    this.incognito,
    required this.enviado,
    required this.recibido,
    this.cargando,
    this.upload = 100,
    this.thumburl,
    this.forwarded = false,
    required this.isReply,
    this.parentmessage,
    this.parenttype,
    this.username,
    this.isGroup = false,
    required this.deleted,
    required this.uid,
    this.onRetry,
    this.avatar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return uid == authService.usuario!.uid
        ? _myMessage(
            context,
          )
        : _notMyMessage(context);
  }

  Widget _myMessage(
    BuildContext context,
  ) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userAvatar = avatar ?? authService.usuario?.avatar;

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              margin:
                  const EdgeInsets.only(right: 10, bottom: 5, left: 50, top: 5),
              decoration: BoxDecoration(
                  color: chat_color, borderRadius: BorderRadius.circular(10)),
              child: Stack(
                children: [
                  incognito!
                      ? Icon(
                          Icons.timelapse_rounded,
                          color: morado,
                          size: 15,
                        )
                      : const SizedBox(),
                  Positioned(
                    bottom: 0,
                    left: 10,
                    child: _buildStatusIndicator(),
                  ),
                  if (forwarded)
                    Positioned(
                      top: 0,
                      left: 1,
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: Image.asset(
                          'assets/icon/forward.png',
                          scale: 2,
                          fit: BoxFit.fill,
                          color: gris,
                        ),
                      ),
                      // enviado!
                      //     ? recibido!
                      //         ?
                      //         : Icon(
                      //             Icons.mark_chat_read_outlined,
                      //             color: verde,
                      //             size: 15,
                      //           )
                      //     : Icon(
                      //         Icons.error_outline_rounded,
                      //         color: gris,
                      //         size: 15,
                      //       ),
                      //  new IconEstado(
                      //   enviado: enviado,
                      //   recibido: recibido,
                      // ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                          margin: const EdgeInsets.only(right: 10, left: 25),
                          child: Text(
                            formatDate(DateTime.parse(hora!),
                                [yyyy, '-', mm, '-', dd]),
                            style: TextStyle(
                              color: gris,
                              fontSize: 10,
                            ),
                          )),
                      if (isReply && !deleted && parentmessage != null)
                        buildReply(parentmessage!, username!, parenttype!),

                      renderMessage(
                          value: true, context: context, isGrp: isGroup),
                      Container(
                        margin:
                            const EdgeInsets.only(right: 10, left: 5, top: 5),
                        child: Text(
                          formatDate(
                              DateTime.parse(hora!), [hh, ':', nn, ' ', am]),
                          style: TextStyle(
                            color: gris,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      // if (type == "video")
                      //   Container(
                      //       height: 5,
                      //       width: 5,
                      //       child: CircularPercentIndicator(
                      //         radius: 10.0,
                      //         lineWidth: 3.0,
                      //         percent: upload!.toDouble(),
                      //         //center: Text("100%"),
                      //         progressColor: Colors.green,
                      //       )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Avatar for sent messages (like WhatsApp)
          if (userAvatar != null && !isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 5),
              child: CircleAvatar(
                backgroundImage: AssetImage(getAvatar(userAvatar, 'user_')),
                radius: 14,
                backgroundColor: blanco,
              ),
            )
          else if (!isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 5),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: gris,
                child: Icon(Icons.person, size: 16, color: blanco),
              ),
            ),
        ],
      ),
    );
  }

  /// Build status indicator with proper icons and colors
  Widget _buildStatusIndicator() {
    // Determine message status
    if (recibido) {
      // Delivered - double checkmark (blue)
      return const Icon(
        FontAwesomeIcons.checkDouble,
        color: Colors.blue,
        size: 15,
      );
    } else if (enviado) {
      // Sent - single checkmark (blue)
      return const Icon(
        FontAwesomeIcons.check,
        color: Colors.blue,
        size: 15,
      );
    } else {
      // Not sent - could be sending or failed
      // If onRetry is provided, it means message failed and can be retried
      if (onRetry != null) {
        // Failed - red exclamation with retry button
        return GestureDetector(
          onTap: onRetry,
          child: const Tooltip(
            message: 'Tap to retry',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 15,
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.refresh,
                  color: Colors.red,
                  size: 12,
                ),
              ],
            ),
          ),
        );
      } else {
        // Sending/Queued - clock icon (gray)
        return const Icon(
          Icons.access_time,
          color: Colors.grey,
          size: 15,
        );
      }
    }
  }

  Widget buildReply(String msg, String username, String typ) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(24),
          ),
        ),
        child: ReplyMessageWidget(
          username: username,
          type: typ,
          message: msg,
          onCancelReply: () {
            //print("shiiiiiiiiiit");
          },
        ),
      );

  Widget _notMyMessage(
    BuildContext context,
  ) {
    // Get avatar for received messages
    final receivedAvatar = avatar;

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages (like WhatsApp)
          if (receivedAvatar != null && !isGroup)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 5),
              child: CircleAvatar(
                backgroundImage: AssetImage(getAvatar(receivedAvatar, 'user_')),
                radius: 14,
                backgroundColor: blanco,
              ),
            )
          else if (!isGroup)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 5),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: gris,
                child: Icon(Icons.person, size: 16, color: blanco),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(
                  left: 10, bottom: 5, right: 100, top: 5),
              decoration: BoxDecoration(
                  color: chat_color2, borderRadius: BorderRadius.circular(20)),
              child: Stack(
                children: [
                  incognito!
                      ? Icon(
                          Icons.timelapse_rounded,
                          color: morado,
                          size: 15,
                        )
                      : const SizedBox(),
                  if (forwarded)
                    Positioned(
                      top: 0,
                      left: 1,
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: Image.asset(
                          'assets/icon/forward.png',
                          scale: 2,
                          fit: BoxFit.fill,
                          color: gris,
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 5, left: 25),
                        child: Text(
                          formatDate(
                              DateTime.parse(hora!), [yyyy, '-', mm, '-', dd]),
                          style: TextStyle(
                            color: gris,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 5, left: 5),
                        child: emisor != null && type != 'system'
                            ? Text(emisor!,
                                style: TextStyle(
                                    color: gris, fontWeight: FontWeight.bold))
                            : const SizedBox(),
                      ),
                      if (isReply && !deleted)
                        buildReply(parentmessage!, username!, parenttype!),
                      renderMessage(
                          value: false, context: context, isGrp: isGroup),
                      Container(
                        margin:
                            const EdgeInsets.only(right: 5, left: 25, top: 2),
                        child: Text(
                          formatDate(
                              DateTime.parse(hora!), [hh, ':', nn, ' ', am]),
                          style: TextStyle(
                            color: gris,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget renderMessage(
      {required bool value,
      required BuildContext context,
      required bool isGrp}) {
    dynamic chatProvider;
    if (isGrp) {
      chatProvider = Provider.of<GroupChatProvider>(context, listen: false);
    } else {
      chatProvider = Provider.of<ChatProvider>(context, listen: false);
    }

    if (type == 'system') {
      return Text(
        AppLocalizations.of(context)!
            .translateReplace(texto!, '{USUARIO}', emisor!),
        style: TextStyle(color: gris, fontSize: 16),
      );
    } else if (deleted) {
      return Container(
        margin: const EdgeInsets.only(left: 5, right: 5, top: 0),
        child: Text(
          'Message deleted',
          style: TextStyle(
            fontStyle:
                FontStyle.italic, // Italic text to show it's a deleted message
            color: negro, // Grey color to indicate deletion
            fontSize: 13.0, // You can adjust the size as needed
            letterSpacing:
                1.1, // Adds spacing to make the italic effect more noticeable
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else if (type == 'text') {
      // //print(this.texto);
      return Container(
        margin: const EdgeInsets.only(left: 5, right: 5, top: 0),
        child: Linkify(
          onOpen: _onOpen,
          text: crearURl(deleted ? "Message deleted" : texto!),
          style: TextStyle(color: negro, fontSize: 16),
          linkStyle: TextStyle(color: azul),
        ),
      );
    } else if (type == 'recording') {
      var array = exten!.split('&');
      String duracion;
      String ruta;
      //print(this.exten);
      if (array.length > 1) {
        ruta = "$dir/${fecha!}${array[0]}";
        duracion = array[1];
      } else {
        ruta = "$dir/${fecha!}${exten!}";
        duracion = '00:00';
      }
      chatProvider.addNewPlayer(ruta);
      final player = PlayerWidget(
        isGpr: isGrp,
        key: UniqueKey(),
        url: ruta,
        audioPlayer: chatProvider.players[ruta],
        content: duracion,
      );

      return player;
    } else if (type == 'images') {
      // Get image URL from content (handles both URL and local path for backward compatibility)
      String imageUrl = _getImageUrl();

      return InkWell(
        onTap: () {
          // Open image in full screen
          if (imageUrl.startsWith('http://') ||
              imageUrl.startsWith('https://')) {
            // Network image - use PhotoView directly
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) =>
                    _buildFullScreenNetworkImage(ctx, imageUrl, fecha),
              ),
            );
          } else {
            // Backward compatibility: local file path
            File file = File(imageUrl);
            if (file.existsSync()) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ImageWidget(url: file)),
              );
            }
          }
        },
        child: Hero(
          tag: 'imagen$fecha',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: imageUrl.startsWith('http://') ||
                      imageUrl.startsWith('https://')
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      memCacheHeight: 400,
                      maxWidthDiskCache: 800,
                      maxHeightDiskCache: 1200,
                      placeholder: (context, url) =>
                          _buildMediaPlaceholder(isLoading: true),
                      errorWidget: (context, url, error) {
                        debugPrint(
                            '[ChatMessage] Network image load error: $url - $error');
                        return _buildMediaPlaceholder(isLoading: false);
                      },
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 100),
                    )
                  : _buildLocalImageWidget(imageUrl),
            ),
          ),
        ),
      );
    } else if (type == 'audio') {
      var ruta = "$dir/${fecha!}${exten!}";
      // File file = File(ruta);

      return InkWell(
        onTap: () => OpenFile.open(ruta),
        child: Image.asset(
          'assets/icon/media_audio.png',
          scale: 2,
          fit: BoxFit.fill,
          color: value ? blanco : amarillo,
        ),
      );
    } else if (type == 'video') {
      // Get video URL from content (handles both URL and local path for backward compatibility)
      String videoUrl = _getVideoUrl();
      bool isNetworkVideo =
          videoUrl.startsWith('http://') || videoUrl.startsWith('https://');

      print('[ChatMessage] ========== VIDEO DEBUG ==========');
      print('[ChatMessage] texto (content): $texto');
      print('[ChatMessage] dir: $dir');
      print('[ChatMessage] fecha: $fecha');
      print('[ChatMessage] exten: $exten');
      print('[ChatMessage] videoUrl: $videoUrl');
      print('[ChatMessage] isNetwork: $isNetworkVideo');
      print('[ChatMessage] =====================================');

      // For network videos, we can't generate thumbnails locally
      // For local videos, try to generate thumbnail
      Future<String?> getVideoThumb() async {
        try {
          if (chatProvider.videoThumb.containsKey(videoUrl)) {
            return chatProvider.videoThumb[videoUrl];
          }
          return await chatProvider.getThumbnail(videoUrl);
        } catch (e) {
          print('[ChatMessage] Error generating video thumbnail: $e');
          return null;
        }
      }

      final Future<String?> thumbFuture =
          isNetworkVideo ? Future<String?>.value(null) : getVideoThumb();

      // CRITICAL: Wrap video widget in error boundary to prevent chat from going blank on errors
      return Builder(
        builder: (context) {
          try {
            return InkWell(
              onTap: () {
                try {
                  // Determine data source type based on URL
                  DataSourceType sourceType = isNetworkVideo
                      ? DataSourceType.network
                      : DataSourceType.file;

                  // For local files, check existence before opening
                  if (!isNetworkVideo && !File(videoUrl).existsSync()) {
                    print(
                        '[ChatMessage] ⚠️ Video file does not exist: $videoUrl');
                    return;
                  }

                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VideoPlayerView(
                            url: videoUrl,
                            dataSourceType: sourceType,
                          )));
                } catch (e) {
                  print('[ChatMessage] ⚠️ Error opening video: $e');
                }
              },
              child: Hero(
                tag: 'video$fecha',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: FutureBuilder<String?>(
                      future: thumbFuture,
                      builder: (context, snapshot) {
                        try {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildMediaPlaceholder(isLoading: true);
                          }
                          if (snapshot.hasError) {
                            print(
                                '[ChatMessage] Error loading video thumbnail: ${snapshot.error}');
                            return _buildMediaPlaceholder(isLoading: false);
                          }
                          final thumbPath = snapshot.data;

                          // For network videos without thumbnail, show placeholder with play button
                          if (isNetworkVideo) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.videocam,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.1),
                                        Colors.black.withOpacity(0.4)
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 48),
                                ),
                              ],
                            );
                          }

                          // For local videos with thumbnail
                          if (thumbPath != null &&
                              thumbPath.isNotEmpty &&
                              File(thumbPath).existsSync()) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(thumbPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                        '[ChatMessage] Error loading video thumbnail image: $error');
                                    return _buildMediaPlaceholder(
                                        isLoading: false);
                                  },
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.1),
                                        Colors.black.withOpacity(0.4)
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 48),
                                ),
                              ],
                            );
                          }

                          // Fallback placeholder
                          return _buildMediaPlaceholder(isLoading: false);
                        } catch (e) {
                          print(
                              '[ChatMessage] Exception in video thumbnail builder: $e');
                          return _buildMediaPlaceholder(isLoading: false);
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
          } catch (e) {
            // CRITICAL: Catch any errors in video widget construction to prevent chat from going blank
            print(
                '[ChatMessage] ⚠️ CRITICAL: Error constructing video widget: $e');
            // Return placeholder instead of crashing
            return _buildMediaPlaceholder(isLoading: false);
          }
        },
      );
    } else if (type == 'documents') {
      var ruta = "$dir/${fecha!}${exten!}";
      // File file = File(ruta);

      return InkWell(
        onTap: () {
          //print(ruta);
          OpenFile.open(ruta);
        },
        child: Image.asset(
          'assets/icon/media_document.png',
          scale: 2,
          fit: BoxFit.fill,
          color: value ? blanco : amarillo,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Get image URL from content, handling backward compatibility
  /// Supports: full URLs, local file paths, and hash-only values
  String _getImageUrl() {
    String content = texto ?? '';

    // If empty, construct from fecha and extension (backward compatibility)
    if (content.isEmpty) {
      String dir = this.dir ?? '';
      return "$dir/$fecha$exten";
    }

    // Check if it's already a full URL (new format)
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return content;
    }

    // Check if it's a local file path (old format - backward compatibility)
    if (content.startsWith('/data/') ||
        content.startsWith('/storage/') ||
        content.contains('/')) {
      return content;
    }

    // Otherwise, assume it's a hash and construct the full URL
    // Remove leading slash if present
    String hash = content.startsWith('/') ? content.substring(1) : content;
    return "${Environment.urlArchivos}$hash";
  }

  /// Get video URL from content, handling backward compatibility
  /// Supports: full URLs, local file paths, and hash-only values
  String _getVideoUrl() {
    String content = texto ?? '';

    // If empty, construct from fecha and extension (backward compatibility)
    if (content.isEmpty) {
      String dirValue = this.dir ?? '';
      // If dir is empty or looks like it might be a server path, try to construct URL
      if (dirValue.isEmpty || !dirValue.startsWith('/')) {
        // Might be a server video - try constructing URL from fecha
        if (fecha != null && fecha!.isNotEmpty) {
          return "${Environment.urlArchivos}$fecha${exten ?? ''}";
        }
      }
      return "$dirValue/$fecha$exten";
    }

    // Check if it's already a full URL (new format)
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return content;
    }

    // Check if it's a local file path (old format - backward compatibility)
    if (content.startsWith('/data/') ||
        content.startsWith('/storage/') ||
        (content.contains('/') && content.length > 20)) {
      return content;
    }

    // Otherwise, assume it's a hash/filename and construct the full URL
    // Remove leading slash if present
    String hash = content.startsWith('/') ? content.substring(1) : content;
    return "${Environment.urlArchivos}$hash";
  }

  /// Build widget for local image file (backward compatibility)
  Widget _buildLocalImageWidget(String filePath) {
    File file = File(filePath);

    if (!file.existsSync()) {
      return _buildMediaPlaceholder(isLoading: false);
    }

    return Image.file(
      file,
      key: ValueKey('local_img_$filePath'),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      cacheWidth: 300,
      cacheHeight: 400,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[ChatMessage] Local image load error: $filePath - $error');
        return _buildMediaPlaceholder(isLoading: false);
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _buildMediaPlaceholder(isLoading: true);
      },
    );
  }

  /// Build full-screen view for network images
  Widget _buildFullScreenNetworkImage(
      BuildContext context, String imageUrl, String? fechaTag) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        shadowColor: Colors.transparent,
        leading: InkWell(
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
          ),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          imageUrl.split('/').last,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Hero(
          tag: 'imagen${fechaTag ?? ''}',
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder({required bool isLoading}) {
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.image_not_supported,
              color: Colors.grey[400],
            ),
    );
  }

  /// Build a reactive stream that checks file existence and listens for cache updates
  /// Uses StreamController for proper lifecycle management
  Stream<bool> _buildFileExistenceStream(
      FileCacheService cacheService, String filePath, bool? initialCached) {
    final controller = StreamController<bool>.broadcast();
    bool currentExists = initialCached ?? false;
    StreamSubscription<String>? updateSubscription;

    // Emit initial cached value if available (for instant display)
    if (initialCached != null) {
      controller.add(initialCached);
      currentExists = initialCached;

      // If cached as true, verify file still exists (quick sync check)
      if (initialCached == true) {
        final file = File(filePath);
        if (!file.existsSync()) {
          // File was deleted - clear cache and check again
          cacheService.clearCache(filePath);
          currentExists = false;
          controller.add(false);
        } else {
          // File exists - return early, no need for async check
          // But still listen for updates
          updateSubscription = cacheService.fileUpdates.listen((updatedPath) {
            if (updatedPath == filePath && !controller.isClosed) {
              cacheService.fileExists(filePath).then((exists) {
                if (!controller.isClosed && exists != currentExists) {
                  currentExists = exists;
                  controller.add(exists);
                }
              });
            }
          });

          controller.onCancel = () {
            updateSubscription?.cancel();
          };

          return controller.stream;
        }
      }
    }

    // Perform initial check for uncached or false cached files
    cacheService.fileExists(filePath).then((exists) {
      if (!controller.isClosed) {
        if (exists != currentExists || initialCached == null) {
          currentExists = exists;
          controller.add(exists);
        }
      }
    }).catchError((e) {
      debugPrint('[ChatMessage] Error checking file: $filePath - $e');
      if (!controller.isClosed && currentExists != false) {
        currentExists = false;
        controller.add(false);
      }
    });

    // Listen to file cache updates for this specific file
    updateSubscription = cacheService.fileUpdates.listen((updatedPath) {
      if (updatedPath == filePath && !controller.isClosed) {
        cacheService.fileExists(filePath).then((exists) {
          if (!controller.isClosed && exists != currentExists) {
            currentExists = exists;
            controller.add(exists);
          }
        }).catchError((e) {
          debugPrint(
              '[ChatMessage] Error re-checking file after update: $filePath - $e');
        });
      }
    });

    // Clean up on close
    controller.onCancel = () {
      updateSubscription?.cancel();
    };

    return controller.stream;
  }

  Stream<bool> checkFileExists(String filePath) async* {
    final file = File(filePath);

    // First check immediately
    bool exists = await file.exists();
    if (exists) {
      yield exists;
      return; // File exists, no need to poll
    }

    // If file doesn't exist, poll with exponential backoff for efficiency
    // Start with 1 second, then 2, 4, 8, up to 10 seconds max
    int delaySeconds = 1;
    int maxDelay = 10;
    int maxAttempts = 20; // Stop after 20 attempts (~3 minutes total)
    int attempts = 0;

    while (!exists && attempts < maxAttempts) {
      await Future.delayed(Duration(seconds: delaySeconds));
      exists = await file.exists();
      yield exists;

      if (exists) {
        return; // File found, stop polling
      }

      attempts++;
      // Exponential backoff: 1s, 2s, 4s, 8s, then cap at 10s
      delaySeconds = (delaySeconds * 2).clamp(1, maxDelay);
    }

    // Final yield even if file doesn't exist (to update UI)
    yield exists;
  }

  Future<void> _onOpen(LinkableElement link) async {
    try {
      await launch(link.url);
    } catch (e) {
      //print('Could not lauch $e');
    }
  }
}
