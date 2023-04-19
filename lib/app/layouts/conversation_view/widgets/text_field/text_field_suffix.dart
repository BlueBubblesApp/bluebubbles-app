
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/mentionable_text_editing_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/audio_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/send_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/effects/send_effect_picker.dart';
import 'package:bluebubbles/app/wrappers/cupertino_icon_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:universal_io/io.dart';

class TextFieldSuffix extends StatefulWidget {
  const TextFieldSuffix({
    Key? key,
    required this.subjectTextController,
    required this.textController,
    required this.controller,
    required this.recorderController,
    required this.sendMessage,
    this.isChatCreator = false,
  }) : super(key: key);

  final TextEditingController subjectTextController;
  final MentionTextEditingController textController;
  final ConversationViewController? controller;
  final RecorderController? recorderController;
  final Future<void> Function({String? effect}) sendMessage;
  final bool isChatCreator;

  @override
  OptimizedState createState() => _TextFieldSuffixState();
}

class _TextFieldSuffixState extends OptimizedState<TextFieldSuffix> {

  bool get isChatCreator => widget.isChatCreator;

  void deleteAudioRecording(String path) {
    File(path).delete();
  }

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      valueListenables: [widget.textController, widget.subjectTextController],
      builder: (context, values, _) {
        return Obx(() {
          bool canSend = widget.textController.text.isNotEmpty ||
              widget.subjectTextController.text.isNotEmpty ||
              (widget.controller?.pickedAttachments.isNotEmpty ?? false.obs.value);
          bool showRecording = (widget.controller?.showRecording.value ?? false.obs.value) && widget.recorderController != null;
          return Padding(
            padding: const EdgeInsets.all(3.0),
            child: AnimatedCrossFade(
              crossFadeState: (canSend || isChatCreator) && !showRecording
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 150),
              firstChild: kIsDesktop || kIsWeb ? const SizedBox(height: 32, width: 32) : TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: !iOS || (iOS && !isChatCreator && !showRecording)
                      ? null
                      : !isChatCreator && !showRecording
                      ? context.theme.colorScheme.outline
                      : context.theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(0),
                  maximumSize: const Size(32, 32),
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: !isChatCreator && !showRecording
                  ? CupertinoIconWrapper(icon: Icon(
                    iOS ? CupertinoIcons.mic : Icons.mic_none,
                    color: iOS ? context.theme.colorScheme.outline : context.theme.colorScheme.properOnSurface,
                    size: 20,
                  )) : CupertinoIconWrapper(icon: Icon(
                    iOS ? CupertinoIcons.stop_fill : Icons.stop_circle,
                    color: iOS ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface,
                    size: 15,
                  )),
                onPressed: () async {
                  if (widget.controller == null) return;
                  widget.controller!.showRecording.toggle();
                  if (widget.controller!.showRecording.value) {
                    await widget.recorderController!.record(
                      sampleRate: 44100,
                      bitRate: 320000,
                    );
                  } else {
                    final path = await widget.recorderController!.stop();
                    if (path == null) return;
                    final _file = File(path);
                    final file = PlatformFile(
                      name: _file.path.split("/").last,
                      path: _file.path,
                      bytes: await _file.readAsBytes(),
                      size: await _file.length(),
                    );
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: context.theme.colorScheme.properSurface,
                          title: Text("Send it?", style: context.theme.textTheme.titleLarge),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Review your audio snippet before sending it", style: context.theme.textTheme.bodyLarge),
                              Container(height: 10.0),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: context.width * 0.6),
                                child: AudioPlayer(
                                  key: Key("AudioMessage-$path"),
                                  file: file,
                                  attachment: null,
                                ),
                              )
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: Text(
                                  "Discard",
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)
                              ),
                              onPressed: () {
                                deleteAudioRecording(file.path!);
                                Get.back();
                              },
                            ),
                            TextButton(
                              child: Text(
                                  "Send",
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)
                              ),
                              onPressed: () async {
                                await widget.controller!.send(
                                  [file],
                                  "", "", null, null, null, true,
                                );
                                deleteAudioRecording(file.path!);
                                Get.back();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              secondChild: SendButton(
                sendMessage: widget.sendMessage,
                onLongPress: isChatCreator ? () {} : () {
                  if (widget.controller!.scheduledDate.value != null) return;
                  sendEffectAction(
                    context,
                    widget.controller!,
                    widget.textController.text.trim(),
                    widget.subjectTextController.text.trim(),
                    widget.controller!.replyToMessage?.item1.guid,
                    widget.controller!.replyToMessage?.item2,
                    widget.controller!.chat.guid,
                    widget.sendMessage,
                    widget.textController.mentionables,
                  );
                },
              ),
            ),
          );
        });
      },
    );
  }
}
