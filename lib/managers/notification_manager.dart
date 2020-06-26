import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';

class NotificationManager {
  factory NotificationManager() {
    return _manager;
  }

  String _currentChatGuid = "";
  String get chat => _currentChatGuid;

  static final NotificationManager _manager = NotificationManager._internal();

  NotificationManager._internal();

  List<String> processedNotifications = <String>[];

  void switchChat(Chat chat) {
    _currentChatGuid = chat.guid;
    MethodChannelInterface()
        .invokeMethod("clear-chat-notifs", {"chatGuid": _currentChatGuid});
  }

  void leaveChat() {
    _currentChatGuid = "";
  }

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
