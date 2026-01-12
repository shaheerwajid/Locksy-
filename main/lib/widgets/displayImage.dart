import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ImageWidget extends StatelessWidget {
  final String path;
  final String type;
  final VoidCallback? onCancelReply;

  const ImageWidget({
    Key? key,
    required this.type,
    required this.path,
    this.onCancelReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          children: [
            const SizedBox(
              width: 20,
            ),
            Container(
              color: Colors.green,
              width: 4,
            ),
            const SizedBox(width: 8),
            Expanded(child: buildReplyMessage(path, type)),
          ],
        ),
      );

  Widget buildReplyMessage(path, String type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        type == "img"
            ? _buildImagePreview(path)
            : type == "vid"
                ? FutureBuilder(
                    future: genThumbnail(path),
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      if (snapshot.hasData) {
                        print(snapshot.data);
                        return Image.memory(
                          snapshot.data,
                          width: 40,
                          height: 40,
                        );
                        // return _image;
                      } else if (snapshot.hasError) {
                        // print("Error:\n${snapshot.error.toString()}");
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
                              Text("Generating the thumbnail for: $path..."),
                              const SizedBox(
                                height: 10.0,
                              ),
                              const CircularProgressIndicator(),
                            ]);
                      }
                    })
                : Container(),
        // Row(
        //   children: [
        //     Expanded(
        //       child: Text(
        //         basename(path.split("_")[0]),
        //         style: TextStyle(fontWeight: FontWeight.bold),
        //       ),
        //     ),
        //     if (onCancelReply != null)
        //       GestureDetector(
        //         child: Icon(Icons.close, size: 16),
        //         onTap: onCancelReply,
        //       )
        //   ],
        // ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            "${basename(path).substring(0, 10)}...",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

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

  /// Build image preview with error handling to prevent exceptions
  Widget _buildImagePreview(String imagePath) {
    // Check if file exists before trying to load it
    final file = File(imagePath);
    
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
    return Image.file(
      file,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Handle image loading errors gracefully
        debugPrint('[ImageWidget] Image load error: $imagePath - $error');
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
    );
  }
}
