import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/country_codes.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:convert/convert.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' show get;
import 'package:image_size_getter/image_size_getter.dart' as IMG;
import 'package:intl/intl.dart' as intl;
import 'package:slugify/slugify.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

DateTime parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is DateTime) return value;
  return null;
}

bool isNullOrEmpty(dynamic input, {trimString = false}) {
  if (input == null) return true;
  if (input is String) {
    input = input.trim();
  }

  return GetUtils.isNullOrBlank(input);
}

bool isNullOrZero(int input) {
  if (input == null) return true;
  if (input == 0) return true;
  return false;
}

Size textSize(String text, TextStyle style) {
  final TextPainter textPainter =
      TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)
        ..layout(minWidth: 0, maxWidth: double.infinity);
  return textPainter.size;
}

Future<String> formatPhoneNumber(String str) async {
  // If the string is an email, we don't want to format it
  if (str.isEmail) return str;
  str = str.trim();

  String countryCode = SettingsManager().countryCode ?? "US";
  Map<String, dynamic> meta = {};

  try {
    meta = await FlutterLibphonenumber().parse(str, region: countryCode);
  } catch (ex) {
    if (!str.startsWith("+") && getCodeMap().containsKey(countryCode)) {
      try {
        meta = await FlutterLibphonenumber().parse("${getCodeMap()[countryCode]}$str", region: countryCode);
      } catch (x) {}
    }
  }

  if (!meta.containsKey("national")) {
    if (meta.containsKey("international")) {
      return meta['international'];
    } else {
      return str;
    }
  }

  return meta['national'];
}

Future<List<String>> getCompareOpts(Handle handle) async {
  if (handle.address.isEmail) return [handle.address];

  // Build a list of formatted address (max: 3)
  String formatted = handle.address.toString();
  List<String> opts = [];
  int maxOpts = 4; // This is relatively arbitrary
  for (int i = 0; i < formatted.length; i += 1) {
    String val = formatted.substring(i);
    if (val.length == 0) break;

    opts.add(val);
    if (i + 1 >= maxOpts) break;
  }

  Map<String, dynamic> parsed = await parsePhoneNumber(handle.address, handle.country ?? "US");
  opts.addAll(parsed.values.map((item) => item.toString()).where((item) => item != 'fixedOrMobile'));
  return opts;
}

bool sameAddress(List<String> options, String compared) {
  bool match = false;
  for (String opt in options) {
    if (opt == compared) {
      match = true;
      break;
    }

    if (opt.isEmail && !compared.isEmail) continue;

    String formatted = slugify(compared, delimiter: '').toString().replaceAll('-', '');
    if (options.contains(formatted)) {
      match = true;
      break;
    }
  }

  return match;
}

String getInitials(Contact contact) {
  if (contact == null) return null;

  // Set default initials
  String initials = (contact.name?.first?.isNotEmpty == true ? contact.name.first[0] : "") +
      (contact.name?.last?.isNotEmpty == true ? contact.name.last[0] : "");

  // If the initials are empty, get them from the display name
  if (initials.trim().isEmpty) {
    initials = contact.displayName != null ? contact.displayName[0] : "";
  }

  return initials.toUpperCase();
}

// Future<Uint8List> blurHashDecode(String blurhash, int width, int height) async {
//   List<int> result = await compute(blurHashDecodeCompute,
//       jsonEncode({"hash": blurhash, "width": width, "height": height}));
//   return Uint8List.fromList(result);
// }

// List<int> blurHashDecodeCompute(String data) {
//   Map<String, dynamic> map = jsonDecode(data);
//   Uint8List imageDataBytes = Decoder.decode(
//       map["hash"],
//       ((map["width"] / 200) as double).toInt(),
//       ((map["height"] / 200) as double).toInt());
//   return imageDataBytes.toList();
// }

Future<Map<String, dynamic>> parsePhoneNumber(String number, String region) async {
  Map<String, dynamic> meta = {};
  try {
    return await FlutterLibphonenumber().parse(number, region: region);
  } catch (ex) {
    return meta;
  }
}

String randomString(int length) {
  var rand = new Random();
  var codeUnits = new List.generate(length, (index) {
    return rand.nextInt(33) + 89;
  });

  return new String.fromCharCodes(codeUnits);
}

void showSnackbar(String title, String message) {
  Get.snackbar(title, message,
      snackPosition: SnackPosition.BOTTOM,
      colorText: Get.textTheme.bodyText1.color,
      backgroundColor: Get.theme.accentColor,
      margin: EdgeInsets.only(bottom: 10));
}

bool sameSender(Message first, Message second) {
  return (first != null &&
      second != null &&
      (first.isFromMe && second.isFromMe ||
          (!first.isFromMe &&
              !second.isFromMe &&
              (first.handle != null && second.handle != null && first.handle.address == second.handle.address))));
}

String buildDate(DateTime dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = new intl.DateFormat.jm().format(dateTime);
  String date;
  if (dateTime.isToday()) {
    date = time;
  } else if (dateTime.isYesterday()) {
    date = "Yesterday";
  } else if (DateTime.now().difference(dateTime.toLocal()).inDays <= 7) {
    date = intl.DateFormat("EEEE").format(dateTime);
  } else {
    date = "${dateTime.month.toString()}/${dateTime.day.toString()}/${dateTime.year.toString()}";
  }
  return date;
}

extension DateHelpers on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return now.day == this.day && now.month == this.month && now.year == this.year;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return yesterday.day == this.day && yesterday.month == this.month && yesterday.year == this.year;
  }

  bool isWithin(DateTime other, {int ms, int seconds, int minutes, int hours}) {
    Duration diff = this.difference(other);
    if (ms != null) {
      return diff.inMilliseconds < ms;
    } else if (seconds != null) {
      return diff.inSeconds < seconds;
    } else if (minutes != null) {
      return diff.inMinutes < minutes;
    } else if (hours != null) {
      return diff.inHours < hours;
    } else {
      throw new Exception("No timerange specified!");
    }
  }
}

extension ColorHelpers on Color {
  Color darken([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(this.alpha, (this.red * f).round(), (this.green * f).round(), (this.blue * f).round());
  }

  Color lighten([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(this.alpha, this.red + ((255 - this.red) * p).round(),
        this.green + ((255 - this.green) * p).round(), this.blue + ((255 - this.blue) * p).round());
  }

  Color lightenOrDarken([double percent = 10]) {
    if (this.computeLuminance() >= 0.5) {
      return this.darken(percent);
    } else {
      return this.lighten(percent);
    }
  }
}

Color lightenOrDarken(Color color, [double percent = 10]) {
  if (color.computeLuminance() >= 0.5) {
    return color.darken(percent);
  } else {
    return color.lighten(percent);
  }
}

String sanitizeString(String input) {
  if (input == null) return "";
  input = input.replaceAll(String.fromCharCode(65532), '');
  return input;
}

bool isEmptyString(String input, {stripWhitespace = false}) {
  if (input == null) return true;
  input = sanitizeString(input);
  if (stripWhitespace) {
    input = input.trim();
  }

  return input.isEmpty;
}

bool isParticipantEvent(Message message) {
  if (message == null) return false;
  if (message.itemType == 1 && [0, 1].contains(message.groupActionType)) return true;
  if ([2, 3].contains(message.itemType)) return true;
  return false;
}

String uriToFilename(String uri, String mimeType) {
  // Handle any unknown cases
  String ext = mimeType != null ? mimeType.split('/')[1] : null;
  ext = (ext != null && ext.contains('+')) ? ext.split('+')[0] : ext;
  if (uri == null) return (ext != null) ? 'unknown.$ext' : 'unknown';

  // Get the filename
  String filename = uri;
  if (filename.contains('/')) {
    filename = filename.split('/').last;
  }

  // Get the extension
  if (filename.contains('.')) {
    dynamic split = filename.split('.');
    ext = split[1];
    filename = split[0];
  }

  // Slugify the filename
  filename = slugify(filename, delimiter: '_');

  // Rebuild the filename
  return (ext != null && ext.length > 0) ? '$filename.$ext' : filename;
}

Future<String> getGroupEventText(Message message) async {
  String text = "Unknown group event";
  String handle = "You";
  if (!message.isFromMe && message.handleId != null && message.handle != null)
    handle = await ContactManager().getContactTitle(message.handle);

  String other = "someone";
  if (message.otherHandle != null && [1, 2].contains(message.itemType)) {
    Handle item = await Handle.findOne({"originalROWID": message.otherHandle});
    if (item != null) {
      other = await ContactManager().getContactTitle(item);
    }
  }

  final bool hideNames = SettingsManager().settings.redactedMode && SettingsManager().settings.hideContactInfo;
  if (hideNames) {
    handle = "Someone";
    other = "someone";
  }

  if (message.itemType == 1 && message.groupActionType == 1) {
    text = "$handle removed $other from the conversation";
  } else if (message.itemType == 1 && message.groupActionType == 0) {
    text = "$handle added $other to the conversation";
  } else if (message.itemType == 3) {
    text = "$handle left the conversation";
  } else if (message.itemType == 2 && message.groupTitle != null) {
    text = "$handle named the conversation \"${message.groupTitle}\"";
  }

  return text;
}

Future<MemoryImage> loadAvatar(Chat chat, Handle handle) async {
  if (chat != null) {
    // If the chat hasn't been saved, save it
    if (chat.id == null) await chat.save();

    // If there are no participants, get them
    if (isNullOrEmpty(chat.participants)) {
      await chat.getParticipants();
    }

    // If there are no participants, return
    if (chat.participants == null) return null;

    String address = handle != null ? handle.address : null;
    if (address == null) {
      address = chat.participants.first.address;
    }

    // See if the update contains the current conversation
    int matchIdx = chat.participants.map((i) => i.address).toList().indexOf(handle.address);
    if (matchIdx == -1) return null;
  }

  // Get the contact
  Contact contact = await ContactManager().getCachedContact(handle);
  Uint8List avatar = contact?.photoOrThumbnail;
  if (isNullOrEmpty(avatar)) return null;

  // Set the contact image
  // NOTE: Don't compress this. It will increase load time significantly
  // NOTE: These don't need to be compressed. They are usually already small
  return MemoryImage(avatar);
}

List<RegExpMatch> parseLinks(String text) {
  RegExp exp = new RegExp(
      r"^((((H|h)(T|t)|(F|f))(T|t)(P|p)((S|s)?))\://)?(www.|[a-zA-Z0-9].)[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,6}(\:[0-9]{1,5})*(/($|[a-zA-Z0-9\.\,\;\?\'\\\+&amp;%\$#\=~_\-]+))*$");
  return exp.allMatches(text).toList();
}

String getSizeString(double size) {
  int kb = 1000;
  if (size < kb) {
    return "${(size).floor()} KB";
  } else if (size < pow(kb, 2)) {
    return "${(size / kb).toStringAsFixed(1)} MB";
  } else {
    return "${(size / (pow(kb, 2))).toStringAsFixed(1)} GB";
  }
}

String cleansePhoneNumber(String input) {
  String output = input.replaceAll("-", "");
  output = output.replaceAll("(", "");
  output = output.replaceAll(")", "");
  output = output.replaceAll(" ", "");
  return output;
}

Future<dynamic> loadAsset(String path) {
  return rootBundle.load(path);
}

String stripHtmlTags(String htmlString) {
  final document = parse(htmlString);
  final String parsedString = parse(document.body.text).documentElement.text;

  return parsedString;
}

// int _getInt(str) {
//   var hash = 5381;

//   for (var i = 0; i < str.length; i++) {
//     hash = ((hash << 4) + hash) + str.codeUnitAt(i);
//   }

//   return hash;
// }

List<Color> toColorGradient(String str) {
  if (isNullOrEmpty(str)) return [HexColor("686868"), HexColor("928E8E")];

  int total = 0;
  for (int i = 0; i < (str ?? "").length; i++) {
    total += str.codeUnitAt(i);
  }

  Random random = new Random(total);
  int seed = random.nextInt(7);

  // These are my arbitrary weights. It's based on what I found
  // to be a good amount of each color
  if (seed == 0) {
    return [HexColor("fd678d"), HexColor("ff8aa8")]; // Pink
  } else if (seed == 1) {
    return [HexColor("6bcff6"), HexColor("94ddfd")]; // Blue
  } else if (seed == 2) {
    return [HexColor("fea21c"), HexColor("feb854")]; // Orange
  } else if (seed == 3) {
    return [HexColor("5ede79"), HexColor("8de798")]; // Green
  } else if (seed == 4) {
    return [HexColor("ffca1c"), HexColor("fcd752")]; // Yellow
  } else if (seed == 5) {
    return [HexColor("ff534d"), HexColor("fd726a")]; // Red
  } else {
    return [HexColor("a78df3"), HexColor("bcabfc")]; // Purple
  }
}

bool shouldBeRainbow(Chat chat) {
  Chat theChat = chat;
  if (theChat == null) return false;
  return SettingsManager().settings.colorfulAvatars;
}

Size getGifDimensions(Uint8List bytes) {
  String hexString = "";

  // Bytes 6 and 7 are the height bytes of a gif
  hexString += hex.encode(bytes.sublist(7, 8));
  hexString += hex.encode(bytes.sublist(6, 7));
  int width = int.parse(hexString, radix: 16);

  hexString = "";
  // Bytes 8 and 9 are the height bytes of a gif
  hexString += hex.encode(bytes.sublist(9, 10));
  hexString += hex.encode(bytes.sublist(8, 9));
  int height = int.parse(hexString, radix: 16);

  debugPrint("GIF width: $width");
  debugPrint("GIF height: $height");
  Size size = new Size(width.toDouble(), height.toDouble());
  return size;
}

Future<IMG.Size> getVideoDimensions(Attachment attachment, {Uint8List bytes}) async {
  Uint8List imageData = await VideoThumbnail.thumbnailData(
    video: AttachmentHelper.getAttachmentPath(attachment),
    imageFormat: ImageFormat.JPEG,
    quality: 50,
  );

  return IMG.ImageSizeGetter.getSize(IMG.MemoryInput(imageData));
}

Brightness getBrightness(BuildContext context) {
  return AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ? Brightness.dark : Brightness.light;
}

/// Take the passed [address] or serverAddress from Settings
/// and sanitize it, making sure it includes an http schema
String getServerAddress({String address}) {
  String serverAddress = address ?? SettingsManager().settings.serverAddress;
  if (serverAddress == null) return null;

  String sanitized = serverAddress.replaceAll("https://", "").replaceAll("http://", "").trim();
  if (sanitized.isEmpty) return null;

  // If the serverAddress doesn't start with HTTP, modify it
  if (!serverAddress.startsWith("http")) {
    // If it''s an ngrok address, use HTTPS, otherwise, just use HTTP
    if (serverAddress.contains("ngrok.io")) {
      serverAddress = "https://$serverAddress";
    } else {
      serverAddress = "http://$serverAddress";
    }
  }

  return serverAddress;
}

Future<String> getDeviceName() async {
  String deviceName = "android-client";

  try {
    // Load device info
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    // Gather device info
    List<String> items = [androidInfo?.brand ?? androidInfo?.manufacturer, androidInfo?.model, androidInfo?.androidId]
        .where((element) => element != null)
        .toList();

    // Set device name
    if (items.length > 0) {
      deviceName = items.join("_").toLowerCase();
    }
  } catch (ex) {
    debugPrint("Failed to get device name! Defaulting to 'android-client'");
    debugPrint(ex.toString());
  }

  // Fallback for if it happens to be empty or null, somehow... idk
  if (isNullOrEmpty((deviceName ?? "").trim())) {
    deviceName = "android-client";
  }

  return deviceName;
}

String getFilenameFromUrl(String url) {
  if (isNullOrEmpty(url)) return null;

  // Return everything after the last slash
  if (url.contains("/")) {
    String end = url.split("/").last;
    return end.split("?")[0];
  }

  // If there are no slashes, it's probably an invalid URL, so let's just ignore it
  return null;
}

Future<File> saveImageFromUrl(String guid, String url) async {
  // Make sure the URL is "formed"
  if (!url.contains("/")) return null;

  // Get the filename from the URL
  String filename = getFilenameFromUrl(url);
  if (filename == null) return null;

  try {
    var response = await get(Uri.parse(url));

    Directory baseDir = new Directory("${AttachmentHelper.getBaseAttachmentsPath()}/$guid");
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }

    String newPath = "${baseDir.path}/$filename";
    File file = new File(newPath);
    file.writeAsBytesSync(response.bodyBytes);

    return file;
  } catch (ex) {
    return null;
  }
}

Icon getIndicatorIcon(SocketState socketState, {double size = 24}) {
  Icon icon;

  if (SettingsManager().settings.colorblindMode) {
    if (socketState == SocketState.CONNECTING) {
      icon = Icon(Icons.cloud_upload, color: HexColor('ffd500').withAlpha(200), size: size);
    } else if (socketState == SocketState.CONNECTED) {
      icon = Icon(Icons.cloud_done, color: HexColor('32CD32').withAlpha(200), size: size);
    } else {
      icon = Icon(Icons.cloud_off, color: HexColor('DC143C').withAlpha(200), size: size);
    }
  } else {
    if (socketState == SocketState.CONNECTING) {
      icon = Icon(Icons.fiber_manual_record, color: HexColor('ffd500').withAlpha(200), size: size);
    } else if (socketState == SocketState.CONNECTED) {
      icon = Icon(Icons.fiber_manual_record, color: HexColor('32CD32').withAlpha(200), size: size);
    } else {
      icon = Icon(Icons.fiber_manual_record, color: HexColor('DC143C').withAlpha(200), size: size);
    }
  }

  return icon;
}

FCMData parseFcmJson(Map<String, dynamic> fcmMeta) {
  String clientId = fcmMeta["client"][0]["oauth_client"][0]["client_id"];
  return FCMData(
    projectID: fcmMeta["project_info"]["project_id"],
    storageBucket: fcmMeta["project_info"]["storage_bucket"],
    apiKey: fcmMeta["client"][0]["api_key"][0]["current_key"],
    firebaseURL: fcmMeta["project_info"]["firebase_url"],
    clientID: clientId,
    applicationID: clientId.substring(0, clientId.indexOf("-")),
  );
}

String encodeUri(String uri) {
  return Uri.encodeFull(uri)
      .replaceAll('-', '%2D')
      .replaceAll('_', '%5F')
      .replaceAll('.', '%2E')
      .replaceAll('!', '%21')
      .replaceAll('~', '%7E')
      .replaceAll('*', '%2A')
      .replaceAll('\'', '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29');
}

Future<PlayerStatus> getControllerStatus(VideoPlayerController controller) async {
  if (controller == null) return PlayerStatus.NONE;

  Duration currentPos = controller.value.position;
  if (controller.value.duration == currentPos) {
    return PlayerStatus.ENDED;
  } else if (!controller.value.isPlaying && currentPos.inMilliseconds == 0) {
    return PlayerStatus.STOPPED;
  } else if (!controller.value.isPlaying && currentPos.inMilliseconds != 0) {
    return PlayerStatus.PAUSED;
  } else if (controller.value.isPlaying) {
    return PlayerStatus.PLAYING;
  }

  return PlayerStatus.NONE;
}
