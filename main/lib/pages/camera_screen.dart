
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SimpleCameraScreen extends StatefulWidget {
  const SimpleCameraScreen({super.key});

  @override
  SimpleCameraScreenState createState() => SimpleCameraScreenState();
}

class SimpleCameraScreenState extends State<SimpleCameraScreen> {
  late CameraController _cameraController;
  late List<CameraDescription> cameras;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first, // Use the first available camera
      ResolutionPreset.high,
    );

    await _cameraController.initialize();
    setState(() {
      isInitialized = true;
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> takePhoto() async {
    try {
      final XFile photo = await _cameraController.takePicture();
      Navigator.pop(context, File(photo.path)); // Return the photo file
    } catch (e) {
      print('Error taking photo: $e');
    }
  }

  Future<void> recordVideo() async {
    try {
      await _cameraController.startVideoRecording();
    } catch (e) {
      print('Error starting video recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      // Define the video file path with a .mp4 extension
      final videoPath =
          '${directory.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Stop the video recording and get the temporary video file
      final XFile video = await _cameraController.stopVideoRecording();

      // Create a File from the temporary video XFile
      final File videoFile = File(videoPath);

      // Write the content of the temporary video file to the new location
      await videoFile.writeAsBytes(await video.readAsBytes());

      // Create a new XFile from the saved video file path
      final XFile savedVideo = XFile(videoFile.path);

      // Use addPostFrameCallback to call Navigator.pop after the current frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context, savedVideo); // Return the new XFile
      });
    } catch (e) {
      print('Error stopping video recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: takePhoto,
                  child: const Text('Take Photo'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () async {
                    await recordVideo();
                    await Future.delayed(const Duration(
                        seconds: 5)); // Simulate a 5-second video
                    await stopRecording();
                  },
                  child: const Text('Record Video'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
