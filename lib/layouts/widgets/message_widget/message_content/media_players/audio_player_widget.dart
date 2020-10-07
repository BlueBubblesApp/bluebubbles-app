import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';

class AudioPlayerWiget extends StatefulWidget {
  AudioPlayerWiget({
    Key key,
    this.file,
  }) : super(key: key);

  final File file;

  @override
  _AudioPlayerWigetState createState() => _AudioPlayerWigetState();
}

class _AudioPlayerWigetState extends State<AudioPlayerWiget> {
  bool isPlaying = false;
  Duration current;

  AssetsAudioPlayer player = AssetsAudioPlayer();

  @override
  void initState() {
    super.initState();
    player.open(Audio.file(widget.file.path), autoStart: false);

    // Listen for when the audio is finished
    player.playlistFinished.listen((bool finished) async {
      // We only care if it's finished
      if (!finished) return;

      // Restart the clip
      await player.seek(Duration());

      // Set isPlaying and re-render
      isPlaying = false;
      if (this.mounted) setState(() {});
    });

    // Listen for new play status
    player.isPlaying.listen((bool playing) {
      // Update the state with the correct isPlaying bool
      isPlaying = playing;
      if (this.mounted) setState(() {});
    });

    // Update the current position if it's changed
    player.currentPosition.listen((Duration position) {
      if (position.inSeconds != (current ?? Duration()).inSeconds &&
          this.mounted) {
        current = position;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String formatDuration(Duration duration) {
    if (duration == null) return "00:00";
    String minutes = duration.inMinutes.toString();
    String seconds = duration.inSeconds.toString();
    minutes = (minutes.length == 1) ? "0$minutes" : minutes;
    seconds = (seconds.length == 1) ? "0$seconds" : seconds;
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    Playing playing = player.current.value;
    return Container(
        alignment: Alignment.center,
        width: 200,
        color: Theme.of(context).accentColor,
        constraints: new BoxConstraints(maxHeight: 100.0, maxWidth: 200.0),
        child: GestureDetector(
            onTap: () async {
              if (!isPlaying) {
                setState(() {
                  isPlaying = true;
                });
                await player.play();
              } else {
                await player.pause();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Audio Message",
                    style: Theme.of(context).textTheme.bodyText1),
                (isPlaying)
                    ? Icon(Icons.pause_circle_outline,
                        size: 50.0,
                        color: Theme.of(context).textTheme.subtitle1.color)
                    : Icon(Icons.play_circle_filled,
                        size: 50.0,
                        color: Theme.of(context).textTheme.subtitle1.color),
                (playing == null)
                    ? Text("00:00 / 00:00",
                        style: Theme.of(context).textTheme.bodyText1)
                    : Text(
                        (playing.audio.duration == null ||
                                playing.audio.duration.inSeconds == 0)
                            ? formatDuration(current)
                            : "${formatDuration(current)} / ${formatDuration(playing.audio.duration)}",
                        style: Theme.of(context).textTheme.bodyText1)
              ],
            )));
  }
}
