import 'package:bluebubbles/helpers/models/constants.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/foundation.dart';

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