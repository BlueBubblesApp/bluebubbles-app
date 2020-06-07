import 'package:bluebubble_messages/managers/method_channel_interface.dart';

class NotificationManager {
  factory NotificationManager() {
    return _manager;
  }

  static final NotificationManager _manager = NotificationManager._internal();

  NotificationManager._internal();

  void createNotificationChannel() {
    MethodChannelInterface().invokeMethod("create-notif-channel", {
      "channel_name": "New Messages",
      "channel_description": "For new messages retreived",
      "CHANNEL_ID": "com.bluebubbles.new_messages"
    });
  }

  void createNewNotification(String contentTitle, String contentText,
      String group, int id, int summaryId) {
    MethodChannelInterface().platform.invokeMethod("new-message-notification", {
      "CHANNEL_ID": "com.bluebubbles.new_messages",
      "contentTitle": contentTitle,
      "contentText": contentText,
      "group": group,
      "notificationId": id,
      "summaryId": summaryId,
    });
  }
}
