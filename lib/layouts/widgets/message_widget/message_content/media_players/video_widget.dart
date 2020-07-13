import 'dart:async';
import 'dart:io';

import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoWidget extends StatefulWidget {
  VideoWidget({Key key, this.file, this.attachment}) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  VideoPlayerController _controller;

  bool showPlayPauseOverlay = true;
  Timer hideOverlayTimer;

  @override
  void initState() {
    super.initState();
    debugPrint("height ${widget.attachment.width}");
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((value) {
        // _controller.play();
        setState(() {});
      });
    showPlayPauseOverlay = !_controller.value.isPlaying;
    _controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: GestureDetector(
        onTap: () {
          if (_controller.value.isPlaying) {
            _controller.pause();
            setState(() {
              showPlayPauseOverlay = true;
            });
          } else {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => VideoViewer(
                  controller: _controller,
                  heroTag: widget.attachment.guid,
                ),
              ),
            );
          }
        },
        child: _controller.value.aspectRatio != null
            ? Hero(
                tag: widget.attachment.guid,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        children: <Widget>[
                          VideoPlayer(_controller),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: showPlayPauseOverlay ? 1 : 0,
                      duration: Duration(milliseconds: 250),
                      child: Container(
                        decoration: BoxDecoration(
                          color: HexColor('26262a').withOpacity(0.5),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        padding: EdgeInsets.all(10),
                        child: _controller.value.isPlaying
                            ? GestureDetector(
                                child: Icon(
                                  Icons.pause,
                                  color: Colors.white,
                                  size: 45,
                                ),
                                onTap: () {
                                  _controller.pause();
                                  setState(() {
                                    showPlayPauseOverlay = true;
                                  });
                                },
                              )
                            : GestureDetector(
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 45,
                                ),
                                onTap: () {
                                  _controller.play();
                                  setState(() {
                                    showPlayPauseOverlay = false;
                                  });
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              )
            : Container(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
