import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' show get;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart' as intl;
import 'package:libphonenumber_plugin/libphonenumber_plugin.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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

List<String> getUniqueNumbers(Iterable<String> numbers) {
  List<String> phones = [];
  for (String phone in numbers) {
    bool exists = false;
    for (String current in phones) {
      if (cleansePhoneNumber(phone) == cleansePhoneNumber(current)) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      phones.add(phone);
    }
  }

  return phones;
}

List<String> getUniqueEmails(Iterable<String> list) {
  List<String> emails = [];
  for (String email in list) {
    bool exists = false;
    for (String current in emails) {
      if (email.trim() == current.trim()) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      emails.add(email);
    }
  }

  return emails;
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

String randomString(int length) =>
    String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(Random().nextInt(_chars.length))));

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
    return now.day == day && now.month == month && now.year == year;
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
  return AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
}

/// Take the passed [address] or serverAddress from Settings
/// and sanitize it, making sure it includes an http schema
String? sanitizeServerAddress({String? address}) {
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
  double pixelRatio = ui.window.devicePixelRatio;

  //Size in logical pixels
  Size logicalScreenSize = ui.window.physicalSize / pixelRatio;
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

Future<Uint8List> avatarAsBytes({
  required String chatGuid,
  required bool isGroup,
  required Handle? handle,
  List<Handle>? participants,
  double quality = 256,
}) async {
  ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  Canvas canvas = Canvas(pictureRecorder);

  await paintGroupAvatar(chatGuid: chatGuid, participants: participants, canvas: canvas, size: quality);

  ui.Picture picture = pictureRecorder.endRecording();
  ui.Image image = await picture.toImage(quality.toInt(), quality.toInt());

  Uint8List bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

  return bytes;
}

Future<void> paintGroupAvatar({
  required String chatGuid,
  required List<Handle>? participants,
  required Canvas canvas,
  required double size,
}) async {
  String customPath = join((await getApplicationSupportDirectory()).path, "avatars",
      chatGuid.characters.where((c) => c.isAlphabetOnly || c.isNum).join(), "avatar.jpg");

  if (File(customPath).existsSync()) {
    Uint8List? customAvatar = await circularize(File(customPath).readAsBytesSync(), size: size.toInt());
    if (customAvatar != null) {
      canvas.drawImage(await loadImage(customAvatar), Offset(0, 0), Paint());
      return;
    }
  }

  if (participants == null) return;
  int maxAvatars = SettingsManager().settings.maxAvatarsInGroupWidget.value;

  if (participants.length == 1) {
    await paintAvatar(
      chatGuid: chatGuid,
      handle: participants.first,
      canvas: canvas,
      offset: Offset(0, 0),
      size: size,
    );
    return;
  }

  Paint paint = Paint()..color = (Get.context?.theme.colorScheme.secondary ?? HexColor("928E8E")).withOpacity(0.6);
  canvas.drawCircle(Offset(size * 0.5, size * 0.5), size * 0.5, paint);

  int realAvatarCount = min(participants.length, maxAvatars);

  for (int index = 0; index < realAvatarCount; index++) {
    double padding = size * 0.08;
    double angle = index / realAvatarCount * 2 * pi + pi * 0.25;
    double adjustedWidth = size * (-0.07 * realAvatarCount + 1);
    double innerRadius = size - adjustedWidth * 0.5 - 2 * padding;
    double realSize = adjustedWidth * 0.65;
    double top = size * 0.5 + (innerRadius * 0.5) * sin(angle + pi) - realSize * 0.5;
    double left = size * 0.5 - (innerRadius * 0.5) * cos(angle + pi) - realSize * 0.5;

    if (index == maxAvatars - 1 && participants.length > maxAvatars) {
      Paint paint = Paint();
      paint.isAntiAlias = true;
      paint.color = Get.context?.theme.colorScheme.secondary.withOpacity(0.8) ?? HexColor("686868").withOpacity(0.8);
      canvas.drawCircle(Offset(left + realSize * 0.5, top + realSize * 0.5), realSize * 0.5, paint);

      IconData icon = Icons.people;

      TextPainter()
        ..textDirection = TextDirection.rtl
        ..textAlign = TextAlign.center
        ..text = TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
                fontSize: adjustedWidth * 0.3,
                fontFamily: icon.fontFamily,
                color: Get.context?.textTheme.subtitle1!.color!.withOpacity(0.8)))
        ..layout()
        ..paint(canvas, Offset(left + realSize * 0.25, top + realSize * 0.25));
    } else {
      Paint paint = Paint()
        ..color = (SettingsManager().settings.skin.value == Skins.Samsung
                ? Get.context?.theme.colorScheme.secondary
                : Get.context?.theme.backgroundColor) ??
            HexColor("928E8E");
      canvas.drawCircle(Offset(left + realSize * 0.5, top + realSize * 0.5), realSize * 0.5, paint);
      await paintAvatar(
        chatGuid: chatGuid,
        handle: participants[index],
        canvas: canvas,
        offset: Offset(left + realSize * 0.01, top + realSize * 0.01),
        size: realSize * 0.99,
        borderWidth: size * 0.01,
        fontSize: adjustedWidth * 0.3,
      );
    }
  }
}

Future<void> paintAvatar(
    {required String chatGuid,
    required Handle? handle,
    required Canvas canvas,
    required Offset offset,
    required double size,
    double? fontSize,
    double? borderWidth}) async {
  fontSize ??= size * 0.5;
  borderWidth ??= size * 0.05;

  String customPath = join((await getApplicationSupportDirectory()).path, "avatars",
      chatGuid.characters.where((c) => c.isAlphabetOnly || c.isNum).join(), "avatar.jpg");

  if (File(customPath).existsSync()) {
    Uint8List? customAvatar = await circularize(File(customPath).readAsBytesSync(), size: size.toInt());
    if (customAvatar != null) {
      canvas.drawImage(await loadImage(customAvatar), offset, Paint());
      return;
    }
  } else {
    Contact? contact = ContactManager().getContact(handle?.address);
    if (contact?.hasAvatar ?? false) {
      Uint8List? contactAvatar =
          await circularize(contact!.avatarHiRes.value ?? contact.avatar.value!, size: size.toInt());
      if (contactAvatar != null) {
        canvas.drawImage(await loadImage(contactAvatar), offset, Paint());
        return;
      }
    }
  }

  List<Color> colors;
  if (handle?.color == null) {
    colors = toColorGradient(handle?.address);
  } else {
    colors = [
      HexColor(handle!.color!).lightenAmount(0.02),
      HexColor(handle.color!),
    ];
  }

  double dx = offset.dx;
  double dy = offset.dy;

  Paint paint = Paint();
  paint.isAntiAlias = true;
  paint.shader =
      ui.Gradient.linear(Offset(dx + size * 0.5, dy + size * 0.5), Offset(size.toDouble(), size.toDouble()), [
    !SettingsManager().settings.colorfulAvatars.value
        ? HexColor("928E8E")
        : colors.isNotEmpty
            ? colors[1]
            : HexColor("928E8E"),
    !SettingsManager().settings.colorfulAvatars.value
        ? HexColor("686868")
        : colors.isNotEmpty
            ? colors[0]
            : HexColor("686868"),
  ]);

  canvas.drawCircle(Offset(dx + size * 0.5, dy + size * 0.5), size * 0.5, paint);

  String? initials = ContactManager().getContactInitials(handle);

  if (initials == null) {
    IconData icon = Icons.person;

    TextPainter()
      ..textDirection = TextDirection.rtl
      ..textAlign = TextAlign.center
      ..text = TextSpan(
          text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: fontSize, fontFamily: icon.fontFamily))
      ..layout()
      ..paint(canvas, Offset(dx + size * 0.25, dy + size * 0.25));
  } else {
    TextPainter text = TextPainter()
      ..textDirection = TextDirection.ltr
      ..textAlign = TextAlign.center
      ..text = TextSpan(
        text: initials,
        style: TextStyle(fontSize: fontSize),
      )
      ..layout();

    text.paint(canvas, Offset(dx + (size - text.width) * 0.5, dy + (size - text.height) * 0.5));
  }
}

Future<Uint8List?> circularize(Uint8List data, {required int size}) async {
  ui.Image image;
  Uint8List _data = data;

  // Resize the image if it's the wrong size
  img.Image? _image = img.decodeImage(data);
  if (_image != null) {
    _image = img.copyResize(_image, width: size, height: size);

    _data = img.encodePng(_image) as Uint8List;
  }

  image = await loadImage(_data);

  ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  Canvas canvas = Canvas(pictureRecorder);
  Paint paint = Paint();
  paint.isAntiAlias = true;

  Path path = Path()..addOval(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

  canvas.clipPath(path);

  canvas.drawImage(image, Offset(0, 0), paint);

  ui.Picture picture = pictureRecorder.endRecording();
  image = await picture.toImage(image.width, image.height);

  Uint8List? bytes = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();

  return bytes;
}

Future<ui.Image> loadImage(Uint8List data) async {
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(data, (ui.Image image) {
    return completer.complete(image);
  });
  return completer.future;
}

final RegExp emojiRegex = RegExp(r"[#*0-9]\uFE0F?\u20E3|[\xA9\xAE\u203C\u2049\u2122\u2139\u2194-\u2199\u21A9\u21AA\u231A\u231B\u2328\u23CF\u23ED-\u23EF\u23F1\u23F2\u23F8-\u23FA\u24C2\u25AA\u25AB\u25B6\u25C0\u25FB\u25FC\u25FE\u2600-\u2604\u260E\u2611\u2614\u2615\u2618\u2620\u2622\u2623\u2626\u262A\u262E\u262F\u2638-\u263A\u2640\u2642\u2648-\u2653\u265F\u2660\u2663\u2665\u2666\u2668\u267B\u267E\u267F\u2692\u2694-\u2697\u2699\u269B\u269C\u26A0\u26A7\u26AA\u26B0\u26B1\u26BD\u26BE\u26C4\u26C8\u26CF\u26D1\u26D3\u26E9\u26F0-\u26F5\u26F7\u26F8\u26FA\u2702\u2708\u2709\u270F\u2712\u2714\u2716\u271D\u2721\u2733\u2734\u2744\u2747\u2757\u2763\u27A1\u2934\u2935\u2B05-\u2B07\u2B1B\u2B1C\u2B55\u3030\u303D\u3297\u3299]\uFE0F?|[\u261D\u270C\u270D](?:\uFE0F|\uD83C[\uDFFB-\uDFFF])?|[\u270A\u270B](?:\uD83C[\uDFFB-\uDFFF])?|[\u23E9-\u23EC\u23F0\u23F3\u25FD\u2693\u26A1\u26AB\u26C5\u26CE\u26D4\u26EA\u26FD\u2705\u2728\u274C\u274E\u2753-\u2755\u2795-\u2797\u27B0\u27BF\u2B50]|\u26F9(?:\uFE0F|\uD83C[\uDFFB-\uDFFF])?(?:\u200D[\u2640\u2642]\uFE0F?)?|\u2764\uFE0F?(?:\u200D(?:\uD83D\uDD25|\uD83E\uDE79))?|\uD83C(?:[\uDC04\uDD70\uDD71\uDD7E\uDD7F\uDE02\uDE37\uDF21\uDF24-\uDF2C\uDF36\uDF7D\uDF96\uDF97\uDF99-\uDF9B\uDF9E\uDF9F\uDFCD\uDFCE\uDFD4-\uDFDF\uDFF5\uDFF7]\uFE0F?|[\uDF85\uDFC2\uDFC7](?:\uD83C[\uDFFB-\uDFFF])?|[\uDFC3\uDFC4\uDFCA](?:\uD83C[\uDFFB-\uDFFF])?(?:\u200D[\u2640\u2642]\uFE0F?)?|[\uDFCB\uDFCC](?:\uFE0F|\uD83C[\uDFFB-\uDFFF])?(?:\u200D[\u2640\u2642]\uFE0F?)?|[\uDCCF\uDD8E\uDD91-\uDD9A\uDE01\uDE1A\uDE2F\uDE32-\uDE36\uDE38-\uDE3A\uDE50\uDE51\uDF00-\uDF20\uDF2D-\uDF35\uDF37-\uDF7C\uDF7E-\uDF84\uDF86-\uDF93\uDFA0-\uDFC1\uDFC5\uDFC6\uDFC8\uDFC9\uDFCF-\uDFD3\uDFE0-\uDFF0\uDFF8-\uDFFF]|\uDDE6\uD83C[\uDDE8-\uDDEC\uDDEE\uDDF1\uDDF2\uDDF4\uDDF6-\uDDFA\uDDFC\uDDFD\uDDFF]|\uDDE7\uD83C[\uDDE6\uDDE7\uDDE9-\uDDEF\uDDF1-\uDDF4\uDDF6-\uDDF9\uDDFB\uDDFC\uDDFE\uDDFF]|\uDDE8\uD83C[\uDDE6\uDDE8\uDDE9\uDDEB-\uDDEE\uDDF0-\uDDF5\uDDF7\uDDFA-\uDDFF]|\uDDE9\uD83C[\uDDEA\uDDEC\uDDEF\uDDF0\uDDF2\uDDF4\uDDFF]|\uDDEA\uD83C[\uDDE6\uDDE8\uDDEA\uDDEC\uDDED\uDDF7-\uDDFA]|\uDDEB\uD83C[\uDDEE-\uDDF0\uDDF2\uDDF4\uDDF7]|\uDDEC\uD83C[\uDDE6\uDDE7\uDDE9-\uDDEE\uDDF1-\uDDF3\uDDF5-\uDDFA\uDDFC\uDDFE]|\uDDED\uD83C[\uDDF0\uDDF2\uDDF3\uDDF7\uDDF9\uDDFA]|\uDDEE\uD83C[\uDDE8-\uDDEA\uDDF1-\uDDF4\uDDF6-\uDDF9]|\uDDEF\uD83C[\uDDEA\uDDF2\uDDF4\uDDF5]|\uDDF0\uD83C[\uDDEA\uDDEC-\uDDEE\uDDF2\uDDF3\uDDF5\uDDF7\uDDFC\uDDFE\uDDFF]|\uDDF1\uD83C[\uDDE6-\uDDE8\uDDEE\uDDF0\uDDF7-\uDDFB\uDDFE]|\uDDF2\uD83C[\uDDE6\uDDE8-\uDDED\uDDF0-\uDDFF]|\uDDF3\uD83C[\uDDE6\uDDE8\uDDEA-\uDDEC\uDDEE\uDDF1\uDDF4\uDDF5\uDDF7\uDDFA\uDDFF]|\uDDF4\uD83C\uDDF2|\uDDF5\uD83C[\uDDE6\uDDEA-\uDDED\uDDF0-\uDDF3\uDDF7-\uDDF9\uDDFC\uDDFE]|\uDDF6\uD83C\uDDE6|\uDDF7\uD83C[\uDDEA\uDDF4\uDDF8\uDDFA\uDDFC]|\uDDF8\uD83C[\uDDE6-\uDDEA\uDDEC-\uDDF4\uDDF7-\uDDF9\uDDFB\uDDFD-\uDDFF]|\uDDF9\uD83C[\uDDE6\uDDE8\uDDE9\uDDEB-\uDDED\uDDEF-\uDDF4\uDDF7\uDDF9\uDDFB\uDDFC\uDDFF]|\uDDFA\uD83C[\uDDE6\uDDEC\uDDF2\uDDF3\uDDF8\uDDFE\uDDFF]|\uDDFB\uD83C[\uDDE6\uDDE8\uDDEA\uDDEC\uDDEE\uDDF3\uDDFA]|\uDDFC\uD83C[\uDDEB\uDDF8]|\uDDFD\uD83C\uDDF0|\uDDFE\uD83C[\uDDEA\uDDF9]|\uDDFF\uD83C[\uDDE6\uDDF2\uDDFC]|\uDFF3\uFE0F?(?:\u200D(?:\u26A7\uFE0F?|\uD83C\uDF08))?|\uDFF4(?:\u200D\u2620\uFE0F?|\uDB40\uDC67\uDB40\uDC62\uDB40(?:\uDC65\uDB40\uDC6E\uDB40\uDC67|\uDC73\uDB40\uDC63\uDB40\uDC74|\uDC77\uDB40\uDC6C\uDB40\uDC73)\uDB40\uDC7F)?)|\uD83D(?:[\uDC3F\uDCFD\uDD49\uDD4A\uDD6F\uDD70\uDD73\uDD76-\uDD79\uDD87\uDD8A-\uDD8D\uDDA5\uDDA8\uDDB1\uDDB2\uDDBC\uDDC2-\uDDC4\uDDD1-\uDDD3\uDDDC-\uDDDE\uDDE1\uDDE3\uDDE8\uDDEF\uDDF3\uDDFA\uDECB\uDECD-\uDECF\uDEE0-\uDEE5\uDEE9\uDEF0\uDEF3]\uFE0F?|[\uDC42\uDC43\uDC46-\uDC50\uDC66\uDC67\uDC6B-\uDC6D\uDC72\uDC74-\uDC76\uDC78\uDC7C\uDC83\uDC85\uDC8F\uDC91\uDCAA\uDD7A\uDD95\uDD96\uDE4C\uDE4F\uDEC0\uDECC](?:\uD83C[\uDFFB-\uDFFF])?|[\uDC6E\uDC70\uDC71\uDC73\uDC77\uDC81\uDC82\uDC86\uDC87\uDE45-\uDE47\uDE4B\uDE4D\uDE4E\uDEA3\uDEB4-\uDEB6](?:\uD83C[\uDFFB-\uDFFF])?(?:\u200D[\u2640\u2642]\uFE0F?)?|[\uDD74\uDD90](?:\uFE0F|\uD83C[\uDFFB-\uDFFF])?|[\uDC00-\uDC07\uDC09-\uDC14\uDC16-\uDC3A\uDC3C-\uDC3E\uDC40\uDC44\uDC45\uDC51-\uDC65\uDC6A\uDC79-\uDC7B\uDC7D-\uDC80\uDC84\uDC88-\uDC8E\uDC90\uDC92-\uDCA9\uDCAB-\uDCFC\uDCFF-\uDD3D\uDD4B-\uDD4E\uDD50-\uDD67\uDDA4\uDDFB-\uDE2D\uDE2F-\uDE34\uDE37-\uDE44\uDE48-\uDE4A\uDE80-\uDEA2\uDEA4-\uDEB3\uDEB7-\uDEBF\uDEC1-\uDEC5\uDED0-\uDED2\uDED5-\uDED7\uDEDD-\uDEDF\uDEEB\uDEEC\uDEF4-\uDEFC\uDFE0-\uDFEB\uDFF0]|\uDC08(?:\u200D\u2B1B)?|\uDC15(?:\u200D\uD83E\uDDBA)?|\uDC3B(?:\u200D\u2744\uFE0F?)?|\uDC41\uFE0F?(?:\u200D\uD83D\uDDE8\uFE0F?)?|\uDC68(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?\uDC68|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D(?:[\uDC68\uDC69]\u200D\uD83D(?:\uDC66(?:\u200D\uD83D\uDC66)?|\uDC67(?:\u200D\uD83D[\uDC66\uDC67])?)|[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uDC66(?:\u200D\uD83D\uDC66)?|\uDC67(?:\u200D\uD83D[\uDC66\uDC67])?)|\uD83E[\uDDAF-\uDDB3\uDDBC\uDDBD])|\uD83C(?:\uDFFB(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?\uDC68\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D\uDC68\uD83C[\uDFFC-\uDFFF])))?|\uDFFC(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?\uDC68\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D\uDC68\uD83C[\uDFFB\uDFFD-\uDFFF])))?|\uDFFD(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?\uDC68\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D\uDC68\uD83C[\uDFFB\uDFFC\uDFFE\uDFFF])))?|\uDFFE(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?\uDC68\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D\uDC68\uD83C[\uDFFB-\uDFFD\uDFFF])))?|\uDFFF(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?\uDC68\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D\uDC68\uD83C[\uDFFB-\uDFFE])))?))?|\uDC69(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:\uDC8B\u200D\uD83D)?[\uDC68\uDC69]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D(?:[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uDC66(?:\u200D\uD83D\uDC66)?|\uDC67(?:\u200D\uD83D[\uDC66\uDC67])?|\uDC69\u200D\uD83D(?:\uDC66(?:\u200D\uD83D\uDC66)?|\uDC67(?:\u200D\uD83D[\uDC66\uDC67])?))|\uD83E[\uDDAF-\uDDB3\uDDBC\uDDBD])|\uD83C(?:\uDFFB(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:[\uDC68\uDC69]|\uDC8B\u200D\uD83D[\uDC68\uDC69])\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D[\uDC68\uDC69]\uD83C[\uDFFC-\uDFFF])))?|\uDFFC(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:[\uDC68\uDC69]|\uDC8B\u200D\uD83D[\uDC68\uDC69])\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D[\uDC68\uDC69]\uD83C[\uDFFB\uDFFD-\uDFFF])))?|\uDFFD(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:[\uDC68\uDC69]|\uDC8B\u200D\uD83D[\uDC68\uDC69])\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D[\uDC68\uDC69]\uD83C[\uDFFB\uDFFC\uDFFE\uDFFF])))?|\uDFFE(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:[\uDC68\uDC69]|\uDC8B\u200D\uD83D[\uDC68\uDC69])\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D[\uDC68\uDC69]\uD83C[\uDFFB-\uDFFD\uDFFF])))?|\uDFFF(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D\uD83D(?:[\uDC68\uDC69]|\uDC8B\u200D\uD83D[\uDC68\uDC69])\uD83C[\uDFFB-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83D[\uDC68\uDC69]\uD83C[\uDFFB-\uDFFE])))?))?|\uDC6F(?:\u200D[\u2640\u2642]\uFE0F?)?|\uDD75(?:\uFE0F|\uD83C[\uDFFB-\uDFFF])?(?:\u200D[\u2640\u2642]\uFE0F?)?|\uDE2E(?:\u200D\uD83D\uDCA8)?|\uDE35(?:\u200D\uD83D\uDCAB)?|\uDE36(?:\u200D\uD83C\uDF2B\uFE0F?)?)|\uD83E(?:[\uDD0C\uDD0F\uDD18-\uDD1F\uDD30-\uDD34\uDD36\uDD77\uDDB5\uDDB6\uDDBB\uDDD2\uDDD3\uDDD5\uDEC3-\uDEC5\uDEF0\uDEF2-\uDEF6](?:\uD83C[\uDFFB-\uDFFF])?|[\uDD26\uDD35\uDD37-\uDD39\uDD3D\uDD3E\uDDB8\uDDB9\uDDCD-\uDDCF\uDDD4\uDDD6-\uDDDD](?:\uD83C[\uDFFB-\uDFFF])?(?:\u200D[\u2640\u2642]\uFE0F?)?|[\uDDDE\uDDDF](?:\u200D[\u2640\u2642]\uFE0F?)?|[\uDD0D\uDD0E\uDD10-\uDD17\uDD20-\uDD25\uDD27-\uDD2F\uDD3A\uDD3F-\uDD45\uDD47-\uDD76\uDD78-\uDDB4\uDDB7\uDDBA\uDDBC-\uDDCC\uDDD0\uDDE0-\uDDFF\uDE70-\uDE74\uDE78-\uDE7C\uDE80-\uDE86\uDE90-\uDEAC\uDEB0-\uDEBA\uDEC0-\uDEC2\uDED0-\uDED9\uDEE0-\uDEE7]|\uDD3C(?:\u200D[\u2640\u2642]\uFE0F?|\uD83C[\uDFFB-\uDFFF])?|\uDDD1(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\uD83C[\uDF3E\uDF73\uDF7C\uDF84\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83E\uDDD1))|\uD83C(?:\uDFFB(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D(?:\uD83D\uDC8B\u200D)?\uD83E\uDDD1\uD83C[\uDFFC-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF84\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83E\uDDD1\uD83C[\uDFFB-\uDFFF])))?|\uDFFC(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D(?:\uD83D\uDC8B\u200D)?\uD83E\uDDD1\uD83C[\uDFFB\uDFFD-\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF84\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83E\uDDD1\uD83C[\uDFFB-\uDFFF])))?|\uDFFD(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D(?:\uD83D\uDC8B\u200D)?\uD83E\uDDD1\uD83C[\uDFFB\uDFFC\uDFFE\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF84\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83E\uDDD1\uD83C[\uDFFB-\uDFFF])))?|\uDFFE(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D(?:\uD83D\uDC8B\u200D)?\uD83E\uDDD1\uD83C[\uDFFB-\uDFFD\uDFFF]|\uD83C[\uDF3E\uDF73\uDF7C\uDF84\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83E\uDDD1\uD83C[\uDFFB-\uDFFF])))?|\uDFFF(?:\u200D(?:[\u2695\u2696\u2708]\uFE0F?|\u2764\uFE0F?\u200D(?:\uD83D\uDC8B\u200D)?\uD83E\uDDD1\uD83C[\uDFFB-\uDFFE]|\uD83C[\uDF3E\uDF73\uDF7C\uDF84\uDF93\uDFA4\uDFA8\uDFEB\uDFED]|\uD83D[\uDCBB\uDCBC\uDD27\uDD2C\uDE80\uDE92]|\uD83E(?:[\uDDAF-\uDDB3\uDDBC\uDDBD]|\uDD1D\u200D\uD83E\uDDD1\uD83C[\uDFFB-\uDFFF])))?))?|\uDEF1(?:\uD83C(?:\uDFFB(?:\u200D\uD83E\uDEF2\uD83C[\uDFFC-\uDFFF])?|\uDFFC(?:\u200D\uD83E\uDEF2\uD83C[\uDFFB\uDFFD-\uDFFF])?|\uDFFD(?:\u200D\uD83E\uDEF2\uD83C[\uDFFB\uDFFC\uDFFE\uDFFF])?|\uDFFE(?:\u200D\uD83E\uDEF2\uD83C[\uDFFB-\uDFFD\uDFFF])?|\uDFFF(?:\u200D\uD83E\uDEF2\uD83C[\uDFFB-\uDFFE])?))?)");