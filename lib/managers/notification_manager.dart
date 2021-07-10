import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

/// [NotificationManager] holds data relating to the current chat, and manages things such as
class NotificationManager {
  factory NotificationManager() {
    return _manager;
  }

  static const String NEW_MESSAGE_CHANNEL = "com.bluebubbles.new_messages";
  static const String SOCKET_ERROR_CHANNEL = "com.bluebubbles.socket_error";

  static final NotificationManager _manager = NotificationManager._internal();
  NotificationManager._internal();

  /// [processedItems] holds all of the notifications that have already been notified / processed
  /// This ensures that items don't get processed twice
  List<String> processedItems = <String>[];

  /// [defaultAvatar] is the avatar that is used if there is no contact icon
  Uint8List? defaultAvatar;
  Uint8List? defaultMultiUserAvatar;

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
  Future<void> switchChat(Chat? chat) async {
    if (chat == null) {
      // CurrentChat.getCurrentChat(chat)?.dispose();
      return;
    }

    CurrentChat.getCurrentChat(chat)?.isAlive = true;
    await chat.setUnreadStatus(false);

    if (SettingsManager().settings.enablePrivateAPI) {
      if (SettingsManager().settings.privateMarkChatAsRead) {
        SocketManager().sendMessage("mark-chat-read", {"chatGuid": chat.guid}, (data) {});
      }

      if (!MethodChannelInterface().headless && SettingsManager().settings.sendTypingIndicators) {
        SocketManager().sendMessage("update-typing-status", {"chatGuid": chat.guid}, (data) {});
      }
    }
    ChatBloc().updateUnreads();
    MethodChannelInterface().invokeMethod("clear-chat-notifs", {"chatGuid": chat.guid});
  }

  /// Creates notification channel for android
  /// This is done through native code and all of this data is hard coded for now
  Future<void> createNotificationChannel(String channelID, String channelName, String channelDescription) async {
    await MethodChannelInterface().invokeMethod("create-notif-channel", {
      "channel_name": channelName,
      "channel_description": channelDescription,
      "CHANNEL_ID": channelID,
    });
  }

  /// Creates a notification by sending to native code
  ///
  /// @param [contentTitle] title of the notification
  ///
  /// @param [contentText] text of the notification
  ///
  /// @param [group] the tag for the group of the notification.
  /// Notifications are grouped by a shared string, and this sets that value.
  ///
  /// @param [id] the id of the notification to separate it from other notifications. Generally this is just a randomized integer
  ///
  /// @param [summaryId] the id summary of the message. Generally this is just the chat rowid.
  ///
  /// @param [timeStamp] is the specified time at which the message was sent.
  ///
  /// @param [senderName] the contact which the message was sent from. This is just the contact title of the message.
  ///
  /// @param [groupConversation] tells the notification if it is a group conversation.
  /// This is something just required by android.
  ///
  /// @param [handle] optional parameter of the handle of the message
  ///
  /// @param [contact] optional parameter of the contact of the message
  void createNewNotification(String contentTitle, String? contentText, String? group, Chat chat, int id, int? summaryId,
      int timeStamp, String? senderName, bool groupConversation, Handle? handle, Contact? contact) async {
    Uint8List? contactIcon;

    try {
      // If there is a contact specified, we can use it's avatar
      if (contact != null) {
        if (contact.avatar!.length > 0) contactIcon = contact.avatar;
        // Otherwise if there isn't, we use the [defaultAvatar]
      } else {
        // If [defaultAvatar] is not loaded, load it from assets
        if (defaultAvatar == null) {
          ByteData file = await loadAsset("assets/images/person.png");
          defaultAvatar = file.buffer.asUint8List();
        }

        contactIcon = defaultAvatar;
      }
    } catch (ex) {
      debugPrint("Failed to load contact avatar: ${ex.toString()}");
    }
    await ChatBloc().updateShareTarget(chat);

    // Invoke the method in native code
    MethodChannelInterface().platform.invokeMethod("new-message-notification", {
      "CHANNEL_ID": NEW_MESSAGE_CHANNEL,
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

  /// Creates a notification for when the socket is disconnected
  void createSocketWarningNotification() {
    MethodChannelInterface().platform.invokeMethod("create-socket-issue-warning", {
      "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
    });
  }

  /// Clears the socket warning notification
  void clearSocketWarning() {
    MethodChannelInterface().platform.invokeMethod("clear-socket-issue");
  }
}
