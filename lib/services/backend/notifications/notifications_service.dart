import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/app/widgets/components/reaction.dart';
import 'package:bluebubbles/helpers/models/reaction.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:quick_notify/quick_notify.dart';
import 'package:timezone/timezone.dart';
import 'package:universal_html/html.dart' hide File, Platform;
import 'package:universal_io/io.dart';
import 'package:win_toast/win_toast.dart';

NotificationsService notif = Get.isRegistered<NotificationsService>() ? Get.find<NotificationsService>() : Get.put(NotificationsService());

class NotificationsService extends GetxService {
  static const String NEW_MESSAGE_CHANNEL = "com.bluebubbles.new_messages";
  static const String SOCKET_ERROR_CHANNEL = "com.bluebubbles.socket_error";
  static const String REMINDER_CHANNEL = "com.bluebubbles.reminders";

  final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

  bool get hideContent => ss.settings.hideTextPreviews.value;

  Future<void> init() async {
    if (!kIsWeb && !kIsDesktop) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_stat_icon');
      final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await flnp.initialize(initializationSettings);
      // create notif channels
      createNotificationChannel(
        NEW_MESSAGE_CHANNEL,
        "New Messages",
        "Displays all received new messages",
      );
      createNotificationChannel(
        SOCKET_ERROR_CHANNEL,
        "Socket Connection Error",
        "Displays connection failures",
      );
      createNotificationChannel(
        SOCKET_ERROR_CHANNEL,
        "Message Reminders",
        "Displays message reminders set through the app",
      );
    }
    if (!kIsWeb && Platform.isWindows) {
      WinToast.instance().initialize(
        appName: "BlueBubbles",
        productName: "BlueBubbles",
        companyName: "23344BlueBubbles",
      );
      // Delete temp dir in case any notif icons weren't cleared
      Directory temp = Directory(join(fs.appDocDir.path, "temp"));
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  Future<void> createNotificationChannel(String channelID, String channelName, String channelDescription) async {
    await mcs.invokeMethod("create-notif-channel", {
      "channel_name": channelName,
      "channel_description": channelDescription,
      "CHANNEL_ID": channelID,
    });
  }

  Future<void> createReminder(Chat chat, Message message, DateTime time) async {
    await flnp.zonedSchedule(
      Random().nextInt(9998) + 1,
      'Reminder: ${_notifChatTitle(chat, "")}',
      hideContent ? "iMessage" : MessageHelper.getNotificationText(message),
      TZDateTime.from(time, local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          REMINDER_CHANNEL,
          'Reminders',
          channelDescription: 'Message reminder notifications',
          priority: Priority.max,
          importance: Importance.max,
          color: HexColor("4990de"),
        ),
      ),
      payload: MessageHelper.getNotificationText(message),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime
    );
  }

  Future<void> createNotification(Chat chat, Message message) async {
    if (chat.shouldMuteNotification(message) || message.isFromMe!) return;

    final isGroup = chat.isGroup();
    final guid = chat.guid;
    final contactName = message.handle?.displayName ?? "Unknown";
    final title = _notifChatTitle(chat, contactName);
    final text = hideContent ? "iMessage" : MessageHelper.getNotificationText(message);
    final isReaction = !isNullOrEmpty(message.associatedMessageGuid)!;

    final chatIcon = await avatarAsBytes(
        isGroup: isGroup,
        participants: chat.participants,
        chatGuid: guid,
        quality: 256
    );
    final contactIcon = message.handle?.contact?.avatar ?? (message.handle != null ? await avatarAsBytes(
        isGroup: isGroup,
        participants: [message.handle!],
        chatGuid: guid,
        quality: 256
    ) : (await loadAsset("assets/images/person64.png")).buffer.asUint8List());

    if (kIsWeb && Notification.permission == "granted") {
      final notif = Notification(title, body: text, icon: "data:image/png;base64,${base64Encode(chatIcon)}", tag: message.guid);
      notif.onClick.listen((event) async {
        await intents.openChat(guid);
      });
    } else if (kIsDesktop) {
      if (Platform.isWindows) {
        // Create a temp file with the avatar
        String path = join(fs.appDocDir.path, "temp", "${randomString(8)}.png");
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(chatIcon);

        List<int> selectedIndices = ss.settings.selectedActionIndices;
        List<String> _actions = ss.settings.actionList;
        final papi = ss.settings.enablePrivateAPI.value;

        List<String> actions = _actions.whereIndexed((i, e) => selectedIndices.contains(i))
            .map((action) => action == "Mark Read" ? action : !isReaction && papi ? ReactionTypes.reactionToEmoji[action]! : null)
            .whereNotNull().toList();

        final toast = await WinToast.instance().showToast(
          imagePath: path,
          type: ToastType.imageAndText02,
          title: title,
          subtitle: text,
          actions: actions,
        );

        toast?.eventStream.listen((event) async {
          // If we get any event, the notification has been shown, and we can delete the temp file
          if (await File(path).exists()) {
            File(path).delete();
          }
          // Show window and open the right chat
          if (event is ActivatedEvent) {
            Chat? chat = Chat.findOne(guid: guid);
            if (chat == null) return;

            if (event.actionIndex == null) {
              WinToast.instance().bringWindowToFront();
              await intents.openChat(guid);
            } else if (actions[event.actionIndex!] == "Mark Read") {
              chat.toggleHasUnread(false);
            } else if (papi) {
              final reaction = ReactionHelpers.emojiToReaction(actions[event.actionIndex!]);
              outq.queue(OutgoingItem(
                type: QueueType.newMessage,
                chat: chat,
                message: Message(
                  associatedMessageGuid: message.guid,
                  associatedMessageType: describeEnum(reaction),
                  dateCreated: DateTime.now(),
                  hasAttachments: false,
                  isFromMe: true,
                  handleId: 0,
                ),
                selected: message,
                reaction: reaction,
              ));
            }
          }
        });
      } else {
        QuickNotify.notify(title: title, content: text);
      }
    } else {
      await mcs.invokeMethod("new-message-notification", {
        "CHANNEL_ID": NEW_MESSAGE_CHANNEL,
        "CHANNEL_NAME": "New Messages",
        "notificationId": Random().nextInt(9998) + 1,
        "summaryId": chat.id,
        "chatGuid": guid,
        "chatIsGroup": isGroup,
        "chatTitle": title,
        "chatIcon": isGroup ? chatIcon : contactIcon,
        "contactName": contactName,
        "contactAvatar": contactIcon,
        "messageGuid": message.guid!,
        "messageText": text,
        "messageDate": message.dateCreated!.millisecondsSinceEpoch,
        "messageIsFromMe": false,
      });
    }
  }

  Future<void> createSocketError() async {
    await mcs.invokeMethod("create-socket-issue-warning", {
      "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
    });
  }

  Future<void> createFailedToSend() async {
    await mcs.invokeMethod("message-failed-to-send", {
      "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
    });
  }

  Future<void> clearSocketError() async {
    await mcs.invokeMethod("clear-socket-issue");
  }

  Future<void> clearFailedToSend() async {
    await mcs.invokeMethod("clear-failed-to-send");
  }

  String _notifChatTitle(Chat chat, String contactName) {
    final title = chat.getTitle() ?? (chat.isGroup() ? 'Group Chat' : 'DM');
    if (kIsDesktop) {
      return chat.isGroup() ? "$title: $contactName" : title;
    }
    return title;
  }
}