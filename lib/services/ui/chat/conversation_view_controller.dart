import 'dart:async';
import 'dart:isolate';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

ConversationViewController cvc(Chat chat, {String? tag}) => Get.isRegistered<ConversationViewController>(tag: tag ?? chat.guid)
? Get.find<ConversationViewController>(tag: tag ?? chat.guid) : Get.put(ConversationViewController(chat, tag_: tag), tag: tag ?? chat.guid);

class ConversationViewController extends StatefulController with GetSingleTickerProviderStateMixin {
  final Chat chat;
  late final String tag;
  bool fromChatCreator = false;
  bool addedRecentPhotoReply = false;
  final AutoScrollController scrollController = AutoScrollController();

  ConversationViewController(this.chat, {String? tag_}) {
    tag = tag_ ?? chat.guid;
  }

  // caching items
  final Map<String, Uint8List> imageData = {};
  final List<Tuple4<Attachment, PlatformFile, BuildContext, Completer<Uint8List>>> imageCacheQueue = [];
  final Map<String, Map<String, Uint8List>> stickerData = {};
  final Map<String, Metadata> legacyUrlPreviews = {};
  final Map<String, VideoController> videoPlayers = {};
  final Map<String, PlayerController> audioPlayers = {};
  final Map<String, Player> audioPlayersDesktop = {};
  final Map<String, List<EntityAnnotation>> mlKitParsedText = {};

  // message view items
  final RxBool showTypingIndicator = false.obs;
  final RxBool showScrollDown = false.obs;
  final RxDouble timestampOffset = 0.0.obs;
  final RxBool inSelectMode = false.obs;
  final RxList<Message> selected = <Message>[].obs;
  final RxList<Tuple3<Message, MessagePart, SpellCheckTextEditingController>> editing = <Tuple3<Message, MessagePart, SpellCheckTextEditingController>>[].obs;
  final GlobalKey focusInfoKey = GlobalKey();
  final RxBool recipientNotifsSilenced = false.obs;
  bool showingOverlays = false;
  bool _subjectWasLastFocused = false; // If this is false, then message field was last focused (default)

  FocusNode get lastFocusedNode => _subjectWasLastFocused ? subjectFocusNode : focusNode;
  SpellCheckTextEditingController get lastFocusedTextController => _subjectWasLastFocused ? subjectTextController : textController;

  // text field items
  bool showAttachmentPicker = false;
  final GlobalKey textFieldKey = GlobalKey();
  final RxList<PlatformFile> pickedAttachments = <PlatformFile>[].obs;
  final focusNode = FocusNode();
  final subjectFocusNode = FocusNode();
  late final textController = MentionTextEditingController(focusNode: focusNode);
  late final subjectTextController = SpellCheckTextEditingController(focusNode: subjectFocusNode);
  final RxBool showRecording = false.obs;
  final RxList<Emoji> emojiMatches = <Emoji>[].obs;
  final RxInt emojiSelectedIndex = 0.obs;
  final RxList<Mentionable> mentionMatches = <Mentionable>[].obs;
  final RxInt mentionSelectedIndex = 0.obs;
  final ScrollController emojiScrollController = ScrollController();
  final Rxn<DateTime> scheduledDate = Rxn<DateTime>(null);
  final Rxn<Tuple2<Message, int>> _replyToMessage = Rxn<Tuple2<Message, int>>(null);
  Tuple2<Message, int>? get replyToMessage => _replyToMessage.value;
  set replyToMessage(Tuple2<Message, int>? m) {
    _replyToMessage.value = m;
    if (m != null) {
      lastFocusedNode.requestFocus();
    }
  }
  late final mentionables = chat.participants.map((e) => Mentionable(
    handle: e,
  )).toList();

  bool keyboardOpen = false;
  double _keyboardOffset = 0;
  Timer? _scrollDownDebounce;
  Future<void> Function(Tuple6<List<PlatformFile>, String, String, String?, int?, String?>, bool)? sendFunc;
  bool isProcessingImage = false;

  @override
  void onInit() {
    super.onInit();

    textController.mentionables = mentionables;
    KeyboardVisibilityController().onChange.listen((bool visible) async {
      keyboardOpen = visible;
      if (scrollController.hasClients) {
        _keyboardOffset = scrollController.offset;
      }
    });

    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      if (keyboardOpen
          && ss.settings.hideKeyboardOnScroll.value
          && scrollController.offset > _keyboardOffset + 100) {
        focusNode.unfocus();
        subjectFocusNode.unfocus();
      }

      if (showScrollDown.value && scrollController.offset >= 500) return;
      if (!showScrollDown.value && scrollController.offset < 500) return;

      if (scrollController.offset >= 500 && !showScrollDown.value) {
        showScrollDown.value = true;
        if (_scrollDownDebounce?.isActive ?? false) _scrollDownDebounce?.cancel();
        _scrollDownDebounce = Timer(const Duration(seconds: 3), () {
          showScrollDown.value = false;
        });
      } else if (showScrollDown.value) {
        showScrollDown.value = false;
      }
    });

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _subjectWasLastFocused = false;
      }
    });

    subjectFocusNode.addListener(() {
      if (subjectFocusNode.hasFocus) {
        _subjectWasLastFocused = true;
      }
    });
  }

  @override
  void onClose() {
    for (PlayerController a in audioPlayers.values) {
      a.pausePlayer();
      a.dispose();
    }
    for (Player a in audioPlayersDesktop.values) {
      a.dispose();
    }
    scrollController.dispose();
    super.onClose();
  }

  Future<void> scrollToBottom() async {
    if (scrollController.positions.isNotEmpty && scrollController.positions.first.extentBefore > 0) {
      await scrollController.animateTo(
        0.0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    }

    if (ss.settings.openKeyboardOnSTB.value) {
      focusNode.requestFocus();
    }
  }

  Future<void> send(List<PlatformFile> attachments, String text, String subject, String? replyGuid, int? replyPart, String? effectId, bool isAudioMessage) async {
    sendFunc?.call(Tuple6(attachments, text, subject, replyGuid, replyPart, effectId), isAudioMessage);
  }

  void queueImage(Tuple4<Attachment, PlatformFile, BuildContext, Completer<Uint8List>> item) {
    imageCacheQueue.add(item);
    if (!isProcessingImage) _processNextImage();
  }

  Future<void> _processNextImage() async {
    if (imageCacheQueue.isEmpty) {
      isProcessingImage = false;
      return;
    }

    isProcessingImage = true;
    final queued = imageCacheQueue.removeAt(0);
    final attachment = queued.item1;
    final file = queued.item2;
    Uint8List? tmpData;
    // If it's an image, compress the image when loading it
    if (kIsWeb || file.path == null) {
      if (attachment.mimeType?.contains("image/tif") ?? false) {
        final receivePort = ReceivePort();
        await Isolate.spawn(unsupportedToPngIsolate, IsolateData(file, receivePort.sendPort));
        // Get the processed image from the isolate.
        final image = await receivePort.first as Uint8List?;
        tmpData = image;
      } else {
        tmpData = file.bytes;
      }
    } else if (attachment.canCompress) {
      tmpData = await as.loadAndGetProperties(attachment, actualPath: file.path!);
      // All other attachments can be held in memory as bytes
    } else {
      tmpData = await File(file.path!).readAsBytes();
    }
    if (tmpData == null) {
      queued.item4.complete(Uint8List.fromList([]));
      return;
    }
    imageData[attachment.guid!] = tmpData;
    try {
      await precacheImage(MemoryImage(tmpData), queued.item3);
    } catch (_) {}
    queued.item4.complete(tmpData);

    await _processNextImage();
  }

  bool isSelected(String guid) {
    return selected.firstWhereOrNull((e) => e.guid == guid) != null;
  }

  bool isEditing(String guid, int part) {
    return editing.firstWhereOrNull((e) => e.item1.guid == guid && e.item2.part == part) != null;
  }

  void close() {
    eventDispatcher.emit("update-highlight", null);
    cm.setAllInactiveSync();
    Get.delete<ConversationViewController>(tag: tag);
  }
}