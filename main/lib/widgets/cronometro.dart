import 'dart:async';
import 'package:flutter/material.dart';

class Cronometro extends StatefulWidget {
  const Cronometro({super.key});

  @override
  _CronometroState createState() => _CronometroState();
}

class _CronometroState extends State<Cronometro> {
  bool isStart = true;
  String _stopwatchText = '00:00';
  final _stopWatch = Stopwatch();
  final _timeout = const Duration(seconds: 1);
  Timer? timer;

  @override
  void initState() {
    _startStopButtonPressed();
    super.initState();
  }

  @override
  void dispose() {
    _stopWatch.stop();
    timer!.cancel();

    super.dispose();
  }

  void _startTimeout() {
    timer = Timer(_timeout, _handleTimeout);
  }

  String get duracion {
    return _stopwatchText;
  }

  void _handleTimeout() {
    if (_stopWatch.isRunning) {
      _startTimeout();
    }
    setState(() {
      _setStopwatchText();
    });
  }

  void _startStopButtonPressed() {
    setState(() {
      if (_stopWatch.isRunning) {
        isStart = true;
        _stopWatch.stop();
      } else {
        isStart = false;
        _stopWatch.start();
        _startTimeout();
      }
    });
  }

  void _setStopwatchText() {
    _stopwatchText =
        '${(_stopWatch.elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(_stopWatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _stopwatchText,
    );
  }
}
