import 'dart:async';

import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:video_player/video_player.dart';

/// Holds cached metadata for the currently opened chat
///
/// This allows us to get around passing data through the trees and we can just store it here
class CurrentChat {
  factory CurrentChat() {
    return _manager;
  }

  static final CurrentChat _manager = CurrentChat._internal();

  CurrentChat._internal();

  StreamController _stream = StreamController.broadcast();

  Stream get stream => _stream.stream;

  Chat chat;

  Map<String, SavedAttachmentData> attachments;
  Map<String, Metadata> urlPreviews;
  Map<String, VideoPlayerController> currentPlayingVideo;
  List<VideoPlayerController> controllersToDispose;
  List<Attachment> chatAttachments;
  List<String> sentMessages;
  OverlayEntry entry;

  /// Initialize all the values for the currently open chat
  /// @param [chat] the chat object you are initializing for
  void init(Chat chat) {
    // If we are reinitializing the same chat, do nothing
    if (this.chat != null && this.chat.guid == chat.guid) return;
    dispose();

    this.chat = chat;
    attachments = {};
    currentPlayingVideo = {};
    urlPreviews = {};
    controllersToDispose = [];
    chatAttachments = [];
    sentMessages = [];
    entry = null;
  }

  /// Fetch and store all of the attachments for a [message]
  /// @param [message] the message you want to fetch for
  void getAttachmentsForMessage(Message message) {
    // If we have already disposed, do nothing
    if (chat == null) return;
    if (CurrentChat().attachments.containsKey(message.guid)) return;
    if (message.hasAttachments) {
      CurrentChat().attachments[message.guid] = new SavedAttachmentData();
    }
  }

  /// Fetch the attachment data for a particular message
  SavedAttachmentData getSavedAttachmentData(Message message) {
    if (attachments.containsKey(message.guid)) {
      return attachments[message.guid];
    }

    return null;
  }

  /// Retreive all of the attachments associated with a chat
  Future<void> updateChatAttachments() async {
    chatAttachments = await Chat.getAttachments(chat);
  }

  void changeCurrentPlayingVideo(Map<String, VideoPlayerController> video) {
    if (currentPlayingVideo != null && currentPlayingVideo.length > 0) {
      currentPlayingVideo.values.forEach((element) {
        controllersToDispose.add(element);
        element = null;
      });
    }
    currentPlayingVideo = video;
    _stream.sink.add(null);
  }

  /// Dispose all of the controllers and whatnot
  void dispose() {
    chat = null;
    if (currentPlayingVideo != null && currentPlayingVideo.length > 0) {
      currentPlayingVideo.values.forEach((element) {
        element.dispose();
      });
    }
    if (entry != null) entry.remove();
  }

  /// Dipose of the controllers which we no longer need
  void disposeControllers() {
    controllersToDispose.forEach((element) {
      element.dispose();
    });
    controllersToDispose = [];
  }
}
