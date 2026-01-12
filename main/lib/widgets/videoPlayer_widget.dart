import 'package:CryptoChat/helpers/style.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class VideoWidget extends StatefulWidget {
  final String path;
  const VideoWidget({super.key, required this.path});

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  String? data;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    data = widget.path;
    //  print('VideoPlayer1: ' + this.data!);
    _controller = VideoPlayerController.network(data!)
      ..initialize().then((_) => setState(() {}));
    _autoPlay();
  }

  _autoPlay() {
    _controller!.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    data = widget.path;
    return Scaffold(
      backgroundColor: drawer_white,
      appBar: AppBar(
        backgroundColor: drawer_light_white,
        shadowColor: drawer_light_white,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: gris,
          ),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          data!.split('/')[data!.split('/').length - 1],
          style: TextStyle(color: gris),
        ),
      ),
      body: Center(
        child: Hero(
          tag: 'video',
          child: SizedBox(
            width: 200,
            height: 200,
            child: GestureDetector(
              child: Stack(
                children: <Widget>[
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width ?? 0,
                        height: _controller!.value.size.height ?? 0,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  _controller!.value.isPlaying
                      ? const SizedBox()
                      : Align(
                          child: Container(
                            decoration: BoxDecoration(
                              color: grisClaro.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: primary,
                              size: 100,
                            ),
                          ),
                        )
                ],
              ),
              onTap: () {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
                setState(() {});
                // await OpenFile.open(data);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller!.dispose();
  }
}
