import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/send_animation.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/picked_attachments_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/reply_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/text_field_suffix.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class ConversationTextField extends CustomStateful<ConversationViewController> {
  ConversationTextField({
    Key? key,
    required super.parentController,
  }) : super(key: key);

  static ConversationTextFieldState? of(BuildContext context) {
    return context.findAncestorStateOfType<ConversationTextFieldState>();
  }

  @override
  ConversationTextFieldState createState() => ConversationTextFieldState();
}

class ConversationTextFieldState extends CustomState<ConversationTextField, void, ConversationViewController> with TickerProviderStateMixin {
  final recorderController = RecorderController();

  // emoji
  final Map<String, Emoji> emojiNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.shortName, e)));
  final Map<String, Emoji> emojiFullNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.name, e)));

  // typing indicators
  String oldText = "\n";
  Timer? _debounceTyping;

  // emoji
  String oldEmojiText = "";

  Chat get chat => controller.chat;

  String get chatGuid => chat.guid;

  bool get showAttachmentPicker => controller.showAttachmentPicker;

  @override
  void initState() {
    super.initState();
    forceDelete = false;

    // Load the initial chat drafts
    getDrafts();
    if (controller.fromChatCreator) {
      controller.focusNode.requestFocus();
    } else if (ss.settings.autoOpenKeyboard.value) {
      updateObx(() {
        controller.focusNode.requestFocus();
      });
    }

    controller.focusNode.addListener(() => focusListener(false));
    controller.subjectFocusNode.addListener(() => focusListener(true));

    controller.textController.addListener(() => textListener(false));
    controller.subjectTextController.addListener(() => textListener(true));
  }

  void getDrafts() async {
    getTextDraft();
    await getAttachmentDrafts();
  }

  void getTextDraft({String? text}) {
    // Only change the text if the incoming text is different.
    final incomingText = text ?? chat.textFieldText;
    if (incomingText != null && incomingText.isNotEmpty && incomingText != controller.textController.text) {
      controller.textController.text = incomingText;
    }
  }

  Future<void> getAttachmentDrafts({List<String> attachments = const []}) async {
    // Only change the attachments if the incoming attachments are different.
    final incomingAttachments = attachments.isEmpty ? chat.textFieldAttachments : attachments;
    final currentPicked = controller.pickedAttachments.map((element) => element.path).toList();
    if (incomingAttachments.any((element) => !currentPicked.contains(element))) {
      controller.pickedAttachments.clear();
    }

    for (String s in incomingAttachments) {
      final file = File(s);
      if (!currentPicked.contains(s) && await file.exists()) {
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

  void focusListener(bool subject) async {
    final _focusNode = subject ? controller.subjectFocusNode : controller.focusNode;
    if (_focusNode.hasFocus && showAttachmentPicker) {
      setState(() {
        controller.showAttachmentPicker = !showAttachmentPicker;
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
      chat.textFieldText = controller.textController.text;
    }
    // typing indicators
    final newText = "${controller.subjectTextController.text}\n${controller.textController.text}";
    if (newText != oldText) {
      _debounceTyping?.cancel();
      oldText = newText;
      // don't send a bunch of duplicate events for every typing change
      if (_debounceTyping == null && ss.settings.privateSendTypingIndicators.value && chat.autoSendTypingIndicators!) {
        socket.sendMessage("started-typing", {"chatGuid": chatGuid});
        _debounceTyping = Timer(const Duration(seconds: 3), () {
          socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
          _debounceTyping = null;
        });
      }
    }
    // emoji picker
    final _controller = subject ? controller.subjectTextController : controller.textController;
    final newEmojiText = _controller.text;
    if (newEmojiText.contains(":") && newEmojiText != oldEmojiText) {
      oldEmojiText = newEmojiText;
      final regExp = RegExp(r"(?<=^| |\n|[^a-zA-Z]):[^: \n]{2,}((?=[ \n]|$)|:)", multiLine: true);
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
              .followedBy(emojiFullNames.keys.where((name) => name.contains(emojiName))); // Substring 1 to avoid dupes
          Iterable<Emoji> emojiMatches = emojiNameMatches.followedBy(emojiNameAnywhereMatches).map((n) => emojiNames[n] ?? emojiFullNames[n]!);
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
    chat.textFieldText = controller.textController.text;
    chat.textFieldAttachments = controller.pickedAttachments.where((e) => e.path != null).map((e) => e.path!).toList();
    chat.save(updateTextFieldText: true, updateTextFieldAttachments: true);

    controller.focusNode.dispose();
    controller.subjectFocusNode.dispose();
    controller.textController.dispose();
    controller.subjectTextController.dispose();
    recorderController.dispose();
    if (ss.settings.privateSendTypingIndicators.value && chat.autoSendTypingIndicators!) {
      socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
    }

    super.dispose();
  }

  Future<void> sendMessage({String? effect}) async {
    if (controller.scheduledDate.value != null) {
      final date = controller.scheduledDate.value!;
      if (date.isBefore(DateTime.now())) return showSnackbar("Error", "Pick a date in the future!");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.properSurface,
            title: Text(
              "Scheduling message...",
              style: context.theme.textTheme.titleLarge,
            ),
            content: Container(
              height: 70,
              child: Center(
                child: CircularProgressIndicator(
                  backgroundColor: context.theme.colorScheme.properSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                ),
              ),
            ),
          );
        },
      );
      final response = await http.createScheduled(chat.guid, controller.textController.text, date.toUtc(), {"type": "once"});
      Navigator.of(context).pop();
      if (response.statusCode == 200 && response.data != null) {
        showSnackbar("Notice", "Message scheduled successfully for ${buildFullDate(date)}");
      } else {
        Logger.error("Scheduled message error: ${response.statusCode}");
        Logger.error(response.data);
        showSnackbar("Error", "Something went wrong!");
      }
    } else {
      if (controller.textController.text.isEmpty && controller.subjectTextController.text.isEmpty) {
        if (controller.replyToMessage != null) {
          return showSnackbar("Error", "Replies must be sent with a text message!");
        } else if (effect != null) {
          return showSnackbar("Error", "Effects must be sent with a text message!");
        }
      }
      await controller.send(
        controller.pickedAttachments,
        controller.textController.text,
        controller.subjectTextController.text,
        controller.replyToMessage?.item1.threadOriginatorGuid ?? controller.replyToMessage?.item1.guid,
        controller.replyToMessage?.item2,
        effect,
      );
    }
    controller.pickedAttachments.clear();
    controller.textController.clear();
    controller.subjectTextController.clear();
    controller.replyToMessage = null;
    controller.scheduledDate.value = null;

    // Remove the saved text field draft
    if ((chat.textFieldText ?? "").isNotEmpty) {
      chat.textFieldText = "";
      chat.save(updateTextFieldText: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5.0, top: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                icon: Icon(
                  iOS
                      ? CupertinoIcons.square_arrow_up_on_square_fill
                      : material
                          ? Icons.add_circle_outline
                          : Icons.add,
                  color: context.theme.colorScheme.outline,
                  size: 28,
                ),
                visualDensity: VisualDensity.compact,
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
                              content: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
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
                              ]),
                              backgroundColor: context.theme.colorScheme.properSurface,
                            ));
                  } else {
                    if (!showAttachmentPicker) {
                      controller.focusNode.unfocus();
                      controller.subjectFocusNode.unfocus();
                    }
                    setState(() {
                      controller.showAttachmentPicker = !showAttachmentPicker;
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
                        apiKey: kIsWeb ? GIPHY_API_KEY : dotenv.get('GIPHY_API_KEY'),
                        tabColor: context.theme.primaryColor,
                      );
                      if (gif?.images?.original != null) {
                        final response = await http.downloadFromUrl(gif!.images!.original!.url);
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
                      }
                    }),
              if (kIsDesktop)
                IconButton(
                  icon: Icon(iOS ? CupertinoIcons.location_solid : Icons.location_on_outlined, color: context.theme.colorScheme.outline, size: 28),
                  onPressed: () async {
                    await Share.location(chat);
                  },
                ),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    TextFieldComponent(
                      key: controller.textFieldKey,
                      subjectTextController: controller.subjectTextController,
                      textController: controller.textController,
                      controller: controller,
                      recorderController: recorderController,
                      sendMessage: sendMessage,
                    ),
                    Positioned(
                        top: 0,
                        bottom: 0,
                        child: Obx(() => AnimatedSize(
                              duration: const Duration(milliseconds: 500),
                              curve: controller.showRecording.value ? Curves.easeOutBack : Curves.easeOut,
                              child: !controller.showRecording.value
                                  ? const SizedBox.shrink()
                                  : Builder(builder: (context) {
                                      final box = controller.textFieldKey.currentContext?.findRenderObject() as RenderBox?;
                                      final textFieldSize = box?.size ?? const Size(250, 35);
                                      return AudioWaveforms(
                                        size: Size(textFieldSize.width - (samsung ? 0 : 80), textFieldSize.height - 15),
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
                                      );
                                    }),
                            ))),
                    SendAnimation(parentController: controller),
                  ],
                ),
              ),
              if (samsung)
                Padding(
                  padding: const EdgeInsets.only(right: 5.0),
                  child: TextFieldSuffix(
                    subjectTextController: controller.subjectTextController,
                    textController: controller.textController,
                    controller: controller,
                    recorderController: recorderController,
                    sendMessage: sendMessage,
                  ),
                ),
            ]),
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

class TextFieldComponent extends StatelessWidget {
  const TextFieldComponent({
    Key? key,
    required this.subjectTextController,
    required this.textController,
    required this.controller,
    required this.recorderController,
    required this.sendMessage,
    this.focusNode,
    this.initialAttachments = const [],
  }) : super(key: key);

  final TextEditingController subjectTextController;
  final TextEditingController textController;
  final ConversationViewController? controller;
  final RecorderController recorderController;
  final Future<void> Function({String? effect}) sendMessage;
  final FocusNode? focusNode;

  final List<PlatformFile> initialAttachments;

  bool get iOS => ss.settings.skin.value == Skins.iOS;

  bool get samsung => ss.settings.skin.value == Skins.Samsung;

  Chat? get chat => controller?.chat;

  bool get isChatCreator => controller == null;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKey: (_, ev) => isChatCreator ? KeyEventResult.ignored : handleKey(_, ev, context),
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Container(
          decoration: iOS
              ? BoxDecoration(
                  border: Border.fromBorderSide(BorderSide(
                    color: context.theme.colorScheme.properSurface,
                    width: 1.5,
                  )),
                  borderRadius: BorderRadius.circular(20),
                )
              : BoxDecoration(
                  color: context.theme.colorScheme.properSurface,
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
                if (!isChatCreator) ReplyHolder(controller: controller!),
                if (initialAttachments.isNotEmpty || !isChatCreator)
                  PickedAttachmentsHolder(
                    controller: controller,
                    textController: textController,
                    subjectTextController: controller?.subjectTextController ?? TextEditingController(),
                    initialAttachments: initialAttachments,
                  ),
                if (!isChatCreator)
                  Obx(() {
                    if (controller!.pickedAttachments.isNotEmpty && iOS) {
                      return Divider(
                        height: 1.5,
                        thickness: 1.5,
                        color: context.theme.colorScheme.properSurface,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                if (!isChatCreator && ss.settings.enablePrivateAPI.value && ss.settings.privateSubjectLine.value && chat!.isIMessage)
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    focusNode: controller!.subjectFocusNode,
                    autocorrect: true,
                    controller: controller!.subjectTextController,
                    scrollPhysics: const CustomBouncingScrollPhysics(),
                    style: context.theme.extension<BubbleText>()!.bubbleText.copyWith(fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.multiline,
                    maxLines: 14,
                    minLines: 1,
                    selectionControls: iOS ? cupertinoTextSelectionControls : materialTextSelectionControls,
                    spellCheckConfiguration: kIsWeb ? null : const SpellCheckConfiguration(),
                    enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                    textInputAction: TextInputAction.next,
                    cursorColor: context.theme.colorScheme.primary,
                    cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(iOS && !kIsDesktop && !kIsWeb ? 10 : 12.5),
                      isDense: true,
                      isCollapsed: true,
                      hintText: "Subject",
                      enabledBorder: InputBorder.none,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      hintStyle: context.theme
                          .extension<BubbleText>()!
                          .bubbleText
                          .copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.bold),
                      suffixIconConstraints: const BoxConstraints(minHeight: 0),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                    },
                    onSubmitted: (String value) {
                      controller!.focusNode.requestFocus();
                    },
                    onContentCommitted: onContentCommit,
                  ),
                if (!isChatCreator && ss.settings.enablePrivateAPI.value && ss.settings.privateSubjectLine.value && chat!.isIMessage && iOS)
                  Divider(
                    height: 1.5,
                    thickness: 1.5,
                    indent: 10,
                    color: context.theme.colorScheme.properSurface,
                  ),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  focusNode: controller?.focusNode,
                  autocorrect: true,
                  controller: textController,
                  scrollPhysics: const CustomBouncingScrollPhysics(),
                  style: context.theme.extension<BubbleText>()!.bubbleText,
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                  selectionControls: ss.settings.skin.value == Skins.iOS ? cupertinoTextSelectionControls : materialTextSelectionControls,
                  spellCheckConfiguration: kIsWeb ? null : const SpellCheckConfiguration(),
                  autofocus: (kIsWeb || kIsDesktop) && !isChatCreator,
                  enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                  textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop ? TextInputAction.send : TextInputAction.newline,
                  cursorColor: context.theme.colorScheme.primary,
                  cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(iOS && !kIsDesktop && !kIsWeb ? 10 : 12.5),
                    isDense: true,
                    isCollapsed: true,
                    hintText: isChatCreator
                        ? "New Message"
                        : ss.settings.recipientAsPlaceholder.value == true
                            ? chat!.getTitle()
                            : chat!.isTextForwarding
                                ? "Text Forwarding"
                                : "iMessage",
                    enabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    hintStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                    suffixIconConstraints: const BoxConstraints(minHeight: 0),
                    suffixIcon: samsung && !isChatCreator
                        ? null
                        : Padding(
                            padding: EdgeInsets.only(right: iOS ? 0.0 : 5.0),
                            child: TextFieldSuffix(
                              subjectTextController: subjectTextController,
                              textController: textController,
                              controller: controller,
                              recorderController: recorderController,
                              sendMessage: sendMessage,
                            ),
                          ),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  onSubmitted: (String value) {
                    controller?.focusNode.requestFocus();
                    if (isNullOrEmpty(value)! && (controller?.pickedAttachments.isEmpty ?? false)) return;
                    sendMessage.call();
                  },
                  onContentCommitted: onContentCommit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void onContentCommit(CommittedContent content) async {
    // Add some debugging logs
    Logger.info("[Content Commit] Keyboard received content");
    Logger.info("  -> Content Type: ${content.mimeType}");
    Logger.info("  -> URI: ${content.uri}");
    Logger.info("  -> Content Length: ${content.hasData ? content.data!.length : "null"}");

    // Parse the filename from the URI and read the data as a List<int>
    String filename = fs.uriToFilename(content.uri, content.mimeType);

    // Save the data to a location and add it to the file picker
    if (content.hasData) {
      controller?.pickedAttachments.add(PlatformFile(
        name: filename,
        size: content.data!.length,
        bytes: content.data,
      ));
    } else {
      showSnackbar('Insertion Failed', 'Attachment has no data!');
    }
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
      if (windowsData?.keyCode == 40 ||
          linuxData?.keyCode == 65364 ||
          webData?.code == "ArrowDown" ||
          androidData?.physicalKey == PhysicalKeyboardKey.arrowDown) {
        if (controller!.emojiSelectedIndex.value < controller!.emojiMatches.length - 1) {
          controller!.emojiSelectedIndex.value++;
          if (controller!.emojiSelectedIndex.value >= downMovementIndex &&
              controller!.emojiSelectedIndex < controller!.emojiMatches.length - maxShown + downMovementIndex + 1) {
            controller!.emojiScrollController
                .jumpTo(max((controller!.emojiSelectedIndex.value - downMovementIndex) * 48, controller!.emojiScrollController.offset));
          }
          return KeyEventResult.handled;
        }
      }

      // Up arrow
      if (windowsData?.keyCode == 38 ||
          linuxData?.keyCode == 65362 ||
          webData?.code == "ArrowUp" ||
          androidData?.physicalKey == PhysicalKeyboardKey.arrowUp) {
        if (controller!.emojiSelectedIndex.value > 0) {
          controller!.emojiSelectedIndex.value--;
          if (controller!.emojiSelectedIndex.value >= upMovementIndex &&
              controller!.emojiSelectedIndex < controller!.emojiMatches.length - maxShown + upMovementIndex + 1) {
            controller!.emojiScrollController
                .jumpTo(min((controller!.emojiSelectedIndex.value - upMovementIndex) * 48, controller!.emojiScrollController.offset));
          }
          return KeyEventResult.handled;
        }
      }

      // Tab or Enter
      if (windowsData?.keyCode == 9 ||
          linuxData?.keyCode == 65289 ||
          webData?.code == "Tab" ||
          androidData?.physicalKey == PhysicalKeyboardKey.tab ||
          windowsData?.keyCode == 13 ||
          linuxData?.keyCode == 65293 ||
          webData?.code == "Enter" ||
          androidData?.physicalKey == PhysicalKeyboardKey.enter) {
        if (controller!.emojiMatches.length > controller!.emojiSelectedIndex.value) {
          int index = controller!.emojiSelectedIndex.value;
          TextEditingController textField =
              controller!.subjectFocusNode.hasPrimaryFocus ? controller!.subjectTextController : controller!.textController;
          String text = textField.text;
          RegExp regExp = RegExp(":[^: \n]{1,}([ \n:]|\$)", multiLine: true);
          Iterable<RegExpMatch> matches = regExp.allMatches(text);
          if (matches.isNotEmpty && matches.any((m) => m.start < textField.selection.start)) {
            RegExpMatch match = matches.lastWhere((m) => m.start < textField.selection.start);
            String char = controller!.emojiMatches[index].char;
            String _text = "${text.substring(0, match.start)}$char ${text.substring(match.end)}";
            textField.text = _text;
            textField.selection = TextSelection.fromPosition(TextPosition(offset: match.start + char.length + 1));
          } else {
            // If the user moved the cursor before trying to insert an emoji, reset the picker
            controller!.emojiScrollController.jumpTo(0);
          }
          controller!.emojiSelectedIndex.value = 0;
          controller!.emojiMatches.value = <Emoji>[];

          return KeyEventResult.handled;
        }
        if (ss.settings.privateSubjectLine.value) {
          // Tab to switch between text fields
          if (!ev.isShiftPressed && controller!.subjectFocusNode.hasPrimaryFocus) {
            controller!.focusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (ev.isShiftPressed && controller!.focusNode.hasPrimaryFocus) {
            controller!.subjectFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }

      // Escape
      if (windowsData?.keyCode == 27 ||
          linuxData?.keyCode == 65307 ||
          webData?.code == "Escape" ||
          androidData?.physicalKey == PhysicalKeyboardKey.escape) {
        if (controller!.replyToMessage != null) {
          controller!.replyToMessage = null;
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
      sendMessage();
      controller!.focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (windowsData != null) {
      if ((windowsData.physicalKey == PhysicalKeyboardKey.keyV || windowsData.logicalKey == LogicalKeyboardKey.keyV) && (ev.isControlPressed)) {
        Pasteboard.image.then((image) {
          if (image != null) {
            controller!.pickedAttachments.add(PlatformFile(
              name: "${randomString(8)}.png",
              bytes: image,
              size: image.length,
            ));
          }
        });
      }
    }

    if (linuxData != null) {
      if ((linuxData.physicalKey == PhysicalKeyboardKey.keyV || linuxData.logicalKey == LogicalKeyboardKey.keyV) && (ev.isControlPressed)) {
        Pasteboard.image.then((image) {
          if (image != null) {
            controller!.pickedAttachments.add(PlatformFile(
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
                controller!.pickedAttachments.add(PlatformFile(
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
      if (!isNullOrEmpty(textController.text)! || !isNullOrEmpty(controller!.subjectTextController.text)!) {
        sendMessage();
        controller!.focusNode.previousFocus(); // I genuinely don't know why this works
        return KeyEventResult.handled;
      } else {
        controller!.subjectTextController.text = "";
        textController.text = ""; // Stop pressing physical enter with enterIsSend from creating newlines
        controller!.focusNode.previousFocus(); // I genuinely don't know why this works
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
