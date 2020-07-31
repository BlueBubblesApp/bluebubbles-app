import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  VideoViewer({Key key, this.heroTag, this.controller, this.file})
      : super(key: key);
  final String heroTag;
  final VideoPlayerController controller;
  final File file;

  @override
  _VideoViewerState createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  StreamController<double> videoProgressStream = StreamController();
  bool showPlayPauseOverlay = false;
  Timer hideOverlayTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.setVolume(1);
    widget.controller.addListener(() async {
      if (this.mounted && widget.controller.value.isPlaying) {
        Duration duration = await widget.controller.position;
        if (widget.controller.value.duration != null) {
          if (!videoProgressStream.isClosed)
            videoProgressStream.sink.add(duration.inMilliseconds.toDouble());
        }
      }
    });
    showPlayPauseOverlay = !widget.controller.value.isPlaying;
  }

  @override
  void dispose() {
    videoProgressStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                showPlayPauseOverlay = !showPlayPauseOverlay;
                resetTimer();
                setTimer();
              });
            },
            child: Hero(
              tag: widget.heroTag,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height,
                            maxWidth: MediaQuery.of(context).size.width,
                          ),
                          child: AspectRatio(
                            aspectRatio: widget.controller.value.aspectRatio,
                            child: Stack(
                              children: <Widget>[
                                VideoPlayer(widget.controller),
                              ],
                            ),
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
                      child: widget.controller.value.isPlaying
                          ? GestureDetector(
                              child: Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 45,
                              ),
                              onTap: () {
                                widget.controller.pause();
                                setState(() {});
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
                                widget.controller.play();
                                resetTimer();
                                setTimer();
                                setState(() {});
                              },
                            ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 50.0, right: 10),
            child: Align(
              alignment: Alignment.topRight,
              child: CupertinoButton(
                onPressed: () async {
                  if (await Permission.storage.request().isGranted) {
                    await ImageGallerySaver.saveFile(widget.file.path);
                    FlutterToast(context).showToast(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25.0),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25.0),
                              color: Theme.of(context)
                                  .accentColor
                                  .withOpacity(0.1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText1
                                      .color,
                                ),
                                SizedBox(
                                  width: 12.0,
                                ),
                                Text(
                                  "Saved to gallery",
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Icon(
                  Icons.file_download,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          StreamBuilder(
            stream: videoProgressStream.stream,
            builder: (context, AsyncSnapshot<double> snapshot) {
              return AnimatedOpacity(
                opacity: showPlayPauseOverlay ? 1 : 0,
                duration: Duration(milliseconds: 500),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 1 / 10,
                  child: Slider(
                    min: 0,
                    max: widget.controller.value.duration.inMilliseconds
                        .toDouble(),
                    onChangeStart: (value) {
                      widget.controller.pause();
                      videoProgressStream.sink.add(value);
                      widget.controller
                          .seekTo(Duration(milliseconds: value.toInt()));
                      resetTimer();
                    },
                    onChanged: (double value) async {
                      // widget.controller.pause();
                      videoProgressStream.sink.add(value);

                      if ((await widget.controller.position).inMilliseconds !=
                          value.toInt()) {
                        widget.controller
                            .seekTo(Duration(milliseconds: value.toInt()));
                      }
                    },
                    onChangeEnd: (double value) {
                      widget.controller.play();
                      videoProgressStream.sink.add(value);

                      widget.controller
                          .seekTo(Duration(milliseconds: value.toInt()));
                      setTimer();
                    },
                    value: (snapshot.hasData ? snapshot.data : 0.0)
                        .clamp(
                            0, widget.controller.value.duration.inMilliseconds)
                        .toDouble(),
                  ),
                ),
              );
            },
          )
        ],
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
