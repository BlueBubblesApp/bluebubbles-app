import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
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
      return diff.inMilliseconds.abs() < ms;
    } else if (seconds != null) {
      return diff.inSeconds.abs() < seconds;
    } else if (minutes != null) {
      return diff.inMinutes.abs() < minutes;
    } else if (hours != null) {
      return diff.inHours.abs() < hours;
    } else if (days != null) {
      return diff.inDays.abs() < days;
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

extension ClientMessageErrorExtension on ClientMessageError {
  static const codes = {
    ClientMessageError.clientError: 10001,
    ClientMessageError.badGateway: 10002,
    ClientMessageError.gatewayTimeout: 10003,
    ClientMessageError.connectionRefused: 10004,
    ClientMessageError.notFound: 10005,
    ClientMessageError.editFailed: 10006,
    ClientMessageError.unsendFailed: 10007,
    ClientMessageError.userCanceled: 10008,
  };

  static const friendlyTitles = {
    ClientMessageError.clientError: "Client Error",
    ClientMessageError.badGateway: "Bad Gateway",
    ClientMessageError.gatewayTimeout: "Gateway Timeout",
    ClientMessageError.connectionRefused: "Connection Refused",
    ClientMessageError.notFound: "Not Found",
    ClientMessageError.editFailed: "Edit Failed",
    ClientMessageError.unsendFailed: "Unsend Failed",
    ClientMessageError.userCanceled: "Manually Canceled",
  };

  int get code => codes[this]!;
  String get friendlyTitle => friendlyTitles[this]!;

  /// Returns the [ClientMessageError] whose code matches [code], or null if
  /// the code belongs to a server-side error.
  static ClientMessageError? fromCode(int code) {
    for (final entry in codes.entries) {
      if (entry.value == code) return entry.key;
    }
    return null;
  }
}

/// Returns a user-facing error message for an incoming server error code.
/// Add specific mappings in the switch statement as needed.
/// Defaults to "iMessage Error" for any unrecognised server code.
String serverErrorMessage(int code) {
  switch (code) {
    // Add specific server error code → message mappings here, e.g.:
    // case 22: return "The recipient is not registered with iMessage.";
    default:
      return "iMessage Error";
  }
}

extension EffectHelper on MessageEffect {
  bool get isBubble =>
      this == MessageEffect.slam ||
      this == MessageEffect.loud ||
      this == MessageEffect.gentle ||
      this == MessageEffect.invisibleInk;

  /// Effects that animate over the whole conversation rather than the bubble.
  ///
  /// [MessageEffect.echo] is deliberately excluded even though it is one of
  /// Apple's screen effects: it has no renderer here, and handing it to
  /// `ScreenEffectsWidget` would leave that widget holding a selection it never
  /// clears — blocking every effect that comes after it.
  bool get isScreen => this != MessageEffect.none && this != MessageEffect.echo && !isBubble;
}

/// Used when playing iMessage effects
extension WidgetLocation on GlobalKey {
  Rect? globalPaintBounds(BuildContext context) {
    double difference = context.width - NavigationSvc.width(context);
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

extension FormatStatCount on num {
  /// Formats a large integer count into a compact string (e.g. 10500 → "10.5k", 1200000 → "1.2M").
  String formatStatCount() {
    if (this >= 1000000) {
      final val = this / 1000000;
      final formatted = val.toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}M';
    } else if (this >= 1000) {
      final val = this / 1000;
      final formatted = val.toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}k';
    } else {
      return toInt().toString();
    }
  }
}

extension StringAlpha on String? {
  /// Returns the first ASCII alphabetical character from the string, uppercased,
  /// or null if the string is null / contains no alphabetical characters.
  String? get firstAlpha {
    if (this == null) return null;
    for (int i = 0; i < this!.length; i++) {
      final c = this!.codeUnitAt(i);
      if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
        return String.fromCharCode(c & ~0x20); // force uppercase
      }
    }
    return null;
  }
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

    return "${size.toStringAsFixed(decimals)}${withSuffix ? " $postfix" : ""}";
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
    if (!SettingsSvc.settings.filterUnknownSenders.value) return this;
    if (unknown) {
      return where((e) => !e.isGroup && e.handles.firstOrNull?.contactsV2.isEmpty != false).toList().obs;
    } else {
      return where((e) => e.isGroup || (!e.isGroup && e.handles.firstOrNull?.contactsV2.isNotEmpty == true))
          .toList()
          .obs;
    }
  }
}

extension PlatformSpecificCapitalize on String {
  String get psCapitalize {
    if (SettingsSvc.settings.skin.value == Skins.iOS) {
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

/// Bidirectional formatting characters. A string carrying an RTL override
/// renders in a different order than it reads, which is a cheap way to disguise
/// what a title, filename or contact name actually says.
///
/// Deliberately excludes U+200C/U+200D (ZWNJ/ZWJ): those are real characters in
/// Arabic and Indic scripts, and ZWJ is what holds multi-person emoji sequences
/// together.
final RegExp _bidiControls = RegExp('[\u{061C}\u{200E}\u{200F}\u{202A}-\u{202E}\u{2066}-\u{2069}]');

/// Non-breaking and zero-width spaces, plus the byte-order mark.
final RegExp _exoticSpaces = RegExp('[\u{00A0}\u{2000}-\u{200B}\u{202F}\u{205F}\u{3000}\u{FEFF}]');

extension InvisibleCharacters on String {
  /// Strips bidi overrides and normalises exotic spaces to plain ones.
  ///
  /// Normalising the spaces *before* any whitespace collapse is what makes a
  /// string built entirely out of them correctly come out empty.
  String get withoutInvisibleFormatting => replaceAll(_bidiControls, '').replaceAll(_exoticSpaces, ' ');
}

extension HostMatching on Uri {
  /// True when this URI's host equals [domain] or is a subdomain of it.
  ///
  /// Compares label-wise rather than by bare `endsWith`, so `notyoutube.com`
  /// does not match `youtube.com`.
  bool hostMatches(String domain) {
    final lower = host.toLowerCase();
    final target = domain.toLowerCase();
    return lower == target || lower.endsWith('.$target');
  }

  /// True when [hostMatches] holds for any of [domains] — the per-country
  /// public suffixes a site uses (`amazon.co.uk`, `amazon.de`, ...).
  bool hostMatchesAny(Iterable<String> domains) => domains.any(hostMatches);
}

extension ShortenString on String {
  String shorten(int length) {
    if (this.length <= length) return this;
    return "${substring(0, length)}...";
  }
}

extension FirstWord on String {
  /// Returns the first whitespace-delimited word, or the full string if there is none.
  String get firstWord {
    final spaceIdx = indexOf(' ');
    return spaceIdx == -1 ? this : substring(0, spaceIdx);
  }
}

extension TitleCase on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

// Returns the attachments as a string representation for message preview/notification text.
String _getAttachmentText(List<Attachment?> attachments) {
  Map<String, int> counts = {};
  for (Attachment? attachment in attachments) {
    String? mime = attachment!.mimeType;
    String key;
    if (mime == null) {
      key = "Link";
    } else if (mime.contains("vcard")) {
      key = "Contact card";
    } else if (mime.contains("location")) {
      key = "Location";
    } else if (mime.contains("contact")) {
      key = "Contact";
    } else if (mime.contains("video")) {
      key = "Video";
    } else if (mime.contains("audio")) {
      key = "Audio message";
    } else if (mime.contains("image/gif")) {
      key = "GIF";
    } else if (mime.contains("image")) {
      key = "Photo";
    } else if (mime.contains("application/pdf")) {
      key = "PDF";
    } else {
      key = mime.split("/").first.capitalize ?? "File";
    }

    int current = counts.containsKey(key) ? counts[key]! : 0;
    counts[key] = current + 1;
    // a message can only ever have 1 link (but multiple "attachments", so we break out)
    if (key == "Link") break;
  }

  List<String> attachmentStr = [];
  counts.forEach((key, value) {
    attachmentStr.add("$value $key${value > 1 ? "s" : ""}");
  });
  return attachmentStr.join(attachmentStr.length == 2 ? " & " : ", ");
}

extension RandomListChoice<E> on List<E> {
  E randomChoice() => this[Random().nextInt(length)];
}

extension MessageNotificationExtension on Message {
  String getNotificationText({bool withSender = false, bool hideContactInfo = false, bool hideMessageContent = false}) {
    String compute() {
      if (isGroupEvent) return groupEventText;
      if (expressiveSendStyleId == "com.apple.MobileSMS.expressivesend.invisibleink") {
        return "Message sent with Invisible Ink";
      }

      final String sender = !withSender
          ? ""
          : isFromMe! || handleRelation.target == null
              ? "You: "
              : (hideContactInfo ? "Someone: " : "${handleRelation.target?.displayName ?? "Someone"}: ");

      if (isInteractive) {
        return "$sender$interactiveText";
      }

      if (isNullOrEmpty(fullText) && !hasAttachments && isNullOrEmpty(associatedMessageGuid)) {
        if (dateEdited != null) {
          return "${sender}Unsent message";
        }
        return "${sender}Empty message";
      }

      // Handle the case where it's just a link, and we can show the Website title instead of "1 Link"
      if (!isNullOrEmpty(payloadData?.urlData)) {
        // Get the title of the website
        final title = payloadData!.urlData?.firstOrNull?.title;
        if (!isNullOrEmpty(title)) {
          String text = "Website: ${title!.shorten(50)}";

          // If there is a URL, grab just the domain and show it in parentheses.
          if (!isNullOrEmpty(payloadData!.urlData?.firstOrNull?.url)) {
            final uri = Uri.tryParse(payloadData!.urlData!.first.url ?? "");
            if (uri != null) {
              final domain = uri.host.replaceFirst("www.", "");
              text += " ($domain)";
            }
          }

          return text;
        }
      }

      // If there are attachments, return the number of attachments
      if (dbAttachments.isNotEmpty) {
        if (isSticker) return "${sender}1 Sticker";
        return "$sender${_getAttachmentText(dbAttachments.toList())}";
      } else if (hasAttachments) {
        // Fallback: message is marked as having attachments but they haven't loaded yet
        // (can happen with outgoing messages before the attachment links are fully persisted)
        return "${sender}Attachment";
      } else if (!isNullOrEmpty(associatedMessageGuid)) {
        // It's a reaction message, get the sender
        String reactionSender = isFromMe!
            ? 'You'
            : (hideContactInfo ? "Someone" : (handleRelation.target?.reactionDisplayName ?? "Someone"));
        // fetch the associated message object
        Message? associatedMessage = Message.findOne(guid: associatedMessageGuid);
        if (associatedMessage != null) {
          // grab the verb we'll use from the reactionToVerb map
          String? verb = ReactionTypes.reactionToVerb[associatedMessageType];
          // we need to check balloonBundleId first because for some reason
          // game pigeon messages have the text "�"
          if (associatedMessage.isInteractive) {
            return "$reactionSender $verb $interactiveText";
            // now we check if theres a subject or text and construct out message based off that
          } else if (associatedMessage.expressiveSendStyleId == "com.apple.MobileSMS.expressivesend.invisibleink") {
            return "$reactionSender $verb a message with Invisible Ink";
          } else {
            String? messageText;
            bool attachment = false;
            if (associatedMessagePart != null && associatedMessage.attributedBody.firstOrNull != null) {
              final attrBod = associatedMessage.attributedBody.first;
              final ranges = attrBod.runs
                  .where((e) => e.attributes?.messagePart == associatedMessagePart)
                  .map((e) => e.range)
                  .sorted((a, b) => a.first.compareTo(b.first));
              final attachmentGuids = attrBod.runs
                  .where(
                      (e) => e.attributes?.messagePart == associatedMessagePart && e.attributes?.attachmentGuid != null)
                  .map((e) => e.attributes?.attachmentGuid)
                  .toSet();
              if (attachmentGuids.isNotEmpty) {
                attachment = true;
                messageText = _getAttachmentText(
                  associatedMessage.dbAttachments.where((e) => attachmentGuids.contains(e.guid)).toList(),
                );
              } else if (ranges.isNotEmpty) {
                messageText = "";
                for (List range in ranges) {
                  final substring = attrBod.string.substring(range.first, range.first + range.last);
                  messageText = messageText! + substring;
                }
              }
            }
            // fallback
            if (messageText == null) {
              if (associatedMessage.hasAttachments) {
                attachment = true;
                messageText = _getAttachmentText(associatedMessage.dbAttachments.toList());
              } else {
                messageText = (associatedMessage.subject ?? "") +
                    (!isNullOrEmpty(associatedMessage.subject?.trim()) ? "\n" : "") +
                    (associatedMessage.text ?? "");
              }
            }
            return '$reactionSender $verb ${attachment ? "" : "“"}$messageText${attachment ? "" : "”"}';
          }
        }
        // if we can't fetch the associated message for some reason
        // (or none of the above conditions about it are true)
        // then we should fallback to unparsed reaction messages
        Logger.info("Couldn't fetch associated message for message: $guid");
        return "$reactionSender $text";
      } else {
        // It's all other message types
        return sender + fullText;
      }
    }

    final result = compute();
    if (hideMessageContent) {
      return faker.lorem.words(result.split(" ").length).join(" ");
    }
    return result;
  }
}
