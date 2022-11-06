import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/picked_attachment.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/send_button.dart';
import 'package:bluebubbles/app/widgets/components/send_effect_picker.dart';
import 'package:bluebubbles/app/widgets/cupertino/custom_cupertino_text_field.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/app/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:universal_io/io.dart';

class ConversationTextField extends CustomStateful<ConversationViewController> {
  final Future<bool> Function(List<PlatformFile> attachments, String text,
      String subject, String? replyToGuid, String? effectId) onSend;

  ConversationTextField({
    Key? key,
    required this.onSend,
    required super.parentController,
  }) : super(key: key);

  static ConversationTextFieldState? of(BuildContext context) {
    return context.findAncestorStateOfType<ConversationTextFieldState>();
  }

  @override
  ConversationTextFieldState createState() => ConversationTextFieldState();
}

class ConversationTextFieldState extends CustomState<ConversationTextField, void, ConversationViewController> with TickerProviderStateMixin {
  final focusNode = FocusNode();
  final subjectFocusNode = FocusNode();
  late final textController = TextEditingController(text: chat.textFieldText);
  final subjectTextController = TextEditingController();
  final recorderController = RecorderController();

  bool showAttachmentPicker = false;

  Chat get chat => controller.chat;
  String get chatGuid => chat.guid;

  @override
  void initState() {
    super.initState();
    forceDelete = false;
    if (ss.settings.autoOpenKeyboard.value) {
      updateObx(() {
        focusNode.requestFocus();
      });
    }

    focusNode.addListener(() => focusListener(false));
    subjectFocusNode.addListener(() => focusListener(true));
  }

  void focusListener(bool subject) async {
    final _focusNode = subject ? subjectFocusNode : focusNode;
    if (_focusNode.hasFocus && showAttachmentPicker) {
      setState(() {
        showAttachmentPicker = !showAttachmentPicker;
      });
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    subjectFocusNode.dispose();
    textController.dispose();
    subjectTextController.dispose();
    recorderController.dispose();

    chat.save(updateTextFieldText: true, updateTextFieldAttachments: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.square_arrow_up_on_square_fill, color: context.theme.colorScheme.outline, size: 28),
                      onPressed: () async {
                        if (kIsDesktop) {
                          final res = await FilePicker.platform.pickFiles(withReadStream: true, allowMultiple: true);
                          if (res == null || res.files.isEmpty || res.files.first.readStream == null) return;

                          for (pf.PlatformFile e in res.files) {
                            if (e.size / 1024000 > 1000) {
                              showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                              continue;
                            }
                            controller.pickedAttachments.add(PlatformFile(
                              path: e.path,
                              name: e.name,
                              size: e.size,
                              bytes: await readByteStream(e.readStream!),
                            ));
                          }
                          Get.back();
                        } else if (kIsWeb) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("What would you like to do?", style: context.theme.textTheme.titleLarge),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ListTile(
                                    title: Text("Upload file", style: Theme.of(context).textTheme.bodyLarge),
                                    onTap: () async {
                                      final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
                                      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                                      for (pf.PlatformFile e in res.files) {
                                        if (e.size / 1024000 > 1000) {
                                          showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                                          continue;
                                        }
                                        controller.pickedAttachments.add(PlatformFile(
                                          path: null,
                                          name: e.name,
                                          size: e.size,
                                          bytes: e.bytes!,
                                        ));
                                      }
                                      Get.back();
                                    },
                                  ),
                                  ListTile(
                                    title: Text("Send location", style: Theme.of(context).textTheme.bodyLarge),
                                    onTap: () async {
                                      Share.location(chat);
                                      Get.back();
                                    },
                                  ),
                                ]
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                            )
                          );
                        } else {
                          if (!showAttachmentPicker) {
                            focusNode.unfocus();
                            subjectFocusNode.unfocus();
                          }
                          setState(() {
                            showAttachmentPicker = !showAttachmentPicker;
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: _TextFields(
                        chat: chat,
                        subjectFocusNode: subjectFocusNode,
                        subjectTextController: subjectTextController,
                        focusNode: focusNode,
                        textController: textController,
                        controller: controller,
                        recorderController: recorderController,
                      ),
                    )
                  ]
                ),
                Obx(() => AnimatedContainer(
                  height: 50,
                  duration: Duration(milliseconds: 500),
                  curve: controller.showRecording.value ? Curves.easeOutBack : Curves.easeOut,
                  width: controller.showRecording.value ? 250 : 0,
                  child: AudioWaveforms(
                    size: Size(220, 40),
                    recorderController: recorderController,
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                    waveStyle: WaveStyle(
                      waveColor: Colors.white,
                      waveCap: StrokeCap.square,
                      spacing: 4.0,
                      showBottom: true,
                      extendWaveform: true,
                      showMiddleLine: false,
                    ),
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(BorderSide(
                        color: context.theme.colorScheme.outline,
                        width: 1,
                      )),
                      borderRadius: BorderRadius.circular(20),
                      color: context.theme.colorScheme.properSurface,
                    ),
                  ),
                )),
              ],
            ),
            AnimatedSize(
              duration: Duration(milliseconds: 250),
              curve: Curves.easeIn,
              alignment: Alignment.bottomCenter,
              child: !showAttachmentPicker
                  ? SizedBox(width: ns.width(context))
                  : AttachmentPicker(
                      controller: controller,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextFields extends StatelessWidget {
  const _TextFields({
    Key? key,
    required this.chat,
    required this.subjectFocusNode,
    required this.subjectTextController,
    required this.focusNode,
    required this.textController,
    required this.controller,
    required this.recorderController,
  }) : super(key: key);

  final Chat chat;
  final FocusNode subjectFocusNode;
  final TextEditingController subjectTextController;
  final FocusNode focusNode;
  final TextEditingController textController;
  final ConversationViewController controller;
  final RecorderController recorderController;

  void deleteAudioRecording(String path) {
    controller.audioPlayers[path]?.item1.dispose();
    controller.audioPlayers[path]?.item2.pause();
    controller.audioPlayers.removeWhere((key, _) => key == path);
    File(path).delete();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(
              color: context.theme.colorScheme.properSurface,
              width: 1.5,
            )),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSize(
            duration: Duration(milliseconds: 400),
            alignment: Alignment.bottomCenter,
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  if (controller.pickedAttachments.isNotEmpty) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 150,
                        minHeight: 150,
                      ),
                      child: CustomScrollView(
                        physics: ThemeSwitcher.getScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        slivers: [
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return PickedAttachment(
                                  data: controller.pickedAttachments[index],
                                  controller: controller,
                                );
                              },
                              childCount: controller.pickedAttachments.length,
                            ),
                          )
                        ],
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
                Obx(() {
                  if (controller.pickedAttachments.isNotEmpty) {
                    return Divider(
                      height: 1.5,
                      thickness: 1.5,
                      color: context.theme.colorScheme.properSurface,
                    );
                  }
                  return const SizedBox.shrink();
                }),
                if (ss.settings.enablePrivateAPI.value &&
                    ss.settings.privateSubjectLine.value &&
                    chat.isIMessage)
                  CustomCupertinoTextField(
                    textCapitalization: TextCapitalization.sentences,
                    focusNode: subjectFocusNode,
                    autocorrect: true,
                    controller: subjectTextController,
                    scrollPhysics: const CustomBouncingScrollPhysics(),
                    style: context.theme.extension<BubbleText>()!.bubbleText.copyWith(fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.multiline,
                    maxLines: 14,
                    minLines: 1,
                    placeholder: "Subject",
                    padding: const EdgeInsets.all(10),
                    placeholderStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(
                        color: context.theme.colorScheme.outline,
                        fontWeight: FontWeight.bold
                    ),
                    autofocus: kIsWeb || kIsDesktop,
                    enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                    textInputAction: TextInputAction.next,
                    cursorColor: context.theme.colorScheme.primary,
                    cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
                    decoration: const BoxDecoration(),
                    onLongPressStart: () {
                      Feedback.forLongPress(context);
                    },
                    onTap: () {
                      HapticFeedback.selectionClick();
                    },
                    onSubmitted: (String value) {
                      focusNode.requestFocus();
                    },
                    // onContentCommitted: onContentCommit,
                  ),
                if (ss.settings.enablePrivateAPI.value &&
                    ss.settings.privateSubjectLine.value &&
                    chat.isIMessage)
                  Divider(
                    height: 1.5,
                    thickness: 1.5,
                    indent: 10,
                    color: context.theme.colorScheme.properSurface,
                  ),
                CustomCupertinoTextField(
                  textCapitalization: TextCapitalization.sentences,
                  focusNode: focusNode,
                  autocorrect: true,
                  controller: textController,
                  scrollPhysics: const CustomBouncingScrollPhysics(),
                  style: context.theme.extension<BubbleText>()!.bubbleText,
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                  placeholder: ss.settings.recipientAsPlaceholder.value == true
                      ? chat.getTitle()
                      : chat.isTextForwarding
                          ? "Text Forwarding"
                          : "iMessage",
                  padding: const EdgeInsets.all(10),
                  placeholderStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                  autofocus: kIsWeb || kIsDesktop,
                  enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                  textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                    ? TextInputAction.send
                    : TextInputAction.newline,
                  cursorColor: context.theme.colorScheme.primary,
                  cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
                  decoration: const BoxDecoration(),
                  onLongPressStart: () {
                    Feedback.forLongPress(context);
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  onSubmitted: (String value) {
                    /*focusNode.requestFocus();
                    if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                    sendMessage();*/
                  },
                  // onContentCommitted: onContentCommit,
                  suffix: MultiValueListenableBuilder(
                    valueListenables: [textController, subjectTextController],
                    builder: (context, values, _) {
                      return Obx(() {
                        bool canSend = textController.text.isNotEmpty ||
                            subjectTextController.text.isNotEmpty ||
                            controller.pickedAttachments.isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: AnimatedCrossFade(
                            crossFadeState: canSend
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 150),
                            firstChild: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: !controller.showRecording.value
                                    ? context.theme.colorScheme.outline : context.theme.colorScheme.primary,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(0),
                                maximumSize: Size(32, 32),
                                minimumSize: Size(32, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Obx(() => !controller.showRecording.value ? const Icon(
                                CupertinoIcons.waveform,
                                color: Colors.white,
                                size: 25,
                              ) : Icon(
                                CupertinoIcons.stop,
                                color: context.theme.colorScheme.onPrimary,
                                size: 25,
                              )),
                              onPressed: () async {
                                controller.showRecording.toggle();
                                if (controller.showRecording.value) {
                                  await recorderController.record();
                                } else {
                                  final path = await recorderController.stop();
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
                                            AudioPlayerWidget(
                                              key: Key("AudioMessage-$path"),
                                              file: file,
                                              context: context,
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
                                            }
                                          ),
                                          TextButton(
                                            child: Text(
                                              "Send",
                                              style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)
                                            ),
                                            onPressed: () async {
                                              // await widget.onSend([file], "", "", null, null);
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
                              onLongPress: () {
                                /*sendEffectAction(
                                  context,
                                  this,
                                  textController.text.trim(),
                                  subjectTextController.text.trim(),
                                  null,
                                  chatGuid,
                                  sendMessage,
                                );*/
                              },
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      materialSkin: TextField(),
    );
  }
}
