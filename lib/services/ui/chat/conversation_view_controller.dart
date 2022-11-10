import 'dart:async';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tuple/tuple.dart';
import 'package:video_player/video_player.dart';

ConversationViewController cvc(Chat chat, {String? tag}) => Get.isRegistered<ConversationViewController>(tag: tag ?? chat.guid)
? Get.find<ConversationViewController>(tag: tag ?? chat.guid) : Get.put(ConversationViewController(chat, tag_: tag), tag: tag ?? chat.guid);

class ConversationViewController extends StatefulController with SingleGetTickerProviderMixin {
  final Chat chat;
  late final String tag;
  final AutoScrollController scrollController = AutoScrollController();
  final GlobalKey key = GlobalKey();

  ConversationViewController(this.chat, {String? tag_}) {
    tag = tag_ ?? chat.guid;
  }

  final Map<String, Uint8List> imageData = {};
  final Map<String, Map<String, Uint8List>> stickerData = {};
  final Map<String, Metadata> urlPreviews = {};
  final Map<String, VideoPlayerController> videoPlayers = {};
  final Map<String, Player> videoPlayersDesktop = {};
  final Map<String, Tuple2<ChewieAudioController, VideoPlayerController>> audioPlayers = {};
  final Map<String, Tuple2<Player, Player>> audioPlayersDesktop = {};
  final Map<String, List<EntityAnnotation>> mlKitParsedText = {};

  final RxBool showTypingIndicator = false.obs;
  final RxBool showScrollDown = false.obs;
  // text field items
  final GlobalKey textFieldKey = GlobalKey();
  final RxList<PlatformFile> pickedAttachments = <PlatformFile>[].obs;
  final RxBool showRecording = false.obs;
  final RxList<Emoji> emojiMatches = <Emoji>[].obs;
  final RxInt emojiSelectedIndex = 0.obs;
  final ScrollController emojiScrollController = ScrollController();
  final Rxn<Message> _replyToMessage = Rxn<Message>(null);
  Message? get replyToMessage => _replyToMessage.value;
  set replyToMessage(Message? m) {
    _replyToMessage.value = m;
    if (m != null) {
      focusNode.requestFocus();
    }
  }
  final focusNode = FocusNode();
  final subjectFocusNode = FocusNode();

  bool keyboardOpen = false;
  double _keyboardOffset = 0;
  Timer? _scrollDownDebounce;
  Future<void> Function(Tuple5<List<PlatformFile>, String, String, String?, String?>)? sendFunc;

  final RxDouble timestampOffset = 0.0.obs;

  @override
  void onInit() {
    super.onInit();

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
  }

  @override
  void onClose() {
    for (VideoPlayerController v in videoPlayers.values) {
      v.dispose();
    }
    for (Player v in videoPlayersDesktop.values) {
      v.dispose();
    }
    for (Tuple2<ChewieAudioController, VideoPlayerController> a in audioPlayers.values) {
      a.item1.dispose();
      a.item2.dispose();
    }
    for (Tuple2<Player, Player> a in audioPlayersDesktop.values) {
      a.item1.dispose();
      a.item2.dispose();
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

  Future<void> send(List<PlatformFile> attachments, String text, String subject, String? replyGuid, String? effectId) async {
    sendFunc?.call(Tuple5(attachments, text, subject, replyGuid, effectId));
  }

  void close() {
    Get.delete<ConversationViewController>(tag: tag);
  }
}