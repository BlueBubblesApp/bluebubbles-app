import 'package:bluebubbles/helpers/models/constants.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

extension UrlParsing on String {
  bool get hasUrl => urlRegex.hasMatch(this) && !kIsWeb;
}

extension MessageErrorExtension on MessageError {
  static const codes = {
    MessageError.NO_ERROR: 0,
    MessageError.TIMEOUT: 4,
    MessageError.NO_CONNECTION: 1000,
    MessageError.BAD_REQUEST: 1001,
    MessageError.SERVER_ERROR: 1002,
  };

  int get code => codes[this]!;
}

extension EffectHelper on MessageEffect {
  bool get isBubble => this == MessageEffect.slam || this == MessageEffect.loud || this == MessageEffect.gentle || this == MessageEffect.invisibleInk;

  bool get isScreen => !isBubble && this != MessageEffect.none;
}

Indicator shouldShow(
    Message? latestMessage, Message? myLastMessage, Message? lastReadMessage, Message? lastDeliveredMessage) {
  if (!(latestMessage?.isFromMe ?? false)) return Indicator.NONE;
  if (latestMessage?.dateRead != null) return Indicator.READ;
  if (latestMessage?.dateDelivered != null) return Indicator.DELIVERED;
  if (latestMessage?.guid == lastReadMessage?.guid) return Indicator.READ;
  if (latestMessage?.guid == lastDeliveredMessage?.guid) return Indicator.DELIVERED;
  if (latestMessage?.dateCreated != null) return Indicator.SENT;

  return Indicator.NONE;
}

extension ChatListHelpers on RxList<Chat> {
  /// Helper to return archived chats or all chats depending on the bool passed to it
  /// This helps reduce a vast amount of code in build methods so the widgets can
  /// update without StreamBuilders
  RxList<Chat> archivedHelper(bool archived) {
    if (archived) {
      return where((e) => e.isArchived ?? false).toList().obs;
    } else {
      return where((e) => !(e.isArchived ?? false)).toList().obs;
    }
  }

  RxList<Chat> bigPinHelper(bool pinned) {
    if (pinned) {
      return where((e) => e.isPinned ?? false).toList().obs;
    } else {
      return where((e) => !(e.isPinned ?? false)).toList().obs;
    }
  }

  RxList<Chat> unknownSendersHelper(bool unknown) {
    if (!ss.settings.filterUnknownSenders.value) return this;
    if (unknown) {
      return where((e) => e.participants.length == 1 && cs.getContact(e.participants[0].address) == null)
          .toList()
          .obs;
    } else {
      return where((e) =>
      e.participants.length > 1 ||
          (e.participants.length == 1 && cs.getContact(e.participants[0].address) != null)).toList().obs;
    }
  }
}