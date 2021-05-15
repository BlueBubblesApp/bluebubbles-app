import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  VideoViewer({Key key, @required this.file, @required this.attachment, this.showInteractions}) : super(key: key);
  final File file;
  final Attachment attachment;
  final bool showInteractions;

  @override
  _VideoViewerState createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  StreamController<double> videoProgressStream = StreamController();
  bool showPlayPauseOverlay = false;
  Timer hideOverlayTimer;
  VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = new VideoPlayerController.file(widget.file);
    controller.setVolume(1);
    controller.addListener(() async {
      if (this.mounted && controller.value.isPlaying) {
        Duration duration = await controller.position;
        if (controller.value.duration != null) {
          if (!videoProgressStream.isClosed) videoProgressStream.sink.add(duration.inMilliseconds.toDouble());
        }
      }
    });
    showPlayPauseOverlay = !controller.value.isPlaying;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await controller.initialize();
    if (this.mounted) setState(() {});
  }

  @override
  void dispose() {
    videoProgressStream.close();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> interactives = [];
    if (widget.showInteractions != null) {
      interactives.addAll([
        Padding(
          padding: EdgeInsets.only(top: 50.0, right: 10),
          child: Align(
            alignment: Alignment.topRight,
            child: CupertinoButton(
              onPressed: () async {
                await AttachmentHelper.saveToGallery(context, widget.file);
              },
              child: Icon(
                Icons.file_download,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 50.0, right: 70),
          child: Align(
            alignment: Alignment.topRight,
            child: CupertinoButton(
              onPressed: () async {
                // final Uint8List bytes = await widget.file.readAsBytes();
                await Share.file(
                  "Shared ${widget.attachment.mimeType.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                  widget.attachment.transferName,
                  widget.file.path,
                  widget.attachment.mimeType,
                );
              },
              child: Icon(
                Icons.share,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ]);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!this.mounted) return;

                setState(() {
                  showPlayPauseOverlay = !showPlayPauseOverlay;
                  resetTimer();
                  setTimer();
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height,
                          maxWidth: MediaQuery.of(context).size.width,
                        ),
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: Stack(
                            children: <Widget>[
                              VideoPlayer(controller),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                      child: controller.value.isPlaying
                          ? GestureDetector(
                              child: Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 45,
                              ),
                              onTap: () {
                                controller.pause();
                                if (this.mounted) setState(() {});
                                resetTimer();
                                setTimer();
                              },
                            )
                          : GestureDetector(
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 45,
                              ),
                              onTap: () {
                                controller.play();
                                resetTimer();
                                setTimer();
                                if (this.mounted) setState(() {});
                              },
                            ),
                    ),
                  )
                ],
              ),
            ),
            ...interactives,
            controller.value.duration != null
                ? StreamBuilder(
                    stream: videoProgressStream.stream,
                    builder: (context, AsyncSnapshot<double> snapshot) {
                      return AnimatedOpacity(
                        opacity: showPlayPauseOverlay ? 1 : 0,
                        duration: Duration(milliseconds: 500),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 1 / 10,
                          child: Slider(
                            min: 0,
                            max: controller.value.duration.inMilliseconds.toDouble(),
                            onChangeStart: (value) {
                              controller.pause();
                              videoProgressStream.sink.add(value);
                              controller.seekTo(Duration(milliseconds: value.toInt()));
                              resetTimer();
                            },
                            onChanged: (double value) async {
                              // controller.pause();
                              videoProgressStream.sink.add(value);

                              if ((await controller.position).inMilliseconds != value.toInt()) {
                                controller.seekTo(Duration(milliseconds: value.toInt()));
                              }
                            },
                            onChangeEnd: (double value) {
                              controller.play();
                              videoProgressStream.sink.add(value);

                              controller.seekTo(Duration(milliseconds: value.toInt()));
                              setTimer();
                            },
                            value: (snapshot.hasData ? snapshot.data : 0.0)
                                .clamp(0, controller.value.duration.inMilliseconds)
                                .toDouble(),
                          ),
                        ),
                      );
                    },
                  )
                : Container()
          ],
        ),
      ),
    );
  }

  void resetTimer() {
    if (hideOverlayTimer != null) hideOverlayTimer.cancel();
  }

  void setTimer() {
    if (showPlayPauseOverlay) {
      hideOverlayTimer = Timer(Duration(seconds: 3), () {
        if (this.mounted)
          setState(() {
            showPlayPauseOverlay = false;
          });
      });
    }
  }
}
