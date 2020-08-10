import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/material.dart';

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
  double progress = 0.0;
  AssetsAudioPlayer player = AssetsAudioPlayer();

  @override
  void initState() {
    super.initState();
    player.open(Audio.file(widget.file.path), autoStart: false);
    player.playlistFinished.listen((event) {
      player.pause();
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 200,
      color: Theme.of(context).accentColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              player.playOrPause();
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  StreamBuilder(
                      stream: player.isPlaying,
                      builder: (context, AsyncSnapshot<bool> snapshot) {
                        return Icon(
                          snapshot.data ? Icons.pause : Icons.play_arrow,
                          color: Colors.blue,
                        );
                      }),
                  Container(
                    width: 27,
                    height: 27,
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 1,
                        color: Colors.blue,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: StreamBuilder(
                        stream: player.currentPosition,
                        builder: (context, AsyncSnapshot<Duration> snapshot) {
                          debugPrint("update duration " +
                              snapshot.data.inSeconds.toString());
                          return CircularProgressIndicator(
                            strokeWidth: snapshot.data.inMilliseconds /
                                player.current.value.audio.duration
                                    .inMilliseconds,
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          );
                        }),
                  )
                ],
              ),
            ),
          )
        ],
      ),

      // Column(
      //   children: <Widget>[
      //     Center(
      //       child: Text(
      //         basename(widget.file.path),
      //         style: Theme.of(context).textTheme.bodyText1,
      //       ),
      //     ),
      //     Spacer(
      //       flex: 1,
      //     ),
      //     Row(
      //       children: <Widget>[
      //         ButtonTheme(
      //           minWidth: 1,
      //           height: 30,
      //           child: RaisedButton(
      //             onPressed: () {
      //               setState(() {
      //                 play = !play;
      //               });
      //             },
      //             child: Icon(
      //               play ? Icons.pause : Icons.play_arrow,
      //               size: 15,
      //             ),
      //           ),
      //         ),
      //         Expanded(
      //           child: Slider(
      //             value: progress,
      //             onChanged: (double value) {
      //               setState(() {
      //                 progress = value;
      //               });
      //             },
      //           ),
      //         )
      //       ],
      //     ),
      //   ],
      // ),
    );
  }
}
