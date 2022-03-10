import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:async_task/async_task.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/country_codes.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' show get;
import 'package:intl/intl.dart' as intl;
import 'package:libphonenumber_plugin/libphonenumber_plugin.dart';
import 'package:slugify/slugify.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is DateTime) return value;
  return null;
}

bool? isNullOrEmpty(dynamic input, {trimString = false}) {
  if (input == null) return true;
  if (input is String) {
    input = input.trim();
  }

  return GetUtils.isNullOrBlank(input);
}

bool isNullOrZero(int? input) {
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

Future<String> formatPhoneNumber(dynamic item) async {
  String countryCode = SettingsManager().countryCode ?? "US";
  String? address;

  // Set the address/country accordingly
  if (item is String?) {
    address = item;
  } else if (item is Handle?) {
    address = item?.address;
    countryCode = item?.country ?? countryCode;
  } else if (item is UniqueContact?) {
    address = item?.address;
  } else {
    return item.toString();
  }

  // If we don't have a valid address, or it's an email, return it
  if (address == null || address.isEmail) return address ?? "Unknown";
  address = address.trim(); // Trim it just in case

  String? meta;

  try {
    meta = await PhoneNumberUtil.formatAsYouType(address, countryCode);
  } catch (ex) {
    CountryCode? cc = getCountryCodes().firstWhereOrNull((e) => e.code == countryCode);
    if (!address.startsWith("+") && cc != null) {
      try {
        meta = await PhoneNumberUtil.formatAsYouType("${cc.dialCode}$address", countryCode);
      } catch (_) {}
    }
  }

  return meta ?? address;
}

Future<List<String>> getCompareOpts(Handle handle) async {
  if (handle.address.isEmail) return [handle.address];

  // Build a list of formatted address (max: 3)
  String formatted = handle.address.toString();
  List<String> opts = [];
  int maxOpts = 4; // This is relatively arbitrary
  for (int i = 0; i < formatted.length; i += 1) {
    String val = formatted.substring(i);
    if (val.isEmpty) break;

    opts.add(val);
    if (i + 1 >= maxOpts) break;
  }

  String? parsed = await parsePhoneNumber(handle.address, handle.country ?? "US");
  if (parsed != null) opts.add(parsed);
  return opts;
}

bool sameAddress(List<String?> options, String? compared) {
  bool match = false;
  if (compared == null) return match;
  for (String? opt in options) {
    if (isNullOrEmpty(opt)!) continue;
    if (opt == compared) {
      match = true;
      break;
    } else if (compared.endsWith(opt!) && opt.length >= 9) {
      match = true;
      break;
    } else if (opt.endsWith(compared) && compared.length >= 9) {
      match = true;
      break;
    }

    if (opt.isEmail && !compared.isEmail) continue;

    String formatted = slugify(compared, delimiter: '').toString().replaceAll('-', '');
    if (opt.endsWith(formatted) || formatted.endsWith(opt)) {
      match = true;
      break;
    }
  }

  return match;
}

String? getInitials(Contact contact) {
  // Set default initials
  String initials = (contact.structuredName?.givenName.isNotEmpty == true ? contact.structuredName!.givenName[0] : "") +
      (contact.structuredName?.familyName.isNotEmpty == true ? contact.structuredName!.familyName[0] : "");

  // If the initials are empty, get them from the display name
  if (initials.trim().isEmpty && contact.displayName.isNotEmpty) {
    initials = contact.displayName[0];
  }

  return initials.isEmpty ? null : initials.toUpperCase();
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

Future<String?> parsePhoneNumber(String number, String region) async {
  try {
    if (kIsWeb) {
      return await PhoneNumberUtil.normalizePhoneNumber(number, region);
    } else {
      return FlutterLibphonenumber().formatNumberSync(number);
    }
  } catch (ex) {
    return null;
  }
}

String randomString(int length) {
  var rand = Random();
  var codeUnits = List.generate(length, (index) {
    return rand.nextInt(33) + 89;
  });

  return String.fromCharCodes(codeUnits);
}

void showSnackbar(String title, String message,
    {int animationMs = 250, int durationMs = 1500, Function(GetBar)? onTap, TextButton? button}) {
  Get.snackbar(title, message,
      snackPosition: SnackPosition.BOTTOM,
      colorText: Get.textTheme.bodyText1!.color,
      backgroundColor: Get.theme.colorScheme.secondary,
      margin: EdgeInsets.only(bottom: 10),
      maxWidth: Get.width - 20,
      isDismissible: false,
      duration: Duration(milliseconds: durationMs),
      animationDuration: Duration(milliseconds: animationMs),
      mainButton: button,
      onTap: onTap ??
          (GetBar bar) {
            if (Get.isSnackbarOpen ?? false) Get.back();
          });
}

bool sameSender(Message? first, Message? second) {
  return (first != null &&
      second != null &&
      (first.isFromMe! && second.isFromMe! ||
          (!first.isFromMe! &&
              !second.isFromMe! &&
              (first.handle != null && second.handle != null && first.handle!.address == second.handle!.address))));
}

String buildDate(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = SettingsManager().settings.use24HrFormat.value
      ? intl.DateFormat.Hm().format(dateTime)
      : intl.DateFormat.jm().format(dateTime);
  String date;
  if (dateTime.isToday()) {
    date = time;
  } else if (dateTime.isYesterday()) {
    date = "Yesterday";
  } else if (DateTime.now().difference(dateTime.toLocal()).inDays <= 7) {
    date = intl.DateFormat("EEEE").format(dateTime);
  } else {
    date = intl.DateFormat.yMd().format(dateTime);
  }
  return date;
}

String buildSeparatorDateSamsung(DateTime dateTime) {
  return intl.DateFormat.yMMMMEEEEd().format(dateTime);
}

String buildTime(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = SettingsManager().settings.use24HrFormat.value
      ? intl.DateFormat.Hm().format(dateTime)
      : intl.DateFormat.jm().format(dateTime);
  return time;
}

String buildFullDate(DateTime time) {
  return intl.DateFormat.yMd().add_jm().format(time);
}

extension DateHelpers on DateTime {
  bool isTomorrow({DateTime? otherDate}) {
    final now = otherDate?.add(Duration(days: 1)) ?? DateTime.now().add(Duration(days: 1));
    return now.day == day &&
        now.month == month &&
        now.year == year;
  }

  bool isToday() {
    final now = DateTime.now();
    return now.day == day && now.month == month && now.year == year;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
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

String sanitizeString(String? input) {
  if (input == null) return "";
  input = input.replaceAll(String.fromCharCode(65532), '');
  return input;
}

bool isEmptyString(String? input, {stripWhitespace = false}) {
  if (input == null) return true;
  input = sanitizeString(input);
  if (stripWhitespace) {
    input = input.trim();
  }

  return input.isEmpty;
}

bool isParticipantEvent(Message message) {
  if (message.itemType == 1 && [0, 1].contains(message.groupActionType)) return true;
  if ([2, 3].contains(message.itemType)) return true;
  return false;
}

String uriToFilename(String? uri, String? mimeType) {
  // Handle any unknown cases
  String? ext = mimeType != null ? mimeType.split('/')[1] : null;
  ext = (ext != null && ext.contains('+')) ? ext.split('+')[0] : ext;
  if (uri == null) return (ext != null) ? 'unknown.$ext' : 'unknown';

  // Get the filename
  String filename = uri;
  if (filename.contains('/')) {
    filename = filename.split('/').last;
  }

  // Get the extension
  if (filename.contains('.')) {
    List<String> split = filename.split('.');
    ext = split[1];
    filename = split[0];
  }

  // Slugify the filename
  filename = slugify(filename, delimiter: '_');

  // Rebuild the filename
  return (ext != null && ext.isNotEmpty) ? '$filename.$ext' : filename;
}

String getGroupEventText(Message message) {
  String text = "Unknown group event";
  String? handle = "You";
  if (!message.isFromMe! && message.handleId != null && message.handle != null) {
    handle = ContactManager().getContactTitle(message.handle);
  }

  String? other = "someone";
  if (message.otherHandle != null && [1, 2].contains(message.itemType)) {
    Handle? item = Handle.findOne(originalROWID: message.otherHandle);
    if (item != null) {
      other = ContactManager().getContactTitle(item);
    }
  }

  final bool hideNames =
      SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
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
  } else if (message.itemType == 6) {
    text = "$handle started a FaceTime call";
  }

  return text;
}

List<RegExpMatch> parseLinks(String text) {
  return urlRegex.allMatches(text).toList();
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

String stripHtmlTags(String? htmlString) {
  final document = parse(htmlString);
  final String parsedString = parse(document.body!.text).documentElement!.text;

  return parsedString;
}

// int _getInt(str) {
//   var hash = 5381;

//   for (var i = 0; i < str.length; i++) {
//     hash = ((hash << 4) + hash) + str.codeUnitAt(i);
//   }

//   return hash;
// }

List<Color> toColorGradient(String? str) {
  if (isNullOrEmpty(str)!) return [HexColor("686868"), HexColor("928E8E")];

  int total = 0;
  for (int i = 0; i < (str ?? "").length; i++) {
    total += str!.codeUnitAt(i);
  }

  Random random = Random(total);
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

  Logger.debug("GIF width: $width");
  Logger.debug("GIF height: $height");
  Size size = Size(width.toDouble(), height.toDouble());
  return size;
}

SystemUiOverlayStyle getBrightness(BuildContext context) {
  return AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

/// Take the passed [address] or serverAddress from Settings
/// and sanitize it, making sure it includes an http schema
String? getServerAddress({String? address}) {
  String serverAddress = address ?? SettingsManager().settings.serverAddress.value;

  String sanitized = serverAddress.replaceAll("https://", "").replaceAll("http://", "").trim();
  if (sanitized.isEmpty) return null;

  Uri? uri = Uri.tryParse(serverAddress);
  if (uri?.scheme.isEmpty ?? true) {
    if (serverAddress.contains("ngrok.io")) {
      serverAddress = "https://$serverAddress";
    } else {
      serverAddress = "http://$serverAddress";
    }
  }

  return serverAddress;
}

Future<String> getDeviceName() async {
  String deviceName = "bluebubbles-client";

  try {
    // Load device info
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    // Gather device info
    List<String> items = [];

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      items.addAll([androidInfo.brand!, androidInfo.model!, androidInfo.androidId!]);
    } else if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      items.addAll([describeEnum(webInfo.browserName), webInfo.platform!]);
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      items.addAll([windowsInfo.computerName]);
    } else if (Platform.isLinux) {
      LinuxDeviceInfo windowsInfo = await deviceInfo.linuxInfo;
      items.addAll([windowsInfo.prettyName]);
    }

    // Set device name
    if (items.isNotEmpty) {
      deviceName = items.join("_").toLowerCase();
    }
  } catch (ex) {
    Logger.error("Failed to get device name! Defaulting to 'bluebubbles-client'");
    Logger.error(ex.toString());
  }

  // Fallback for if it happens to be empty or null, somehow... idk
  if (isNullOrEmpty(deviceName.trim())!) {
    deviceName = "bluebubbles-client";
  }

  return deviceName;
}

/// Contextless way to get device width
double getDeviceWidth() {
  double pixelRatio = window.devicePixelRatio;

  //Size in logical pixels
  Size logicalScreenSize = window.physicalSize / pixelRatio;
  return logicalScreenSize.width;
}

String? getFilenameFromUri(String url) {
  if (isNullOrEmpty(url)!) return null;

  // Return everything after the last slash
  if (url.contains("/")) {
    String end = url.split("/").last;
    return end.split("?")[0];
  }

  // If there are no slashes, it's probably an invalid URL, so let's just ignore it
  return null;
}

Future<File?> saveImageFromUrl(String guid, String url) async {
  // Make sure the URL is "formed"
  if (kIsWeb || !url.contains("/")) return null;

  // Get the filename from the URL
  String? filename = getFilenameFromUri(url);
  if (filename == null) return null;

  try {
    var response = await get(Uri.parse(url));

    Directory baseDir = Directory("${AttachmentHelper.getBaseAttachmentsPath()}/$guid");
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }

    String newPath = "${baseDir.path}/$filename";
    File file = File(newPath);
    file.writeAsBytesSync(response.bodyBytes);

    return file;
  } catch (ex) {
    return null;
  }
}

Widget getIndicatorIcon(SocketState socketState, {double size = 24, bool showAlpha = true}) {
  return Obx(() {
    if (SettingsManager().settings.colorblindMode.value) {
      if (socketState == SocketState.CONNECTING) {
        return Icon(Icons.cloud_upload, color: HexColor('ffd500').withAlpha(showAlpha ? 200 : 255), size: size);
      } else if (socketState == SocketState.CONNECTED) {
        return Icon(Icons.cloud_done, color: HexColor('32CD32').withAlpha(showAlpha ? 200 : 255), size: size);
      } else {
        return Icon(Icons.cloud_off, color: HexColor('DC143C').withAlpha(showAlpha ? 200 : 255), size: size);
      }
    } else {
      if (socketState == SocketState.CONNECTING) {
        return Icon(Icons.fiber_manual_record, color: HexColor('ffd500').withAlpha(showAlpha ? 200 : 255), size: size);
      } else if (socketState == SocketState.CONNECTED) {
        return Icon(Icons.fiber_manual_record, color: HexColor('32CD32').withAlpha(showAlpha ? 200 : 255), size: size);
      } else {
        return Icon(Icons.fiber_manual_record, color: HexColor('DC143C').withAlpha(showAlpha ? 200 : 255), size: size);
      }
    }
  });
}

Color getIndicatorColor(SocketState socketState) {
  if (socketState == SocketState.CONNECTING) {
    return HexColor('ffd500');
  } else if (socketState == SocketState.CONNECTED) {
    return HexColor('32CD32');
  } else {
    return HexColor('DC143C');
  }
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

/// Helps prevent "setState cannot be called while the widget tree is building"
/// error by checking if setState can actually be called
Future<bool> rebuild(State s) async {
  if (!s.mounted) return false;

  // if there's a current frame,
  if (SchedulerBinding.instance!.schedulerPhase != SchedulerPhase.idle) {
    // wait for the end of that frame.
    await SchedulerBinding.instance!.endOfFrame;
    if (!s.mounted) return false;
  }

  // ignore protected member use error - that's the whole point of this function
  //ignore:, invalid_use_of_protected_member
  s.setState(() {});
  return true;
}

/// Create a "fake" asynchronous task from a traditionally synchronous task
///
/// Used for heavy ObjectBox read/writes to avoid causing jank
Future<T?> createAsyncTask<T>(AsyncTask<List<dynamic>, T> task) async {
  final executor = AsyncExecutor(parallelism: 0, taskTypeRegister: () => [task]);
  executor.logger.enabled = true;
  executor.logger.enabledExecution = true;
  await executor.execute(task);
  return task.result;
}

extension PlatformSpecificCapitalize on String {
  String get psCapitalize {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      return toUpperCase();
    } else {
      return this;
    }
  }
}

extension LastChars on String {
  String lastChars(int n) => substring(length - n);
}

extension IsEmoji on String {
  bool get hasEmoji {
    RegExp darkSunglasses = RegExp('\u{1F576}');
    return RegExp("${emojiRegex.pattern}|${darkSunglasses.pattern}").hasMatch(this);
  }
}

extension WidgetLocation on GlobalKey {
  Rect? globalPaintBounds(BuildContext context) {
    double difference = context.width - CustomNavigator.width(context);
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

/// this extensions allows us to update an RxMap without re-rendering UI
/// (to avoid getting the markNeedsBuild exception)
extension ConditionlAdd on RxMap {
  void conditionalAdd(Object? key, Object? value, bool shouldRefresh) {
    // ignore this warning, for some reason value is a protected member
    // ignore: invalid_use_of_protected_member
    this.value[key] = value;
    if (shouldRefresh) refresh();
  }
}

bool get kIsDesktop => (Platform.isWindows || Platform.isLinux || Platform.isMacOS) && !kIsWeb;
