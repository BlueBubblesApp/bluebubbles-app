import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/text_field_attachment_list.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_text_field.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/send_effect_picker.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';
import 'package:transparent_pointer/transparent_pointer.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class BlueBubblesTextField extends StatefulWidget {
  final List<PlatformFile>? existingAttachments;
  final String? existingText;
  final bool? isCreator;
  final bool wasCreator;
  final Future<bool> Function(
      List<PlatformFile> attachments, String text, String subject, String? replyToGuid, String? effectId) onSend;
  final String? chatGuid;

  BlueBubblesTextField({
    Key? key,
    this.existingAttachments,
    this.existingText,
    required this.isCreator,
    required this.wasCreator,
    required this.onSend,
    required this.chatGuid,
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
  TextFieldData? textFieldData;
  final StreamController _streamController = StreamController.broadcast();
  DropzoneViewController? dropZoneController;
  ChatController? safeChat;
  Chat? chat;
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

  Stream get stream => _streamController.stream;

  bool get _canRecord => controller!.text.isEmpty && pickedImages.isEmpty && subjectController!.text.isEmpty;

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

    EventDispatcher().stream.listen((event) {
      if (!event.containsKey("type")) return;
      if (event['type'] == 'update-emoji-picker') {
        if (event['data']['chatGuid'] != widget.chatGuid) return;
        emojiSelectedIndex.value = 0;
        emojiMatches.value = event['data']['emojiMatches'];
      } else if (event['type'] == 'replace-emoji') {
        if (event['data']['chatGuid'] != widget.chatGuid) return;
        emojiSelectedIndex.value = 0;
        int index = event['data']['emojiMatchIndex'];
        String text = controller!.text;
        RegExp regExp = RegExp(":[^: \n]{1,}([ \n:]|\$)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        if (matches.isNotEmpty && matches.any((m) => m.start < controller!.selection.start)) {
          RegExpMatch match = matches.lastWhere((m) => m.start < controller!.selection.start);
          String char = emojiMatches.value[index].char;
          emojiMatches.value = <Emoji>[];
          String _text = text.substring(0, match.start) + char + " " + text.substring(match.end);
          controller!.text = _text;
          controller!.selection = TextSelection.fromPosition(TextPosition(offset: match.start + char.length + 1));
        } else {
          // If the user moved the cursor before trying to insert an emoji, reset the picker
          emojiSelectedIndex.value = 0;
          emojiMatches.value = <Emoji>[];
        }
        EventDispatcher().emit('focus-keyboard', null);
      }
    });

    emojiNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.shortName, e)));
    emojiFullNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.name, e)));

    getPlaceholder();
    chat = ChatController.forGuid(widget.chatGuid)?.chat;
    if (ChatController.forGuid(widget.chatGuid) != null) {
      textFieldData = TextFieldBloc().getTextField(widget.chatGuid!);
    }

    controller = textFieldData != null ? textFieldData!.controller : TextEditingController();
    subjectController = textFieldData != null ? textFieldData!.subjectController : TextEditingController();

    // Add the text listener to detect when we should send the typing indicators
    controller!.addListener(() {
      setCanRecord();
      if (!mounted || ChatController.forGuid(widget.chatGuid)?.chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!SettingsManager().settings.enablePrivateAPI.value ||
          !SettingsManager().settings.privateSendTypingIndicators.value) {
        return;
      }

      if (controller!.text.isEmpty && pickedImages.isEmpty && selfTyping) {
        selfTyping = false;
        SocketManager().sendMessage("stopped-typing", {"chatGuid": widget.chatGuid}, (data) {});
      } else if (!selfTyping && (controller!.text.isNotEmpty || pickedImages.isNotEmpty)) {
        selfTyping = true;
        if (SettingsManager().settings.privateSendTypingIndicators.value &&
            ChatController.forGuid(widget.chatGuid)!.chat.autoSendTypingIndicators!) {
          SocketManager().sendMessage("started-typing", {"chatGuid": widget.chatGuid}, (data) {});
        }
      }

      if (mounted) setState(() {});
    });
    subjectController!.addListener(() {
      setCanRecord();
      if (!mounted || ChatController.forGuid(widget.chatGuid)?.chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!SettingsManager().settings.enablePrivateAPI.value ||
          !SettingsManager().settings.privateSendTypingIndicators.value) {
        return;
      }

      if (subjectController!.text.isEmpty && pickedImages.isEmpty && selfTyping) {
        selfTyping = false;
        SocketManager().sendMessage("stopped-typing", {"chatGuid": widget.chatGuid}, (data) {});
      } else if (!selfTyping && (subjectController!.text.isNotEmpty || pickedImages.isNotEmpty)) {
        selfTyping = true;
        if (SettingsManager().settings.privateSendTypingIndicators.value &&
            ChatController.forGuid(widget.chatGuid)!.chat.autoSendTypingIndicators!) {
          SocketManager().sendMessage("started-typing", {"chatGuid": widget.chatGuid}, (data) {});
        }
      }

      if (mounted) setState(() {});
    });

    // Add a listener for emoji
    controller!.addListener(() {
      String text = controller!.text;
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
        EventDispatcher()
            .emit('update-emoji-picker', {'emojiMatches': allMatches.toList(), 'chatGuid': widget.chatGuid});
      }
    });

    // Create the focus node and then add a an event emitter whenever
    // the focus changes
    focusNode = FocusNode();
    subjectFocusNode = FocusNode();
    focusNode!.addListener(() {
      ChatController.forGuid(widget.chatGuid)?.keyboardOpen = focusNode?.hasFocus ?? false;

      if (focusNode!.hasFocus && mounted) {
        if (!showShareMenu.value) return;
        showShareMenu.value = false;
      }

      EventDispatcher().emit("keyboard-status", focusNode!.hasFocus);
    });
    subjectFocusNode!.addListener(() {
      ChatController.forGuid(widget.chatGuid)?.keyboardOpen = focusNode?.hasFocus ?? false;

      if (focusNode!.hasFocus && mounted) {
        if (!showShareMenu.value) return;
        showShareMenu.value = false;
      }

      EventDispatcher().emit("keyboard-status", focusNode!.hasFocus);
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

    EventDispatcher().stream.listen((event) {
      if (!event.containsKey("type")) return;
      if (event["type"] == "unfocus-keyboard" && (focusNode!.hasFocus || subjectFocusNode!.hasFocus)) {
        focusNode!.unfocus();
        subjectFocusNode!.unfocus();
      } else if (event["type"] == "focus-keyboard" && !focusNode!.hasFocus && !subjectFocusNode!.hasFocus) {
        focusNode!.requestFocus();
        if (event['data'] is Message) {
          replyToMessage.value = event['data'];
        }
      } else if (event["type"] == "text-field-update-attachments") {
        addSharedAttachments();
        while (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      } else if (event["type"] == "text-field-update-text") {
        while (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      } else if (event["type"] == "focus-keyboard" && event["data"] != null) {
        replyToMessage.value = event['data'];
      }
    });

    if (widget.existingText != null) {
      controller!.text = widget.existingText!;
    }

    if (widget.existingAttachments != null) {
      addAttachments(widget.existingAttachments ?? []);
      updateTextFieldAttachments();
    }

    if (textFieldData != null) {
      addAttachments(textFieldData?.attachments ?? []);
    }

    setCanRecord();
  }

  void setCanRecord() {
    bool canRec = _canRecord;
    if (canRec != canRecord.value) {
      canRecord.value = canRec;
    }
  }

  void addAttachments(List<PlatformFile> attachments) {
    pickedImages.addAll(attachments);
    if (!kIsWeb) pickedImages = pickedImages.toSet().toList();
    setCanRecord();
  }

  void updateTextFieldAttachments() {
    if (textFieldData != null) {
      textFieldData!.attachments = List<PlatformFile>.from(pickedImages);
      _streamController.sink.add(null);
    }

    setCanRecord();
  }

  void addSharedAttachments() {
    if (textFieldData != null && mounted) {
      pickedImages = textFieldData!.attachments;
      setState(() {});
    }

    setCanRecord();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    safeChat = ChatController.forGuid(widget.chatGuid);
  }

  @override
  void dispose() {
    focusNode!.dispose();
    subjectFocusNode!.dispose();
    _streamController.close();

    if (safeChat?.chat == null) controller!.dispose();
    if (safeChat?.chat == null) subjectController!.dispose();

    if (!kIsWeb) {
      String dir = SettingsManager().appDocDir.path;
      Directory tempAssets = Directory("$dir/tempAssets");
      tempAssets.exists().then((value) {
        if (value) {
          tempAssets.delete(recursive: true);
        }
      });
    }
    pickedImages = [];
    super.dispose();
  }

  void disposeAudioFile(BuildContext context, PlatformFile file) {
    // Dispose of the audio controller
    ChatController.forGuid(widget.chatGuid)?.audioPlayers[file.path]?.item1.dispose();
    ChatController.forGuid(widget.chatGuid)?.audioPlayers[file.path]?.item2.pause();
    ChatController.forGuid(widget.chatGuid)?.audioPlayers.removeWhere((key, _) => key == file.path);
    if (file.path != null) {
      // Delete the file
      File(file.path!).delete();
    }
  }

  void onContentCommit(CommittedContent content) async {
    // Add some debugging logs
    Logger.info("[Content Commit] Keyboard received content");
    Logger.info("  -> Content Type: ${content.mimeType}");
    Logger.info("  -> URI: ${content.uri}");
    Logger.info("  -> Content Length: ${content.hasData ? content.data!.length : "null"}");

    // Parse the filename from the URI and read the data as a List<int>
    String filename = uriToFilename(content.uri, content.mimeType);

    // Save the data to a location and add it to the file picker
    if (content.hasData) {
      addAttachments([PlatformFile(
        name: filename,
        size: content.data!.length,
        bytes: content.data,
      )]);

      // Update the state
      updateTextFieldAttachments();
      if (mounted) setState(() {});
    } else {
      showSnackbar('Insertion Failed', 'Attachment has no data!');
    }
  }

  Future<void> reviewAudio(BuildContext originalContext, PlatformFile file) async {
    showDialog(
      context: originalContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          title: Text("Send it?", style: Theme.of(context).textTheme.headline1),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Review your audio snippet before sending it", style: Theme.of(context).textTheme.subtitle1),
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
                child: Text("Discard", style: Theme.of(context).textTheme.subtitle1),
                onPressed: () {
                  // Dispose of the audio controller
                  if (!kIsWeb) disposeAudioFile(originalContext, file);

                  // Remove the OG alert dialog
                  Get.back();
                }),
            TextButton(
              child: Text(
                "Send",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              onPressed: () async {
                ChatController? thisChat = ChatController.of(originalContext);
                if (thisChat == null) {
                  addAttachments([file]);
                } else {
                  await widget.onSend([file], "", "", null, null);
                  if (!kIsWeb) disposeAudioFile(originalContext, file);
                }

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
      final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

      for (pf.PlatformFile e in res.files) {
        addAttachment(PlatformFile(
          path: e.path,
          name: e.name,
          size: e.size,
          bytes: e.bytes,
        ));
      }
      Get.back();
      return;
    }
    if (kIsWeb) {
      Get.defaultDialog(
        title: "What would you like to do?",
        titleStyle: Theme.of(context).textTheme.headline1,
        confirm: Container(height: 0, width: 0),
        cancel: Container(height: 0, width: 0),
        content: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          ListTile(
            title: Text("Upload file", style: Theme.of(context).textTheme.bodyText1),
            onTap: () async {
              final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
              if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

              for (pf.PlatformFile e in res.files) {
                addAttachment(PlatformFile(
                  path: null,
                  name: e.name,
                  size: e.size,
                  bytes: e.bytes,
                ));
              }
              Get.back();
            },
          ),
          ListTile(
            title: Text("Send location", style: Theme.of(context).textTheme.bodyText1),
            onTap: () async {
              Share.location(ChatController.forGuid(widget.chatGuid)!.chat);
              Get.back();
            },
          ),
        ]),
        backgroundColor: Theme.of(context).backgroundColor,
      );
      return;
    }

    bool showMenu = showShareMenu.value;

    // If the image picker is already open, close it, and return
    if (!showMenu) {
      focusNode!.unfocus();
      subjectFocusNode!.unfocus();
    }
    if (!showMenu && !(await PhotoManager.requestPermission())) {
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
                      (SettingsManager().settings.enablePrivateAPI.value &&
                              SettingsManager().settings.privateSubjectLine.value
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
                              color: context.theme.colorScheme.secondary,
                              boxShadow: [
                                BoxShadow(
                                  color: context.theme.backgroundColor,
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
                                      EventDispatcher().emit(
                                          'replace-emoji', {'emojiMatchIndex': index, 'chatGuid': widget.chatGuid});
                                    },
                                    child: Obx(
                                      () => ListTile(
                                        dense: true,
                                        selectedTileColor: context.theme.colorScheme.secondary.lightenOrDarken(20),
                                        tileColor: context.theme.colorScheme.secondary,
                                        selected: emojiSelectedIndex.value == index,
                                        title: Row(
                                          children: <Widget>[
                                            Text(
                                              emojis[index].char,
                                              style:
                                                  context.textTheme.subtitle1!.apply(fontFamily: "Apple Color Emoji"),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              ":${emojis[index].shortName}:",
                                              style: context.textTheme.subtitle1!.copyWith(fontWeight: FontWeight.bold),
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
        if (SettingsManager().settings.skin.value == Skins.Material ||
            SettingsManager().settings.skin.value == Skins.Samsung)
          buildSendButton(),
      ],
    );
  }

  Widget buildShareButton() {
    double size = SettingsManager().settings.skin.value == Skins.iOS ? 37 : 40;
    return AnimatedSize(
      duration: Duration(milliseconds: 300),
      child: Container(
        height: size,
        width: fileDragged ? size * 3 : size,
        margin: EdgeInsets.only(
            left: 5.0, right: 5.0, bottom: SettingsManager().settings.skin.value == Skins.iOS && kIsDesktop ? 4.5 : 0),
        decoration: BoxDecoration(
          color: SettingsManager().settings.skin.value == Skins.Samsung ? null : Theme.of(context).primaryColor,
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
                        right: SettingsManager().settings.skin.value == Skins.iOS ? 0 : 1,
                        left: SettingsManager().settings.skin.value == Skins.iOS ? 0.5 : 0),
                    child: fileDragged
                        ? Center(child: Text("Drop file here"))
                        : Icon(
                            SettingsManager().settings.skin.value == Skins.iOS
                                ? CupertinoIcons.share
                                : SettingsManager().settings.skin.value == Skins.Samsung
                                    ? Icons.add
                                    : Icons.share,
                            color: SettingsManager().settings.skin.value == Skins.Samsung
                                ? context.theme.textTheme.bodyText1!.color
                                : Colors.white,
                            size: SettingsManager().settings.skin.value == Skins.Samsung ? 26 : 20,
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
    double size = SettingsManager().settings.skin.value == Skins.iOS ? 37 : 40;
    return Container(
      height: size,
      width: size,
      margin: EdgeInsets.only(
          right: 5.0, bottom: SettingsManager().settings.skin.value == Skins.iOS && kIsDesktop ? 4.5 : 0),
      child: ClipOval(
        child: Material(
          color: SettingsManager().settings.skin.value == Skins.Samsung
              ? Colors.transparent
              : Theme.of(context).primaryColor,
          child: Theme(
            data: Theme.of(context).copyWith(
              bottomSheetTheme: BottomSheetThemeData(
                backgroundColor: Theme.of(context).backgroundColor,
                modalBackgroundColor: Theme.of(context).backgroundColor,
              ),
              brightness:
                  Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
              canvasColor: Theme.of(context).backgroundColor,
              iconTheme: IconThemeData(color: Colors.black45),
            ),
            child: Builder(builder: (context) {
              return InkWell(
                onTap: () async {
                  GiphyGif? gif = await GiphyGet.getGif(
                    context: context,
                    apiKey: dotenv.get('GIPHY_API_KEY'),
                    tabColor: context.theme.primaryColor,
                  );
                  if (gif?.images?.original != null) {
                    final response = await api.downloadGiphy(gif!.images!.original!.url);
                    if (response.statusCode == 200) {
                      try {
                        final Uint8List data = response.data;
                        addAttachment(PlatformFile(
                          path: null,
                          name: (gif.title ?? randomString(8)) + ".gif",
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
                      right: SettingsManager().settings.skin.value == Skins.iOS ? 0 : 1,
                      left: SettingsManager().settings.skin.value == Skins.iOS ? 0.5 : 0),
                  child: Icon(
                    Icons.gif,
                    color: SettingsManager().settings.skin.value == Skins.Samsung
                        ? context.theme.textTheme.bodyText1!.color
                        : Colors.white,
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

  Future<void> getPlaceholder() async {
    String placeholder = chat?.isTextForwarding ?? false ? "Text Forwarding" : "iMessage";

    try {
      // Don't do anything if this setting isn't enabled
      if (SettingsManager().settings.recipientAsPlaceholder.value) {
        // Redacted mode stuff
        final bool hideInfo =
            SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
        final bool generateNames =
            SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

        // If it's a group chat, get the title of the chat
        if (ChatController.forGuid(widget.chatGuid)?.chat.isGroup() ?? false) {
          if (generateNames) {
            placeholder = "Group Chat";
          } else if (hideInfo) {
            placeholder = chat?.isTextForwarding ?? false ? "Text Forwarding" : "iMessage";
          } else {
            String? title = ChatController.forGuid(widget.chatGuid)?.chat.getTitle();
            if (!isNullOrEmpty(title)!) {
              placeholder = title!;
            }
          }
        } else if (!isNullOrEmpty(ChatController.forGuid(widget.chatGuid)?.chat.participants)!) {
          if (generateNames) {
            placeholder = ChatController.forGuid(widget.chatGuid)!.chat.fakeNames[0];
          } else if (hideInfo) {
            placeholder = chat?.isTextForwarding ?? false ? "Text Forwarding" : "iMessage";
          } else {
            // If it's not a group chat, get the participant's contact info
            Handle? handle = ChatController.forGuid(widget.chatGuid)?.chat.participants[0];
            Contact? contact = ContactManager().getContact(handle?.address);
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
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeMessageContent.value;
    final bool hideContent = (SettingsManager().settings.redactedMode.value &&
        SettingsManager().settings.hideMessageContent.value &&
        !generateContent);
    final bool generateContactInfo =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;
    final bool hideContactInfo = SettingsManager().settings.redactedMode.value &&
        SettingsManager().settings.hideContactInfo.value &&
        !generateContactInfo;
    return AnimatedSize(
      duration: Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: FocusScope(
        child: Focus(
          onKey: (focus, event) {
            if (event is RawKeyDownEvent) {
              RawKeyEventDataWindows? windowsData;
              RawKeyEventDataLinux? linuxData;
              RawKeyEventDataWeb? webData;
              if (event.data is RawKeyEventDataWindows) {
                windowsData = event.data as RawKeyEventDataWindows;
              } else if (event.data is RawKeyEventDataLinux) {
                linuxData = event.data as RawKeyEventDataLinux;
              } else if (event.data is RawKeyEventDataWeb) {
                webData = event.data as RawKeyEventDataWeb;
                print(webData.code);
              }

              int maxShown = context.height / 3 ~/ 48;
              int upMovementIndex = maxShown ~/ 3;
              int downMovementIndex = maxShown * 2 ~/ 3;

              // Down arrow
              if (windowsData?.keyCode == 40 || linuxData?.keyCode == 65364 || webData?.code == "ArrowDown") {
                if (emojiSelectedIndex.value < emojiMatches.value.length - 1) {
                  emojiSelectedIndex.value++;
                  if (emojiSelectedIndex.value >= downMovementIndex &&
                      emojiSelectedIndex < emojiMatches.value.length - maxShown + downMovementIndex + 1) {
                    emojiController
                        .jumpTo(max((emojiSelectedIndex.value - downMovementIndex) * 48, emojiController.offset));
                  }
                }
                return KeyEventResult.handled;
              }

              // Up arrow
              if (windowsData?.keyCode == 38 || linuxData?.keyCode == 65362 || webData?.code == "ArrowUp") {
                if (emojiSelectedIndex.value > 0) {
                  emojiSelectedIndex.value--;
                  if (emojiSelectedIndex.value >= upMovementIndex &&
                      emojiSelectedIndex < emojiMatches.value.length - maxShown + upMovementIndex + 1) {
                    emojiController
                        .jumpTo(min((emojiSelectedIndex.value - upMovementIndex) * 48, emojiController.offset));
                  }
                }
                return KeyEventResult.handled;
              }

              // Tab
              if (windowsData?.keyCode == 9 || linuxData?.keyCode == 65289 || webData?.code == "Tab") {
                if (emojiMatches.value.length > emojiSelectedIndex.value) {
                  EventDispatcher()
                      .emit('replace-emoji', {'emojiMatchIndex': emojiSelectedIndex.value, 'chatGuid': chat!.guid});
                  emojiSelectedIndex.value = 0;
                  emojiController.jumpTo(0);
                  return KeyEventResult.handled;
                }
              }

              // Enter
              if (windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") {
                if (emojiMatches.value.length > emojiSelectedIndex.value) {
                  EventDispatcher()
                      .emit('replace-emoji', {'emojiMatchIndex': emojiSelectedIndex.value, 'chatGuid': chat!.guid});
                  emojiSelectedIndex.value = 0;
                  emojiController.jumpTo(0);
                  return KeyEventResult.handled;
                }
              }

              // Escape
              if (windowsData?.keyCode == 27 || linuxData?.keyCode == 65307 || webData?.code == "Escape") {
                if (replyToMessage.value != null) {
                  replyToMessage.value = null;
                  return KeyEventResult.handled;
                }
              }
            }

            if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
            RawKeyEventDataWindows? windowsData;
            RawKeyEventDataLinux? linuxData;
            RawKeyEventDataWeb? webData;
            if (event.data is RawKeyEventDataWindows) {
              windowsData = event.data as RawKeyEventDataWindows;
            } else if (event.data is RawKeyEventDataLinux) {
              linuxData = event.data as RawKeyEventDataLinux;
            } else if (event.data is RawKeyEventDataWeb) {
              webData = event.data as RawKeyEventDataWeb;
            }
            if ((windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") &&
                !event.isShiftPressed) {
              sendMessage();
              focusNode!.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.data is RawKeyEventDataWeb) {
              var data = event.data as RawKeyEventDataWeb;
              if ((data.physicalKey == PhysicalKeyboardKey.keyV || data.logicalKey == LogicalKeyboardKey.keyV) &&
                  (event.isControlPressed || previousKeyCode == 0x1700000000)) {
                getPastedImageWeb().then((value) {
                  if (value != null) {
                    var r = html.FileReader();
                    r.readAsArrayBuffer(value);
                    r.onLoadEnd.listen((e) {
                      if (r.result != null && r.result is Uint8List) {
                        Uint8List data = r.result as Uint8List;
                        addAttachment(PlatformFile(
                          name: randomString(8) + ".png",
                          bytes: data,
                          size: data.length,
                        ));
                      }
                    });
                  }
                });
              }
              previousKeyCode = data.logicalKey.keyId;
              return KeyEventResult.ignored;
            }
            if (kIsDesktop || kIsWeb) return KeyEventResult.ignored;
            if (event.physicalKey == PhysicalKeyboardKey.enter && SettingsManager().settings.sendWithReturn.value) {
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
            if (event.isKeyPressed(LogicalKeyboardKey.enter) &&
                SettingsManager().settings.sendWithReturn.value &&
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
                  color: Theme.of(context).backgroundColor,
                  border: Border.fromBorderSide((SettingsManager().settings.enablePrivateAPI.value &&
                              SettingsManager().settings.privateSubjectLine.value &&
                              (chat?.isIMessage ?? true)) ||
                          replyToMessage.value != null
                      ? BorderSide(
                          color: Theme.of(context).dividerColor,
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
                        color: Theme.of(context).dividerColor,
                        child: reply != null
                            ? Row(
                                children: [
                                  IconButton(
                                    constraints: BoxConstraints(maxWidth: 30),
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    icon: Icon(
                                      CupertinoIcons.xmark_circle,
                                      color: Theme.of(context).textTheme.subtitle1!.color,
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
                                                  ? ContactManager().getContact(reply.handle?.address)?.fakeName ?? "You"
                                                  : ContactManager()
                                                          .getContact(reply.handle?.address ?? "")
                                                          ?.displayName ??
                                                      reply.handle?.address ??
                                                      "You",
                                          style: Theme.of(context).textTheme.subtitle1!.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: hideContactInfo ? Colors.transparent : null),
                                        ),
                                        TextSpan(
                                          text:
                                              " - ${generateContent ? faker.lorem.words(MessageHelper.getNotificationText(reply).split(" ").length).join(" ") : MessageHelper.getNotificationText(reply)}",
                                          style: Theme.of(context).textTheme.subtitle1!.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: hideContent ? Colors.transparent : null),
                                        ),
                                      ]),
                                      style: Theme.of(context).textTheme.subtitle1,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                      );
                    }),
                    if (SettingsManager().settings.enablePrivateAPI.value &&
                        SettingsManager().settings.privateSubjectLine.value &&
                        (chat?.isIMessage ?? true))
                      CustomCupertinoTextField(
                        enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                        textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                            ? TextInputAction.next
                            : TextInputAction.newline,
                        cursorColor: Theme.of(context).primaryColor,
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
                        style: Theme.of(context).textTheme.bodyText1!.apply(
                              color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                      Brightness.light
                                  ? Colors.black
                                  : Colors.white,
                              fontSizeDelta: -0.25,
                            ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 14,
                        minLines: 1,
                        placeholder: "Subject",
                        padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                        placeholderStyle: Theme.of(context).textTheme.subtitle1!.copyWith(fontWeight: FontWeight.bold),
                        autofocus: false,
                        decoration: BoxDecoration(
                          color: Theme.of(context).backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    if (SettingsManager().settings.enablePrivateAPI.value &&
                        SettingsManager().settings.privateSubjectLine.value &&
                        (chat?.isIMessage ?? true))
                      Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          endIndent: 10,
                          color: Theme.of(context).dividerColor),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        CustomCupertinoTextField(
                          enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                          enabled: sendCountdown == null,
                          textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                              ? TextInputAction.send
                              : TextInputAction.newline,
                          cursorColor: Theme.of(context).primaryColor,
                          onLongPressStart: () {
                            Feedback.forLongPress(context);
                          },
                          onTap: () {
                            HapticFeedback.selectionClick();
                          },
                          key: _searchFormKey,
                          onSubmitted: (String value) {
                            if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                            focusNode!.requestFocus();
                            sendMessage();
                          },
                          onContentCommitted: onContentCommit,
                          textCapitalization: TextCapitalization.sentences,
                          focusNode: focusNode,
                          autocorrect: true,
                          controller: controller,
                          scrollPhysics: CustomBouncingScrollPhysics(),
                          style: Theme.of(context).textTheme.bodyText1!.apply(
                                color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                        Brightness.light
                                    ? Colors.black
                                    : Colors.white,
                                fontSizeDelta: -0.25,
                                fontFamily: kIsDesktop ? "Apple Color Emoji" : null,
                              ),
                          keyboardType: TextInputType.multiline,
                          maxLines: 14,
                          minLines: 1,
                          placeholder: SettingsManager().settings.recipientAsPlaceholder.value == true
                              ? placeholder.value
                              : chat?.isTextForwarding ?? false
                                  ? "Text Forwarding"
                                  : "iMessage",
                          padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                          placeholderStyle: Theme.of(context).textTheme.subtitle1,
                          autofocus: (SettingsManager().settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop) &&
                              !widget.isCreator!,
                          decoration: BoxDecoration(
                            color: Theme.of(context).backgroundColor,
                            border: Border.fromBorderSide(
                              (SettingsManager().settings.enablePrivateAPI.value &&
                                          SettingsManager().settings.privateSubjectLine.value &&
                                          (chat?.isIMessage ?? true)) ||
                                      replyToMessage.value != null
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: Theme.of(context).dividerColor,
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
                    (SettingsManager().settings.enablePrivateAPI.value &&
                                SettingsManager().settings.privateSubjectLine.value &&
                                (chat?.isIMessage ?? true)) ||
                            replyToMessage.value != null
                        ? BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1.5,
                            style: BorderStyle.solid,
                          )
                        : BorderSide.none,
                  ),
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
                          color: Theme.of(context).dividerColor,
                          child: reply != null
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    IconButton(
                                      constraints: BoxConstraints(maxWidth: 30),
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      icon: Icon(
                                        CupertinoIcons.xmark_circle,
                                        color: Theme.of(context).textTheme.subtitle1!.color,
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
                                              text: ContactManager()
                                                      .getContact(reply.handle?.address)
                                                      ?.displayName ??
                                                  replyToMessage.value!.handle?.address ??
                                                  "You",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1!
                                                  .copyWith(fontWeight: FontWeight.bold)),
                                          TextSpan(
                                              text: " - ${MessageHelper.getNotificationText(reply)}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1!
                                                  .copyWith(fontStyle: FontStyle.italic)),
                                        ]),
                                        style: Theme.of(context).textTheme.subtitle1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Container());
                    }),
                    if (SettingsManager().settings.enablePrivateAPI.value &&
                        SettingsManager().settings.privateSubjectLine.value &&
                        (chat?.isIMessage ?? true))
                      TextField(
                        enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                        controller: subjectController,
                        focusNode: subjectFocusNode,
                        textCapitalization: TextCapitalization.sentences,
                        autocorrect: true,
                        textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                            ? TextInputAction.next
                            : TextInputAction.newline,
                        autofocus: false,
                        cursorColor: Theme.of(context).primaryColor,
                        onSubmitted: (String value) {
                          focusNode!.requestFocus();
                        },
                        style: Theme.of(context).textTheme.bodyText1!.apply(
                              color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                      Brightness.light
                                  ? Colors.black
                                  : Colors.white,
                              fontSizeDelta: -0.25,
                            ),
                        decoration: InputDecoration(
                          isDense: true,
                          enabledBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          disabledBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          focusedBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          hintText: "Subject",
                          hintStyle: Theme.of(context).textTheme.subtitle1!.copyWith(fontWeight: FontWeight.bold),
                          contentPadding: EdgeInsets.only(
                            left: 10,
                            top: 15,
                            right: 10,
                            bottom: 10,
                          ),
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 14,
                        minLines: 1,
                      ),
                    if (SettingsManager().settings.enablePrivateAPI.value &&
                        SettingsManager().settings.privateSubjectLine.value &&
                        (chat?.isIMessage ?? true))
                      Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          endIndent: 10,
                          color: Theme.of(context).dividerColor),
                    TextField(
                      enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      autofocus: (SettingsManager().settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop) &&
                          !widget.isCreator!,
                      cursorColor: Theme.of(context).primaryColor,
                      key: _searchFormKey,
                      onSubmitted: (String value) {
                        if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                        focusNode!.requestFocus();
                        sendMessage();
                      },
                      style: Theme.of(context).textTheme.bodyText1!.apply(
                            color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                    Brightness.light
                                ? Colors.black
                                : Colors.white,
                            fontSizeDelta: -0.25,
                          ),
                      onContentCommitted: onContentCommit,
                      decoration: InputDecoration(
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: (SettingsManager().settings.enablePrivateAPI.value &&
                                      SettingsManager().settings.privateSubjectLine.value &&
                                      (chat?.isIMessage ?? true)) ||
                                  replyToMessage.value != null
                              ? BorderSide.none
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: (SettingsManager().settings.enablePrivateAPI.value &&
                                      SettingsManager().settings.privateSubjectLine.value &&
                                      (chat?.isIMessage ?? true)) ||
                                  replyToMessage.value != null
                              ? BorderSide.none
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: (SettingsManager().settings.enablePrivateAPI.value &&
                                      SettingsManager().settings.privateSubjectLine.value &&
                                      (chat?.isIMessage ?? true)) ||
                                  replyToMessage.value != null
                              ? BorderSide.none
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        hintText: SettingsManager().settings.recipientAsPlaceholder.value == true
                            ? placeholder.value
                            : chat?.isTextForwarding ?? false
                                ? "Text Forwarding"
                                : "iMessage",
                        hintStyle: Theme.of(context).textTheme.subtitle1,
                        contentPadding: EdgeInsets.only(
                          left: 10,
                          top: 15,
                          right: 10,
                          bottom: 10,
                        ),
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: 14,
                      minLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            samsungSkin: Obx(
              () => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(1),
                  border: Border.fromBorderSide((SettingsManager().settings.enablePrivateAPI.value &&
                              SettingsManager().settings.privateSubjectLine.value &&
                              (chat?.isIMessage ?? true)) ||
                          replyToMessage.value != null
                      ? BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1.5,
                          style: BorderStyle.solid,
                        )
                      : BorderSide.none),
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Obx(
                      () {
                        Message? reply = replyToMessage.value;
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 150),
                          width: double.infinity,
                          height: reply == null ? 0 : 40,
                          color: Theme.of(context).dividerColor,
                          child: reply != null
                              ? Row(
                                  children: [
                                    IconButton(
                                      constraints: BoxConstraints(maxWidth: 30),
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      icon: Icon(
                                        CupertinoIcons.xmark_circle,
                                        color: Theme.of(context).textTheme.subtitle1!.color,
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
                                              text: ContactManager()
                                                      .getContact(reply.handle?.address)
                                                      ?.displayName ??
                                                  reply.handle?.address ??
                                                  "You",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1!
                                                  .copyWith(fontWeight: FontWeight.bold)),
                                          TextSpan(
                                              text: " - ${MessageHelper.getNotificationText(reply)}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1!
                                                  .copyWith(fontStyle: FontStyle.italic)),
                                        ]),
                                        style: Theme.of(context).textTheme.subtitle1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(),
                        );
                      },
                    ),
                    if (SettingsManager().settings.enablePrivateAPI.value &&
                        SettingsManager().settings.privateSubjectLine.value &&
                        (chat?.isIMessage ?? true))
                      TextField(
                        enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                        controller: subjectController,
                        focusNode: subjectFocusNode,
                        textCapitalization: TextCapitalization.sentences,
                        autocorrect: true,
                        textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                            ? TextInputAction.next
                            : TextInputAction.newline,
                        autofocus: false,
                        cursorColor: Theme.of(context).primaryColor,
                        onSubmitted: (String value) {
                          focusNode!.requestFocus();
                        },
                        style: Theme.of(context).textTheme.bodyText1!.apply(
                              color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                      Brightness.light
                                  ? Colors.black
                                  : Colors.white,
                              fontSizeDelta: -0.25,
                            ),
                        decoration: InputDecoration(
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          hintText: "Subject",
                          hintStyle: Theme.of(context).textTheme.subtitle1!.copyWith(fontWeight: FontWeight.bold),
                          contentPadding: EdgeInsets.only(
                            left: 10,
                            top: 15,
                            right: 10,
                            bottom: 10,
                          ),
                          filled: true,
                          fillColor: context.theme.dividerColor,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 14,
                        minLines: 1,
                      ),
                    if (SettingsManager().settings.enablePrivateAPI.value &&
                        SettingsManager().settings.privateSubjectLine.value &&
                        (chat?.isIMessage ?? true))
                      Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          endIndent: 10,
                          color: Theme.of(context).dividerColor),
                    TextField(
                      enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      autofocus: (SettingsManager().settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop) &&
                          !widget.isCreator!,
                      cursorColor: Theme.of(context).primaryColor,
                      key: _searchFormKey,
                      onSubmitted: (String value) {
                        if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                        focusNode!.requestFocus();
                        sendMessage();
                      },
                      style: Theme.of(context).textTheme.bodyText1!.apply(
                            color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                    Brightness.light
                                ? Colors.black
                                : Colors.white,
                            fontSizeDelta: -0.25,
                          ),
                      onContentCommitted: onContentCommit,
                      decoration: InputDecoration(
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: (SettingsManager().settings.enablePrivateAPI.value &&
                                  SettingsManager().settings.privateSubjectLine.value &&
                                  (chat?.isIMessage ?? true))
                              ? BorderSide.none
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: (SettingsManager().settings.enablePrivateAPI.value &&
                                  SettingsManager().settings.privateSubjectLine.value &&
                                  (chat?.isIMessage ?? true))
                              ? BorderSide.none
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: (SettingsManager().settings.enablePrivateAPI.value &&
                                  SettingsManager().settings.privateSubjectLine.value &&
                                  (chat?.isIMessage ?? true))
                              ? BorderSide.none
                              : BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        hintText: SettingsManager().settings.recipientAsPlaceholder.value == true
                            ? placeholder.value
                            : chat?.isTextForwarding ?? false
                                ? "Text Forwarding"
                                : "iMessage",
                        hintStyle: Theme.of(context).textTheme.subtitle1,
                        contentPadding: EdgeInsets.only(
                          left: 10,
                          top: 15,
                          right: 10,
                          bottom: 10,
                        ),
                        filled: true,
                        fillColor: context.theme.dividerColor,
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
      String appDocPath = SettingsManager().appDocDir.path;
      Directory directory = Directory("$appDocPath/attachments/");
      if (!await directory.exists()) {
        directory.createSync();
      }
      pathName = "$appDocPath/attachments/OutgoingAudioMessage.m4a";
      File file = File(pathName);
      if (file.existsSync()) file.deleteSync();
    }

    if (!isRecording.value) {
      await Record().start(
        path: pathName, // required
        encoder: AudioEncoder.AAC, // by default
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
              size: 0,
              bytes:
                  kIsWeb ? (await Dio().get(pathName, options: Options(responseType: ResponseType.bytes))).data : null,
            ));
      }
    }
  }

  Future<void> sendMessage({String? effect}) async {
    // If send delay is enabled, delay the sending
    if (!isNullOrZero(SettingsManager().settings.sendDelay.value)) {
      // Break the delay into 1 second intervals
      for (var i = 0; i < SettingsManager().settings.sendDelay.value; i++) {
        if (i != 0 && sendCountdown == null) break;

        // Update UI with new state information
        if (mounted) {
          setState(() {
            sendCountdown = SettingsManager().settings.sendDelay.value - i;
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
      controller!.text = "";
      subjectController!.text = "";
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
          (SettingsManager().settings.skin.value == Skins.iOS)
              ? Container(
                  height: SettingsManager().settings.skin.value == Skins.iOS ? 35 : 40,
                  width: SettingsManager().settings.skin.value == Skins.iOS ? 35 : 40,
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
                          (chat?.isIMessage ?? true)) {
                        sendEffectAction(context, this, controller!.text.trim(), subjectController!.text.trim(),
                            replyToMessage.value?.guid, widget.chatGuid, sendMessage);
                      }
                    },
                    child: ButtonTheme(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.only(
                              right: 0,
                            ),
                            primary: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            elevation: 0),
                        onPressed: sendAction,
                        onLongPress: (sendCountdown == null && (!canRecord.value || kIsDesktop)) &&
                                !isRecording.value &&
                                (chat?.isIMessage ?? true)
                            ? () => sendEffectAction(
                                context,
                                this,
                                controller!.text.trim(),
                                subjectController!.text.trim(),
                                replyToMessage.value?.guid,
                                widget.chatGuid,
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
                                    color: (isRecording.value) ? Colors.red : Colors.white,
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
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                )),
                            AnimatedOpacity(
                              opacity: sendCountdown != null ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 50),
                              child: Icon(
                                CupertinoIcons.xmark_circle,
                                color: Colors.red,
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
                        color: SettingsManager().settings.skin.value == Skins.Samsung
                            ? Colors.transparent
                            : Theme.of(context).primaryColor,
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
                                (chat?.isIMessage ?? true)) {
                              sendEffectAction(context, this, controller!.text.trim(), subjectController!.text.trim(),
                                  replyToMessage.value?.guid, widget.chatGuid, sendMessage);
                            }
                          },
                          child: InkWell(
                            onTap: sendAction,
                            onLongPress: (sendCountdown == null && (!canRecord.value || kIsDesktop)) &&
                                    !isRecording.value &&
                                    (chat?.isIMessage ?? true)
                                ? () => sendEffectAction(
                                    context,
                                    this,
                                    controller!.text.trim(),
                                    subjectController!.text.trim(),
                                    replyToMessage.value?.guid,
                                    widget.chatGuid,
                                    sendMessage)
                                : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Obx(() => AnimatedOpacity(
                                      opacity: sendCountdown == null && canRecord.value && !kIsDesktop ? 1.0 : 0.0,
                                      duration: Duration(milliseconds: 150),
                                      child: Icon(
                                        SettingsManager().settings.skin.value == Skins.Samsung
                                            ? CupertinoIcons.waveform
                                            : Icons.mic,
                                        color: (isRecording.value)
                                            ? Colors.red
                                            : SettingsManager().settings.skin.value == Skins.Samsung
                                                ? context.theme.textTheme.bodyText1!.color
                                                : Colors.white,
                                        size: SettingsManager().settings.skin.value == Skins.Samsung ? 26 : 20,
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
                                        color: SettingsManager().settings.skin.value == Skins.Samsung
                                            ? context.theme.textTheme.bodyText1!.color
                                            : Colors.white,
                                        size: SettingsManager().settings.skin.value == Skins.Samsung ? 26 : 20,
                                      ),
                                    )),
                                AnimatedOpacity(
                                  opacity: sendCountdown != null ? 1.0 : 0.0,
                                  duration: Duration(milliseconds: 50),
                                  child: Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.red,
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
      } else if (!kIsWeb && image.path == file.path) {
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
