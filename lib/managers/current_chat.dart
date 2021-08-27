import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/utils.dart';
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
}

class CurrentChatInheritedWidget extends InheritedWidget {
  final CurrentChat currentChat;
  CurrentChatInheritedWidget({
    required Widget child,
    required this.currentChat,
  }) : super(child: child);

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Holds cached metadata for the currently opened chat
///
/// This allows us to get around passing data through the trees and we can just store it here
class CurrentChat extends GetxController {
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
  bool keyboardOpen = false;
  bool isAlive = false;
  StreamController<double> timeStampOffsetStream = StreamController<double>.broadcast();
  late MessageMarkers messageMarkers;
  ScrollController scrollController = ScrollController();
  final RxBool showScrollDown = false.obs;

  double _keyboardOpenOffset = 0;
  Map<String, List<Attachment?>> _messageAttachments = {};
  double _timeStampOffset = 0.0;

  double get timeStampOffset => _timeStampOffset;

  set timeStampOffset(double value) {
    if (_timeStampOffset == value) return;
    _timeStampOffset = value;
    if (!timeStampOffsetStream.isClosed) timeStampOffsetStream.sink.add(_timeStampOffset);
  }

  CurrentChat({required this.chat});

  @override
  void onInit() {
    messageMarkers = new MessageMarkers(this.chat);

    EventDispatcher.instance.stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      // Track the offset for when the keyboard is opened
      if (event["type"] == "keyboard-status" && scrollController.hasClients) {
        keyboardOpen = event.containsKey("data") ? event["data"] : false;
        if (keyboardOpen) {
          _keyboardOpenOffset = scrollController.offset;
        }
      }
    });
    scrollController.addListener(() async {
      if (!scrollController.hasClients) return;

      // Check and see if we need to unfocus the keyboard
      // The +100 is relatively arbitrary. It was the threshold I thought was good
      if (keyboardOpen &&
          SettingsManager().settings.hideKeyboardOnScroll.value &&
          scrollController.offset > _keyboardOpenOffset + 100) {
        EventDispatcher.instance.emit("unfocus-keyboard", null);
      }

      if (showScrollDown.value && scrollController.offset >= 500) return;
      if (!showScrollDown.value && scrollController.offset < 500) return;

      if (scrollController.offset >= 500 && !showScrollDown.value) {
        showScrollDown.value = true;
      } else if (showScrollDown.value) {
        showScrollDown.value = false;
      }
    });
    super.onInit();
  }

  /// Dispose all of the controllers and whatnot
  @override
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

    audioPlayers.forEach((key, value) async {
      value.item1.dispose();
      value.item2.dispose();
      audioPlayers.remove(key);
    });
    super.dispose();
  }

  /// Find the nearest [CurrentChat] in the widget tree
  static CurrentChat? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CurrentChatInheritedWidget>()?.currentChat;
  }

  /// Find the chat with the specified GUID
  static CurrentChat? forGuid(String guid) {
    if (Get.isRegistered<CurrentChat>(tag: guid)) {
      return Get.find<CurrentChat>(tag: guid);
    }
    return null;
  }

  /// Find the currently active chat
  static CurrentChat? get activeChat {
    for (String guid in ChatBloc().currentChatGuids) {
      if (Get.isRegistered<CurrentChat>(tag: guid)) {
        CurrentChat currentChat = Get.find<CurrentChat>(tag: guid);
        if (currentChat.isAlive) {
          return currentChat;
        }
      }
    }
    return null;
  }

  static CurrentChat? getCurrentChat(Chat? chat) {
    if (chat?.guid == null) return null;
    return Get.put(CurrentChat(chat: chat!), tag: chat.guid);
  }

  /// Fetch and store all of the attachments for a [message]
  /// @param [message] the message you want to fetch for
  List<Attachment?>? getAttachmentsForMessage(Message? message) {
    // If we have already disposed, do nothing
    if (!_messageAttachments.containsKey(message!.guid)) {
      preloadMessageAttachments(specificMessages: [message]);
      return [];
    }
    return _messageAttachments[message.guid];
  }

  List<Attachment?>? updateExistingAttachments(NewMessageEvent event) {
    if (event.type != NewMessageType.UPDATE) return null;
    String? oldGuid = event.event["oldGuid"];
    if (!_messageAttachments.containsKey(oldGuid)) return [];
    Message message = event.event["message"];
    if (message.attachments!.isEmpty) return [];

    _messageAttachments.remove(oldGuid);
    _messageAttachments[message.guid!] = message.attachments ?? [];

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

  Future<void> preloadMessageAttachments({List<Message?>? specificMessages}) async {
    List<Message?> messages =
        specificMessages != null ? specificMessages : await Chat.getMessagesSingleton(chat, limit: 25);
    for (Message? message in messages) {
      if (message!.hasAttachments) {
        List<Attachment?>? attachments = await message.fetchAttachments();
        _messageAttachments[message.guid!] = attachments ?? [];
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
    showTypingIndicator = false;
    _stream.sink.add(
      {
        "type": CurrentChatEvent.TypingStatus,
        "data": false,
      },
    );
  }

  /// Retrieve all of the attachments associated with a chat
  Future<void> updateChatAttachments() async {
    chatAttachments = await Chat.getAttachments(chat);
  }

  void changeCurrentPlayingVideo(Map<String, VideoPlayerController> video) {
    if (!isNullOrEmpty(currentPlayingVideo)!) {
      currentPlayingVideo.values.forEach((element) {
        videoControllersToDispose.add(element);
      });
    }
    currentPlayingVideo = video;
  }

  Future<void> scrollToBottom() async {
    await scrollController.animateTo(
      0.0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 300),
    );

    if (SettingsManager().settings.openKeyboardOnSTB.value) {
      EventDispatcher.instance.emit("focus-keyboard", null);
      _keyboardOpenOffset = 0;
    }
  }

  /// Dipose of the controllers which we no longer need
  void disposeControllers() {
    // just in case the scroll controller was disposed beforehand
    try{
      scrollController.dispose();
    } catch (_) {}
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
