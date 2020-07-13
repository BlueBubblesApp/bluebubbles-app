import 'dart:async';

import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  VideoViewer({
    Key key,
    this.heroTag,
    this.controller,
  }) : super(key: key);
  final String heroTag;
  final VideoPlayerController controller;

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
          videoProgressStream.sink.add(duration.inMilliseconds.toDouble());
        }
      }
    });
    showPlayPauseOverlay = !widget.controller.value.isPlaying;
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
