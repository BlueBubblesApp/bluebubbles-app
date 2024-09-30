import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:get/get.dart';

class ObservableChat {
  final RxnString _title = RxnString();
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
  final RxBool lockChatName = false.obs;
  final RxBool lockChatIcon = false.obs;
  final RxnBool autoSendReadReceipts = RxnBool();
  final RxnBool autoSendTypingIndicators = RxnBool();
  final RxDouble sendProgress = 0.0.obs;
  final RxnString _lastMessagePreview = RxnString();

  RxnString get title {
    if (ss.settings.redactedMode.value && ss.settings.hideContactInfo.value) {
      _title.value = participants.length > 1 ? "Group Chat" : participants[0].fakeName;
    }

    return _title;
  }

  RxnString get lastMessagePreview {
    if (_lastMessagePreview.value != null) {
      return _lastMessagePreview;
    }

    if (latestMessage.value == null) {
      _lastMessagePreview.value = "[ No messages ]";
    } else {
      _lastMessagePreview.value = MessageHelper.getNotificationText(latestMessage.value!);
    }

    return _lastMessagePreview;
  }

  ObservableChat({
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
    bool lockChatName = false,
    bool lockChatIcon = false,
    bool? autoSendReadReceipts,
    bool? autoSendTypingIndicators,
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
    this.title.value = title;
    _lastMessagePreview.value = subtitle;
    this.customAvatarPath.value = customAvatarPath;
    this.isArchived.value = isArchived;
    this.isDeleted.value = isDeleted;
    this.isHighlighted.value = isHighlighted;
    this.isPartiallyHighlighted.value = isPartiallyHighlighted;
    this.lockChatName.value = lockChatName;
    this.lockChatIcon.value = lockChatIcon;
    this.autoSendReadReceipts.value = autoSendReadReceipts;
    this.autoSendTypingIndicators.value = autoSendTypingIndicators;
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

  overwrite(Chat chat) {
    isUnread.value = chat.hasUnreadMessage;
    isPinned.value = chat.isPinned;
    pinIndex.value = chat.pinIndex;
    muteType.value = chat.muteType;
    muteArgs.value = chat.muteArgs;
    title.value = chat.title;
    customAvatarPath.value = chat.customAvatarPath;
    isArchived.value = chat.isArchived;
    isDeleted.value = chat.dateDeleted != null;
    lockChatName.value = chat.lockChatName;
    lockChatIcon.value = chat.lockChatIcon;
    autoSendReadReceipts.value = chat.autoSendReadReceipts;
    autoSendTypingIndicators.value = chat.autoSendTypingIndicators;
    participants.value = chat.participants;
    latestMessage.value = chat.latestMessage;
  }

  factory ObservableChat.fromChat(Chat chat) {
    return ObservableChat(
      isUnread: chat.hasUnreadMessage,
      isPinned: chat.isPinned,
      pinIndex: chat.pinIndex,
      muteType: chat.muteType,
      muteArgs: chat.muteArgs,
      title: chat.title,
      subtitle: null,
      customAvatarPath: chat.customAvatarPath,
      isArchived: chat.isArchived,
      isDeleted: chat.dateDeleted != null,
      lockChatName: chat.lockChatName,
      lockChatIcon: chat.lockChatIcon,
      autoSendReadReceipts: chat.autoSendReadReceipts,
      autoSendTypingIndicators: chat.autoSendTypingIndicators,
      participants: chat.participants,
      latestMessage: chat.latestMessage,
    );
  }
}