import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/picked_attachment.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/send_button.dart';
import 'package:bluebubbles/app/widgets/components/send_effect_picker.dart';
import 'package:bluebubbles/app/widgets/cupertino/custom_cupertino_text_field.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/app/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:emojis/emoji.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

// todo list
// reimplement gif / location button DONE
// reimplement emoji insertion DONE
// reimplement viewing picked in full screen DONE
// fix bugs with picked not disappearing properly
// reimplement focus listener for keyboard shortcuts DONE
// reimplement typing indicator DONE
// reimplement event handlers DONE
// reimplement reply to message
// reimplement send
// reimplement effect picker

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
  late final textController = TextEditingController(text: chat.textFieldText);
  final subjectTextController = TextEditingController();
  final recorderController = RecorderController();
  // emoji
  final Map<String, Emoji> emojiNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.shortName, e)));
  final Map<String, Emoji> emojiFullNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.name, e)));

  bool showAttachmentPicker = false;
  // typing indicators
  String oldText = "";
  Timer? _debounceTyping;
  // emoji
  String oldEmojiText = "";

  Chat get chat => controller.chat;
  String get chatGuid => chat.guid;

  @override
  void initState() {
    super.initState();
    forceDelete = false;
    if (ss.settings.autoOpenKeyboard.value) {
      updateObx(() {
        getDraftAttachments();
        controller.focusNode.requestFocus();
      });
    }

    controller.focusNode.addListener(() => focusListener(false));
    controller.subjectFocusNode.addListener(() => focusListener(true));

    textController.addListener(() => textListener(false));
    subjectTextController.addListener(() => textListener(true));
  }

  void getDraftAttachments() async {
    if (chat.textFieldAttachments.isNotEmpty) {
      for (String s in chat.textFieldAttachments) {
        final file = File(s);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          controller.pickedAttachments.add(PlatformFile(
            name: file.path.split("/").last,
            bytes: bytes,
            size: bytes.length,
            path: s,
          ));
        }
      }
    }
  }

  void focusListener(bool subject) async {
    final _focusNode = subject ? controller.subjectFocusNode : controller.focusNode;
    if (_focusNode.hasFocus && showAttachmentPicker) {
      setState(() {
        showAttachmentPicker = !showAttachmentPicker;
      });
    }
    // remove emoji picker if no field is focused
    if (!controller.subjectFocusNode.hasFocus && !controller.focusNode.hasFocus) {
      controller.emojiMatches.value = [];
      controller.emojiSelectedIndex.value = 0;
    }
  }

  void textListener(bool subject) {
    if (!subject) {
      chat.textFieldText = textController.text;
    }
    // typing indicators
    final newText = "${subjectTextController.text}\n${textController.text}";
    if (newText != oldText) {
      _debounceTyping?.cancel();
      oldText = newText;
      // don't send a bunch of duplicate events for every typing change
      if (_debounceTyping == null) {
        socket.sendMessage("started-typing", {"chatGuid": chatGuid});
      }
      _debounceTyping = Timer(const Duration(seconds: 3), () {
        socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
        _debounceTyping = null;
      });
    }
    // emoji picker
    final _controller = subject ? subjectTextController : textController;
    final newEmojiText = _controller.text;
    if (newEmojiText.contains(":") && newEmojiText != oldEmojiText) {
      oldEmojiText = newEmojiText;
      final regExp = RegExp(r"(?<=^| |\n):[^: \n]{2,}((?=[ \n]|$)|:)", multiLine: true);
      final matches = regExp.allMatches(newEmojiText);
      List<Emoji> allMatches = [];
      String emojiName = "";
      if (matches.isNotEmpty && matches.first.start < _controller.selection.start) {
        RegExpMatch match = matches.lastWhere((m) => m.start < _controller.selection.start);
        if (newEmojiText[match.end - 1] == ":") {
          // Full emoji text (do not search for partial matches)
          emojiName = newEmojiText.substring(match.start + 1, match.end - 1).toLowerCase();
          if (emojiNames.keys.contains(emojiName)) {
            allMatches = [Emoji.byShortName(emojiName)!];
            // We can replace the :emoji: with the actual emoji here
            String _text = newEmojiText.substring(0, match.start) + allMatches.first.char + newEmojiText.substring(match.end);
            _controller.text = _text;
            _controller.selection = TextSelection.fromPosition(TextPosition(offset: match.start + allMatches.first.char.length));
            allMatches.clear();
          } else {
            allMatches = Emoji.byKeyword(emojiName).toList();
          }
        } else if (match.end >= _controller.selection.start) {
          emojiName = newEmojiText.substring(match.start + 1, match.end).toLowerCase();
          Iterable<Emoji> emojiExactlyMatches = emojiNames.containsKey(emojiName) ? [emojiNames[emojiName]!] : [];
          Iterable<String> emojiNameMatches = emojiNames.keys.where((name) => name.startsWith(emojiName));
          Iterable<String> emojiNameAnywhereMatches = emojiNames.keys
              .where((name) => name.substring(1).contains(emojiName))
              .followedBy(
              emojiFullNames.keys.where((name) => name.contains(emojiName))); // Substring 1 to avoid dupes
          Iterable<Emoji> emojiMatches =
              emojiNameMatches.followedBy(emojiNameAnywhereMatches).map((n) => emojiNames[n] ?? emojiFullNames[n]!);
          Iterable<Emoji> keywordMatches = Emoji.byKeyword(emojiName);
          allMatches = emojiExactlyMatches.followedBy(emojiMatches.followedBy(keywordMatches)).toSet().toList();
          // Remove tone variations
          List<Emoji> withoutTones = allMatches.toList();
          withoutTones.removeWhere((e) => e.shortName.contains("_tone"));
          if (withoutTones.isNotEmpty) {
            allMatches = withoutTones;
          }
        }
        Logger.info("${allMatches.length} matches found for: $emojiName");
      }
      if (allMatches.isNotEmpty) {
        controller.emojiMatches.value = allMatches;
        controller.emojiSelectedIndex.value = 0;
      } else {
        controller.emojiMatches.value = [];
        controller.emojiSelectedIndex.value = 0;
      }
    } else {
      controller.emojiMatches.value = [];
      controller.emojiSelectedIndex.value = 0;
    }
  }

  @override
  void dispose() {
    controller.focusNode.dispose();
    controller.subjectFocusNode.dispose();
    textController.dispose();
    subjectTextController.dispose();
    recorderController.dispose();
    socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});

    chat.textFieldAttachments = controller.pickedAttachments.where((e) => e.path != null).map((e) => e.path!).toList();
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
                            controller.focusNode.unfocus();
                            controller.subjectFocusNode.unfocus();
                          }
                          setState(() {
                            showAttachmentPicker = !showAttachmentPicker;
                          });
                        }
                      },
                    ),
                    if (!Platform.isAndroid)
                      IconButton(
                        icon: Icon(Icons.gif, color: context.theme.colorScheme.outline, size: 28),
                        onPressed: () async {
                          GiphyGif? gif = await GiphyGet.getGif(
                            context: context,
                            apiKey: GIPHY_API_KEY,
                            tabColor: context.theme.primaryColor,
                          );
                          if (gif?.images?.original != null) {
                            final response = await http.downloadGiphy(gif!.images!.original!.url);
                            if (response.statusCode == 200) {
                              try {
                                final Uint8List data = response.data;
                                controller.pickedAttachments.add(PlatformFile(
                                  path: null,
                                  name: "${gif.title ?? randomString(8)}.gif",
                                  size: data.length,
                                  bytes: data,
                                ));
                                return;
                              } catch (_) {}
                            }
                          } else {
                            showSnackbar("Error", "Something went wrong, please try again.");
                          }
                        }
                      ),
                    if (kIsDesktop)
                      IconButton(
                        icon: Icon(iOS ? CupertinoIcons.location_solid : Icons.location_on_outlined, color: context.theme.colorScheme.outline, size: 28),
                        onPressed: () async {
                          await Share.location(chat);
                        },
                      ),
                    Expanded(
                      child: _TextFields(
                        chat: chat,
                        subjectTextController: subjectTextController,
                        textController: textController,
                        controller: controller,
                        recorderController: recorderController,
                      ),
                    )
                  ]
                ),
                Obx(() => AnimatedContainer(
                  height: 50,
                  duration: const Duration(milliseconds: 500),
                  curve: controller.showRecording.value ? Curves.easeOutBack : Curves.easeOut,
                  width: controller.showRecording.value ? 250 : 0,
                  child: AudioWaveforms(
                    size: const Size(220, 40),
                    recorderController: recorderController,
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                    waveStyle: const WaveStyle(
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
              duration: const Duration(milliseconds: 250),
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
    required this.subjectTextController,
    required this.textController,
    required this.controller,
    required this.recorderController,
  }) : super(key: key);

  final Chat chat;
  final TextEditingController subjectTextController;
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
    return FocusScope(
      child: Focus(
        onKey: (_, ev) => handleKey(_, ev, context),
        child: ThemeSwitcher(
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
                duration: const Duration(milliseconds: 400),
                alignment: Alignment.bottomCenter,
                curve: Curves.easeOutBack,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Obx(() {
                          if (controller.pickedAttachments.isNotEmpty) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(
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
                                          key: ValueKey(controller.pickedAttachments[index].name),
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
                          if (controller.emojiMatches.isNotEmpty) {
                            return ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: min(controller.emojiMatches.length * 48, 150)),
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: context.theme.colorScheme.properSurface,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Scrollbar(
                                    radius: Radius.circular(4),
                                    controller: controller.emojiScrollController,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 0),
                                      controller: controller.emojiScrollController,
                                      physics: CustomBouncingScrollPhysics(),
                                      shrinkWrap: true,
                                      itemBuilder: (BuildContext context, int index) => Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTapDown: (details) {
                                            controller.emojiSelectedIndex.value = index;
                                          },
                                          onTap: () {
                                            final _controller = controller.focusNode.hasFocus ? textController : subjectTextController;
                                            controller.emojiSelectedIndex.value = 0;
                                            final text = _controller.text;
                                            final regExp = RegExp(":[^: \n]{1,}([ \n:]|\$)", multiLine: true);
                                            final matches = regExp.allMatches(text);
                                            if (matches.isNotEmpty && matches.any((m) => m.start < _controller.selection.start)) {
                                              final match = matches.lastWhere((m) => m.start < _controller.selection.start);
                                              final char = controller.emojiMatches[index].char;
                                              _controller.text = "${text.substring(0, match.start)}$char ${text.substring(match.end)}";
                                              _controller.selection = TextSelection.fromPosition(TextPosition(offset: match.start + char.length + 1));
                                            }
                                            controller.emojiMatches.clear();
                                          },
                                          child: Obx(() => ListTile(
                                              dense: true,
                                              selectedTileColor: context.theme.colorScheme.properSurface.lightenOrDarken(20),
                                              selected: controller.emojiSelectedIndex.value == index,
                                              title: Row(
                                                children: <Widget>[
                                                  Text(
                                                    controller.emojiMatches[index].char,
                                                    style:
                                                    context.textTheme.labelLarge!.apply(fontFamily: "Apple Color Emoji"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    ":${controller.emojiMatches[index].shortName}:",
                                                    style: context.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              )),
                                          ),
                                        ),
                                      ),
                                      itemCount: controller.emojiMatches.length,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }),
                      ],
                    ),
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
                        focusNode: controller.subjectFocusNode,
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
                          controller.focusNode.requestFocus();
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
                      focusNode: controller.focusNode,
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
                        /*controller.focusNode.requestFocus();
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
                                  child: Center(
                                    child: Obx(() => !controller.showRecording.value ? const Icon(
                                      CupertinoIcons.waveform,
                                      color: Colors.white,
                                      size: 25,
                                    ) : Icon(
                                      CupertinoIcons.stop_fill,
                                      color: context.theme.colorScheme.onPrimary,
                                      size: 25,
                                    )),
                                  ),
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
        ),
      ),
    );
  }

  KeyEventResult handleKey(FocusNode _, RawKeyEvent ev, BuildContext context) {
    if (ev is RawKeyDownEvent) {
      RawKeyEventDataWindows? windowsData;
      RawKeyEventDataLinux? linuxData;
      RawKeyEventDataWeb? webData;
      RawKeyEventDataAndroid? androidData;
      if (ev.data is RawKeyEventDataWindows) {
        windowsData = ev.data as RawKeyEventDataWindows;
      } else if (ev.data is RawKeyEventDataLinux) {
        linuxData = ev.data as RawKeyEventDataLinux;
      } else if (ev.data is RawKeyEventDataWeb) {
        webData = ev.data as RawKeyEventDataWeb;
      } else if (ev.data is RawKeyEventDataAndroid) {
        androidData = ev.data as RawKeyEventDataAndroid;
      }

      int maxShown = context.height / 3 ~/ 48;
      int upMovementIndex = maxShown ~/ 3;
      int downMovementIndex = maxShown * 2 ~/ 3;

      // Down arrow
      if (windowsData?.keyCode == 40 || linuxData?.keyCode == 65364 || webData?.code == "ArrowDown" || androidData?.physicalKey == PhysicalKeyboardKey.arrowDown) {
        if (controller.emojiSelectedIndex.value < controller.emojiMatches.length - 1) {
          controller.emojiSelectedIndex.value++;
          if (controller.emojiSelectedIndex.value >= downMovementIndex &&
              controller.emojiSelectedIndex < controller.emojiMatches.length - maxShown + downMovementIndex + 1) {
            controller.emojiScrollController
                .jumpTo(max((controller.emojiSelectedIndex.value - downMovementIndex) * 48, controller.emojiScrollController.offset));
          }
          return KeyEventResult.handled;
        }
      }

      // Up arrow
      if (windowsData?.keyCode == 38 || linuxData?.keyCode == 65362 || webData?.code == "ArrowUp" || androidData?.physicalKey == PhysicalKeyboardKey.arrowUp) {
        if (controller.emojiSelectedIndex.value > 0) {
          controller.emojiSelectedIndex.value--;
          if (controller.emojiSelectedIndex.value >= upMovementIndex &&
              controller.emojiSelectedIndex < controller.emojiMatches.length - maxShown + upMovementIndex + 1) {
            controller.emojiScrollController
                .jumpTo(min((controller.emojiSelectedIndex.value - upMovementIndex) * 48, controller.emojiScrollController.offset));
          }
          return KeyEventResult.handled;
        }
      }

      // Tab
      if (windowsData?.keyCode == 9 || linuxData?.keyCode == 65289 || webData?.code == "Tab" || androidData?.physicalKey == PhysicalKeyboardKey.tab) {
        if (controller.emojiMatches.length > controller.emojiSelectedIndex.value) {
          eventDispatcher.emit('replace-emoji', {'emojiMatchIndex': controller.emojiSelectedIndex.value, 'chatGuid': chat.guid});
          controller.emojiSelectedIndex.value = 0;
          controller.emojiScrollController.jumpTo(0);
          return KeyEventResult.handled;
        }
      }

      // Enter
      if (windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") {
        if (controller.emojiMatches.length > controller.emojiSelectedIndex.value) {
          eventDispatcher.emit('replace-emoji', {'emojiMatchIndex': controller.emojiSelectedIndex.value, 'chatGuid': chat.guid});
          controller.emojiSelectedIndex.value = 0;
          controller.emojiScrollController.jumpTo(0);
          return KeyEventResult.handled;
        }
      }

      // Escape
      if (windowsData?.keyCode == 27 || linuxData?.keyCode == 65307 || webData?.code == "Escape" || androidData?.physicalKey == PhysicalKeyboardKey.escape) {
        if (controller.replyToMessage.value != null) {
          controller.replyToMessage.value = null;
          return KeyEventResult.handled;
        }
      }
    }

    if (ev is! RawKeyDownEvent) return KeyEventResult.ignored;
    RawKeyEventDataWindows? windowsData;
    RawKeyEventDataLinux? linuxData;
    RawKeyEventDataWeb? webData;
    if (ev.data is RawKeyEventDataWindows) {
      windowsData = ev.data as RawKeyEventDataWindows;
    } else if (ev.data is RawKeyEventDataLinux) {
      linuxData = ev.data as RawKeyEventDataLinux;
    } else if (ev.data is RawKeyEventDataWeb) {
      webData = ev.data as RawKeyEventDataWeb;
    }
    if ((windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") && !ev.isShiftPressed) {
      // sendMessage();
      controller.focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (windowsData != null) {
      if ((windowsData.physicalKey == PhysicalKeyboardKey.keyV ||
          windowsData.logicalKey == LogicalKeyboardKey.keyV) &&
          (ev.isControlPressed)) {
        Pasteboard.image.then((image) {
          if (image != null) {
            controller.pickedAttachments.add(PlatformFile(
              name: "${randomString(8)}.png",
              bytes: image,
              size: image.length,
            ));
          }
        });
      }
    }

    if (webData != null) {
      if ((webData.physicalKey == PhysicalKeyboardKey.keyV || webData.logicalKey == LogicalKeyboardKey.keyV) && (ev.isControlPressed)) {
        getPastedImageWeb().then((value) {
          if (value != null) {
            var r = html.FileReader();
            r.readAsArrayBuffer(value);
            r.onLoadEnd.listen((e) {
              if (r.result != null && r.result is Uint8List) {
                Uint8List data = r.result as Uint8List;
                controller.pickedAttachments.add(PlatformFile(
                  name: "${randomString(8)}.png",
                  bytes: data,
                  size: data.length,
                ));
              }
            });
          }
        });
      }
      return KeyEventResult.ignored;
    }
    if (kIsDesktop || kIsWeb) return KeyEventResult.ignored;
    if (ev.physicalKey == PhysicalKeyboardKey.enter && ss.settings.sendWithReturn.value) {
      if (!isNullOrEmpty(textController.text)! || !isNullOrEmpty(subjectTextController.text)!) {
        // sendMessage();
        controller.focusNode.previousFocus(); // I genuinely don't know why this works
        return KeyEventResult.handled;
      } else {
        subjectTextController.text = "";
        textController.text = ""; // Stop pressing physical enter with enterIsSend from creating newlines
        controller.focusNode.previousFocus(); // I genuinely don't know why this works
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
