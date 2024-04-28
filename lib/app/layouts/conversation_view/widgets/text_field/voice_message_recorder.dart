import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


class VoiceMessageRecorder extends StatefulWidget {
  const VoiceMessageRecorder({
    super.key,
    required this.recorderController,
    required this.textFieldSize,
    required this.iOS,
    required this.samsung,
  });

  final RecorderController? recorderController;

  final Size textFieldSize;

  final bool iOS;

  final bool samsung;

  @override
  _VoiceMessageRecorderState createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder> {
  late Stream<Duration> recordingDurationStream;

  @override
  void initState() {
    recordingDurationStream = widget.recorderController!.onCurrentDuration;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(left: 1),
        child: Row(
          children: [
            AudioWaveforms(
              size: Size(
                  widget.textFieldSize.width - getWidth(widget.iOS, widget.samsung),
                  widget.textFieldSize.height - 15),
              recorderController: widget.recorderController!,
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: widget.iOS ? 10 : 15), // need extra spacing in case of iOS for recording duration
              waveStyle: WaveStyle(
                waveColor: widget.iOS ? context.theme.colorScheme.primary : Colors.white,
                waveCap: StrokeCap.square,
                spacing: 4.0,
                showBottom: true,
                extendWaveform: true,
                showMiddleLine: false,
              ),
              decoration: BoxDecoration(
                border: Border.fromBorderSide(BorderSide(
                  color: widget.iOS
                      ? Colors.transparent
                      : context.theme.colorScheme.outline,
                  width: 1,
                )),
                borderRadius: BorderRadius.circular(20),
                color: widget.iOS
                    ? Colors.transparent
                    : context.theme.colorScheme.properSurface,
              ),
            ),
            Visibility(
              visible: widget.iOS,
              child: Center(
              child: StreamBuilder<Duration>(
                stream: recordingDurationStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final minutes = snapshot.data!.inMinutes;

                    final seconds = (snapshot.data!.inSeconds % 60)
                        .toString()
                        .padLeft(2, '0');

                    return Text(
                      '$minutes:$seconds',
                      style: TextStyle(color: context.theme.colorScheme.primary),
                    );
                  } else {
                    return Container();
                  }
                },
              ),
            ),
          ),
          ],
        ));
  }

  int getWidth(bool iOS, bool samsung){
    if (samsung){
      // width for samsung style
      return 0;
    } else if (iOS){
      return 105;
    }
    // for material
    return 80;
  }
}
