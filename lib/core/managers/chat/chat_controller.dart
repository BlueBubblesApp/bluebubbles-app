import 'dart:async';

import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tuple/tuple.dart';
import 'package:video_player/video_player.dart';

enum ChatControllerEvent {
  TypingStatus,
  VideoPlaying,
}

/// Holds cached metadata for the currently opened chat
///
/// This allows us to get around passing data through the trees and we can just store it here
class ChatController {
  StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();

  Stream get stream => _stream.stream;

  Chat chat;

  Map<String, Uint8List> imageData = {};
  Map<String, Map<String, Uint8List>> stickerData = {};
  Map<String, Metadata> urlPreviews = {};
  Map<String, VideoPlayerController> currentPlayingVideo = {};
  Map<String, Player> videoPlayersDesktop = {};
  Map<String, Tuple2<ChewieAudioController, VideoPlayerController>> audioPlayers = {};
  Map<String, Tuple2<Player, Player>> audioPlayersDesktop = {};
  Map<String, List<EntityAnnotation>> mlKitParsedText = {};
  List<VideoPlayerController> videoControllersToDispose = [];
  List<Player> videoControllersToDisposeDesktop = [];
  bool showTypingIndicator = false;
  Timer? indicatorHideTimer;
  OverlayEntry? entry;
  bool keyboardOpen = false;
  double keyboardOpenOffset = 0;

  bool isActive = false;
  bool isAlive = false;

  double _timeStampOffset = 0.0;
  double _replyOffset = 0.0;

  StreamController<double> timeStampOffsetStream = StreamController<double>.broadcast();
  StreamController<Map<String, dynamic>> replyOffsetStream = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<dynamic> totalOffsetStream = StreamController<dynamic>.broadcast();
  late final StreamSubscription<Query<Chat>> sub;

  late MessageMarkers messageMarkers;

  Timer? _debounce;

  double get timeStampOffset => _timeStampOffset;

  double get replyOffset => _replyOffset;

  double get totalOffset => _timeStampOffset + _replyOffset;

  set timeStampOffset(double value) {
    if (_timeStampOffset == value) return;
    _timeStampOffset = value;
    if (!timeStampOffsetStream.isClosed) timeStampOffsetStream.sink.add(_timeStampOffset);
    if (!totalOffsetStream.isClosed) totalOffsetStream.sink.add(_timeStampOffset - _replyOffset);
  }

  setReplyOffset(String guid, double value) {
    if (_replyOffset == value) return;
    _replyOffset = value;
    if (!replyOffsetStream.isClosed) replyOffsetStream.sink.add({"guid": guid, "offset": _replyOffset});
    if (!totalOffsetStream.isClosed) {
      totalOffsetStream.sink.add({"guid": guid, "offset": _timeStampOffset - _replyOffset, "else": _timeStampOffset});
    }
  }

  AutoScrollController scrollController = AutoScrollController();
  final RxBool showScrollDown = false.obs;

  ChatController(this.chat) {
    messageMarkers = MessageMarkers(chat.guid);

    eventDispatcher.stream.listen((event) {
      // Track the offset for when the keyboard is opened
      if (event.item1 == "keyboard-status" && scrollController.hasClients) {
        keyboardOpen = event.item2 ?? false;
        if (keyboardOpen) {
          keyboardOpenOffset = scrollController.offset;
        }
      }
    });

    // listen for changes to the chat and inform chats service
    if (!kIsWeb) {
      final chatQuery = chatBox.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) {
        final _chat = chatBox.get(chat.id!);
        if (_chat != null) {
          bool shouldSort = chat.latestMessageDate != _chat.latestMessageDate;
          chats.updateChat(_chat, shouldSort: shouldSort);
          chat = _chat.merge(chat);
        }
      });
    }
  }

  static ChatController? forGuid(String? guid) {
    if (guid == null) return null;
    return ChatManager().getChatController(guid);
  }

  void initScrollController() {
    scrollController = AutoScrollController();

    scrollController.addListener(() async {
      if (!scrollController.hasClients) return;

      // Check and see if we need to unfocus the keyboard
      // The +100 is relatively arbitrary. It was the threshold I thought was good
      if (keyboardOpen &&
          ss.settings.hideKeyboardOnScroll.value &&
          scrollController.offset > keyboardOpenOffset + 100) {
        eventDispatcher.emit("unfocus-keyboard", null);
      }

      if (showScrollDown.value && scrollController.offset >= 500) return;
      if (!showScrollDown.value && scrollController.offset < 500) return;

      if (scrollController.offset >= 500 && !showScrollDown.value) {
        showScrollDown.value = true;
        if (_debounce?.isActive ?? false) _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 3), () {
          showScrollDown.value = false;
        });
      } else if (showScrollDown.value) {
        showScrollDown.value = false;
      }
    });
  }

  void initControllers() {
    if (_stream.isClosed) {
      _stream = StreamController.broadcast();
    }

    if (timeStampOffsetStream.isClosed) {
      timeStampOffsetStream = StreamController.broadcast();
    }
  }

  /// Initialize all the values for the currently open chat
  /// @param [chat] the chat object you are initializing for
  void init() {
    dispose();

    imageData = {};
    stickerData = {};
    currentPlayingVideo = {};
    audioPlayers = {};
    urlPreviews = {};
    videoControllersToDispose = [];
    videoControllersToDisposeDesktop = [];
    entry = null;
    isActive = true;
    showTypingIndicator = false;
    indicatorHideTimer = null;
    _timeStampOffset = 0;
    timeStampOffsetStream = StreamController<double>.broadcast();
    showScrollDown.value = false;

    initScrollController();
    initControllers();
    // checkTypingIndicator();
  }

  static ChatController? of(BuildContext context) {
    return context.findAncestorStateOfType<ConversationViewState>()?.currentChat ??
        context.findAncestorStateOfType<MessageDetailsPopupState>()?.currentChat;
  }

  Uint8List? getImageData(Attachment attachment) {
    if (!imageData.containsKey(attachment.guid)) return null;
    return imageData[attachment.guid];
  }

  void saveImageData(Uint8List data, Attachment attachment) {
    imageData[attachment.guid!] = data;
  }

  void clearImageData(Attachment attachment) {
    if (!imageData.containsKey(attachment.guid)) return;
    imageData.remove(attachment.guid);
  }

  void displayTypingIndicator() {
    showTypingIndicator = true;
    _stream.sink.add(
      {
        "type": ChatControllerEvent.TypingStatus,
        "data": true,
      },
    );
  }

  void hideTypingIndicator() {
    indicatorHideTimer?.cancel();
    indicatorHideTimer = null;
    showTypingIndicator = false;
    _stream.sink.add(
      {
        "type": ChatControllerEvent.TypingStatus,
        "data": false,
      },
    );
  }

  void changeCurrentPlayingVideo(Map<String, VideoPlayerController> video) {
    if (!isNullOrEmpty(currentPlayingVideo)!) {
      for (VideoPlayerController element in currentPlayingVideo.values) {
        videoControllersToDispose.add(element);
      }
    }
    currentPlayingVideo = video;
    _stream.sink.add(
      {
        "type": ChatControllerEvent.VideoPlaying,
        "data": video,
      },
    );
  }

  void addVideoDesktop(Map<String, Player> video) {
    if (!isNullOrEmpty(videoPlayersDesktop)!) {
      for (Player element in videoPlayersDesktop.values) {
        print('added');
        videoControllersToDisposeDesktop.add(element);
      }
    }
    videoPlayersDesktop.addAll(video);
    _stream.sink.add(
      {
        "type": ChatControllerEvent.VideoPlaying,
        "data": video,
      },
    );
  }

  /// Dispose all of the controllers and whatnot
  void dispose() {
    if (!isNullOrEmpty(currentPlayingVideo)!) {
      for (VideoPlayerController element in currentPlayingVideo.values) {
        element.dispose();
      }
    }

    if (!isNullOrEmpty(audioPlayers)!) {
      for (Tuple2<ChewieAudioController, VideoPlayerController> element in audioPlayers.values) {
        element.item1.dispose();
        element.item2.dispose();
      }
      audioPlayers = {};
    }

    if (_stream.isClosed) _stream.close();
    if (!timeStampOffsetStream.isClosed) timeStampOffsetStream.close();
    sub.cancel();

    _timeStampOffset = 0;
    showScrollDown.value = false;
    imageData = {};
    stickerData = {};
    currentPlayingVideo = {};
    audioPlayers = {};
    urlPreviews = {};
    videoControllersToDispose = [];
    audioPlayers.forEach((key, value) async {
      value.item1.dispose();
      value.item2.dispose();
      audioPlayers.remove(key);
    });
    isActive = false;
    showTypingIndicator = false;
    scrollController.dispose();

    initScrollController();
    initControllers();

    if (entry != null) entry!.remove();
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
      eventDispatcher.emit("focus-keyboard", null);
      keyboardOpenOffset = 0;
    }
  }

  /// Dipose of the controllers which we no longer need
  void disposeControllers() {
    disposeVideoControllers();
    disposeAudioControllers();
  }

  void disposeVideoControllers() {
    for (VideoPlayerController element in videoControllersToDispose) {
      element.dispose();
    }
    videoControllersToDispose = [];

    for (Player element in videoControllersToDisposeDesktop) {
      element.dispose();
    }
    videoControllersToDisposeDesktop = [];
  }

  void disposeAudioControllers() {
    audioPlayers.forEach((guid, player) {
      try {
        player.item1.dispose();
        player.item2.dispose();
      } catch (_) {}
    });
    audioPlayers = {};
  }
}
