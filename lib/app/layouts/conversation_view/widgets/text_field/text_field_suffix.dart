
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/effects/send_effect_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/audio_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/send_button.dart';
import 'package:bluebubbles/app/wrappers/cupertino_icon_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:path/path.dart';
import 'package:record/record.dart';
import 'package:system_info2/system_info2.dart';
import 'package:universal_io/io.dart';

class TextFieldSuffix extends StatefulWidget {
  const TextFieldSuffix({
    super.key,
    required this.subjectTextController,
    required this.textController,
    required this.controller,
    required this.recorderController,
    required this.sendMessage,
    this.isChatCreator = false,
  });

  final TextEditingController? subjectTextController;
  final TextEditingController textController;
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
      valueListenables: [widget.textController, widget.subjectTextController].whereNotNull().toList(),
      builder: (context, values, _) {
        return Obx(() {
          bool canSend = widget.textController.text.isNotEmpty ||
              (widget.subjectTextController?.text.isNotEmpty ?? false) ||
              (widget.controller?.pickedAttachments.isNotEmpty ?? false.obs.value);
          bool showRecording = (widget.controller?.showRecording.value ?? false.obs.value) && widget.recorderController != null;
          bool isLinuxArm64 = kIsDesktop && Platform.isLinux && SysInfo.kernelArchitecture == ProcessorArchitecture.arm64;
          return Padding(
            padding: const EdgeInsets.all(3.0),
            child: AnimatedCrossFade(
              crossFadeState: (canSend || isChatCreator) && !showRecording
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 150),
              firstChild: kIsWeb ? const SizedBox(height: 32, width: 32) : TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: !iOS || (iOS && !isChatCreator && !showRecording)
                      ? null
                      : !isChatCreator && !showRecording
                      ? context.theme.colorScheme.outline
                      : context.theme.colorScheme.primary.withOpacity(0.4),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(0),
                  maximumSize: kIsDesktop ? const Size(40, 40) : const Size(32, 32),
                  minimumSize: kIsDesktop ? const Size(40, 40) : const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: isLinuxArm64 ? const SizedBox(height: 40) :
                  !isChatCreator && !showRecording
                  ? CupertinoIconWrapper(icon: Icon(
                    iOS ? CupertinoIcons.waveform : Icons.mic_none,
                    color: iOS ? context.theme.colorScheme.outline : context.theme.colorScheme.properOnSurface,
                    size: iOS ? 24 : 20, // Waveform icon appears smaller, using size 24
                  )) : CupertinoIconWrapper(icon: Icon(
                    iOS ? CupertinoIcons.stop_fill : Icons.stop_circle,
                    color: iOS ? context.theme.colorScheme.primary : context.theme.colorScheme.properOnSurface,
                    size: 15,
                  )),
                onPressed: () async {
                  if (widget.controller == null) return;
                  widget.controller!.showRecording.toggle();
                  if (widget.controller!.showRecording.value) {
                    if (kIsDesktop) {
                      File temp = File(join(fs.appDocDir.path, "temp", "recorder", "${widget.controller!.chat.guid.characters.where((c) => c.isAlphabetOnly || c.isNumericOnly).join()}.m4a"));
                      await RecordPlatform.instance.start(widget.controller!.chat.guid, const RecordConfig(bitRate: 320000), path: temp.path);
                      return;
                    }
                    await widget.recorderController!.record(
                      sampleRate: 44100,
                      bitRate: 320000,
                    );
                  } else {
                    late final String? path;
                    late final PlatformFile file;
                    if (kIsDesktop) {
                      path = await RecordPlatform.instance.stop(widget.controller!.chat.guid);
                      if (path == null) return;
                      final _file = File(path);
                      file = PlatformFile(
                        name: basename(_file.path),
                        path: _file.path,
                        bytes: await _file.readAsBytes(),
                        size: await _file.length(),
                      );
                    } else {
                      path = await widget.recorderController!.stop();
                      if (path == null) return;
                      final _file = File(path);
                      file = PlatformFile(
                        name: basename(_file.path),
                        path: _file.path,
                        bytes: await _file.readAsBytes(),
                        size: await _file.length(),
                      );
                    }
                    await showDialog(
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
                    widget.subjectTextController?.text.trim() ?? "",
                    widget.controller!.replyToMessage?.item1.guid,
                    widget.controller!.replyToMessage?.item2,
                    widget.controller!.chat.guid,
                    widget.sendMessage,
                    widget.textController is MentionTextEditingController ? (widget.textController as MentionTextEditingController).mentionables : [],
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
