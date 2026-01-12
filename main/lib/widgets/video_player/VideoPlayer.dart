import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.url,
    required this.dataSourceType,
  });

  final String url;

  final DataSourceType dataSourceType;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Initialize video controller based on data source type
      if (widget.dataSourceType == DataSourceType.file) {
        // Check if file exists for local files
        final file = File(widget.url);
        if (!file.existsSync()) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Video file not found: ${widget.url}';
          });
          return;
        }
        _videoPlayerController = VideoPlayerController.file(file);
      } else if (widget.dataSourceType == DataSourceType.network) {
        // For network URLs
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
        );
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unsupported data source type';
        });
        return;
      }

      await _videoPlayerController!.initialize();

      if (!mounted) return;

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          autoPlay: false,
          looping: false,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );
      });
    } catch (e) {
      print('[VideoPlayerView] Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Video Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading video',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Video'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_chewieController == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Video'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: Chewie(
              key: ValueKey(widget.url),
              controller: _chewieController!,
            ),
          ),
        ],
      ),
    );
  }
}
