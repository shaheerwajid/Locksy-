import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:CryptoChat/helpers/style.dart';

class ImageWidget extends StatefulWidget {
  final File url;

  const ImageWidget({super.key, 
    required this.url,
  });

  @override
  _ImageWidgetState createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  File? file;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    file = widget.url;
    return Scaffold(
      backgroundColor: transparente,
      appBar: AppBar(
        backgroundColor: transparente,
        shadowColor: transparente,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: amarillo,
          ),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          file!.path.split('/')[file!.path.split('/').length - 1],
          style: TextStyle(color: gris),
        ),
      ),
      body: Center(
        // child: GestureDetector(
        child: Container(
          child: Hero(
            tag: 'imagen',
            child: PhotoView(imageProvider: FileImage(file!)),
          ),
        ),
        //   onVerticalDragUpdate: (details) => Navigator.pop(context),
        // ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
