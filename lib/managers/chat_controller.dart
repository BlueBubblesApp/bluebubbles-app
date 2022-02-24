import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
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
  Map<String, Tuple2<ChewieAudioController, VideoPlayerController>> audioPlayers = {};
  Map<String, List<EntityAnnotation>> mlKitParsedText = {};
  List<VideoPlayerController> videoControllersToDispose = [];
  List<Attachment> chatAttachments = [];
  List<Message?> sentMessages = [];
  bool showTypingIndicator = false;
  Timer? indicatorHideTimer;
  OverlayEntry? entry;
  bool keyboardOpen = false;
  double keyboardOpenOffset = 0;

  bool isActive = false;
  bool isAlive = false;

  Map<String, List<Attachment?>> messageAttachments = {};

  double _timeStampOffset = 0.0;
  double _replyOffset = 0.0;

  StreamController<double> timeStampOffsetStream = StreamController<double>.broadcast();
  StreamController<Map<String, dynamic>> replyOffsetStream = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<dynamic> totalOffsetStream = StreamController<dynamic>.broadcast();

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

  ScrollController scrollController = ScrollController();
  final RxBool showScrollDown = false.obs;

  ChatController(this.chat) {
    messageMarkers = MessageMarkers(chat.guid);

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      // Track the offset for when the keyboard is opened
      if (event["type"] == "keyboard-status" && scrollController.hasClients) {
        keyboardOpen = event.containsKey("data") ? event["data"] : false;
        if (keyboardOpen) {
          keyboardOpenOffset = scrollController.offset;
        }
      }
    });
  }

  static ChatController? forGuid(String? guid) {
    if (guid == null) return null;
    return ChatManager().getChatControllerByGuid(guid);
  }

  void initScrollController() {
    scrollController = ScrollController();

    scrollController.addListener(() async {
      if (!scrollController.hasClients) return;

      // Check and see if we need to unfocus the keyboard
      // The +100 is relatively arbitrary. It was the threshold I thought was good
      if (keyboardOpen &&
          SettingsManager().settings.hideKeyboardOnScroll.value &&
          scrollController.offset > keyboardOpenOffset + 100) {
        EventDispatcher().emit("unfocus-keyboard", null);
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
    chatAttachments = [];
    sentMessages = [];
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

  /// Fetch and store all of the attachments for a [message]
  /// @param [message] the message you want to fetch for
  List<Attachment?> getAttachmentsForMessage(Message? message) {
    // If we have already disposed, do nothing
    if (!messageAttachments.containsKey(message!.guid)) {
      preloadMessageAttachments(specificMessages: [message]);
      return messageAttachments[message.guid] ?? [];
    }
    if (messageAttachments[message.guid] != null && messageAttachments[message.guid]!.isNotEmpty) {
      final guids = messageAttachments[message.guid]!.map((e) => e!.guid).toSet();
      messageAttachments[message.guid]!.retainWhere((element) => guids.remove(element!.guid));
    }
    return messageAttachments[message.guid] ?? [];
  }

  List<Attachment?>? updateExistingAttachments(NewMessageEvent event) {
    if (event.type != NewMessageType.UPDATE) return null;
    String? oldGuid = event.event["oldGuid"];
    if (!messageAttachments.containsKey(oldGuid)) return [];
    Message message = event.event["message"];
    if (message.attachments.isEmpty) return [];

    messageAttachments.remove(oldGuid);
    messageAttachments[message.guid!] = message.attachments;

    String? newAttachmentGuid = message.attachments.first!.guid;
    if (imageData.containsKey(oldGuid)) {
      Uint8List data = imageData.remove(oldGuid)!;
      imageData[newAttachmentGuid!] = data;
    } else if (currentPlayingVideo.containsKey(oldGuid)) {
      VideoPlayerController data = currentPlayingVideo.remove(oldGuid)!;
      currentPlayingVideo[newAttachmentGuid!] = data;
    } else if (audioPlayers.containsKey(oldGuid)) {
      Tuple2<ChewieAudioController, VideoPlayerController> data = audioPlayers.remove(oldGuid)!;
      audioPlayers[newAttachmentGuid!] = data;
    } else if (urlPreviews.containsKey(oldGuid)) {
      Metadata data = urlPreviews.remove(oldGuid)!;
      urlPreviews[newAttachmentGuid!] = data;
    }
    return message.attachments;
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

  Future<void> preloadMessageAttachments({List<Message?>? specificMessages}) async {
    // We don't want this to be called twice, so we should get outta here if we already have attachments.
    // The only caveat being if we get passed specific messages to load
    if (messageAttachments.isNotEmpty && specificMessages != null && specificMessages.isEmpty) return;
    List<Message?> messages = specificMessages ?? Chat.getMessages(chat, limit: 25);
    if (specificMessages != null) {
      messageAttachments.addAll(Message.fetchAttachmentsByMessages(messages));
    } else {
      messageAttachments = Message.fetchAttachmentsByMessages(messages);
    }
  }

  Future<void> preloadMessageAttachmentsAsync({List<Message?>? specificMessages}) async {
    // We don't want this to be called twice, so we should get outta here if we already have attachments.
    // The only caveat being if we get passed specific messages to load
    if (messageAttachments.isNotEmpty && specificMessages != null && specificMessages.isEmpty) return;
    List<Message?> messages = specificMessages ?? await Chat.getMessagesAsync(chat, limit: 25);
    if (specificMessages != null) {
      messageAttachments.addAll(await Message.fetchAttachmentsByMessagesAsync(messages));
    } else {
      messageAttachments = await Message.fetchAttachmentsByMessagesAsync(messages);
    }
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

  /// Retrieve all of the attachments associated with a chat
  Future<void> updateChatAttachments() async {
    chatAttachments = await chat.getAttachmentsAsync();
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
    chatAttachments = [];
    sentMessages = [];
    isActive = false;
    showTypingIndicator = false;
    scrollController.dispose();

    initScrollController();
    initControllers();

    if (entry != null) entry!.remove();
  }

  Future<void> scrollToBottom() async {
    await scrollController.animateTo(
      0.0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 300),
    );

    if (SettingsManager().settings.openKeyboardOnSTB.value) {
      EventDispatcher().emit("focus-keyboard", null);
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
