import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:quick_notify/quick_notify.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_html/html.dart' as uh;

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

  /// Creates notification channel for android
  /// This is done through native code and all of this data is hard coded for now
  Future<void> createNotificationChannel(String channelID, String channelName, String channelDescription) async {
    //List<String> sounds = ["twig.wav", "walrus.wav", "sugarfree.wav", "raspberry.wav"];
    await MethodChannelInterface().invokeMethod("create-notif-channel", {
      "channel_name": channelName,
      "channel_description": channelDescription,
      "CHANNEL_ID": channelID,
    });
    /*if (channelID.contains("new_messages")) {
      sounds.forEach((s) async {
        await MethodChannelInterface().invokeMethod("create-notif-channel", {
          "channel_name": channelName,
          "channel_description": channelDescription,
          "CHANNEL_ID": channelID + "_$s",
          "sound": s,
        });
      });
    }*/
  }

  Future<void> scheduleNotification(Chat chat, Message message, DateTime time) async {
    // Get a title as best as we can
    String? chatTitle = chat.getTitle();
    bool isGroup = chat.isGroup();

    // If we couldn't get a chat title, generate placeholder names
    chatTitle ??= isGroup ? 'Group Chat' : 'iMessage Chat';
    await flutterLocalNotificationsPlugin!.zonedSchedule(
        Random().nextInt(9998) + 1,
        'Reminder: $chatTitle',
        MessageHelper.getNotificationText(message),
        tz.TZDateTime.from(time, tz.local),
        fln.NotificationDetails(
            android: fln.AndroidNotificationDetails(
          "com.bluebubbles.reminders",
          'Reminders',
          channelDescription: 'Message reminder notifications',
          priority: fln.Priority.max,
          importance: fln.Importance.max,
          color: HexColor("4990de"),
        )),
        payload: MessageHelper.getNotificationText(message),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: fln.UILocalNotificationDateInterpretation.absoluteTime);
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
  Future<void> createNotificationFromMessage(Chat chat, Message message) async {
    // sanity check to make sure we don't notify if the chat is muted
    if (chat.shouldMuteNotification(message)) return;
    Uint8List? contactIcon;

    // Get the contact name if the message is not from you
    String? contactName = 'You';
    if (!message.isFromMe!) {
      contactName = ContactManager().getContactTitle(message.handle);
    }

    // If it's still null or empty, we need to put something in there... so 'You'
    if (contactName.isEmpty) {
      contactName = 'Unknown';
    }

    // Get the actual contact metadata
    Contact? contact = ContactManager().getContact(message.handle?.address);

    // Build the message text for the notification
    String? messageText = MessageHelper.getNotificationText(message);
    if (SettingsManager().settings.hideTextPreviews.value) messageText = "iMessage";

    // Try to load in an avatar for the person
    try {
      // If there is a contact specified, we can use it's avatar
      if (contact != null && (contact.avatar.value?.isNotEmpty ?? false)) {
        if (contact.avatar.value!.isNotEmpty) contactIcon = contact.avatar.value!;
        // Otherwise if there isn't, we use the [defaultAvatar]
      } else {
        if (contact != null) {
          await ContactManager().loadContactAvatar(contact);
        }
        // If [defaultAvatar] is not loaded, load it from assets
        if ((contact?.avatar.value == null || contact!.avatar.value!.isEmpty) && defaultAvatar == null) {
          ByteData file = await loadAsset("assets/images/person64.png");
          defaultAvatar = file.buffer.asUint8List();
        }

        contactIcon = defaultAvatar;
      }
    } catch (ex) {
      Logger.error("Failed to load contact avatar: ${ex.toString()}");
    }

    try {
      // Try to update the share targets
      await ChatBloc().updateShareTarget(chat);
    } catch (ex) {
      Logger.error("Failed to update share target! Error: ${ex.toString()}");
    }

    // Get a title as best as we can
    String? chatTitle = chat.getTitle();
    bool isGroup = chat.isGroup();

    // If we couldn't get a chat title, generate placeholder names
    chatTitle ??= isGroup ? 'Group Chat' : 'iMessage Chat';

    await createNewMessageNotification(
        chat.guid,
        isGroup,
        chatTitle,
        contactIcon,
        contactName,
        contactIcon,
        message.guid!,
        messageText,
        message.dateCreated ?? DateTime.now(),
        message.isFromMe ?? false,
        chat.id ?? Random().nextInt(9998) + 1);
  }

  Future<void> createNewMessageNotification(
      String chatGuid,
      bool chatIsGroup,
      String chatTitle,
      Uint8List? chatIcon,
      String contactName,
      Uint8List? contactAvatar,
      String messageGuid,
      String messageText,
      DateTime messageDate,
      bool messageIsFromMe,
      int summaryId) async {
    if (kIsWeb && uh.Notification.permission == "granted") {
      var notif = uh.Notification(chatTitle, body: messageText, icon: "/splash/img/dark-4x.png");
      notif.onClick.listen((event) {
        MethodChannelInterface().openChat(chatGuid);
      });
      return;
    }
    if (kIsDesktop) {
      Logger.info("Sending desktop notification");
      QuickNotify.notify(title: chatIsGroup ? "$chatTitle: $contactName" : chatTitle, content: messageText);
      return;
    }
    await MethodChannelInterface().platform.invokeMethod("new-message-notification", {
      "CHANNEL_ID": NEW_MESSAGE_CHANNEL +
          (SettingsManager().settings.notificationSound.value == "default"
              ? ""
              : ("_" + SettingsManager().settings.notificationSound.value)),
      "CHANNEL_NAME": "New Messages",
      "notificationId": Random().nextInt(9998) + 1,
      "summaryId": summaryId,
      "chatGuid": chatGuid,
      "chatIsGroup": chatIsGroup,
      "chatTitle": chatTitle,
      "chatIcon": chatIcon,
      "contactName": contactName,
      "contactAvatar": contactAvatar,
      "messageGuid": messageGuid,
      "messageText": messageText,
      "messageDate": messageDate.millisecondsSinceEpoch,
      "messageIsFromMe": messageIsFromMe,
      "sound": SettingsManager().settings.notificationSound.value,
    });
  }

  //todo implement these notifications on web

  /// Creates a notification for when the socket is disconnected
  void createSocketWarningNotification() {
    if (!kIsWeb && !kIsDesktop) {
      MethodChannelInterface().platform.invokeMethod("create-socket-issue-warning", {
        "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
      });
    }
  }

  void createFailedToSendMessage() {
    if (!kIsWeb && !kIsDesktop) {
      MethodChannelInterface().platform.invokeMethod("message-failed-to-send", {
        "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
      });
    }
  }

  /// Clears the socket warning notification
  void clearSocketWarning() {
    if (!kIsWeb && !kIsDesktop) {
      MethodChannelInterface().platform.invokeMethod("clear-socket-issue");
    }
  }

  void clearFailedToSend() {
    if (!kIsWeb && !kIsDesktop) {
      MethodChannelInterface().platform.invokeMethod("clear-failed-to-send");
    }
  }
}
