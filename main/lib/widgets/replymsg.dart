import 'dart:core';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ReplyMessageWidget extends StatelessWidget {
  final String username;
  final String message;
  final String type;
  final VoidCallback? onCancelReply;

  const ReplyMessageWidget({
    Key? key,
    required this.message,
    required this.type,
    required this.username,
    this.onCancelReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          children: [
            Container(
              color: Colors.green,
              width: 4,
            ),
            const SizedBox(width: 8),
            Expanded(child: buildReplyMessage()),
          ],
        ),
      );
  String normalizeMesaage(String message) {
    if (message.isEmpty || message == 'null') {
      return 'Image';
    }
    List<String> parts = message.split('/');
    String filenameWithExtension = parts.last;
    // If the filename is empty or still the full path, try to extract a meaningful name
    if (filenameWithExtension.isEmpty || filenameWithExtension == message) {
      // If it's a hash or URL, return a generic name
      if (message.startsWith('http://') || message.startsWith('https://') || 
          (!message.contains('/') && message.length < 20)) {
        return 'Image';
      }
      return message.length > 20 ? '${message.substring(0, 20)}...' : message;
    }
    return filenameWithExtension;
  }

  Widget buildReplyMessage() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          type == "img" || type == "images"
              ? _buildImagePreview(message)
              : type == "vid" || type == "video"
                  ? FutureBuilder(
                      future: genThumbnail(message),
                      builder: (BuildContext context, AsyncSnapshot snapshot) {
                        if (snapshot.hasData) {
                          //  print(snapshot.data);
                          return Image.memory(
                            snapshot.data,
                            width: 40,
                            height: 40,
                          );
                          // return _image;
                        } else if (snapshot.hasError) {
                          //          print("Error:\n${snapshot.error.toString()}");
                          return Container(
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.red,
                            child: Text(
                              "Error:\n${snapshot.error.toString()}",
                            ),
                          );
                        } else {
                          return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Text(message),
                                const SizedBox(
                                  height: 10.0,
                                ),
                                const CircularProgressIndicator(),
                              ]);
                        }
                      })
                  : Container(),
          Expanded(
            // Wrap the Column in Expanded
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  capitalize(username),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  normalizeMesaage(message),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const Expanded(child: SizedBox()),
          if (onCancelReply != null)
            GestureDetector(
              onTap: onCancelReply,
              child: const Icon(Icons.close, size: 16),
            )
        ],
      );
  genThumbnail(String path) async {
    final uint8list = await VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxWidth:
          128, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
      quality: 25,
    );
    return uint8list;
  }

  /// Get image URL from content, handling backward compatibility
  /// Supports: full URLs, local file paths, and hash-only values
  String _getImageUrl(String content) {
    if (content.isEmpty || content == 'null') {
      return '';
    }

    // Check if it's already a full URL (new format)
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return content;
    }

    // Check if it's a local file path (old format - backward compatibility)
    if (content.startsWith('/data/') ||
        content.startsWith('/storage/') ||
        (content.contains('/') && !content.startsWith('/'))) {
      return content;
    }

    // Otherwise, assume it's a hash and construct the full URL
    // Remove leading slash if present
    String hash = content.startsWith('/') ? content.substring(1) : content;
    return "${Environment.urlArchivos}$hash";
  }

  /// Build image preview with error handling to prevent exceptions
  /// Handles network URLs, local files, and hash-based URLs
  Widget _buildImagePreview(String imageContent) {
    // Handle null or empty content
    if (imageContent.isEmpty || imageContent == 'null') {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.image_not_supported,
          size: 20,
          color: Colors.grey[600],
        ),
      );
    }
    
    // FIRST: Check if it's already a URL - if so, use it directly (don't try fecha lookup)
    if (imageContent.startsWith('http://') || imageContent.startsWith('https://')) {
      // Already a full URL, skip fecha detection and use it directly
      // Get the proper image URL/path (will return the URL as-is)
      String imageUrl = _getImageUrl(imageContent);
      
      if (imageUrl.isEmpty) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.image_not_supported,
            size: 20,
            color: Colors.grey[600],
          ),
        );
      }
      
      // Display the network image
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          memCacheWidth: 80,
          memCacheHeight: 80,
          placeholder: (context, url) => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('[ReplyMessage] Network image load error: $url - $error');
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.broken_image,
                size: 20,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      );
    }
    
    // SECOND: Check if it's a local file path - if so, use it directly
    if (imageContent.startsWith('/data/') ||
        imageContent.startsWith('/storage/') ||
        (imageContent.contains('/') && imageContent.length > 20)) {
      // It's a local file path, use it directly
      final file = File(imageContent);
      
      if (!file.existsSync()) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.image_not_supported,
            size: 20,
            color: Colors.grey[600],
          ),
        );
      }
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          file,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[ReplyMessage] Local image load error: $imageContent - $error');
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.broken_image,
                size: 20,
                color: Colors.grey[600],
              ),
            );
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    
    // THIRD: Check if content is a PURE fecha (timestamp) - ONLY digits, no other characters
    // A fecha looks like "20251130125412393" - exactly 17 digits, all numeric
    // If socket service couldn't resolve it, we can't display it as an image
    if (RegExp(r'^\d{17}$').hasMatch(imageContent)) {
      debugPrint('[ReplyMessage] Content is a fecha (timestamp), cannot load image: $imageContent');
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.image_not_supported,
          size: 20,
          color: Colors.grey[600],
        ),
      );
    }
    
    // Get the proper image URL/path (for hash-based URLs or other formats)
    String imageUrl = _getImageUrl(imageContent);
    
    // If URL is still empty after processing, show placeholder
    if (imageUrl.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.image_not_supported,
          size: 20,
          color: Colors.grey[600],
        ),
      );
    }

    // Check if it's a network URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          memCacheWidth: 80,
          memCacheHeight: 80,
          placeholder: (context, url) => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('[ReplyMessage] Network image load error: $url - $error');
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.broken_image,
                size: 20,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      );
    }

    // Otherwise, treat as local file path
    final file = File(imageUrl);
    
    if (!file.existsSync()) {
      // File doesn't exist, show placeholder
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.image_not_supported,
          size: 20,
          color: Colors.grey[600],
        ),
      );
    }

    // File exists, load with error handling
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        file,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Handle image loading errors gracefully
          debugPrint('[ReplyMessage] Local image load error: $imageUrl - $error');
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.broken_image,
              size: 20,
              color: Colors.grey[600],
            ),
          );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          // Show loading indicator while image is loading
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
