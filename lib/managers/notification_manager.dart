import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class NotificationManager {
  factory NotificationManager() {
    return _manager;
  }

  Chat _currentChat;
  Chat get chat => _currentChat;
  String get chatGuid => _currentChat != null ? _currentChat.guid : null;

  static final NotificationManager _manager = NotificationManager._internal();
  NotificationManager._internal();

  List<String> processedItems = <String>[];

  Uint8List personAvatar;

  /// Checks if a [guid] has been marked as processed
  bool hasProcessed(String guid) {
    return processedItems.contains(guid);
  }

  /// Adds a [guid] to the list of processed items.
  /// If the list is more than 100 items, concatenate
  /// the list to 100 items. This is to mitigate memory issues
  /// when the app has been running for a while. We insert at
  /// index 0 to speed up the "search" process
  void addProcessed(String guid) {
    processedItems.insert(0, guid);
    if (processedItems.length > 100) {
      processedItems = processedItems.sublist(0, 100);
    }
  }

  /// Sets the currently active [chat]. As a result,
  /// the chat will be marked as read, and the notifications
  /// for the chat will be cleared
  void switchChat(Chat chat) async {
    if (chat == null) return;

    _currentChat = chat;
    await chat.setUnreadStatus(false);
    MethodChannelInterface()
        .invokeMethod("clear-chat-notifs", {"chatGuid": _currentChat.guid});
  }

  /// Sets the currently active chat to null because
  /// there is no active chat.
  void leaveChat() {
    _currentChat = null;
  }

  void createNotificationChannel() {
    MethodChannelInterface().invokeMethod("create-notif-channel", {
      "channel_name": "New Messages",
      "channel_description": "For new messages retreived",
      "CHANNEL_ID": "com.bluebubbles..new_messages"
    });
  }

  void createNewNotification(
      String contentTitle,
      String contentText,
      String group,
      int id,
      int summaryId,
      int timeStamp,
      String senderName,
      bool groupConversation,
      {Handle handle,
      Contact contact}) async {
    Uint8List contactIcon;

    try {
      if (contact != null) {
        if (contact.avatar.length > 0) contactIcon = contact.avatar;
      } else {
        if (personAvatar == null) {
          ByteData file = await loadAsset("assets/images/person.png");
          personAvatar = file.buffer.asUint8List();
        }

        contactIcon = personAvatar;
      }
    } catch (ex) {
      debugPrint("Failed to load contact avatar: ${ex.toString()}");
    }

    MethodChannelInterface().platform.invokeMethod("new-message-notification", {
      "CHANNEL_ID": "com.bluebubbles..new_messages",
      "CHANNEL_NAME": "New Messages",
      "contentTitle": contentTitle,
      "contentText": contentText,
      "group": group,
      "notificationId": id,
      "summaryId": summaryId,
      "timeStamp": timeStamp,
      "name": senderName,
      "groupConversation": groupConversation,
      "contactIcon": contactIcon,
    });
  }

  void createSocketWarningNotification() {
    MethodChannelInterface()
        .platform
        .invokeMethod("create-socket-issue-warning", {
      "CHANNEL_ID": "com.bluebubbles..new_messages",
    });
  }

  void clearSocketWarning() {
    MethodChannelInterface().platform.invokeMethod("clear-socket-issue");
  }
}
