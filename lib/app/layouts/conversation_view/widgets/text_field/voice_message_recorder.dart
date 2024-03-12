import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/colors/voice_message_recorder_colors.dart';
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
                  widget.textFieldSize.width - (widget.samsung ? 0 : 105),
                  widget.textFieldSize.height - 15),
              recorderController: widget.recorderController!,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              waveStyle: WaveStyle(
                waveColor: widget.iOS ? iOSWavesColor : Colors.white,
                waveCap: StrokeCap.square,
                spacing: 4.0,
                showBottom: true,
                extendWaveform: true,
                showMiddleLine: false,
              ),
              decoration: BoxDecoration(
                border: Border.fromBorderSide(BorderSide(
                  color: widget.iOS
                      ? CupertinoDynamicColor.resolve(iOSVoiceRecorderBackgroundColor, context)
                      : context.theme.colorScheme.outline,
                  width: 1,
                )),
                borderRadius: BorderRadius.circular(20),
                color: widget.iOS
                    ? CupertinoDynamicColor.resolve(iOSVoiceRecorderBackgroundColor, context)
                    : context.theme.colorScheme.properSurface,
              ),
            ),
            Center(
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
                      style: TextStyle(color: Color(0xFFff6f61)),
                    );
                  } else {
                    return Container();
                  }
                },
              ),
            ),
          ],
        ));
  }
}
