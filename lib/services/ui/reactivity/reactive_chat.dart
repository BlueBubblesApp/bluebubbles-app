import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:get/get.dart';

class ReactiveChat {
  final Chat chat;

  final RxBool isUnread = false.obs;
  final RxnString muteType = RxnString();
  final RxnString _title = RxnString();
  final RxnString _subtitle = RxnString();

  RxnString get title {
    if (_title.value != null) {
      return _title;
    }

    _title.value = chat.getTitle();
    return _title;
  }

  RxnString get subtitle {
    if (_subtitle.value != null) {
      return _subtitle;
    }

    _subtitle.value = MessageHelper.getNotificationText(chat.latestMessage);
    return _subtitle;
  }

  ReactiveChat(this.chat, {
    bool isUnread = false,
    String? muteType,
    String? title,
    String? subtitle
  }) {
    this.isUnread.value = isUnread;
    this.muteType.value = muteType;
    _title.value = title;
    _subtitle.value = subtitle;
  }

  factory ReactiveChat.fromChat(Chat chat) {
    return ReactiveChat(
      chat,
      isUnread: chat.hasUnreadMessage ?? false,
      muteType: chat.muteType,
      title: null,
      subtitle: null
    );
  }
}