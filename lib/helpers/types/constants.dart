import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:unicode_emojis/unicode_emojis.dart';

const effectMap = {
  "slam": "com.apple.MobileSMS.expressivesend.impact",
  "loud": "com.apple.MobileSMS.expressivesend.loud",
  "gentle": "com.apple.MobileSMS.expressivesend.gentle",
  "invisible ink": "com.apple.MobileSMS.expressivesend.invisibleink",
  "echo": "com.apple.messages.effect.CKEchoEffect",
  "spotlight": "com.apple.messages.effect.CKSpotlightEffect",
  "balloons": "com.apple.messages.effect.CKHappyBirthdayEffect",
  "confetti": "com.apple.messages.effect.CKConfettiEffect",
  "love": "com.apple.messages.effect.CKHeartEffect",
  "lasers": "com.apple.messages.effect.CKLasersEffect",
  "fireworks": "com.apple.messages.effect.CKFireworksEffect",
  "celebration": "com.apple.messages.effect.CKSparklesEffect",
};

const stringToMessageEffect = {
  null: MessageEffect.none,
  "slam": MessageEffect.slam,
  "loud": MessageEffect.loud,
  "gentle": MessageEffect.gentle,
  "invisible ink": MessageEffect.invisibleInk,
  "echo": MessageEffect.echo,
  "spotlight": MessageEffect.spotlight,
  "balloons": MessageEffect.balloons,
  "confetti": MessageEffect.confetti,
  "love": MessageEffect.love,
  "lasers": MessageEffect.lasers,
  "fireworks": MessageEffect.fireworks,
  "celebration": MessageEffect.celebration,
};

// known balloon bundle IDs - there will be a lot more
const balloonBundleIdMap = {
  'com.apple.Handwriting.HandwritingProvider': 'Handwriten Message',
  'com.apple.DigitalTouchBalloonProvider': 'Digital Touch Message',
  'com.apple.messages.MSMessageExtensionBalloonPlugin': {
    'com.nearfuturespecialists.imessagepoll.MessagesExtension': 'iMessage Poll',
    'be.nieldeckx.poll.extension': 'iMessage Poll',
    'com.gamerdelights.gamepigeon.ext': 'GamePigeon',
    'com.google.ios.youtube.MessagesExtension': 'YouTube',
    'com.shazam.Shazam.imessageextension': 'Shazam',
    'com.apple.mobileslideshow.PhotosMessagesApp': 'Photo Slideshow',
    'com.contextoptional.OpenTable.Messages': 'OpenTable',
    'com.apple.PassbookUIService.PeerPaymentMessagesExtension': 'Apple Pay',
    'com.apple.icloud.apps.messages.business.extension': 'Business Interactive Message',
    'com.google.Maps.MessagesExtension': 'Google Maps',
  }
};

final balloonBundleIdIconMap = {
  'com.apple.Handwriting.HandwritingProvider':
      SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.pencil_outline : Icons.brush_outlined,
  'com.apple.DigitalTouchBalloonProvider':
      SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.scribble : Icons.draw_outlined,
  'com.apple.messages.MSMessageExtensionBalloonPlugin': {
    'com.nearfuturespecialists.imessagepoll.MessagesExtension':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.doc_chart : Icons.ballot_outlined,
    'be.nieldeckx.poll.extension':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.doc_chart : Icons.ballot_outlined,
    'com.gamerdelights.gamepigeon.ext':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.game_controller : Icons.sports_esports_outlined,
    'com.google.ios.youtube.MessagesExtension':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.play_rectangle_fill : Icons.smart_display,
    'com.shazam.Shazam.imessageextension':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.music_mic : Icons.noise_aware,
    'com.apple.mobileslideshow.PhotosMessagesApp': SettingsSvc.settings.skin.value == Skins.iOS
        ? CupertinoIcons.slider_horizontal_below_rectangle
        : Icons.slideshow,
    'com.contextoptional.OpenTable.Messages': Icons.dinner_dining_outlined,
    'com.apple.PassbookUIService.PeerPaymentMessagesExtension':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.money_dollar : Icons.attach_money,
    'com.google.Maps.MessagesExtension':
        SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.location_solid : Icons.location_on_outlined,
  }
};

const frequencyToText = {
  "hourly": "hour",
  "daily": "day",
  "weekly": "week",
  "monthly": "month",
  "yearly": "year",
};

enum MessageEffect {
  none,
  slam,
  loud,
  gentle,
  invisibleInk,
  echo,
  spotlight,
  balloons,
  confetti,
  love,
  lasers,
  fireworks,
  celebration,
}

enum MessageError { NO_ERROR, TIMEOUT, NO_CONNECTION, BAD_REQUEST, SERVER_ERROR }

/// Client-side send errors. Codes start at 10000 to avoid overlap with
/// server-generated error codes (which are HTTP status codes or values < 1000).
enum ClientMessageError {
  clientError, // 10001 — generic app-side / validation error
  badGateway, // 10002 — HTTP 502
  gatewayTimeout, // 10003 — HTTP 504 or Dio timeout
  connectionRefused, // 10004 — connection refused / unreachable
  notFound, // 10005 — HTTP 404
  editFailed, // 10006 — message edit rejected or failed
  unsendFailed, // 10007 — message unsend rejected or failed
  userCanceled, // 10008 — manually canceled by the user from conversation details
}

enum Skins {
  iOS,
  Material,
  Samsung,
}

enum SwipeDirection {
  LEFT,
  RIGHT,
}

enum BBTitleBarStyle { native, custom, hidden }

/// When the app may contact a linked website to build a preview card.
///
/// Fetching a preview for somebody else's link discloses the user's IP address
/// and rough read time to whoever controls that URL, and runs the parser
/// against markup that person chose. Restricting it to known senders shrinks
/// that exposure to people already in the user's contacts.
///
/// Previews supplied by the server as part of Apple's payload data are
/// unaffected by this setting — no outbound request is involved.
enum LinkPreviewPolicy {
  /// Never fetch automatically; every preview is loaded by tapping.
  never,

  /// Fetch only for messages sent by a saved contact (or by the user).
  contactsOnly,

  /// Fetch for every link.
  always;

  /// Label for the settings picker.
  String get label {
    switch (this) {
      case LinkPreviewPolicy.never:
        return 'Never';
      case LinkPreviewPolicy.contactsOnly:
        return 'Contacts Only';
      case LinkPreviewPolicy.always:
        return 'Always';
    }
  }

  String get description {
    switch (this) {
      case LinkPreviewPolicy.never:
        return 'Link previews load only when you tap them';
      case LinkPreviewPolicy.contactsOnly:
        return 'Load automatically for saved contacts; tap to load for everyone else';
      case LinkPreviewPolicy.always:
        return 'Load automatically for every link, including from unknown senders';
    }
  }
}

enum MaterialSwipeAction {
  pin,
  alerts,
  delete,
  mark_read,
  archive,
}

enum SecurityLevel {
  locked,
  locked_and_secured,
}

enum MessageStatusIndicator { READ, DELIVERED, SENT, NONE }

enum LoadMessageResult { RETRIEVED_MESSAGES, FAILED_TO_RETRIEVE, RETRIEVED_LAST_PAGE }

enum SearchMethod { local, network }

enum LineType { meToMe, otherToMe, meToOther, otherToOther }

enum PlayerStatus { NONE, STOPPED, PAUSED, PLAYING, ENDED }

enum PayloadType { url, app }

enum Origin { incomingMessageHandler, outgoingMessageHandler }

const mimeTypeFriendlyNames = <String, String>{
  'application/pdf': 'PDF',
  'application/zip': 'ZIP',
  'application/x-zip-compressed': 'ZIP',
  'application/x-tar': 'TAR',
  'application/gzip': 'GZIP',
  'application/x-gzip': 'GZIP',
  'application/json': 'JSON',
  'application/xml': 'XML',
  'application/msword': 'Word',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'Word',
  'application/vnd.ms-excel': 'Excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'Excel',
  'application/vnd.ms-powerpoint': 'PowerPoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'PowerPoint',
  'application/rtf': 'RTF',
  'audio/mpeg': 'MP3',
  'audio/mp4': 'Audio',
  'audio/aac': 'AAC',
  'audio/wav': 'WAV',
  'audio/x-wav': 'WAV',
  'audio/caf': 'Audio',
  'audio/ogg': 'OGG',
  'audio/flac': 'FLAC',
  'audio/x-flac': 'FLAC',
  'audio/amr': 'AMR',
  'image/jpeg': 'JPEG',
  'image/png': 'PNG',
  'image/gif': 'GIF',
  'image/webp': 'WebP',
  'image/bmp': 'BMP',
  'image/tiff': 'TIFF',
  'image/svg+xml': 'SVG',
  'image/heic': 'HEIC',
  'image/heif': 'HEIF',
  'video/mp4': 'MP4',
  'video/quicktime': 'MOV',
  'video/x-msvideo': 'AVI',
  'video/webm': 'WebM',
  'video/x-matroska': 'MKV',
  'video/3gpp': '3GP',
  'video/mpeg': 'MPEG',
  'text/plain': 'Text',
  'text/html': 'HTML',
  'text/css': 'CSS',
  'text/javascript': 'JS',
  'text/csv': 'CSV',
  'text/xml': 'XML',
};

String mimeTypeToFriendlyName(String? mimeType) {
  if (mimeType == null || mimeType.isEmpty) return 'File';
  final exact = mimeTypeFriendlyNames[mimeType.toLowerCase()];
  if (exact != null) return exact;
  if (mimeType.startsWith('image/')) return 'Image';
  if (mimeType.startsWith('video/')) return 'Video';
  if (mimeType.startsWith('audio/')) return 'Audio';
  if (mimeType.startsWith('text/')) return 'Text';
  return 'File';
}

final urlRegex = RegExp(
    r"(?:^| )(((((H|h)(T|t)|(F|f))(T|t)(P|p)((S|s)?))\://)|www.)[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,6}(\:[0-9]{1,5})*(/($|[a-zA-Z0-9\.\,\;\?\'\\\+&amp;%\$#@!^*()\=~_\/-]+))*");

// Built from the same dataset as :shortcode: search, so detection and search cover the same emoji. Longest first so
// ZWJ sequences win over their parts; the lookahead skips the alternation on code units no emoji starts with.
final RegExp emojiRegex = () {
  final all = UnicodeEmojis.allEmojis
      .expand((e) => [e, ...?e.skinVariations])
      .expand((e) => [
            e.emoji,
            if (e.nonQualified != null)
              String.fromCharCodes(e.nonQualified!.split("-").map((c) => int.parse(c, radix: 16))),
          ])
      .toSet()
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final firsts = all.map((e) => e.codeUnitAt(0)).toSet().map((c) => "\\u${c.toRadixString(16).padLeft(4, "0")}").join();
  // U+1F900–1F9FF and U+1FA70–1FAFF are emoji-only blocks where new emoji land, so catch any the dataset predates
  const unlisted = r"\uD83E[\uDD00-\uDDFF\uDE70-\uDEFF](?:\uD83C[\uDFFB-\uDFFF])?";
  return RegExp("(?=[$firsts])(?:${all.map(RegExp.escape).join("|")}|$unlisted)");
}();

const bigEmojiScaleFactor = 3.0;

const appName = "BlueBubbles";

const randomAvatarBackgroundColors = [
  // Pinks
  "#FFB6C1", // LightPink
  "#FF69B4", // HotPink
  "#FF1493", // DeepPink
  // Reds
  "#DB7093", // PaleVioletRed
  "#C71585", // MediumVioletRed
  // Purples
  "#E6E6FA", // Lavender
  "#D8BFD8", // Thistle
  "#DDA0DD", // Plum
  "#EE82EE", // Violet
  "#DA70D6", // Orchid
  "#BA55D3", // MediumOrchid
  "#9932CC", // DarkOrchid
  "#9400D3", // DarkViolet
  "#8A2BE2", // BlueViolet
  // Blues
  "#ADD8E6", // LightBlue
  "#87CEEB", // SkyBlue
  "#00BFFF", // DeepSkyBlue
  "#1E90FF", // DodgerBlue
  "#6495ED", // CornflowerBlue
  "#4169E1", // RoyalBlue
  // Greens
  "#98FB98", // PaleGreen
  "#00FF7F", // SpringGreen
  "#3CB371", // MediumSeaGreen
  "#228B22", // ForestGreen
];
