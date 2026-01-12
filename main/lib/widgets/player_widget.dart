import 'package:CryptoChat/providers/ChatProvider.dart';
import 'package:CryptoChat/providers/GroupProvider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:CryptoChat/helpers/funciones.dart';

import 'package:CryptoChat/helpers/style.dart';
import 'package:provider/provider.dart';

class PlayerWidget extends StatefulWidget {
  final String url;
  final String? content;
  final AudioPlayer audioPlayer;
  final bool isGpr;
  const PlayerWidget({
    super.key,
    required this.url,
    this.content,
    required this.isGpr,
    required this.audioPlayer,
  });

  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String? ruta;
  String? tiempo;
  // AudioPlayer audioPlayer AudioPlayer();
  PlayerState playerState = PlayerState.paused;
  bool _initialized = false;

  bool _isPlay = false;

  Duration? duration;
  Duration? position = const Duration(seconds: 0);

  @override
  void initState() {
    _initAudioPlayer();
    super.initState();
  }

  void _initAudioPlayer() {
    if (_initialized) return;
    _initialized = true;

    // Ensure completion event stops playback and resets to start
    widget.audioPlayer.setReleaseMode(ReleaseMode.stop);

    widget.audioPlayer.onDurationChanged.listen((Duration d) {
      if (mounted) {
        setState(() {
          duration = d;
        });
      }
    });

    widget.audioPlayer.onPositionChanged.listen((Duration p) {
      if (mounted) {
        setState(() {
          position = p;
          // Force rebuild to update slider/circle position
        });
      }
    });

    widget.audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (mounted) {
        setState(() {
          playerState = s;
          if (s == PlayerState.stopped || s == PlayerState.paused) {
            _isPlay = false;
          } else if (s == PlayerState.playing) {
            _isPlay = true;
          }
        });
      }
    });
    widget.audioPlayer.onPlayerComplete.listen((event) {
      _onComplete();
      if (mounted) {
        setState(() {
          position = duration;
          _isPlay = false;
        });
      }
    });

    // audioPlayer!.onPlayerError.listen((msg) {
    //   print('AudioPlayer Error : $msg');
    //   if (mounted)
    //     setState(() {
    //       playerState = PlayerState.paused;
    //       duration = Duration(seconds: 0);
    //       position = Duration(seconds: 0);
    //     });
    //});
  }

  // _getDuration() async {
  //   File file = File(widget.url);
  //   var value = file.existsSync();
  //   // var value = await info.getMediaInfo(widget.url);
  //   print(value);
  // }

  @override
  Widget build(BuildContext context) {
    ruta = widget.url;
    tiempo = widget.content;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            !_isPlay
                ? GestureDetector(
                    onTap: () {
                      _play();
                    },
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 35,
                      color: primary,
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      _pause();
                    },
                    child: Icon(
                      Icons.pause_rounded,
                      size: 33,
                      color: primary,
                    ),
                  ),
            Container(
              child: Text(
                _isPlay ? formatTiempo(position!) : tiempo!,
                style: TextStyle(color: gris),
              ),
            ),
            SizedBox(
              height: 10,
              width: MediaQuery.of(context).size.width * 0.45,
              child: Slider(
                activeColor: primary,
                inactiveColor: gris.withOpacity(0.5),
                onChanged: (value) {
                  if (duration == null || duration!.inMilliseconds == 0) return;
                  final res = value * duration!.inMilliseconds;
                  setState(() {
                    position = Duration(milliseconds: res.round());
                  });
                },
                onChangeEnd: (value) {
                  if (duration == null || duration!.inMilliseconds == 0) return;
                  final res = value * duration!.inMilliseconds;
                  widget.audioPlayer.seek(Duration(milliseconds: res.round()));
                },
                value: _progress(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _play() async {
    if (widget.isGpr) {
      Provider.of<GroupChatProvider>(context, listen: false).stopAllPlayers();
    } else {
      Provider.of<ChatProvider>(context, listen: false).stopAllPlayers();
    }
    _initAudioPlayer();
    await widget.audioPlayer.play(DeviceFileSource(ruta!));

    tiempo = formatTiempo(position ?? Duration.zero);
    if (mounted) setState(() => _isPlay = true);
  }

  _pause() async {
    tiempo = formatTiempo(position!);
    await widget.audioPlayer.pause();

    if (mounted) setState(() => _isPlay = false);
  }

  _onComplete() async {
    widget.audioPlayer.seek(Duration.zero);
    position = Duration.zero;
    tiempo = formatTiempo(duration ?? Duration.zero);
    if (mounted) setState(() => _isPlay = false);
  }

  double _progress() {
    if (position == null || duration == null || duration!.inMilliseconds == 0) {
      return 0;
    }
    final posMs = position!.inMilliseconds.clamp(0, duration!.inMilliseconds);
    return posMs / duration!.inMilliseconds;
  }

  stopALL() async {
    await widget.audioPlayer.stop();
  }

  @override
  void dispose() {
    stopALL();
    // Do NOT dispose shared audioPlayer here; it is managed by providers
    super.dispose();
  }
}
