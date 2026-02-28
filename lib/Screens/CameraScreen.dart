import 'dart:math';

import 'package:camera/camera.dart';
import 'package:wingbase/Screens/CameraView.dart';
import 'package:wingbase/Screens/VideoView.dart';
import 'package:flutter/material.dart';

List<CameraDescription> cameras = [];

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraController;
  late Future<void> cameraValue;
  bool isRecording = false;
  bool flash = false;
  bool isCameraFront = true;
  double transform = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: true,
    );
    cameraValue = _cameraController.initialize();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _cameraController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder(
            future: cameraValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: CameraPreview(_cameraController),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
          Positioned(
            bottom: 0.0,
            child: Container(
              color: Colors.black,
              width: MediaQuery.of(context).size.width,
              height: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            flash = !flash;
                          });
                          flash
                              ? _cameraController.setFlashMode(FlashMode.torch)
                              : _cameraController.setFlashMode(FlashMode.off);
                        },
                        icon: Icon(
                          flash ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          takePhoto(context);
                        },
                        onLongPress: () {
                          startVideo();
                        },
                        onLongPressUp: () {
                          stopVideo(context);
                        },
                        child: isRecording
                            ? Icon(
                                Icons.radio_button_on,
                                color: Colors.red,
                                size: 80,
                              )
                            : Icon(
                                Icons.panorama_fish_eye,
                                color: Colors.white,
                                size: 70,
                              ),
                      ),
                      IconButton(
                        onPressed: () async {
                          setState(() {
                            isCameraFront = !isCameraFront;
                            transform += pi;
                          });
                          int cameraPos = isCameraFront ? 0 : 1;
                          _cameraController = CameraController(
                            cameras[cameraPos],
                            ResolutionPreset.high,
                          );
                          cameraValue = _cameraController.initialize();
                        },
                        icon: AnimatedRotation(
                          turns: transform / (2 * pi),
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Hold for video, tap for photo",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void takePhoto(BuildContext context) async {
    XFile file = await _cameraController.takePicture();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (builder) => CameraViewPage(path: file.path)),
    );
  }

  void startVideo() async {
    await _cameraController.startVideoRecording();
    setState(() => isRecording = true);
  }

  void stopVideo(BuildContext context) async {
    XFile videofile = await _cameraController.stopVideoRecording();
    setState(() => isRecording = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (builder) => VideoViewPage(path: videofile.path),
      ),
    );
  }
}
