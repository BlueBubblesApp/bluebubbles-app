import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/text_field/attachments/list/text_field_attachment_list.dart';
import 'package:bluebubbles/app/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/app/widgets/cupertino/custom_cupertino_text_field.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/app/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/widgets/components/send_effect_picker.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/ui/chat/chat_lifecycle_manager.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:dio/dio.dart';
import 'package:emojis/emoji.dart';
import 'package:faker/faker.dart';
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';
import 'package:transparent_pointer/transparent_pointer.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class BlueBubblesTextField extends StatefulWidget {
  final Future<bool> Function(
      List<PlatformFile> attachments, String text, String subject, String? replyToGuid, String? effectId) onSend;
  final ConversationViewController controller;

  BlueBubblesTextField({
    Key? key,
    required this.onSend,
    required this.controller,
  }) : super(key: key);

  static BlueBubblesTextFieldState? of(BuildContext context) {
    return context.findAncestorStateOfType<BlueBubblesTextFieldState>();
  }

  @override
  BlueBubblesTextFieldState createState() => BlueBubblesTextFieldState();
}

class BlueBubblesTextFieldState extends State<BlueBubblesTextField> with TickerProviderStateMixin {
  TextEditingController? controller;
  FocusNode? focusNode;
  TextEditingController? subjectController;
  FocusNode? subjectFocusNode;
  List<PlatformFile> pickedImages = [];
  DropzoneViewController? dropZoneController;
  ChatLifecycleManager? safeChat;
  late final Chat chat = widget.controller.chat;
  String get chatGuid => chat.guid;
  ConversationViewController get cvController => widget.controller;
  Rxn<Message?> replyToMessage = Rxn();

  bool selfTyping = false;
  int? sendCountdown;
  bool? stopSending;
  bool fileDragged = false;
  int? previousKeyCode;

  final RxString placeholder = "BlueBubbles".obs;
  final RxBool isRecording = false.obs;
  final RxBool canRecord = true.obs;

  // bool selfTyping = false;

  bool get _canRecord => controller!.text.isEmpty && pickedImages.isEmpty && subjectController!.text.isEmpty && !recordDelay;
  bool recordDelay = false;
  Timer? _debounce;

  final RxBool showShareMenu = false.obs;

  final GlobalKey<FormFieldState<String>> _searchFormKey = GlobalKey<FormFieldState<String>>();

  Rx<List<Emoji>> emojiMatches = Rx(<Emoji>[]);
  Map<String, Emoji> emojiNames = {};
  Map<String, Emoji> emojiFullNames = {};
  RxInt emojiSelectedIndex = 0.obs;
  String previousText = "";
  ScrollController emojiController = ScrollController();

  @override
  void initState() {
    super.initState();

    eventDispatcher.stream.listen((e) {
      if (e.item1 == 'update-emoji-picker') {
        if (e.item2['chatGuid'] != chatGuid) return;
        emojiSelectedIndex.value = 0;
        emojiMatches.value = e.item2['emojiMatches'];
      } else if (e.item1 == 'replace-emoji') {
        if (e.item2['chatGuid'] != chatGuid) return;
        emojiSelectedIndex.value = 0;
        int index = e.item2['emojiMatchIndex'];
        String text = controller!.text;
        RegExp regExp = RegExp(":[^: \n]{1,}([ \n:]|\$)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        if (matches.isNotEmpty && matches.any((m) => m.start < controller!.selection.start)) {
          RegExpMatch match = matches.lastWhere((m) => m.start < controller!.selection.start);
          String char = emojiMatches.value[index].char;
          emojiMatches.value = <Emoji>[];
          String _text = "${text.substring(0, match.start)}$char ${text.substring(match.end)}";
          controller!.text = _text;
          controller!.selection = TextSelection.fromPosition(TextPosition(offset: match.start + char.length + 1));
        } else {
          // If the user moved the cursor before trying to insert an emoji, reset the picker
          emojiSelectedIndex.value = 0;
          emojiMatches.value = <Emoji>[];
        }
        eventDispatcher.emit('focus-keyboard', null);
      }
    });

    emojiNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.shortName, e)));
    emojiFullNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.name, e)));

    getPlaceholder();

    controller = TextEditingController(text: chat.textFieldText);
    subjectController = TextEditingController();

    // Add the text listener to detect when we should send the typing indicators
    controller!.addListener(() {
      setCanRecord();
      if (!mounted || chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!ss.settings.enablePrivateAPI.value ||
          !ss.settings.privateSendTypingIndicators.value) {
        return;
      }

      if (controller!.text.isEmpty && pickedImages.isEmpty && selfTyping) {
        selfTyping = false;
        socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
      } else if (!selfTyping && (controller!.text.isNotEmpty || pickedImages.isNotEmpty)) {
        selfTyping = true;
        if (ss.settings.privateSendTypingIndicators.value &&
            chat.autoSendTypingIndicators!) {
          socket.sendMessage("started-typing", {"chatGuid": chatGuid});
        }
      }

      if (mounted) setState(() {});
    });
    subjectController!.addListener(() {
      setCanRecord();
      if (!mounted || chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!ss.settings.enablePrivateAPI.value ||
          !ss.settings.privateSendTypingIndicators.value) {
        return;
      }

      if (subjectController!.text.isEmpty && pickedImages.isEmpty && selfTyping) {
        selfTyping = false;
        socket.sendMessage("stopped-typing", {"chatGuid": chatGuid});
      } else if (!selfTyping && (subjectController!.text.isNotEmpty || pickedImages.isNotEmpty)) {
        selfTyping = true;
        if (ss.settings.privateSendTypingIndicators.value &&
            chat.autoSendTypingIndicators!) {
          socket.sendMessage("started-typing", {"chatGuid": chatGuid});
        }
      }

      if (mounted) setState(() {});
    });

    // Add a listener for emoji
    controller!.addListener(() {
      String text = controller!.text;
      chat.textFieldText = text;
      if (text != previousText) {
        previousText = text;
        RegExp regExp = RegExp(r"(?<=^| |\n):[^: \n]{2,}((?=[ \n]|$)|:)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        List<Emoji> allMatches = [];
        String emojiName = "";
        if (matches.isNotEmpty && matches.first.start < controller!.selection.start) {
          RegExpMatch match = matches.lastWhere((m) => m.start < controller!.selection.start);
          if (text[match.end - 1] == ":") {
            // Full emoji text (do not search for partial matches
            emojiName = text.substring(match.start + 1, match.end - 1).toLowerCase();
            if (emojiNames.keys.contains(emojiName)) {
              allMatches = [Emoji.byShortName(emojiName)!];
              // We can replace the :emoji: with the actual emoji here
              String _text = text.substring(0, match.start) + allMatches.first.char + text.substring(match.end);
              controller!.text = _text;
              controller!.selection =
                  TextSelection.fromPosition(TextPosition(offset: match.start + allMatches.first.char.length));
              allMatches = <Emoji>[];
            } else {
              allMatches = Emoji.byKeyword(emojiName).toList();
            }
          } else if (match.end >= controller!.selection.start) {
            emojiName = text.substring(match.start + 1, match.end).toLowerCase();
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
          print("${allMatches.length} matches found for: $emojiName");
        }
        eventDispatcher
            .emit('update-emoji-picker', {'emojiMatches': allMatches.toList(), 'chatGuid': chatGuid});
      }
    });

    // Create the focus node and then add a an event emitter whenever
    // the focus changes
    focusNode = FocusNode();
    subjectFocusNode = FocusNode();
    focusNode!.addListener(() {
      cvController.keyboardOpen = focusNode?.hasFocus ?? false;

      if (focusNode!.hasFocus && mounted) {
        if (!showShareMenu.value) return;
        showShareMenu.value = false;
      }

      eventDispatcher.emit("keyboard-status", focusNode!.hasFocus);
    });
    subjectFocusNode!.addListener(() {
      cvController.keyboardOpen = focusNode?.hasFocus ?? false;

      if (focusNode!.hasFocus && mounted) {
        if (!showShareMenu.value) return;
        showShareMenu.value = false;
      }

      eventDispatcher.emit("keyboard-status", focusNode!.hasFocus);
    });

    if (kIsWeb) {
      html.document.onDragOver.listen((event) {
        var t = event.dataTransfer;
        if (t.types != null && t.types!.length == 1 && t.types!.first == "Files" && fileDragged == false) {
          setState(() {
            fileDragged = true;
          });
        }
      });

      html.document.onDragLeave.listen((event) {
        if (fileDragged == true) {
          setState(() {
            fileDragged = false;
          });
        }
      });
    }

    eventDispatcher.stream.listen((event) {
      if (event.item1 == "unfocus-keyboard" && (focusNode!.hasFocus || subjectFocusNode!.hasFocus)) {
        focusNode!.unfocus();
        subjectFocusNode!.unfocus();
      } else if (event.item1 == "focus-keyboard" && !focusNode!.hasFocus && !subjectFocusNode!.hasFocus) {
        focusNode!.requestFocus();
        if (event.item2 is Message) {
          replyToMessage.value = event.item2;
        }
      } else if (event.item1 == "text-field-update-attachments") {
        addSharedAttachments();
        while (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      } else if (event.item1 == "text-field-update-text") {
        while (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      } else if (event.item1 == "focus-keyboard" && event.item2 != null) {
        replyToMessage.value = event.item2;
      }
    });

    getCachedAttachments();

    setCanRecord();
  }

  void setCanRecord() {
    bool canRec = _canRecord;
    if (canRec != canRecord.value) {
      canRecord.value = canRec;
    }
  }

  void getCachedAttachments() async {
    if (chat.textFieldAttachments.isNotEmpty ?? false) {
      for (String s in chat.textFieldAttachments) {
        final file = File(s);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          addAttachments([
            PlatformFile(
              name: file.path.split("/").last,
              bytes: bytes,
              size: bytes.length,
              path: s,
            ),
          ]);
        }
      }
    }
  }

  void addAttachments(List<PlatformFile> attachments) {
    pickedImages.addAll(attachments);
    if (!kIsWeb) pickedImages = pickedImages.toSet().toList();
    setCanRecord();
  }

  void updateTextFieldAttachments() {
    chat.textFieldAttachments.addAll(pickedImages.where((e) => e.path != null).map((e) => e.path!));

    setCanRecord();
  }

  void addSharedAttachments() {
    getCachedAttachments();
    setCanRecord();
  }

  @override
  void dispose() {
    focusNode!.dispose();
    subjectFocusNode!.dispose();
    if (safeChat?.chat == null) controller!.dispose();
    if (safeChat?.chat == null) subjectController!.dispose();

    if (!kIsWeb) {
      Directory tempAssets = Directory("${fs.appDocDir.path}/tempAssets");
      tempAssets.exists().then((value) {
        if (value) {
          tempAssets.delete(recursive: true);
        }
      });
    }
    pickedImages = [];
    chat.save(updateTextFieldText: true, updateTextFieldAttachments: true);
    super.dispose();
  }

  void disposeAudioFile(BuildContext context, PlatformFile file) {
    // Dispose of the audio controller
    cvController.audioPlayers[file.path]?.item1.dispose();
    cvController.audioPlayers[file.path]?.item2.pause();
    cvController.audioPlayers.removeWhere((key, _) => key == file.path);
    if (file.path != null) {
      // Delete the file
      File(file.path!).delete();
    }
  }

  // void onContentCommit(CommittedContent content) async {
  //   // Add some debugging logs
  //   Logger.info("[Content Commit] Keyboard received content");
  //   Logger.info("  -> Content Type: ${content.mimeType}");
  //   Logger.info("  -> URI: ${content.uri}");
  //   Logger.info("  -> Content Length: ${content.hasData ? content.data!.length : "null"}");

  //   // Parse the filename from the URI and read the data as a List<int>
  //   String filename = uriToFilename(content.uri, content.mimeType);

  //   // Save the data to a location and add it to the file picker
  //   if (content.hasData) {
  //     addAttachments([PlatformFile(
  //       name: filename,
  //       size: content.data!.length,
  //       bytes: content.data,
  //     )]);

  //     // Update the state
  //     updateTextFieldAttachments();
  //     if (mounted) setState(() {});
  //   } else {
  //     showSnackbar('Insertion Failed', 'Attachment has no data!');
  //   }
  // }

  Future<void> reviewAudio(BuildContext originalContext, PlatformFile file) async {
    showDialog(
      context: originalContext,
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
                key: Key("AudioMessage-${file.size}"),
                file: file,
                context: originalContext,
              )
            ],
          ),
          actions: <Widget>[
            TextButton(
                child: Text("Discard", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () {
                  // Dispose of the audio controller
                  if (!kIsWeb) disposeAudioFile(originalContext, file);

                  // Remove the OG alert dialog
                  Get.back();
                }),
            TextButton(
              child: Text(
                "Send", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
              onPressed: () async {
                await widget.onSend([file], "", "", null, null);
                if (!kIsWeb) disposeAudioFile(originalContext, file);

                // Remove the OG alert dialog
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> toggleShareMenu() async {
    if (kIsDesktop) {
      final res = await FilePicker.platform.pickFiles(withReadStream: true, allowMultiple: true);
      if (res == null || res.files.isEmpty || res.files.first.readStream == null) return;

      for (pf.PlatformFile e in res.files) {
        if (e.size / 1024000 > 100) {
          showSnackbar("Error", "This file is over 100 MB! Please compress it before sending.");
          continue;
        }
        addAttachment(PlatformFile(
          path: e.path,
          name: e.name,
          size: e.size,
          bytes: await readByteStream(e.readStream!),
        ));
      }
      Get.back();
      return;
    }
    if (kIsWeb) {
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
                  if (e.size / 1024000 > 100) {
                    showSnackbar("Error", "This file is over 100 MB! Please compress it before sending.");
                    continue;
                  }
                  addAttachment(PlatformFile(
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
        )
      );
      return;
    }

    bool showMenu = showShareMenu.value;

    // If the image picker is already open, close it, and return
    if (!showMenu) {
      focusNode!.unfocus();
      subjectFocusNode!.unfocus();
    }
    if (!showMenu && !(await PhotoManager.requestPermissionExtend()).isAuth) {
      showShareMenu.value = false;
      return;
    }

    showShareMenu.value = !showMenu;
  }

  Future<bool> _onWillPop() async {
    if (showShareMenu.value) {
      if (mounted) {
        showShareMenu.value = false;
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      top: false,
      child: WillPopScope(
          onWillPop: _onWillPop,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: 5, top: 5, bottom: 5, right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      buildAttachmentList(),
                      buildTextFieldAlwaysVisible(),
                      buildAttachmentPicker(),
                    ],
                  ),
                ),
              ),
            ],
          )),
    );
  }

  Widget buildAttachmentList() => Padding(
        padding: EdgeInsets.only(left: kIsWeb || kIsDesktop ? 90 : 50.0),
        child: TextFieldAttachmentList(
          attachments: pickedImages,
          onRemove: (PlatformFile attachment) {
            pickedImages.removeWhere((element) => kIsWeb || attachment.path == null
                ? element.bytes == attachment.bytes
                : element.path == attachment.path);
            updateTextFieldAttachments();
            if (mounted) setState(() {});
          },
        ),
      );

  Widget buildTextFieldAlwaysVisible() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        buildShareButton(),
        if (kIsWeb || kIsDesktop) buildGIFButton(),
        if (kIsDesktop) buildLocationButton(),
        Flexible(
          flex: 1,
          fit: FlexFit.loose,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              buildActualTextField(),
              Obx(() {
                List<Emoji> emojis = emojiMatches.value;
                return Positioned(
                  left: 0,
                  right: 0,
                  height: min(emojiMatches.value.length * 48, context.height ~/ 144 * 48),
                  bottom: 48 +
                      (replyToMessage.value != null ? 40 : 0) +
                      (ss.settings.enablePrivateAPI.value &&
                              ss.settings.privateSubjectLine.value
                          ? 40
                          : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: MediaQuery.removePadding(
                      removeTop: true,
                      context: context,
                      child: Scrollbar(
                        radius: Radius.circular(4),
                        controller: emojiController,
                        child: DeferPointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: context.theme.colorScheme.properSurface,
                              boxShadow: [
                                BoxShadow(
                                  color: context.theme.colorScheme.shadow,
                                  offset: Offset(0, 0),
                                  blurRadius: 20,
                                  blurStyle: BlurStyle.outer,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ListView.builder(
                                controller: emojiController,
                                physics: CustomBouncingScrollPhysics(),
                                itemBuilder: (BuildContext context, int index) => Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTapDown: (details) {
                                      emojiSelectedIndex.value = index;
                                    },
                                    onTap: () {
                                      eventDispatcher.emit(
                                          'replace-emoji', {'emojiMatchIndex': index, 'chatGuid': chatGuid});
                                    },
                                    child: Obx(
                                      () => ListTile(
                                        dense: true,
                                        selectedTileColor: context.theme.colorScheme.properSurface.lightenOrDarken(20),
                                        selected: emojiSelectedIndex.value == index,
                                        title: Row(
                                          children: <Widget>[
                                            Text(
                                              emojis[index].char,
                                              style:
                                                  context.textTheme.labelLarge!.apply(fontFamily: "Apple Color Emoji"),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              ":${emojis[index].shortName}:",
                                              style: context.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                itemCount: emojiMatches.value.length,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (ss.settings.skin.value == Skins.Material ||
            ss.settings.skin.value == Skins.Samsung)
          buildSendButton(),
      ],
    );
  }

  Widget buildShareButton() {
    double size = ss.settings.skin.value == Skins.iOS ? 37 : 40;
    return AnimatedSize(
      duration: Duration(milliseconds: 300),
      child: Container(
        height: size,
        width: fileDragged ? size * 3 : size,
        margin: EdgeInsets.only(
            left: 5.0, right: 5.0, bottom: ss.settings.skin.value == Skins.iOS && kIsDesktop ? 4.5 : 0),
        decoration: BoxDecoration(
          color: ss.settings.skin.value == Skins.Samsung ? null : context.theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(fileDragged ? 5 : 40),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (kIsWeb)
              DropzoneView(
                operation: DragOperation.copy,
                cursor: CursorType.auto,
                onCreated: (c) {
                  dropZoneController = c;
                },
                onDrop: (ev) async {
                  fileDragged = false;
                  addAttachment(PlatformFile(
                      name: await dropZoneController!.getFilename(ev),
                      bytes: await dropZoneController!.getFileData(ev),
                      size: await dropZoneController!.getFileSize(ev)));
                },
              ),
            TransparentPointer(
              child: ClipRRect(
                child: InkWell(
                  onTap: toggleShareMenu,
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: ss.settings.skin.value == Skins.iOS ? 0 : 1,
                        left: ss.settings.skin.value == Skins.iOS ? 0.5 : 0),
                    child: fileDragged
                        ? Center(child: Text("Drop file here"))
                        : Icon(
                            ss.settings.skin.value == Skins.iOS
                                ? CupertinoIcons.share
                                : kIsDesktop ? Icons.file_upload : ss.settings.skin.value == Skins.Samsung
                                    ? Icons.add
                                    : Icons.share,
                            color: ss.settings.skin.value == Skins.Samsung
                                ? context.theme.colorScheme.onBackground
                                : context.theme.colorScheme.onPrimary,
                            size: ss.settings.skin.value == Skins.Samsung ? 26 : 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildGIFButton() {
    double size = ss.settings.skin.value == Skins.iOS ? 37 : 40;
    return Container(
      height: size,
      width: size,
      margin: EdgeInsets.only(
          right: 5.0, bottom: ss.settings.skin.value == Skins.iOS && kIsDesktop ? 4.5 : 0),
      child: ClipOval(
        child: Material(
          color: ss.settings.skin.value == Skins.Samsung
              ? Colors.transparent
              : context.theme.colorScheme.primary,
          child: Theme(
            data: context.theme.copyWith(
              bottomSheetTheme: BottomSheetThemeData(
                backgroundColor: context.theme.colorScheme.properSurface,
                modalBackgroundColor: context.theme.colorScheme.properSurface,
              ),
              brightness: context.theme.colorScheme.brightness,
              canvasColor: context.theme.colorScheme.properSurface,
              iconTheme: IconThemeData(color: context.theme.colorScheme.properOnSurface),
            ),
            child: Builder(builder: (context) {
              return InkWell(
                onTap: () async {
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
                        addAttachment(PlatformFile(
                          path: null,
                          name: "${gif.title ?? randomString(8)}.gif",
                          size: data.length,
                          bytes: data,
                        ));
                        return;
                      } catch (_) {}
                    }
                  }
                  if (gif != null) {
                    showSnackbar("Error", "Something went wrong, please try again.");
                  }
                },
                child: Padding(
                  padding: EdgeInsets.only(
                      right: ss.settings.skin.value == Skins.iOS ? 0 : 1,
                      left: ss.settings.skin.value == Skins.iOS ? 0.5 : 0),
                  child: Icon(
                    Icons.gif,
                    color: ss.settings.skin.value == Skins.Samsung
                        ? context.theme.colorScheme.onBackground
                        : context.theme.colorScheme.onPrimary,
                    size: 26,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget buildLocationButton() {
    double size = ss.settings.skin.value == Skins.iOS ? 37 : 40;
    return Container(
      height: size,
      width: size,
      margin: EdgeInsets.only(
          right: 5.0, bottom: ss.settings.skin.value == Skins.iOS && kIsDesktop ? 4.5 : 0),
      child: ClipOval(
        child: Material(
          color: ss.settings.skin.value == Skins.Samsung
              ? Colors.transparent
              : context.theme.colorScheme.primary,
          child: InkWell(
            onTap: () async {
              await Share.location(chat);
            },
            child: Padding(
              padding: EdgeInsets.only(
                  top: ss.settings.skin.value == Skins.iOS ? 1 : 0,
                  right: ss.settings.skin.value == Skins.iOS ? 0 : 1,
                  left: ss.settings.skin.value == Skins.iOS ? 1 : 2),
              child: Icon(
                ss.settings.skin.value == Skins.iOS ? CupertinoIcons.location_solid : Icons.location_on_outlined,
                color: ss.settings.skin.value == Skins.Samsung
                    ? context.theme.colorScheme.onBackground
                    : context.theme.colorScheme.onPrimary,
                size: 20,
              ),
            ),
          )
        ),
      ),
    );
  }

  Future<void> getPlaceholder() async {
    String placeholder = chat.isTextForwarding ? "Text Forwarding" : "iMessage";

    try {
      // Don't do anything if this setting isn't enabled
      if (ss.settings.recipientAsPlaceholder.value) {
        // Redacted mode stuff
        final bool hideInfo =
            ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
        final bool generateNames =
            ss.settings.redactedMode.value && ss.settings.generateFakeContactNames.value;

        // If it's a group chat, get the title of the chat
        if (chat.isGroup ?? false) {
          if (generateNames) {
            placeholder = "Group Chat";
          } else if (hideInfo) {
            placeholder = chat.isTextForwarding ? "Text Forwarding" : "iMessage";
          } else {
            String? title = chat.getTitle();
            if (!isNullOrEmpty(title)!) {
              placeholder = title!;
            }
          }
        } else if (!isNullOrEmpty(chat.participants)!) {
          if (generateNames) {
            placeholder = chat.participants.length > 1 ? "Group Chat" : chat.participants[0].fakeName;
          } else if (hideInfo) {
            placeholder = chat.isTextForwarding ?? false ? "Text Forwarding" : "iMessage";
          } else {
            // If it's not a group chat, get the participant's contact info
            Handle? handle = chat.participants[0];
            Contact? contact = handle.contact;
            if (contact == null) {
              placeholder = await formatPhoneNumber(handle);
            } else {
              placeholder = contact.displayName;
            }
          }
        }
      }
    } catch (ex) {
      Logger.error("Error setting Text Field Placeholder!");
      Logger.error(ex.toString());
    }

    if (placeholder != this.placeholder.value) {
      this.placeholder.value = placeholder;
    }
  }

  Widget buildActualTextField() {
    final bool generateContent =
        ss.settings.redactedMode.value && ss.settings.generateFakeMessageContent.value;
    final bool hideContent = (ss.settings.redactedMode.value &&
        ss.settings.hideMessageContent.value &&
        !generateContent);
    final bool generateContactInfo =
        ss.settings.redactedMode.value && ss.settings.generateFakeContactNames.value;
    final bool hideContactInfo = ss.settings.redactedMode.value &&
        ss.settings.hideContactInfo.value &&
        !generateContactInfo;
    return AnimatedSize(
      duration: Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: FocusScope(
        child: Focus(
          onKey: (focus, ev) {
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
                if (emojiSelectedIndex.value < emojiMatches.value.length - 1) {
                  emojiSelectedIndex.value++;
                  if (emojiSelectedIndex.value >= downMovementIndex &&
                      emojiSelectedIndex < emojiMatches.value.length - maxShown + downMovementIndex + 1) {
                    emojiController
                        .jumpTo(max((emojiSelectedIndex.value - downMovementIndex) * 48, emojiController.offset));
                  }
                  return KeyEventResult.handled;
                }
              }

              // Up arrow
              if (windowsData?.keyCode == 38 || linuxData?.keyCode == 65362 || webData?.code == "ArrowUp" || androidData?.physicalKey == PhysicalKeyboardKey.arrowUp) {
                if (emojiSelectedIndex.value > 0) {
                  emojiSelectedIndex.value--;
                  if (emojiSelectedIndex.value >= upMovementIndex &&
                      emojiSelectedIndex < emojiMatches.value.length - maxShown + upMovementIndex + 1) {
                    emojiController
                        .jumpTo(min((emojiSelectedIndex.value - upMovementIndex) * 48, emojiController.offset));
                  }
                  return KeyEventResult.handled;
                }
              }

              // Tab
              if (windowsData?.keyCode == 9 || linuxData?.keyCode == 65289 || webData?.code == "Tab" || androidData?.physicalKey == PhysicalKeyboardKey.tab) {
                if (emojiMatches.value.length > emojiSelectedIndex.value) {
                  eventDispatcher.emit('replace-emoji', {'emojiMatchIndex': emojiSelectedIndex.value, 'chatGuid': chat.guid});
                  emojiSelectedIndex.value = 0;
                  emojiController.jumpTo(0);
                  return KeyEventResult.handled;
                }
              }

              // Enter
              if (windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") {
                if (emojiMatches.value.length > emojiSelectedIndex.value) {
                  eventDispatcher.emit('replace-emoji', {'emojiMatchIndex': emojiSelectedIndex.value, 'chatGuid': chat.guid});
                  emojiSelectedIndex.value = 0;
                  emojiController.jumpTo(0);
                  return KeyEventResult.handled;
                }
              }

              // Escape
              if (windowsData?.keyCode == 27 || linuxData?.keyCode == 65307 || webData?.code == "Escape" || androidData?.physicalKey == PhysicalKeyboardKey.escape) {
                if (replyToMessage.value != null) {
                  replyToMessage.value = null;
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
            if ((windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") &&
                !ev.isShiftPressed) {
              sendMessage();
              focusNode!.requestFocus();
              return KeyEventResult.handled;
            }

            if (windowsData != null) {
              if ((windowsData.physicalKey == PhysicalKeyboardKey.keyV ||
                      windowsData.logicalKey == LogicalKeyboardKey.keyV) &&
                  (ev.isControlPressed)) {
                Pasteboard.image.then((image) {
                  if (image != null) {
                    addAttachment(PlatformFile(
                      name: "${randomString(8)}.png",
                      bytes: image,
                      size: image.length,
                    ));
                  }
                });
              }
            }

            if (webData != null) {
              if ((webData.physicalKey == PhysicalKeyboardKey.keyV || webData.logicalKey == LogicalKeyboardKey.keyV) &&
                  (ev.isControlPressed || previousKeyCode == 0x1700000000)) {
                getPastedImageWeb().then((value) {
                  if (value != null) {
                    var r = html.FileReader();
                    r.readAsArrayBuffer(value);
                    r.onLoadEnd.listen((e) {
                      if (r.result != null && r.result is Uint8List) {
                        Uint8List data = r.result as Uint8List;
                        addAttachment(PlatformFile(
                          name: "${randomString(8)}.png",
                          bytes: data,
                          size: data.length,
                        ));
                      }
                    });
                  }
                });
              }
              previousKeyCode = webData.logicalKey.keyId;
              return KeyEventResult.ignored;
            }
            if (kIsDesktop || kIsWeb) return KeyEventResult.ignored;
            if (ev.physicalKey == PhysicalKeyboardKey.enter && ss.settings.sendWithReturn.value) {
              if (!isNullOrEmpty(controller!.text)!) {
                sendMessage();
                focusNode!.previousFocus(); // I genuinely don't know why this works
                return KeyEventResult.handled;
              } else {
                controller!.text = ""; // Stop pressing physical enter with enterIsSend from creating newlines
                focusNode!.previousFocus(); // I genuinely don't know why this works
                return KeyEventResult.handled;
              }
            }
            // 99% sure this isn't necessary but keeping it for now
            if (ev.isKeyPressed(LogicalKeyboardKey.enter) &&
                ss.settings.sendWithReturn.value &&
                !isNullOrEmpty(controller!.text)!) {
              sendMessage();
              focusNode!.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ThemeSwitcher(
            iOSSkin: Obx(
              () => Container(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide((ss.settings.enablePrivateAPI.value &&
                              ss.settings.privateSubjectLine.value &&
                              (chat.isIMessage ?? true)) ||
                          replyToMessage.value != null
                      ? BorderSide(
                          color: context.theme.colorScheme.properSurface,
                          width: 1.5,
                        )
                      : BorderSide.none),
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Obx(() {
                      Message? reply = replyToMessage.value;
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 150),
                        width: double.infinity,
                        height: reply == null ? 0 : 40,
                        color: context.theme.colorScheme.properSurface,
                        child: reply != null
                            ? Row(
                                children: [
                                  IconButton(
                                    constraints: BoxConstraints(maxWidth: 30),
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    icon: Icon(
                                      CupertinoIcons.xmark_circle,
                                      color: context.theme.colorScheme.properOnSurface,
                                      size: 17,
                                    ),
                                    onPressed: () {
                                      replyToMessage.value = null;
                                    },
                                    iconSize: 17,
                                  ),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(children: [
                                        TextSpan(text: "Replying to "),
                                        TextSpan(
                                          text: reply.isFromMe!
                                              ? "You"
                                              : generateContactInfo
                                                  ? reply.handle?.fakeName ??
                                                      "You"
                                                  : reply.handle?.displayName ??
                                                      "You",
                                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: hideContactInfo ? Colors.transparent : context.theme.colorScheme.properOnSurface),
                                        ),
                                        TextSpan(
                                          text:
                                              " - ${generateContent ? faker.lorem.words(MessageHelper.getNotificationText(reply).split(" ").length).join(" ") : MessageHelper.getNotificationText(reply)}",
                                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: hideContent ? Colors.transparent : context.theme.colorScheme.properOnSurface),
                                        ),
                                      ]),
                                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                      );
                    }),
                    if (ss.settings.enablePrivateAPI.value &&
                        ss.settings.privateSubjectLine.value &&
                        (chat.isIMessage ?? true))
                      CustomCupertinoTextField(
                        enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                        textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                            ? TextInputAction.next
                            : TextInputAction.newline,
                        cursorColor: context.theme.colorScheme.primary,
                        onLongPressStart: () {
                          Feedback.forLongPress(context);
                        },
                        onTap: () {
                          HapticFeedback.selectionClick();
                        },
                        onSubmitted: (String value) {
                          focusNode!.requestFocus();
                        },
                        textCapitalization: TextCapitalization.sentences,
                        focusNode: subjectFocusNode,
                        autocorrect: true,
                        controller: subjectController,
                        scrollPhysics: CustomBouncingScrollPhysics(),
                        style: context.theme.extension<BubbleText>()!.bubbleText.copyWith(fontWeight: FontWeight.bold),
                        keyboardType: TextInputType.multiline,
                        maxLines: 14,
                        minLines: 1,
                        placeholder: "Subject",
                        padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                        placeholderStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.bold),
                        autofocus: false,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    if (ss.settings.enablePrivateAPI.value &&
                        ss.settings.privateSubjectLine.value &&
                        (chat.isIMessage ?? true))
                      Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          endIndent: 10,
                          color: context.theme.colorScheme.properSurface),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        CustomCupertinoTextField(
                          enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                          enabled: sendCountdown == null,
                          textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                              ? TextInputAction.send
                              : TextInputAction.newline,
                          cursorColor: context.theme.colorScheme.primary,
                          onLongPressStart: () {
                            Feedback.forLongPress(context);
                          },
                          onTap: () {
                            HapticFeedback.selectionClick();
                          },
                          key: _searchFormKey,
                          onSubmitted: (String value) {
                            focusNode!.requestFocus();
                            if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                            sendMessage();
                          },
                          // onContentCommitted: onContentCommit,
                          textCapitalization: TextCapitalization.sentences,
                          focusNode: focusNode,
                          autocorrect: true,
                          controller: controller,
                          scrollPhysics: CustomBouncingScrollPhysics(),
                          style: context.theme.extension<BubbleText>()!.bubbleText,
                          keyboardType: TextInputType.multiline,
                          maxLines: 14,
                          minLines: 1,
                          placeholder: ss.settings.recipientAsPlaceholder.value == true
                              ? placeholder.value
                              : chat.isTextForwarding ?? false
                                  ? "Text Forwarding"
                                  : "iMessage",
                          padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                          placeholderStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                          autofocus: ss.settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop,
                          decoration: BoxDecoration(
                            border: Border.fromBorderSide(
                              (ss.settings.enablePrivateAPI.value &&
                                          ss.settings.privateSubjectLine.value &&
                                          (chat.isIMessage ?? true)) ||
                                      replyToMessage.value != null
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: context.theme.colorScheme.properSurface,
                                      width: 1.5,
                                    ),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        buildSendButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            materialSkin: Obx(
              () => Container(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide.none,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: context.theme.colorScheme.properSurface,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Obx(() {
                      Message? reply = replyToMessage.value;
                      return AnimatedContainer(
                          duration: Duration(milliseconds: 150),
                          width: double.infinity,
                          height: reply == null ? 0 : 40,
                          color: context.theme.colorScheme.properSurface,
                          child: reply != null
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    IconButton(
                                      constraints: BoxConstraints(maxWidth: 30),
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      icon: Icon(
                                        CupertinoIcons.xmark_circle,
                                        color: context.theme.colorScheme.properOnSurface,
                                        size: 17,
                                      ),
                                      onPressed: () {
                                        replyToMessage.value = null;
                                      },
                                      iconSize: 17,
                                    ),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(children: [
                                          TextSpan(text: "Replying to "),
                                          TextSpan(
                                              text: reply.handle?.displayName ??
                                                  replyToMessage.value!.handle?.address ??
                                                  "You",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .copyWith(fontWeight: FontWeight.bold, color: context.theme.colorScheme.properOnSurface)),
                                          TextSpan(
                                              text: " - ${MessageHelper.getNotificationText(reply)}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .copyWith(fontStyle: FontStyle.italic, color: context.theme.colorScheme.properOnSurface)),
                                        ]),
                                        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Container());
                    }),
                    Obx(() => replyToMessage.value != null ? Divider(
                      height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          endIndent: 10,
                          color: context.theme.colorScheme.outline) : SizedBox.shrink()),
                    if (ss.settings.enablePrivateAPI.value &&
                        ss.settings.privateSubjectLine.value &&
                        (chat.isIMessage ?? true))
                      TextField(
                        enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                        controller: subjectController,
                        focusNode: subjectFocusNode,
                        textCapitalization: TextCapitalization.sentences,
                        autocorrect: true,
                        textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                            ? TextInputAction.next
                            : TextInputAction.newline,
                        autofocus: false,
                        cursorColor: context.theme.colorScheme.primary,
                        onSubmitted: (String value) {
                          focusNode!.requestFocus();
                        },
                        style: context.theme.extension<BubbleText>()!.bubbleText.copyWith(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          enabledBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          disabledBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          focusedBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          hintText: "Subject",
                          hintStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.bold),
                          contentPadding: EdgeInsets.only(
                            left: 10,
                            top: 15,
                            right: 10,
                            bottom: 10,
                          ),
                          fillColor: context.theme.colorScheme.properSurface,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 14,
                        minLines: 1,
                      ),
                    if (ss.settings.enablePrivateAPI.value &&
                        ss.settings.privateSubjectLine.value &&
                        (chat.isIMessage ?? true))
                      Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          endIndent: 10,
                          color: context.theme.colorScheme.outline),
                    TextField(
                      enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      autofocus: ss.settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop,
                      cursorColor: context.theme.colorScheme.primary,
                      key: _searchFormKey,
                      onSubmitted: (String value) {
                        focusNode!.requestFocus();
                        if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                        sendMessage();
                      },
                      style: context.theme.extension<BubbleText>()!.bubbleText,
                      // onContentCommitted: onContentCommit,
                      decoration: InputDecoration(
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        hintText: ss.settings.recipientAsPlaceholder.value == true
                            ? placeholder.value
                            : chat.isTextForwarding ?? false
                                ? "Text Forwarding"
                                : "iMessage",
                        hintStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                        contentPadding: EdgeInsets.only(
                          left: 10,
                          top: 15,
                          right: 10,
                          bottom: 10,
                        ),
                        fillColor: context.theme.colorScheme.properSurface,
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: 14,
                      minLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> startRecording() async {
    HapticFeedback.lightImpact();
    String? pathName;
    if (!kIsWeb) {
      Directory directory = Directory("${fs.appDocDir.path}/attachments/");
      if (!await directory.exists()) {
        directory.createSync();
      }
      pathName = "${fs.appDocDir.path}/attachments/OutgoingAudioMessage.m4a";
      File file = File(pathName);
      if (file.existsSync()) file.deleteSync();
    }

    if (!isRecording.value) {
      await Record().start(
        path: pathName, // required
        encoder: AudioEncoder.aacHe, // by default
        bitRate: 196000, // by default
        samplingRate: 44100, // by default
      );

      if (mounted) {
        isRecording.value = true;
      }
    }
  }

  Future<void> stopRecording() async {
    HapticFeedback.lightImpact();

    if (isRecording.value) {
      String? pathName = await Record().stop();

      if (mounted) {
        isRecording.value = false;
      }

      if (pathName != null) {
        reviewAudio(
            context,
            PlatformFile(
              name: "${randomString(8)}.m4a",
              path: kIsWeb ? null : pathName,
              size: kIsWeb ? 0 : await File(pathName).length(),
              bytes: kIsWeb
                  ? (await http.dio.get(pathName, options: Options(responseType: ResponseType.bytes))).data
                  : await File(pathName).readAsBytes(),
            ));
      }
    }
  }

  Future<void> sendMessage({String? effect}) async {
    // if we actually need to send something, temporarily disable the record button so users don't accidentally press it
    if (!isNullOrEmpty(controller!.text)! || !isNullOrEmpty(subjectController!.text)! || pickedImages.isNotEmpty) {
      recordDelay = true;
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 3), () {
        recordDelay = false;
        setCanRecord();
      });
    }

    // If send delay is enabled, delay the sending
    if (!isNullOrZero(ss.settings.sendDelay.value)) {
      // Break the delay into 1 second intervals
      for (var i = 0; i < ss.settings.sendDelay.value; i++) {
        if (i != 0 && sendCountdown == null) break;

        // Update UI with new state information
        if (mounted) {
          setState(() {
            sendCountdown = ss.settings.sendDelay.value - i;
          });
        }

        await Future.delayed(Duration(seconds: 1));
      }

      if (mounted) {
        setState(() {
          sendCountdown = null;
        });
      }
    }

    if (stopSending != null && stopSending!) {
      stopSending = null;
      return;
    }

    if (await widget.onSend(pickedImages, controller!.text, subjectController!.text,
        replyToMessage.value?.threadOriginatorGuid ?? replyToMessage.value?.guid, effect)) {
      controller!.clear();
      subjectController!.clear();
      replyToMessage.value = null;
      pickedImages.clear();
      updateTextFieldAttachments();
    }
  }

  Future<void> sendAction() async {
    bool shouldUpdate = false;
    if (sendCountdown != null) {
      stopSending = true;
      sendCountdown = null;
      shouldUpdate = true;
    } else if (isRecording.value) {
      await stopRecording();
      shouldUpdate = true;
    } else if (canRecord.value && !isRecording.value && !kIsDesktop && await Record().hasPermission()) {
      await startRecording();
      shouldUpdate = true;
    } else {
      await sendMessage();
    }

    if (shouldUpdate && mounted) setState(() {});
  }

  Widget buildSendButton() => Align(
        alignment: Alignment.centerRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (sendCountdown != null) Text(sendCountdown.toString()),
          (ss.settings.skin.value == Skins.iOS)
              ? Container(
                  height: ss.settings.skin.value == Skins.iOS ? 35 : 40,
                  width: ss.settings.skin.value == Skins.iOS ? 35 : 40,
                  padding: EdgeInsets.only(right: 4, top: 2, bottom: 2),
                  child: GestureDetector(
                    onSecondaryTapUp: (_) async {
                      if (kIsWeb) {
                        (await html.document.onContextMenu.first).preventDefault();
                      }
                      if ((sendCountdown == null &&
                              (!canRecord.value ||
                                  (kIsDesktop &&
                                      (controller!.text.trim().isNotEmpty ||
                                          subjectController!.text.trim().isNotEmpty)))) &&
                          !isRecording.value &&
                          (chat.isIMessage ?? true)) {
                        sendEffectAction(context, this, controller!.text.trim(), subjectController!.text.trim(),
                            replyToMessage.value?.guid, chatGuid, sendMessage);
                      }
                    },
                    child: ButtonTheme(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.only(
                              right: 0,
                            ),
                            primary: context.theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            elevation: 0),
                        onPressed: sendAction,
                        onLongPress: (sendCountdown == null && (!canRecord.value || kIsDesktop)) &&
                                !isRecording.value &&
                                (chat.isIMessage ?? true)
                            ? () => sendEffectAction(
                                context,
                                this,
                                controller!.text.trim(),
                                subjectController!.text.trim(),
                                replyToMessage.value?.guid,
                                chatGuid,
                                sendMessage)
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Obx(() => AnimatedOpacity(
                                  opacity: sendCountdown == null && canRecord.value && !kIsDesktop ? 1.0 : 0.0,
                                  duration: Duration(milliseconds: 150),
                                  child: Icon(
                                    CupertinoIcons.waveform,
                                    color: (isRecording.value) ? Colors.red : context.theme.colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                )),
                            Obx(() => AnimatedOpacity(
                                  opacity:
                                      (sendCountdown == null && (!canRecord.value || kIsDesktop)) && !isRecording.value
                                          ? 1.0
                                          : 0.0,
                                  duration: Duration(milliseconds: 150),
                                  child: Icon(
                                    CupertinoIcons.arrow_up,
                                    color: context.theme.colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                )),
                            AnimatedOpacity(
                              opacity: sendCountdown != null ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 50),
                              child: Icon(
                                CupertinoIcons.xmark_circle,
                                color: context.theme.colorScheme.error,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTapDown: (_) async {
                    if (canRecord.value && !isRecording.value && !kIsDesktop) {
                      await startRecording();
                    }
                  },
                  onTapCancel: () async {
                    await stopRecording();
                  },
                  child: Container(
                    height: 40,
                    width: 40,
                    margin: EdgeInsets.only(left: 5.0),
                    child: ClipOval(
                      child: Material(
                        color: ss.settings.skin.value == Skins.Samsung
                            ? Colors.transparent
                            : context.theme.colorScheme.primary,
                        child: GestureDetector(
                          onSecondaryTapUp: (_) async {
                            if (kIsWeb) {
                              (await html.document.onContextMenu.first).preventDefault();
                            }
                            if ((sendCountdown == null &&
                                    (!canRecord.value ||
                                        (kIsDesktop &&
                                            (controller!.text.trim().isNotEmpty ||
                                                subjectController!.text.trim().isNotEmpty)))) &&
                                !isRecording.value &&
                                (chat.isIMessage ?? true)) {
                              sendEffectAction(context, this, controller!.text.trim(), subjectController!.text.trim(),
                                  replyToMessage.value?.guid, chatGuid, sendMessage);
                            }
                          },
                          child: InkWell(
                            onTap: sendAction,
                            onLongPress: (sendCountdown == null && (!canRecord.value || kIsDesktop)) &&
                                    !isRecording.value &&
                                    (chat.isIMessage ?? true)
                                ? () => sendEffectAction(
                                    context,
                                    this,
                                    controller!.text.trim(),
                                    subjectController!.text.trim(),
                                    replyToMessage.value?.guid,
                                    chatGuid,
                                    sendMessage)
                                : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Obx(() => AnimatedOpacity(
                                      opacity: sendCountdown == null && canRecord.value && !kIsDesktop ? 1.0 : 0.0,
                                      duration: Duration(milliseconds: 150),
                                      child: Icon(
                                        ss.settings.skin.value == Skins.Samsung
                                            ? CupertinoIcons.waveform
                                            : Icons.mic,
                                        color: (isRecording.value)
                                            ? Colors.red
                                            : ss.settings.skin.value == Skins.Samsung
                                                ? context.theme.colorScheme.onBackground
                                                : context.theme.colorScheme.onPrimary,
                                        size: ss.settings.skin.value == Skins.Samsung ? 26 : 20,
                                      ),
                                    )),
                                Obx(() => AnimatedOpacity(
                                      opacity: (sendCountdown == null && (!canRecord.value || kIsDesktop)) &&
                                              !isRecording.value
                                          ? 1.0
                                          : 0.0,
                                      duration: Duration(milliseconds: 150),
                                      child: Icon(
                                        Icons.send,
                                        color: ss.settings.skin.value == Skins.Samsung
                                            ? context.theme.colorScheme.onBackground
                                            : context.theme.colorScheme.onPrimary,
                                        size: ss.settings.skin.value == Skins.Samsung ? 26 : 20,
                                      ),
                                    )),
                                AnimatedOpacity(
                                  opacity: sendCountdown != null ? 1.0 : 0.0,
                                  duration: Duration(milliseconds: 50),
                                  child: Icon(
                                    Icons.cancel_outlined,
                                    color: context.theme.colorScheme.error,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
        ]),
      );

  Widget buildAttachmentPicker() => Obx(() => TextFieldAttachmentPicker(
        visible: showShareMenu.value,
        onAddAttachment: addAttachment,
      ));

  void addAttachment(PlatformFile? file) {
    if (file == null) return;

    for (PlatformFile image in pickedImages) {
      if (image.bytes == file.bytes) {
        pickedImages.removeWhere((element) => element.bytes == file.bytes);
        updateTextFieldAttachments();
        if (mounted) setState(() {});
        return;
      } else if (!kIsWeb && !kIsDesktop && image.path == file.path) {
        pickedImages.removeWhere((element) => element.path == file.path);
        updateTextFieldAttachments();
        if (mounted) setState(() {});
        return;
      }
    }

    addAttachments([file]);
    updateTextFieldAttachments();
    if (mounted) setState(() {});
  }
}
