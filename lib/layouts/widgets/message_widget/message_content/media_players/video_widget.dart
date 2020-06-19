import 'dart:io';

import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flick_video_player/flick_video_player.dart';
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
  FlickManager _flickManager;
  @override
  void initState() {
    super.initState();
    _flickManager = FlickManager(
        autoPlay: false,
        videoPlayerController: VideoPlayerController.file(widget.file));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: FlickVideoPlayer(
        flickManager: _flickManager,
      ),
    );
  }

  @override
  void dispose() {
    if (_flickManager != null) _flickManager.dispose();
    super.dispose();
  }
}
