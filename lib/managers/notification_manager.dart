import 'dart:typed_data';

import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';

class NotificationManager {
  factory NotificationManager() {
    return _manager;
  }

  Chat _currentChat;
  Chat get chat => _currentChat;
  String get chatGuid => _currentChat != null ? _currentChat.guid : null;

  static final NotificationManager _manager = NotificationManager._internal();

  NotificationManager._internal();

  List<String> processedNotifications = <String>[];

  void switchChat(Chat chat) async {
    if (chat == null) return;
    _currentChat = chat;
    await chat.markReadUnread(false);
    MethodChannelInterface()
        .invokeMethod("clear-chat-notifs", {"chatGuid": _currentChat.guid});
  }

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
      Contact contact}) {
    String address = handle.address;

    // if (handle != null) {
    //   //if the address is an email
    //   if (handle.address.contains("@")) {
    //     address = "mailto:${handle.address}";
    //     //if the address is a phone
    //   } else {
    //     address = "tel:${handle.address}";
    //   }
    // }
    Uint8List contactIcon;
    if (contact != null) {
      if (contact.avatar.length > 0) contactIcon = contact.avatar;
    }

    MethodChannelInterface().platform.invokeMethod("new-message-notification", {
      "CHANNEL_ID": "com.bluebubbles..new_messages",
      "CHANNEL_NAME": "New Messages",
      "contentTitle": contentTitle,
      "contentText": contentText,
      "group": group,
      "notificationId": id,
      "summaryId": summaryId,
      "address": address,
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

  // void updateProgressNotification(int id, double progress) {
  //   debugPrint(
  //       "updating progress notif with progress ${(progress * 100).floor()}");
  //   MethodChannelInterface()
  //       .platform
  //       .invokeMethod("update-attachment-download-notification", {
  //     "CHANNEL_ID": "com.bluebubbles..new_messages",
  //     "notificationId": id,
  //     "progress": (progress * 100).floor(),
  //   });
  // }

  // void createProgressNotification(String contentTitle, String contentText,
  //     String group, int id, int summaryId, double progress) {
  //   MethodChannelInterface()
  //       .platform
  //       .invokeMethod("create-attachment-download-notification", {
  //     "CHANNEL_ID": "com.bluebubbles..new_messages",
  //     "contentTitle": contentTitle,
  //     "contentText": contentText,
  //     "group": group,
  //     "notificationId": id,
  //     "summaryId": summaryId,
  //     "progress": (progress * 100).floor(),
  //   });
  // }

  // void finishProgressWithAttachment(
  //     String contentText, int id, Attachment attachment) {
  //   String path;
  //   if (attachment.mimeType != null && attachment.mimeType.startsWith("image/"))
  //     path = "/attachments/${attachment.guid}/${attachment.transferName}";

  //   MethodChannelInterface()
  //       .platform
  //       .invokeMethod("finish-attachment-download", {
  //     "CHANNEL_ID": "com.bluebubbles..new_messages",
  //     "contentText": contentText,
  //     "notificationId": id,
  //     "path": path,
  //   });
  // }
}
