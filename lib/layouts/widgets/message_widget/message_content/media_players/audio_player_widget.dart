import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class AudioPlayerWiget extends StatefulWidget {
  AudioPlayerWiget({
    Key key,
    this.file,
    this.attachment,
  }) : super(key: key);

  final File file;
  final Attachment attachment;

  @override
  _AudioPlayerWigetState createState() => _AudioPlayerWigetState();
}

class _AudioPlayerWigetState extends State<AudioPlayerWiget> {
  bool play = false;
  double progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return AudioWidget.file(
      child: Container(
        height: 100,
        width: 200,
        child: Column(
          children: <Widget>[
            Center(
              child: Text(
                basename(widget.file.path),
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
            Spacer(
              flex: 1,
            ),
            Row(
              children: <Widget>[
                ButtonTheme(
                  minWidth: 1,
                  height: 30,
                  child: RaisedButton(
                    onPressed: () {
                      setState(() {
                        play = !play;
                      });
                    },
                    child: Icon(
                      play ? Icons.pause : Icons.play_arrow,
                      size: 15,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: progress,
                    onChanged: (double value) {
                      setState(() {
                        progress = value;
                      });
                    },
                  ),
                )
              ],
            ),
          ],
        ),
      ),
      path: widget.file.path,
      play: play,
      onPositionChanged: (current, total) {
        debugPrint("${current.inMilliseconds / total.inMilliseconds}");
        setState(() {
          progress = current.inMilliseconds / total.inMilliseconds;
        });
      },
      onFinished: () {
        debugPrint("on finished");
        setState(() {
          play = false;
        });
      },
    );
  }
}
