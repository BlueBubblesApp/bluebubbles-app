import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/camera/camera_screen.dart';
import 'package:bluebubbles/app/layouts/conversation_view/dialogs/custom_mention_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/picked_attachments_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/reply_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/text_field_suffix.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:collection/collection.dart';
import 'package:unicode_emojis/unicode_emojis.dart';
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' hide context;
import 'package:permission_handler/permission_handler.dart';
import 'package:supercharged/supercharged.dart';
import 'package:universal_io/io.dart';

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
    this.alwaysShowSend = false,
    this.hideMediaPicker = false,
  });

  final SpellCheckTextEditingController? subjectTextController;
  final MentionTextEditingController textController;
  final ConversationViewController? controller;
  final RecorderController? recorderController;
  final Future<void> Function({String? effect}) sendMessage;
  final FocusNode? focusNode;

  final List<PlatformFile> initialAttachments;

  /// When true the send button is always shown even with no text/attachments.
  /// Used by the chat creator when an existing chat has been resolved.
  final bool alwaysShowSend;

  /// When true, the camera, attachment picker, and GIF icons are hidden.
  /// Used by the chat creator when no existing chat has been matched yet.
  final bool hideMediaPicker;

  @override
  State<StatefulWidget> createState() => TextFieldComponentState();
}

class TextFieldComponentState extends State<TextFieldComponent> {
  late ConversationViewController? controller;
  late final FocusNode? focusNode;
  late final RecorderController? recorderController;
  late final List<PlatformFile> initialAttachments;
  late final MentionTextEditingController textController;
  late final SpellCheckTextEditingController? subjectTextController;
  late final Future<void> Function({String? effect}) sendMessage;

  late final ValueNotifier<bool> isRecordingNotifier;
  Timer? _sendDelayTimer;

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

    assert(!(subjectTextController == null &&
        !isChatCreator &&
        SettingsSvc.settings.enablePrivateAPI.value &&
        SettingsSvc.settings.privateSubjectLine.value &&
        chat!.isIMessage));
  }

  /// Trigger a send with the user-configured delay (respects the sendDelay setting).
  /// Replaces direct sendMessage() calls from keyboard events so that the delay
  /// is honoured when sending via Enter / numpadEnter / sendWithReturn.
  void _sendWithDelay() {
    final delay = SettingsSvc.settings.sendDelay.value;
    if (delay == 0) {
      sendMessage();
    } else {
      _sendDelayTimer?.cancel();
      _sendDelayTimer = Timer(Duration(seconds: delay), () {
        _sendDelayTimer = null;
        sendMessage();
      });
    }
  }

  @override
  void dispose() {
    _sendDelayTimer?.cancel();
    // dispose of the ValueNotifier when the state is disposed
    isRecordingNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TextFieldComponent old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      controller = widget.controller;
    }
  }

  bool get iOS => SettingsSvc.settings.skin.value == Skins.iOS;

  bool get material => SettingsSvc.settings.skin.value == Skins.Material;

  bool get samsung => SettingsSvc.settings.skin.value == Skins.Samsung;

  Chat? get chat => controller?.chat;

  bool get isChatCreator => focusNode != null;

  bool _showAttachmentPickerLocal = false;

  Future<void> _openCamera({String type = 'camera'}) async {
    bool granted = (await Permission.camera.request()).isGranted;
    if (!granted) {
      showSnackbar("Error", "Camera access was denied!");
      return;
    }

    if (type == 'video') {
      final micGranted = (await Permission.microphone.request()).isGranted;
      if (!micGranted) {
        showSnackbar("Error", "Microphone access was denied!");
        return;
      }
    }

    final XFile? file;
    if (Platform.isAndroid && !kIsWeb) {
      file = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute(
          builder: (_) => CameraScreen(initialMode: type == 'video' ? 'video' : 'photo'),
        ),
      );
    } else if (type == 'camera') {
      file = await ImagePicker().pickImage(source: ImageSource.camera);
    } else {
      file = await ImagePicker().pickVideo(source: ImageSource.camera);
    }

    if (file != null) {
      controller!.pickedAttachments.add(PlatformFile(
        path: file.path,
        name: file.path.split('/').last,
        size: await file.length(),
        bytes: await file.readAsBytes(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final txtController = controller?.textController ?? textController;
    final subjController = controller?.subjectTextController ?? subjectTextController;
    final showIcons = isChatCreator && !widget.hideMediaPicker && controller != null;
    // Captured here because contextMenuBuilder receives its own `context` that shadows this
    // one and may not have the dark theme properly applied (it's a detached overlay context).
    final outerTheme = Theme.of(context);
    Widget textInput = Focus(
      onKeyEvent: (_, ev) => handleKey(_, ev, context, isChatCreator),
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: ValueListenableBuilder<bool>(
            valueListenable: isRecordingNotifier,
            builder: (context, isRecording, child) {
              return Container(
                // Border is placed in the foregroundDecoration so it paints on top of
                // child content (ReplyHolder, attachments, etc.) and remains visible
                // at all corners instead of being covered by opaque children.
                foregroundDecoration: iOS
                    ? BoxDecoration(
                        border: Border.fromBorderSide(BorderSide(
                          color: (isRecording & iOS)
                              ? context.theme.colorScheme.primary.withValues(alpha: 1.0)
                              : context.theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          width: 1,
                        )),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                decoration: iOS
                    ? const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      )
                    : BoxDecoration(
                        color: context.theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  alignment: Alignment.bottomCenter,
                  // easeOutBack overshoots its target size, which works fine in the full
                  // conversation view but causes a brief layout overflow in chat creator
                  // where the available vertical space is tighter (keyboard is open).
                  curve: isChatCreator ? Curves.easeOut : Curves.easeOutBack,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.controller != null) ReplyHolder(controller: widget.controller!),
                      if (initialAttachments.isNotEmpty || !isChatCreator || widget.controller != null)
                        PickedAttachmentsHolder(
                          controller: widget.controller,
                          textController: txtController,
                          initialAttachments: initialAttachments,
                        ),
                      if (!isChatCreator)
                        Obx(() {
                          if (controller!.pickedAttachments.isNotEmpty && iOS) {
                            return Divider(
                              height: 1.5,
                              thickness: 1.5,
                              color: context.theme.colorScheme.surfaceContainerHighest,
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      if (!isChatCreator &&
                          SettingsSvc.settings.enablePrivateAPI.value &&
                          SettingsSvc.settings.privateSubjectLine.value &&
                          chat!.isIMessage)
                        TextField(
                          textCapitalization: TextCapitalization.sentences,
                          focusNode: controller!.subjectFocusNode,
                          autocorrect: true,
                          controller: subjController,
                          scrollPhysics: const CustomBouncingScrollPhysics(),
                          style:
                              context.theme.extension<BubbleText>()!.bubbleText.copyWith(fontWeight: FontWeight.bold),
                          keyboardType: TextInputType.multiline,
                          maxLines: 14,
                          minLines: 1,
                          enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
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
                          contentInsertionConfiguration:
                              ContentInsertionConfiguration(onContentInserted: onContentCommit),
                        ),
                      if (!isChatCreator &&
                          SettingsSvc.settings.enablePrivateAPI.value &&
                          SettingsSvc.settings.privateSubjectLine.value &&
                          chat!.isIMessage &&
                          iOS)
                        Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          color: context.theme.colorScheme.surfaceContainerHighest,
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
                        enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
                        textInputAction: SettingsSvc.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        cursorColor: context.theme.colorScheme.primary,
                        cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(iOS && !kIsDesktop && !kIsWeb ? 10 : 12.5),
                          isDense: true,
                          isCollapsed: true,
                          hintText: isChatCreator
                              ? "New Message"
                              : SettingsSvc.settings.recipientAsPlaceholder.value == true
                                  ? isRecording
                                      ? ""
                                      : chat!.getTitle()
                                  : (chat!.isTextForwarding && !isRecording)
                                      ? "Text Forwarding"
                                      : (!isRecording) // Only show iMessage when not recording
                                          ? "iMessage"
                                          : "",
                          enabledBorder: InputBorder.none,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: (isRecording & iOS),
                          fillColor: (isRecording & iOS)
                              ? context.theme.colorScheme.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                          hintStyle: context.theme
                              .extension<BubbleText>()!
                              .bubbleText
                              .copyWith(color: context.theme.colorScheme.outline),
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
                                    alwaysShowSend: widget.alwaysShowSend,
                                    hasInitialAttachments: initialAttachments.isNotEmpty,
                                  ),
                                ),
                        ),
                        contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                          final start = editableTextState.textEditingValue.selection.start;
                          final end = editableTextState.textEditingValue.selection.end;
                          final text = editableTextState.textEditingValue.text;
                          final selected = editableTextState.textEditingValue.text.substring(
                              (start - 1).clamp(0, text.length), (end + 1).clamp(min(1, text.length), text.length));

                          final toolbar = AdaptiveTextSelectionToolbar.editableText(
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
                                    final mentionMatch =
                                        MentionTextEditingController.escapingRegex.allMatches(textPart).lastOrNull;
                                    if (mentionMatch == null) return; // Shouldn't happen
                                    final mentionText = textPart.substring(mentionMatch.start, mentionMatch.end);
                                    int? mentionIndex = int.tryParse(mentionText.substring(1, mentionText.length - 1));
                                    if (mentionIndex == null) return; // Shouldn't happen
                                    final mention = controller?.mentionables[mentionIndex];
                                    final replacement = mention != null ? "@${mention.displayName}" : "";
                                    text = editableTextState.textEditingValue.text.replaceRange(
                                        (start - 1).clamp(0, text.length),
                                        (end + 1).clamp(min(1, text.length), text.length),
                                        replacement);
                                    final checkSpace = end + replacement.length - 1;
                                    final spaceAfter = checkSpace < text.length &&
                                        text.substring(end + replacement.length - 1, end + replacement.length) == " ";
                                    (controller?.textController ?? textController).value = TextEditingValue(
                                        text: text,
                                        selection: TextSelection.fromPosition(TextPosition(
                                            offset: selection.baseOffset + replacement.length + (spaceAfter ? 1 : 0))));
                                    editableTextState.hideToolbar();
                                  },
                                  label: "Remove Mention",
                                ),
                                ContextMenuButtonItem(
                                  onPressed: () async {
                                    final text = editableTextState.textEditingValue.text;
                                    final textPart = text.substring(0, (end + 1).clamp(1, text.length));
                                    final mentionMatch =
                                        MentionTextEditingController.escapingRegex.allMatches(textPart).lastOrNull;
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
                                    txtController.selection =
                                        TextSelection.fromPosition(TextPosition(offset: end + (spaceAfter ? 1 : 0)));
                                    editableTextState.hideToolbar();
                                  },
                                  label: "Custom Mention",
                                ),
                              ],
                            );

                          // Use outerTheme (captured from the real build context) because the
                          // contextMenuBuilder's own `context` parameter shadows the build context
                          // and may not have the dark theme applied (it's a detached overlay context).
                          return Theme(
                            data: outerTheme.copyWith(
                              cardColor: outerTheme.colorScheme.surfaceContainerHighest,
                              colorScheme: outerTheme.colorScheme.copyWith(
                                surface: outerTheme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            child: toolbar,
                          );
                        },
                        onTap: () {
                          HapticFeedback.selectionClick();
                        },
                        onSubmitted: (String value) {
                          controller?.focusNode.requestFocus();
                          if (isNullOrEmpty(value) && (controller?.pickedAttachments.isEmpty ?? false)) return;
                          _sendWithDelay();
                        },
                        contentInsertionConfiguration:
                            ContentInsertionConfiguration(onContentInserted: onContentCommit),
                      ),
                    ],
                  ),
                ),
              );
            }),
      ),
    );
    if (!showIcons) return textInput;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!kIsWeb && iOS && Platform.isAndroid)
            GestureDetector(
              onLongPress: () {
                _openCamera(type: 'video');
              },
              child: IconButton(
                padding: const EdgeInsets.only(left: 10),
                icon: Icon(CupertinoIcons.camera_fill, color: context.theme.colorScheme.outline, size: 28),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _openCamera();
                },
              ),
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
                  controller!.pickedAttachments.add(PlatformFile(
                    path: e.path,
                    name: e.name,
                    size: e.size,
                    bytes: await readByteStream(e.readStream!),
                  ));
                }
              } else {
                if (!_showAttachmentPickerLocal) FocusScope.of(context).unfocus();
                setState(() => _showAttachmentPickerLocal = !_showAttachmentPickerLocal);
              }
            },
          ),
          Expanded(child: textInput),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeIn,
          alignment: Alignment.bottomCenter,
          child: _showAttachmentPickerLocal
              ? AttachmentPicker(controller: controller!)
              : SizedBox(width: NavigationSvc.width(context)),
        ),
      ],
    );
  }

  void onContentCommit(KeyboardInsertedContent content) async {
    // Add some debugging logs
    Logger.info("[Content Commit] Keyboard received content");
    Logger.info("  -> Content Type: ${content.mimeType}");
    Logger.info("  -> URI: ${content.uri}");
    Logger.info("  -> Content Length: ${content.hasData ? content.data!.length : "null"}");

    // Parse the filename from the URI and read the data as a List<int>
    String filename = FilesystemSvc.uriToFilename(content.uri, content.mimeType);

    // Save the data to a location and add it to the file picker
    if (content.hasData) {
      widget.controller?.pickedAttachments.add(PlatformFile(
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
      if (kIsDesktop) {
        Pasteboard.files().then((files) {
          if (files.isEmpty) {
            Pasteboard.image.then((image) async {
              if (image != null) {
                controller!.pickedAttachments.add(PlatformFile(
                  name: "image-${controller!.pickedAttachments.length + 1}.png",
                  bytes: image,
                  size: image.length,
                ));
              } else {
                String? clipboardText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
                if (clipboardText == null) return;

                TextSelection selection = controller!.lastFocusedTextController.selection;
                String oldText = controller!.lastFocusedTextController.text;
                String newText = oldText.replaceRange(selection.start, selection.end, clipboardText);
                controller!.lastFocusedTextController.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.fromPosition(
                    TextPosition(offset: selection.start + clipboardText.length),
                  ),
                );
              }
            });
          } else {
            for (final String path in files) {
              final String name = basename(path);
              final File file = File(path);
              controller!.pickedAttachments.add(PlatformFile(
                name: name,
                path: path,
                bytes: file.readAsBytesSync(),
                size: file.lengthSync(),
              ));
            }
          }
        });
      } else {
        // This is just web
        Pasteboard.image.then((image) async {
          if (image != null) {
            controller!.pickedAttachments.add(PlatformFile(
              name: "image-${controller!.pickedAttachments.length + 1}.png",
              bytes: image,
              size: image.length,
            ));
          } else {
            String? clipboardText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
            if (clipboardText == null) return;

            TextSelection selection = controller!.lastFocusedTextController.selection;
            String oldText = controller!.lastFocusedTextController.text;
            String newText = oldText.replaceRange(selection.start, selection.end, clipboardText);
            controller!.lastFocusedTextController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.fromPosition(
                TextPosition(offset: selection.start + clipboardText.length),
              ),
            );
          }
        });
      }
      return KeyEventResult.handled;
    }

    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    if (isChatCreator) {
      if ((kIsDesktop || kIsWeb) &&
          (ev.logicalKey == LogicalKeyboardKey.enter || ev.logicalKey == LogicalKeyboardKey.numpadEnter) &&
          !HardwareKeyboard.instance.isShiftPressed) {
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
          controller!.emojiScrollController.jumpTo(max(
              (controller!.mentionSelectedIndex.value - downMovementIndex) * 40,
              controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
      if (controller!.emojiSelectedIndex.value < controller!.emojiMatches.length - 1) {
        controller!.emojiSelectedIndex.value++;
        if (controller!.emojiSelectedIndex.value >= downMovementIndex &&
            controller!.emojiSelectedIndex < controller!.emojiMatches.length - maxShown + downMovementIndex + 1) {
          controller!.emojiScrollController.jumpTo(max((controller!.emojiSelectedIndex.value - downMovementIndex) * 40,
              controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
    }

    // Up arrow
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (chat != null &&
          controller!.lastFocusedTextController.text.isEmpty &&
          SettingsSvc.settings.editLastSentMessageOnUpArrow.value &&
          SettingsSvc.serverDetails.isMinVentura &&
          SettingsSvc.serverDetails.supportsEditAndUnsend) {
        final message = MessagesSvc(chat!.guid).mostRecentSent;
        if (message != null) {
          final messageController = MessagesSvc(chat!.guid).getOrCreateState(message);
          final isSending = messageController.isSending.value;
          if (!isSending) {
            final parts = messageController.parts;
            final part = parts.filter((p) => p.text?.isNotEmpty ?? false).lastOrNull;
            if (part != null) {
              final FocusNode? node = kIsDesktop || kIsWeb ? FocusNode() : null;
              controller!.editing.add(MessageEditEntry(
                  message: message,
                  part: part,
                  controller: SpellCheckTextEditingController(text: part.text!, focusNode: node)));
              node?.requestFocus();
              return KeyEventResult.handled;
            }
          }
        }
      }
      if (controller!.mentionSelectedIndex.value > 0) {
        controller!.mentionSelectedIndex.value--;
        if (controller!.mentionSelectedIndex.value >= upMovementIndex &&
            controller!.mentionSelectedIndex < controller!.mentionMatches.length - maxShown + upMovementIndex + 1) {
          controller!.emojiScrollController.jumpTo(min((controller!.mentionSelectedIndex.value - upMovementIndex) * 40,
              controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
      if (controller!.emojiSelectedIndex.value > 0) {
        controller!.emojiSelectedIndex.value--;
        if (controller!.emojiSelectedIndex.value >= upMovementIndex &&
            controller!.emojiSelectedIndex < controller!.emojiMatches.length - maxShown + upMovementIndex + 1) {
          controller!.emojiScrollController.jumpTo(min(
              (controller!.emojiSelectedIndex.value - upMovementIndex) * 40, controller!.emojiScrollController.offset));
        }
        return KeyEventResult.handled;
      }
    }

    // Tab or Enter
    if (ev.logicalKey == LogicalKeyboardKey.tab ||
        ev.logicalKey == LogicalKeyboardKey.enter ||
        ev.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (controller!.focusNode.hasPrimaryFocus &&
          controller!.mentionMatches.length > controller!.mentionSelectedIndex.value) {
        int index = controller!.mentionSelectedIndex.value;
        TextEditingController textField = controller!.subjectFocusNode.hasPrimaryFocus
            ? controller!.subjectTextController
            : controller!.textController;
        String text = textField.text;
        RegExp regExp = RegExp(r"@(?:[^@ \n]+|$)(?=[ \n]|$)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        if (matches.isNotEmpty && matches.any((m) => m.start < textField.selection.start)) {
          RegExpMatch match = matches.lastWhere((m) => m.start < textField.selection.start);
          controller!.textController
              .addMention(text.substring(match.start, match.end), controller!.mentionMatches[index]);
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
        TextEditingController textField = controller!.subjectFocusNode.hasPrimaryFocus
            ? controller!.subjectTextController
            : controller!.textController;
        String text = textField.text;
        RegExp regExp = RegExp(r":[^: \n]{2,}(?=[ \n]|$)", multiLine: true);
        Iterable<RegExpMatch> matches = regExp.allMatches(text);
        if (matches.isNotEmpty && matches.any((m) => m.start < textField.selection.start)) {
          RegExpMatch match = matches.lastWhere((m) => m.start < textField.selection.start);
          String emoji = controller!.emojiMatches[index].emoji;
          String _text = "${text.substring(0, match.start)}$emoji ${text.substring(match.end)}";
          textField.value =
              TextEditingValue(text: _text, selection: TextSelection.collapsed(offset: match.start + emoji.length + 1));
        } else {
          // If the user moved the cursor before trying to insert an emoji, reset the picker
          controller!.emojiScrollController.jumpTo(0);
        }
        controller!.emojiSelectedIndex.value = 0;
        controller!.emojiMatches.value = <Emoji>[];

        return KeyEventResult.handled;
      }
      if (SettingsSvc.settings.privateSubjectLine.value) {
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
      if (controller!.pickedAttachments.isNotEmpty) {
        controller!.pickedAttachments.clear();
        return KeyEventResult.handled;
      }
    }

    if ((kIsDesktop || kIsWeb) &&
        (ev.logicalKey == LogicalKeyboardKey.enter || ev.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _sendWithDelay();
      // Re-request focus after the frame so any text-clear events don't steal it away
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller!.focusNode.requestFocus();
      });
      return KeyEventResult.handled;
    }

    if (kIsDesktop || kIsWeb) return KeyEventResult.ignored;
    if (ev.physicalKey == PhysicalKeyboardKey.enter && SettingsSvc.settings.sendWithReturn.value) {
      if (!isNullOrEmpty(textController.text) || !isNullOrEmpty(controller!.subjectTextController.text)) {
        _sendWithDelay();
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
