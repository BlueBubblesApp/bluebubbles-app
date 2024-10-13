import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

extension DateHelpers on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return now.day == day && now.month == month && now.year == year;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return yesterday.day == day && yesterday.month == month && yesterday.year == year;
  }

  bool isWithin(DateTime other, {int? ms, int? seconds, int? minutes, int? hours, int? days}) {
    Duration diff = difference(other);
    if (ms != null) {
      return diff.inMilliseconds < ms;
    } else if (seconds != null) {
      return diff.inSeconds < seconds;
    } else if (minutes != null) {
      return diff.inMinutes < minutes;
    } else if (hours != null) {
      return diff.inHours < hours;
    } else if (days != null) {
      return diff.inDays < days;
    } else {
      throw Exception("No timerange specified!");
    }
  }
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
}

/// Used when playing iMessage effects
extension WidgetLocation on GlobalKey {
  Rect? globalPaintBounds(BuildContext context) {
    double difference = context.width - ns.width(context);
    final renderObject = currentContext?.findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      final tempRect = renderObject!.paintBounds.shift(offset);
      return Rect.fromLTRB(tempRect.left - difference, tempRect.top, tempRect.right - difference, tempRect.bottom);
    } else {
      return null;
    }
  }
}

/// Used when rendering message widget
extension TextBubbleColumn on List<Widget> {
  List<Widget> conditionalReverse(bool isFromMe) {
    if (isFromMe) return this;
    return reversed.toList();
  }
}

extension NonZero on int? {
  int? get nonZero => (this ?? 0) == 0 ? null : this;
}

extension FriendlySize on double {
  String getFriendlySize({int decimals = 2, bool withSuffix = true}) {
    double size = this / 1024000.0;
    String postfix = "MB";

    if (size < 1) {
      size = size * 1024;
      postfix = "KB";
    } else if (size > 1024) {
      size = size / 1024;
      postfix = "GB";
    }

    return "${size.toStringAsFixed(decimals)}${withSuffix ? "  $postfix" : ""}";
  }
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
      return where((e) => !e.isGroup && e.participants.firstOrNull?.contact == null).toList().obs;
    } else {
      return where((e) => e.isGroup || (!e.isGroup && e.participants.firstOrNull?.contact != null)).toList().obs;
    }
  }
}

extension PlatformSpecificCapitalize on String {
  String get psCapitalize {
    if (ss.settings.skin.value == Skins.iOS) {
      return toUpperCase();
    } else {
      return this;
    }
  }
}

extension LastChars on String {
  String lastChars(int n) => substring(length - n);
}

extension UrlParsing on String {
  bool get hasUrl => urlRegex.hasMatch(this) && !kIsWeb;
}
extension ShortenString on String {
  String shorten(int length) {
    if (this.length <= length) return this;
    return "${substring(0, length)}...";
  }
}