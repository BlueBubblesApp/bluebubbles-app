import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/managers/attachment_info_bloc.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:tuple/tuple.dart';
import 'package:video_player/video_player.dart';

enum CurrentChatEvent {
  TypingStatus,
  VideoPlaying,
}

/// Holds cached metadata for the currently opened chat
///
/// This allows us to get around passing data through the trees and we can just store it here
class CurrentChat {
  StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();

  Stream get stream => _stream.stream;

  Chat chat;

  Map<String, Uint8List> imageData = {};
  Map<String, Metadata> urlPreviews = {};
  Map<String, VideoPlayerController> currentPlayingVideo = {};
  Map<String, Tuple2<ChewieAudioController, VideoPlayerController>> audioPlayers = {};
  List<VideoPlayerController> videoControllersToDispose = [];
  List<Attachment> chatAttachments = [];
  List<Message?> sentMessages = [];
  bool showTypingIndicator = false;
  Timer? indicatorHideTimer;
  OverlayEntry? entry;
  bool keyboardOpen = false;
  double keyboardOpenOffset = 0;

  bool isAlive = false;

  Map<String, List<Attachment?>> messageAttachments = {};

  double _timeStampOffset = 0.0;

  StreamController<double> timeStampOffsetStream = StreamController<double>.broadcast();

  late MessageMarkers messageMarkers;

  double get timeStampOffset => _timeStampOffset;

  set timeStampOffset(double value) {
    if (_timeStampOffset == value) return;
    _timeStampOffset = value;
    if (!timeStampOffsetStream.isClosed) timeStampOffsetStream.sink.add(_timeStampOffset);
  }

  ScrollController scrollController = ScrollController();
  final RxBool showScrollDown = false.obs;

  CurrentChat(this.chat) {
    messageMarkers = new MessageMarkers(this.chat);

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

  static CurrentChat? getCurrentChat(Chat? chat) {
    if (chat?.guid == null) return null;

    CurrentChat? currentChat = AttachmentInfoBloc().getCurrentChat(chat!.guid!);
    if (currentChat == null) {
      currentChat = CurrentChat(chat);
      AttachmentInfoBloc().addCurrentChat(currentChat);
    }

    return currentChat;
  }

  static bool isActive(String chatGuid) => AttachmentInfoBloc().getCurrentChat(chatGuid)?.isAlive ?? false;

  static CurrentChat? get activeChat {
    if (AttachmentInfoBloc().chatData.isNotEmpty) {
      var res = AttachmentInfoBloc().chatData.values.where((element) => element.isAlive);

      if (res.isNotEmpty) return res.first;

      return null;
    } else {
      return null;
    }
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
    currentPlayingVideo = {};
    audioPlayers = {};
    urlPreviews = {};
    videoControllersToDispose = [];
    chatAttachments = [];
    sentMessages = [];
    entry = null;
    isAlive = true;
    showTypingIndicator = false;
    indicatorHideTimer = null;
    _timeStampOffset = 0;
    timeStampOffsetStream = StreamController<double>.broadcast();
    showScrollDown.value = false;

    initScrollController();
    initControllers();
    // checkTypingIndicator();
  }

  static CurrentChat? of(BuildContext context) {
    return context.findAncestorStateOfType<ConversationViewState>()?.currentChat ??
        context.findAncestorStateOfType<MessageDetailsPopupState>()?.currentChat ??
        null;
  }

  /// Fetch and store all of the attachments for a [message]
  /// @param [message] the message you want to fetch for
  List<Attachment?>? getAttachmentsForMessage(Message? message) {
    // If we have already disposed, do nothing
    if (!messageAttachments.containsKey(message!.guid)) {
      preloadMessageAttachments(specificMessages: [message]);
      return messageAttachments[message.guid];
    }
    if (messageAttachments[message.guid] != null && messageAttachments[message.guid]!.length > 0) {
      final guids = messageAttachments[message.guid]!.map((e) => e!.guid).toSet();
      messageAttachments[message.guid]!.retainWhere((element) => guids.remove(element!.guid));
    }
    return messageAttachments[message.guid];
  }

  List<Attachment?>? updateExistingAttachments(NewMessageEvent event) {
    if (event.type != NewMessageType.UPDATE) return null;
    String? oldGuid = event.event["oldGuid"];
    if (!messageAttachments.containsKey(oldGuid)) return [];
    Message message = event.event["message"];
    if (message.attachments!.isEmpty) return [];

    messageAttachments.remove(oldGuid);
    messageAttachments[message.guid!] = message.attachments ?? [];

    String? newAttachmentGuid = message.attachments!.first!.guid;
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

  void preloadMessageAttachments({List<Message?>? specificMessages}) {
    List<Message?> messages =
        specificMessages != null ? specificMessages : Chat.getMessages(chat, limit: 25);
    for (Message? message in messages) {
      if (message!.hasAttachments) {
        List<Attachment?>? attachments = message.fetchAttachments();
        messageAttachments[message.guid!] = attachments ?? [];
      }
    }
  }

  void displayTypingIndicator() {
    showTypingIndicator = true;
    _stream.sink.add(
      {
        "type": CurrentChatEvent.TypingStatus,
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
        "type": CurrentChatEvent.TypingStatus,
        "data": false,
      },
    );
  }

  /// Retrieve all of the attachments associated with a chat
  void updateChatAttachments() {
    chatAttachments = Chat.getAttachments(chat);
  }

  void changeCurrentPlayingVideo(Map<String, VideoPlayerController> video) {
    if (!isNullOrEmpty(currentPlayingVideo)!) {
      currentPlayingVideo.values.forEach((element) {
        videoControllersToDispose.add(element);
      });
    }
    currentPlayingVideo = video;
    _stream.sink.add(
      {
        "type": CurrentChatEvent.VideoPlaying,
        "data": video,
      },
    );
  }

  /// Dispose all of the controllers and whatnot
  void dispose() {
    if (!isNullOrEmpty(currentPlayingVideo)!) {
      currentPlayingVideo.values.forEach((element) {
        element.dispose();
      });
    }

    if (!isNullOrEmpty(audioPlayers)!) {
      audioPlayers.values.forEach((element) {
        element.item1.dispose();
        element.item2.dispose();
      });
      audioPlayers = {};
    }

    if (_stream.isClosed) _stream.close();
    if (!timeStampOffsetStream.isClosed) timeStampOffsetStream.close();

    _timeStampOffset = 0;
    showScrollDown.value = false;
    imageData = {};
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
    isAlive = false;
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
    videoControllersToDispose.forEach((element) {
      element.dispose();
    });
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
