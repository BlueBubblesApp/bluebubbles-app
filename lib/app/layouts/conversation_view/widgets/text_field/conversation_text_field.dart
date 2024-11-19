import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/dialogs/custom_mention_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/send_animation.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/picked_attachments_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/reply_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/text_field_suffix.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/voice_message_recorder.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/emoji.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:collection/collection.dart';
import 'package:emojis/emoji.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' hide Emoji;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:tenor_flutter/tenor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' hide context;
import 'package:permission_handler/permission_handler.dart';
import 'package:supercharged/supercharged.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

class ConversationTextField extends CustomStateful<ConversationViewController> {
  ConversationTextField({
    super.key,
    required super.parentController,
  });

  static ConversationTextFieldState? of(BuildContext context) {
    return context.findAncestorStateOfType<ConversationTextFieldState>();
  }

  @override
  ConversationTextFieldState createState() => ConversationTextFieldState();
}

class ConversationTextFieldState extends CustomState<ConversationTextField, void, ConversationViewController> with TickerProviderStateMixin {
  final recorderController = kIsWeb ? null : RecorderController();

  // typing indicators
  String oldText = "\n";
  Timer? _debounceTyping;

  // previous text state
  TextSelection oldTextFieldSelection = const TextSelection.collapsed(offset: 0);

  Chat get chat => controller.chat;

  String get chatGuid => chat.guid;

  bool get showAttachmentPicker => controller.showAttachmentPicker;

  late final double emojiPickerHeight = max(256, context.height * 0.4);
  late final emojiColumns = ns.width(context) ~/ 56; // Intentionally not responsive to prevent rebuilds when resizing
  RxBool get showEmojiPicker => controller.showEmojiPicker;

  final proxyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    forceDelete = false;

    // Load the initial chat drafts
    getDrafts();

    controller.textController.processMentions();

    // Save state
    oldTextFieldSelection = controller.textController.selection;

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

    if (kIsDesktop || kIsWeb) {
      proxyController.addListener(() {
        if (proxyController.text.isEmpty) return;
        String emoji = proxyController.text;
        proxyController.clear();
        TextEditingController realController = controller.editing.lastOrNull?.item3 ?? controller.lastFocusedTextController;
        String text = realController.text;
        TextSelection selection = realController.selection;

        realController.text = text.substring(0, selection.start) + emoji + text.substring(selection.end);
        realController.selection = TextSelection.collapsed(offset: selection.start + emoji.length);

        (controller.editing.lastOrNull?.item3.focusNode ?? controller.lastFocusedNode).requestFocus();
      });
    }
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
          name: basename(file.path),
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
  }

  void textListener(bool subject) {
    if (!subject && controller.textController.text.trim().isNotEmpty) {
      chat.textFieldText = controller.textController.text;
    }

    if (!subject) {
      // Handle people arrow-keying or clicking into mentions
      String text = controller.textController.text;
      TextSelection selection = controller.textController.selection;
      if (selection.isCollapsed && selection.start != -1) {
        final behind = text.substring(0, selection.baseOffset);
        final behindMatches = MentionTextEditingController.escapingChar.allMatches(behind);
        if (behindMatches.length % 2 != 0) {
          // Assuming the rest of the code works, we're guaranteed to be inside a mention now
          final ahead = text.substring(selection.baseOffset);
          final aheadMatches = MentionTextEditingController.escapingChar.allMatches(ahead);

          // Now we determine which side of the mention to put the cursor on.
          // We can use the old selection to figure out if the user is moving left/right
          if (oldTextFieldSelection.isCollapsed) {
            if (oldTextFieldSelection.baseOffset > selection.baseOffset) {
              // moving left
              oldTextFieldSelection = TextSelection.collapsed(offset: behindMatches.last.start);
              controller.textController.selection = oldTextFieldSelection;
              return;
            } else if (oldTextFieldSelection.baseOffset < selection.baseOffset) {
              // moving right
              oldTextFieldSelection = TextSelection.collapsed(offset: behind.length + aheadMatches.first.end);
              controller.textController.selection = oldTextFieldSelection;
              return;
            }
          }

          // If we get here then we need to pick the closest side
          if (selection.baseOffset - behindMatches.last.end < aheadMatches.first.start - selection.baseOffset) {
            // moving left
            oldTextFieldSelection = TextSelection.collapsed(offset: behindMatches.last.start);
            controller.textController.selection = oldTextFieldSelection;
            return;
          } else {
            // Closer to right
            oldTextFieldSelection = TextSelection.collapsed(offset: behind.length + aheadMatches.first.end);
            controller.textController.selection = oldTextFieldSelection;
            return;
          }
        }
      }

      if (!selection.isCollapsed && oldTextFieldSelection.baseOffset == selection.baseOffset) {
        if (oldTextFieldSelection.extentOffset < selection.extentOffset) {
          // Means we're shift+selecting rightwards
          final behind = text.substring(0, selection.extentOffset);
          final ahead = text.substring(selection.extentOffset);
          final aheadMatches = MentionTextEditingController.escapingChar.allMatches(ahead);
          if (aheadMatches.length % 2 != 0) {
            // Assuming the rest of the code works, we're guaranteed to be inside a mention now
            oldTextFieldSelection = TextSelection(baseOffset: selection.baseOffset, extentOffset: behind.length + aheadMatches.first.end);
            controller.textController.selection = oldTextFieldSelection;
            return;
          }
        } else if (oldTextFieldSelection.extentOffset > selection.extentOffset) {
          // Means we're shift+selecting leftwards
          final behind = text.substring(0, selection.extentOffset);
          final behindMatches = MentionTextEditingController.escapingChar.allMatches(behind);
          if (behindMatches.length % 2 != 0) {
            // Assuming the rest of the code works, we're guaranteed to be inside a mention now
            oldTextFieldSelection = TextSelection(baseOffset: selection.baseOffset, extentOffset: behindMatches.last.start);
            controller.textController.selection = oldTextFieldSelection;
            return;
          }
        }
      }

      oldTextFieldSelection = controller.textController.selection;
    }

    // typing indicators
    final newText = "${controller.subjectTextController.text}\n${controller.textController.text}";
    if (newText != oldText) {
      _debounceTyping?.cancel();
      oldText = newText;
      // don't send a bunch of duplicate events for every typing change
      if (ss.settings.enablePrivateAPI.value && (chat.autoSendTypingIndicators ?? ss.settings.privateSendTypingIndicators.value)) {
        if (_debounceTyping == null) {
          socket.sendMessage("started-typing", {"chatGuid": chatGuid});
        }
        _debounceTyping = Timer(const Duration(seconds: 3), () {
          socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
          _debounceTyping = null;
        });
      }
    }
    // emoji picker
    final _controller = subject ? controller.subjectTextController : controller.textController;
    final newEmojiText = _controller.text;
    if (newEmojiText.contains(":")) {
      final regExp = RegExp(r"(?<=^|[^a-zA-Z\d]):[^: \n]{2,}(?:(?=[ \n]|$)|:)", multiLine: true);
      final matches = regExp.allMatches(newEmojiText);
      List<Emoji> allMatches = [];
      String emojiName = "";
      if (matches.isNotEmpty && matches.first.start < _controller.selection.start) {
        RegExpMatch match = matches.lastWhere((m) => m.start < _controller.selection.start);
        if (newEmojiText[match.end - 1] == ":") {
          // This will get handled by the text field controller
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
        controller.mentionMatches.value = [];
        controller.mentionSelectedIndex.value = 0;
        controller.emojiMatches.value = allMatches;
        controller.emojiSelectedIndex.value = 0;
        return;
      } else {
        controller.emojiMatches.value = [];
        controller.emojiSelectedIndex.value = 0;
      }
    }

    if (ss.settings.enablePrivateAPI.value && !subject && newEmojiText.contains("@")) {
      final regExp = RegExp(r"(?<=^|[^a-zA-Z\d])@(?:[^@ \n]+|$)(?=[ \n]|$)", multiLine: true);
      final matches = regExp.allMatches(newEmojiText);
      List<Mentionable> allMatches = [];
      String mentionName = "";
      if (matches.isNotEmpty && matches.first.start < _controller.selection.start) {
        RegExpMatch match = matches.lastWhere((m) => m.start < _controller.selection.start);
        final text = newEmojiText.substring(match.start, match.end);
        if (text.endsWith("@")) {
          allMatches = controller.mentionables;
        } else if (newEmojiText[match.end - 1] == "@") {
          mentionName = newEmojiText.substring(match.start + 1, match.end - 1).toLowerCase();
          allMatches = controller.mentionables
              .where((e) =>
                  e.address.toLowerCase().startsWith(mentionName.toLowerCase()) || e.displayName.toLowerCase().startsWith(mentionName.toLowerCase()))
              .toList();
          allMatches.addAll(controller.mentionables
              .where((e) =>
                  !allMatches.contains(e) &&
                  (e.address.isCaseInsensitiveContains(mentionName) || e.displayName.isCaseInsensitiveContains(mentionName)))
              .toList());
        } else if (match.end >= _controller.selection.start) {
          mentionName = newEmojiText.substring(match.start + 1, match.end).toLowerCase();
          allMatches = controller.mentionables
              .where((e) =>
                  e.address.toLowerCase().startsWith(mentionName.toLowerCase()) || e.displayName.toLowerCase().startsWith(mentionName.toLowerCase()))
              .toList();
          allMatches.addAll(controller.mentionables
              .where((e) =>
                  !allMatches.contains(e) &&
                  (e.address.isCaseInsensitiveContains(mentionName) || e.displayName.isCaseInsensitiveContains(mentionName)))
              .toList());
        }
        Logger.info("${allMatches.length} matches found for: $mentionName");
      }
      if (allMatches.isNotEmpty) {
        controller.emojiMatches.value = [];
        controller.emojiSelectedIndex.value = 0;
        controller.mentionMatches.value = allMatches;
        controller.mentionSelectedIndex.value = 0;
        return;
      } else {
        controller.mentionMatches.value = [];
        controller.mentionSelectedIndex.value = 0;
      }
    }

    controller.emojiMatches.value = [];
    controller.emojiSelectedIndex.value = 0;
    controller.mentionMatches.value = [];
    controller.mentionSelectedIndex.value = 0;
  }

  @override
  void dispose() {
    if (controller.textController.text.trim().isNotEmpty) {
      chat.textFieldText = controller.textController.text;
    } else {
      chat.textFieldText = "";
    }
    chat.textFieldAttachments = controller.pickedAttachments.where((e) => e.path != null).map((e) => e.path!).toList();
    chat.save(updateTextFieldText: true, updateTextFieldAttachments: true);

    controller.focusNode.dispose();
    controller.subjectFocusNode.dispose();
    controller.textController.dispose();
    controller.subjectTextController.dispose();
    recorderController?.dispose();
    if (chat.autoSendTypingIndicators ?? ss.settings.privateSendTypingIndicators.value) {
      socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
    }

    super.dispose();
  }

  Future<void> sendMessage({String? effect}) async {
    final text = controller.textController.text;
    if (controller.scheduledDate.value != null) {
      final date = controller.scheduledDate.value!;
      if (date.isBefore(DateTime.now())) return showSnackbar("Error", "Pick a date in the future!");
      if (text.contains(MentionTextEditingController.escapingChar)) {
        return showSnackbar("Error", "Mentions are not allowed in scheduled messages!");
      }
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
      final response = await http.createScheduled(chat.guid, text, date.toUtc(), {"type": "once"});
      Navigator.of(context).pop();
      if (response.statusCode == 200 && response.data != null) {
        showSnackbar("Notice", "Message scheduled successfully for ${buildFullDate(date)}");
      } else {
        Logger.error("Scheduled message error: ${response.statusCode}");
        Logger.error(response.data);
        showSnackbar("Error", "Something went wrong!");
      }
    } else {
      if (text.isEmpty && controller.subjectTextController.text.isEmpty && !ss.settings.privateAPIAttachmentSend.value) {
        if (controller.replyToMessage != null) {
          return showSnackbar("Error", "Turn on Private API Attachment Send to send replies with media!");
        } else if (effect != null) {
          return showSnackbar("Error", "Turn on Private API Attachment Send to send effects with media!");
        }
      }
      if (effect == null && ss.settings.enablePrivateAPI.value) {
        final cleansed = text.replaceAll("!", "").toLowerCase();
        switch (cleansed) {
          case "congratulations":
          case "congrats":
            effect = effectMap["confetti"];
            break;
          case "happy birthday":
            effect = effectMap["balloons"];
            break;
          case "happy new year":
            effect = effectMap["fireworks"];
            break;
          case "happy chinese new year":
          case "happy lunar new year":
            effect = effectMap["celebration"];
            break;
          case "pew pew":
            effect = effectMap["lasers"];
            break;
        }
      }
      await controller.send(
        controller.pickedAttachments,
        text,
        controller.subjectTextController.text,
        controller.replyToMessage?.item1.threadOriginatorGuid ?? controller.replyToMessage?.item1.guid,
        controller.replyToMessage?.item2,
        effect,
        false,
      );
    }
    controller.pickedAttachments.clear();
    controller.textController.clear();
    controller.subjectTextController.clear();
    controller.replyToMessage = null;
    controller.scheduledDate.value = null;
    _debounceTyping = null;
    // Remove the saved text field draft
    if ((chat.textFieldText ?? "").isNotEmpty) {
      chat.textFieldText = "";
      chat.save(updateTextFieldText: true);
    }
  }

  Future<void> openFullCamera({String type = 'camera'}) async {
    bool granted = (await Permission.camera.request()).isGranted;
    if (!granted) {
      showSnackbar("Error", "Camera access was denied!");
      return;
    }

    late final XFile? file;
    if (type == 'camera') {
      file = await ImagePicker().pickImage(source: ImageSource.camera);
    } else {
      file = await ImagePicker().pickVideo(source: ImageSource.camera);
    }
    if (file != null) {
      controller.pickedAttachments.add(PlatformFile(
        path: file.path,
        name: file.path.split('/').last,
        size: await file.length(),
        bytes: await file.readAsBytes(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!kIsWeb && iOS && Platform.isAndroid)
                GestureDetector(
                  onLongPress: () {
                    openFullCamera(type: 'video');
                  },
                  child: IconButton(
                      padding: const EdgeInsets.only(left: 10),
                      icon: Icon(
                        CupertinoIcons.camera_fill,
                        color: context.theme.colorScheme.outline,
                        size: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        openFullCamera();
                      }),
                ),
              IconButton(
                icon: Icon(
                  iOS
                      ? CupertinoIcons.add_circled_solid
                      : material
                          ? Icons.add_circle_outline
                          : Icons.add,
                  color: context.theme.colorScheme.outline,
                  size: 28,
                ),
                visualDensity: Platform.isAndroid ? VisualDensity.compact : null,
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
              if (!kIsWeb && !Platform.isAndroid)
                IconButton(
                    icon: Icon(Icons.gif, color: context.theme.colorScheme.outline, size: 28),
                    onPressed: () async {
                      if (kIsDesktop || kIsWeb) {
                        controller.showingOverlays = true;
                      }
                      Tenor tenor = Tenor(apiKey: kIsWeb ? TENOR_API_KEY : dotenv.get('TENOR_API_KEY'));
                      TenorResult? result = await tenor.showAsBottomSheet(
                        context: context,
                        style: TenorStyle(
                          color: context.theme.colorScheme.properSurface,
                          attributionStyle: TenorAttributionStyle(brightnes: context.theme.brightness),
                          tabBarStyle: TenorTabBarStyle(
                            decoration: BoxDecoration(
                              color: context.theme.colorScheme.properSurface,
                              borderRadius: BorderRadius.circular(8)
                            ),
                            indicator: BoxDecoration(
                              color: context.theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelColor: context.theme.colorScheme.onSurface,
                            unselectedLabelColor: context.theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          searchFieldStyle: TenorSearchFieldStyle(
                            fillColor: context.theme.colorScheme.properSurface,
                          ),
                        ),
                      );
                      if (kIsDesktop || kIsWeb) {
                        controller.showingOverlays = false;
                      }
                      final selectedGif = result?.media.tinyGif ?? result?.media.tinyGifTransparent;
                      if (result != null && selectedGif != null) {
                        final response = await http.downloadFromUrl(selectedGif.url);
                        if (response.statusCode == 200) {
                          try {
                            final Uint8List data = response.data;
                            controller.pickedAttachments.add(PlatformFile(
                              path: null,
                              name: "${result.id}.gif",
                              size: data.length,
                              bytes: data,
                            ));
                            return;
                          } catch (_) {}
                        }
                      }
                    }),
              if (kIsDesktop || kIsWeb)
                IconButton(
                  icon: Icon(iOS ? CupertinoIcons.smiley_fill : Icons.emoji_emotions, color: context.theme.colorScheme.outline, size: 28),
                  onPressed: () {
                    showEmojiPicker.value = !showEmojiPicker.value;
                    (controller.editing.lastOrNull?.item3.focusNode ?? controller.lastFocusedNode).requestFocus();
                  },
                ),
              if (kIsDesktop && !Platform.isLinux)
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
                    if (!kIsWeb)
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
                                        Duration start = DateTime.now().duration();
                                        return kIsDesktop
                                            ? StreamBuilder(
                                                stream: Stream.periodic(const Duration(milliseconds: 100)),
                                                builder: (context, snapshot) {
                                                  Duration elapsed = DateTime.now().duration() - start;
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                                                    width: textFieldSize.width - (samsung ? 0 : 80),
                                                    height: textFieldSize.height - 15,
                                                    child: Center(
                                                      child: AnimatedOpacity(
                                                        duration: const Duration(seconds: 1),
                                                        opacity: (elapsed.inMilliseconds ~/ 1200 % 2 + 0.5).clamp(0, 1),
                                                        child:
                                                            Text("Recording... (${prettyDuration(elapsed)})", style: context.textTheme.titleMedium),
                                                      ),
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
                                                })
                                            : VoiceMessageRecorder(
                                              recorderController: recorderController,
                                              textFieldSize: textFieldSize,
                                              iOS: iOS,
                                              samsung: samsung,
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
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeIn,
              alignment: Alignment.bottomCenter,
              child: Obx(() {
                return showEmojiPicker.value
                    ? Theme(
                        data: context.theme.copyWith(canvasColor: Colors.transparent),
                        child: EmojiPicker(
                          textEditingController: proxyController,
                          scrollController: ScrollController(),
                          config: Config(
                            height: emojiPickerHeight,
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              emojiSizeMax: 28,
                              backgroundColor: Colors.transparent,
                              columns: emojiColumns,
                              noRecents: Text("No Recents", style: context.textTheme.headlineMedium!.copyWith(color: context.theme.colorScheme.outline)),
                            ),
                            viewOrderConfig: const ViewOrderConfig(
                              top: EmojiPickerItem.searchBar,
                              middle: EmojiPickerItem.emojiView,
                              bottom: EmojiPickerItem.categoryBar,
                            ),
                            skinToneConfig: const SkinToneConfig(enabled: false),
                            categoryViewConfig: const CategoryViewConfig(
                              backgroundColor: Colors.transparent,
                              dividerColor: Colors.transparent,
                            ),
                            bottomActionBarConfig: BottomActionBarConfig(
                              customBottomActionBar: (Config config, EmojiViewState state, VoidCallback showSearchView) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Material(
                                          child: InkWell(
                                            onTap: showSearchView,
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(children: [
                                                Icon(
                                                  iOS ? CupertinoIcons.search : Icons.search,
                                                  color: context.theme.colorScheme.outline,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    "Search...",
                                                    style: context.theme.textTheme.bodyLarge!.copyWith(
                                                      color: context.theme.colorScheme.outline,
                                                    ),
                                                  ),
                                                ),
                                              ]),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: IconButton(
                                          icon: Icon(
                                            iOS ? CupertinoIcons.xmark : Icons.close,
                                            color: context.theme.colorScheme.outline,
                                          ),
                                          onPressed: () {
                                            showEmojiPicker.value = false;
                                            controller.lastFocusedNode.requestFocus();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                );
                              },
                            ),
                            searchViewConfig: SearchViewConfig(
                              backgroundColor: Colors.transparent,
                              buttonIconColor: context.theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class TextFieldComponent extends StatefulWidget {
  const TextFieldComponent({
    super.key,
    this.subjectTextController,
    required this.textController,
    required this.controller,
    required this.recorderController,
    required this.sendMessage,
    this.focusNode,
    this.initialAttachments = const [],
  });

  final SpellCheckTextEditingController? subjectTextController;
  final MentionTextEditingController textController;
  final ConversationViewController? controller;
  final RecorderController? recorderController;
  final Future<void> Function({String? effect}) sendMessage;
  final FocusNode? focusNode;

  final List<PlatformFile> initialAttachments;

  @override
  State<StatefulWidget> createState() => TextFieldComponentState();
}


class TextFieldComponentState extends State<TextFieldComponent> {
  late final ConversationViewController? controller;
  late final FocusNode? focusNode;
  late final RecorderController? recorderController;
  late final List<PlatformFile> initialAttachments;
  late final MentionTextEditingController textController;
  late final SpellCheckTextEditingController? subjectTextController;
  late final Future<void> Function({String? effect}) sendMessage;

  late final ValueNotifier<bool> isRecordingNotifier;
  TextFieldComponentState() : isRecordingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    focusNode = widget.focusNode;
    recorderController = widget.recorderController;
    initialAttachments = widget.initialAttachments;
    textController = widget.textController;
    subjectTextController = widget.subjectTextController;
    sendMessage = widget.sendMessage;

    // add a listener to recorderController to update isRecordingNotifier
    recorderController?.addListener(() {
      isRecordingNotifier.value = recorderController?.isRecording ?? false;
    });

    assert(!(subjectTextController == null && !isChatCreator && ss.settings.enablePrivateAPI.value && ss.settings.privateSubjectLine.value && chat!.isIMessage));
  }

  @override
  void dispose() {
    // dispose of the ValueNotifier when the state is disposed
    isRecordingNotifier.dispose();
    super.dispose();
  }

  bool get iOS => ss.settings.skin.value == Skins.iOS;

  bool get samsung => ss.settings.skin.value == Skins.Samsung;

  Chat? get chat => controller?.chat;

  bool get isChatCreator => focusNode != null;

  @override
  Widget build(BuildContext context) {
    final txtController = controller?.textController ?? textController;
    final subjController = controller?.subjectTextController ?? subjectTextController;
    return Focus(
      onKeyEvent: (_, ev) => handleKey(_, ev, context, isChatCreator),
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: ValueListenableBuilder<bool>(
        valueListenable: isRecordingNotifier,
        builder: (context, isRecording, child) {
        return Container(
          decoration: iOS
              ? BoxDecoration(
                  border: Border.fromBorderSide(BorderSide(
                    color: (isRecording & iOS) ? context.theme.colorScheme.primary.withOpacity(1.0) : context.theme.colorScheme.properSurface,
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
                    textController: txtController,
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
                    controller: subjController,
                    scrollPhysics: const CustomBouncingScrollPhysics(),
                    style: context.theme.extension<BubbleText>()!.bubbleText.copyWith(fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.multiline,
                    maxLines: 14,
                    minLines: 1,
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
                      controller?.subjectFocusNode.requestFocus();
                    },
                    contentInsertionConfiguration: ContentInsertionConfiguration(onContentInserted: onContentCommit),
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
                  focusNode: controller?.focusNode ?? focusNode,
                  autocorrect: true,
                  controller: txtController,
                  scrollPhysics: const CustomBouncingScrollPhysics(),
                  style: context.theme.extension<BubbleText>()!.bubbleText,
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
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
                            ? isRecording ? "" : chat!.getTitle()
                            : (chat!.isTextForwarding && !isRecording)
                                ? "Text Forwarding"
                                : (!isRecording) // Only show iMessage when not recording
                                  ? "iMessage" : "",
                    enabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: (isRecording & iOS),
                    fillColor: (isRecording & iOS) ? context.theme.colorScheme.primary.withOpacity(0.3) : Colors.transparent,
                    hintStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                    suffixIconConstraints: const BoxConstraints(minHeight: 0),
                    suffixIcon: samsung && !isChatCreator
                        ? null
                        : Padding(
                            padding: EdgeInsets.only(right: iOS ? 0.0 : 5.0),
                            child: TextFieldSuffix(
                              subjectTextController: subjController,
                              textController: txtController,
                              controller: controller,
                              recorderController: recorderController,
                              sendMessage: sendMessage,
                              isChatCreator: isChatCreator,
                            ),
                          ),
                  ),
                  contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                    final start = editableTextState.textEditingValue.selection.start;
                    final end = editableTextState.textEditingValue.selection.end;
                    final text = editableTextState.textEditingValue.text;
                    final selected = editableTextState.textEditingValue.text
                        .substring((start - 1).clamp(0, text.length), (end + 1).clamp(min(1, text.length), text.length));

                    return AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    )..buttonItems?.addAllIf(
                        MentionTextEditingController.escapingRegex.allMatches(selected).length == 1,
                        [
                          ContextMenuButtonItem(
                            onPressed: () {
                              final TextSelection selection = editableTextState.textEditingValue.selection;
                              if (selection.isCollapsed) {
                                return;
                              }
                              String text = editableTextState.textEditingValue.text;
                              final textPart = text.substring(0, (end + 1).clamp(1, text.length));
                              final mentionMatch = MentionTextEditingController.escapingRegex.allMatches(textPart).lastOrNull;
                              if (mentionMatch == null) return; // Shouldn't happen
                              final mentionText = textPart.substring(mentionMatch.start, mentionMatch.end);
                              int? mentionIndex = int.tryParse(mentionText.substring(1, mentionText.length - 1));
                              if (mentionIndex == null) return; // Shouldn't happen
                              final mention = controller?.mentionables[mentionIndex];
                              final replacement = mention != null ? "@${mention.displayName}" : "";
                              text = editableTextState.textEditingValue.text
                                  .replaceRange((start - 1).clamp(0, text.length), (end + 1).clamp(min(1, text.length), text.length), replacement);
                              final checkSpace = end + replacement.length - 1;
                              final spaceAfter =
                                  checkSpace < text.length && text.substring(end + replacement.length - 1, end + replacement.length) == " ";
                              (controller?.textController ?? textController).value = TextEditingValue(
                                  text: text,
                                  selection: TextSelection.fromPosition(
                                      TextPosition(offset: selection.baseOffset + replacement.length + (spaceAfter ? 1 : 0))));
                              editableTextState.hideToolbar();
                            },
                            label: "Remove Mention",
                          ),
                          ContextMenuButtonItem(
                            onPressed: () async {
                              final text = editableTextState.textEditingValue.text;
                              final textPart = text.substring(0, (end + 1).clamp(1, text.length));
                              final mentionMatch = MentionTextEditingController.escapingRegex.allMatches(textPart).lastOrNull;
                              if (mentionMatch == null) return; // Shouldn't happen
                              final mentionText = textPart.substring(mentionMatch.start, mentionMatch.end);
                              int? mentionIndex = int.tryParse(mentionText.substring(1, mentionText.length - 1));
                              if (mentionIndex == null) return; // Shouldn't happen
                              final mention = controller?.mentionables[mentionIndex];
                              if (kIsDesktop || kIsWeb) {
                                controller?.showingOverlays = true;
                              }
                              final changed = await showCustomMentionDialog(context, mention);
                              if (kIsDesktop || kIsWeb) {
                                controller?.showingOverlays = false;
                              }
                              if (!isNullOrEmpty(changed) && mention != null) {
                                mention.customDisplayName = changed!;
                              }
                              final spaceAfter = end < text.length && text.substring(end, end + 1) == " ";
                              txtController.selection = TextSelection.fromPosition(TextPosition(offset: end + (spaceAfter ? 1 : 0)));
                              editableTextState.hideToolbar();
                            },
                            label: "Custom Mention",
                          ),
                        ],
                      );
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  onSubmitted: (String value) {
                    controller?.focusNode.requestFocus();
                    if (isNullOrEmpty(value) && (controller?.pickedAttachments.isEmpty ?? false)) return;
                    sendMessage.call();
                  },
                  contentInsertionConfiguration: ContentInsertionConfiguration(onContentInserted: onContentCommit),
                ),
              ],
            ),
          ),
        );
        }
        ),
      ),
    );
  }

  void onContentCommit(KeyboardInsertedContent content) async {
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

  KeyEventResult handleKey(FocusNode _, KeyEvent ev, BuildContext context, bool isChatCreator) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;

    if ((kIsWeb || Platform.isWindows || Platform.isLinux) &&
        (ev.physicalKey == PhysicalKeyboardKey.keyV || ev.logicalKey == LogicalKeyboardKey.keyV) &&
        HardwareKeyboard.instance.isControlPressed) {
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

    if (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    if (isChatCreator) {
      if (ev.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
        sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    int maxShown = context.height / 3 ~/ 40;
    int upMovementIndex = maxShown ~/ 3;
    int downMovementIndex = maxShown * 2 ~/ 3;

    // Down arrow
    if (ev.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (controller!.mentionSelectedIndex.value < controller!.mentionMatches.length - 1) {
        controller!.mentionSelectedIndex.value++;
        if (controller!.mentionSelectedIndex.value >= downMovementIndex &&
            controller!.mentionSelectedIndex < controller!.mentionMatches.length - maxShown + downMovementIndex + 1) {
          controller!.emojiScrollController
              .jumpTo(max((controller!.mentionSelectedIndex.value - downMovementIndex) * 40, controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
      if (controller!.emojiSelectedIndex.value < controller!.emojiMatches.length - 1) {
        controller!.emojiSelectedIndex.value++;
        if (controller!.emojiSelectedIndex.value >= downMovementIndex &&
            controller!.emojiSelectedIndex < controller!.emojiMatches.length - maxShown + downMovementIndex + 1) {
          controller!.emojiScrollController
              .jumpTo(max((controller!.emojiSelectedIndex.value - downMovementIndex) * 40, controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
    }

    // Up arrow
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (chat != null &&
          controller!.lastFocusedTextController.text.isEmpty &&
          ss.settings.editLastSentMessageOnUpArrow.value &&
          ss.isMinVenturaSync &&
          ss.serverDetailsSync().item4 >= 148) {
        final message = ms(chat!.guid).mostRecentSent;
        if (message != null && !message.guid!.startsWith("temp")) {
          final parts = mwc(message).parts;
          final part = parts.filter((p) => p.text?.isNotEmpty ?? false).lastOrNull;
          if (part != null) {
            final FocusNode? node = kIsDesktop || kIsWeb ? FocusNode() : null;
            controller!.editing.add(Tuple3(message, part, SpellCheckTextEditingController(text: part.text!, focusNode: node)));
            node?.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }
      if (controller!.mentionSelectedIndex.value > 0) {
        controller!.mentionSelectedIndex.value--;
        if (controller!.mentionSelectedIndex.value >= upMovementIndex &&
            controller!.mentionSelectedIndex < controller!.mentionMatches.length - maxShown + upMovementIndex + 1) {
          controller!.emojiScrollController
              .jumpTo(min((controller!.mentionSelectedIndex.value - upMovementIndex) * 40, controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
      if (controller!.emojiSelectedIndex.value > 0) {
        controller!.emojiSelectedIndex.value--;
        if (controller!.emojiSelectedIndex.value >= upMovementIndex &&
            controller!.emojiSelectedIndex < controller!.emojiMatches.length - maxShown + upMovementIndex + 1) {
          controller!.emojiScrollController
              .jumpTo(min((controller!.emojiSelectedIndex.value - upMovementIndex) * 40, controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
    }

    // Tab or Enter
    if (ev.logicalKey == LogicalKeyboardKey.tab || ev.logicalKey == LogicalKeyboardKey.enter) {
      if (controller!.focusNode.hasPrimaryFocus && controller!.mentionMatches.length > controller!.mentionSelectedIndex.value) {
        int index = controller!.mentionSelectedIndex.value;
        TextEditingController textField =
            controller!.subjectFocusNode.hasPrimaryFocus ? controller!.subjectTextController : controller!.textController;
        String text = textField.text;
        RegExp regExp = RegExp(r"@(?:[^@ \n]+|$)(?=[ \n]|$)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        if (matches.isNotEmpty && matches.any((m) => m.start < textField.selection.start)) {
          RegExpMatch match = matches.lastWhere((m) => m.start < textField.selection.start);
          controller!.textController.addMention(text.substring(match.start, match.end), controller!.mentionMatches[index]);
        } else {
          // If the user moved the cursor before trying to insert a mention, reset the picker
          controller!.emojiScrollController.jumpTo(0);
        }
        controller!.mentionSelectedIndex.value = 0;
        controller!.mentionMatches.value = <Mentionable>[];

        return KeyEventResult.handled;
      }
      if (controller!.emojiMatches.length > controller!.emojiSelectedIndex.value) {
        int index = controller!.emojiSelectedIndex.value;
        TextEditingController textField =
            controller!.subjectFocusNode.hasPrimaryFocus ? controller!.subjectTextController : controller!.textController;
        String text = textField.text;
        RegExp regExp = RegExp(r":[^: \n]{2,}(?=[ \n]|$)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        if (matches.isNotEmpty && matches.any((m) => m.start < textField.selection.start)) {
          RegExpMatch match = matches.lastWhere((m) => m.start < textField.selection.start);
          String char = controller!.emojiMatches[index].char;
          String _text = "${text.substring(0, match.start)}$char ${text.substring(match.end)}";
          textField.value = TextEditingValue(text: _text, selection: TextSelection.collapsed(offset: match.start + char.length + 1));
        } else {
          // If the user moved the cursor before trying to insert an emoji, reset the picker
          controller!.emojiScrollController.jumpTo(0);
        }
        controller!.emojiSelectedIndex.value = 0;
        controller!.emojiMatches.value = <Emoji>[];

        return KeyEventResult.handled;
      }
      if (ss.settings.privateSubjectLine.value) {
        if (ev.logicalKey == LogicalKeyboardKey.tab) {
          // Tab to switch between text fields
          if (!HardwareKeyboard.instance.isShiftPressed && controller!.subjectFocusNode.hasPrimaryFocus) {
            controller!.focusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (HardwareKeyboard.instance.isShiftPressed && controller!.focusNode.hasPrimaryFocus) {
            controller!.subjectFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }
    }

    // Escape
    if (ev.logicalKey == LogicalKeyboardKey.escape) {
      if (controller!.mentionMatches.isNotEmpty) {
        controller!.mentionMatches.value = <Mentionable>[];
        return KeyEventResult.handled;
      }
      if (controller!.emojiMatches.isNotEmpty) {
        controller!.emojiMatches.value = <Emoji>[];
        return KeyEventResult.handled;
      }
      if (controller!.showEmojiPicker.value) {
        controller!.showEmojiPicker.value = false;
        return KeyEventResult.handled;
      }
      if (controller!.replyToMessage != null) {
        controller!.replyToMessage = null;
        return KeyEventResult.handled;
      }
    }

    if ((kIsDesktop || kIsWeb) && ev.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
      sendMessage();
      controller!.focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (kIsDesktop || kIsWeb) return KeyEventResult.ignored;
    if (ev.physicalKey == PhysicalKeyboardKey.enter && ss.settings.sendWithReturn.value) {
      if (!isNullOrEmpty(textController.text) || !isNullOrEmpty(controller!.subjectTextController.text)) {
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
