import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoViewPage extends StatefulWidget {
  const VideoViewPage({super.key, required this.path});
  final String path;

  @override
  State<VideoViewPage> createState() => _VideoViewPageState();
}

class _VideoViewPageState extends State<VideoViewPage> {
  late VideoPlayerController _videoPlayerController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _videoPlayerController = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        setState(() {
          _videoPlayerController.play();
          // _videoPlayerController.setLooping(true);
        });
      });

    _videoPlayerController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _videoPlayerController.removeListener(() {});
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.crop_rotate, size: 27)),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.emoji_emotions_outlined, size: 27),
          ),
          IconButton(onPressed: () {}, icon: Icon(Icons.title, size: 27)),
          IconButton(onPressed: () {}, icon: Icon(Icons.edit)),
        ],
      ),
      body: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height - 180,
                child: _videoPlayerController.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoPlayerController.value.aspectRatio,
                        child: VideoPlayer(_videoPlayerController),
                      )
                    : Container(),
              ),
              Positioned(
                bottom: 0.0,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  child: TextFormField(
                    maxLines: 6,
                    minLines: 1,
                    textAlign: TextAlign.start,
                    decoration: InputDecoration(
                      hintText: "Add caption...",
                      hintStyle: TextStyle(color: Colors.white, fontSize: 17),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 27,
                      ),
                      suffixIcon: CircleAvatar(
                        radius: 27,
                        backgroundColor: Color(0xFF075E54),
                        child: Icon(Icons.check, color: Colors.white, size: 27),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _videoPlayerController.value.isPlaying
                          ? _videoPlayerController.pause()
                          : _videoPlayerController.play();
                    });
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.black38,
                    child: Icon(
                      _videoPlayerController.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
