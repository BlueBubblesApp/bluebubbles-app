import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

class ObservableChat {
  final Chat chat;

  final RxBool isDeleted = false.obs;
  final RxBool isArchived = false.obs;
  final RxBool isUnread = false.obs;
  final RxBool isPinned = false.obs;
  final RxnInt pinIndex = RxnInt();
  final RxnString muteType = RxnString();
  final RxnString muteArgs = RxnString();
  final RxnString customAvatarPath = RxnString();
  final RxList<Handle> participants = <Handle>[].obs;
  final Rxn<Message> latestMessage = Rxn<Message>();
  final RxBool isHighlighted = false.obs;
  final RxBool isPartiallyHighlighted = false.obs;
  final RxBool isObscured = false.obs;
  final RxBool autoSendReadReceipts = false.obs;
  final RxDouble sendProgress = 0.0.obs;

  final RxnString _title = RxnString();
  RxnString get title {
    if (_title.value != null) {
      return _title;
    }

    _title.value = chat.getTitle();
    return _title;
  }

  final RxnString _subtitle = RxnString();
  RxnString get subtitle {
    if (_subtitle.value != null) {
      return _subtitle;
    }

    if (chat.latestMessage == null) {
      _subtitle.value = "[ No messages ]";
    } else {
      _subtitle.value = MessageHelper.getNotificationText(chat.latestMessage!);
    }

    return _subtitle;
  }

  // The app currently has the chat opened
  bool get isOpen => GlobalChatService.activeGuid.value == chat.guid;

  // Active means it's in the foreground
  bool get isAlive => ls.isAlive && isOpen && !isObscured.value;

  ObservableChat(this.chat, {
    bool isUnread = false,
    bool isPinned = false,
    int? pinIndex,
    String? muteType,
    String? muteArgs,
    String? title,
    String? subtitle,
    String? customAvatarPath,
    bool isArchived = false,
    bool isDeleted = false,
    bool isHighlighted = false,
    bool isPartiallyHighlighted = false,
    bool autoSendReadReceipts = false,
    List<String> pickedAttachments = const [],
    String? textFieldText,
    List<Handle> participants = const [],
    Message? latestMessage,
  }) {
    this.isUnread.value = isUnread;
    this.isPinned.value = isPinned;
    this.pinIndex.value = pinIndex;
    this.muteType.value = muteType;
    this.muteArgs.value = muteArgs;
    _title.value = title;
    _subtitle.value = subtitle;
    this.customAvatarPath.value = customAvatarPath;
    this.isArchived.value = isArchived;
    this.isDeleted.value = isDeleted;
    this.isHighlighted.value = isHighlighted;
    this.isPartiallyHighlighted.value = isPartiallyHighlighted;
    this.autoSendReadReceipts.value = autoSendReadReceipts;
    this.latestMessage.value = latestMessage;

    setParticipants(participants);
  }

  setParticipants(List<Handle> value) {
    participants.value = value;
    participants.sort((a, b) {
      bool avatarA = a.contact?.avatar?.isNotEmpty ?? false;
      bool avatarB = b.contact?.avatar?.isNotEmpty ?? false;
      if (!avatarA && avatarB) return 1;
      if (avatarA && !avatarB) return -1;
      return 0;
    });
  }

  setIsObscured(bool value) {
    isObscured.value = value;
  }

  setSendProgress(double value) {
    if (value < 0) value = 0;
    if (value > 1) value = 1;
    sendProgress.value = value;

    if (value == 1) {
      Timer(const Duration(milliseconds: 500), () {
        setSendProgress(0);
      });
    }
  }

  factory ObservableChat.fromChat(Chat chat) {
    return ObservableChat(
      chat,
      isUnread: chat.hasUnreadMessage,
      isPinned: chat.isPinned,
      pinIndex: chat.pinIndex,
      muteType: chat.muteType,
      muteArgs: chat.muteArgs,
      title: null,
      subtitle: null,
      customAvatarPath: chat.customAvatarPath,
      isArchived: chat.isArchived,
      isDeleted: chat.dateDeleted != null,
      autoSendReadReceipts: chat.autoSendReadReceipts ?? false,
      participants: chat.participants,
      latestMessage: chat.latestMessage,
    );
  }
}