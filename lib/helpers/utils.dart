import 'dart:math';
import 'dart:typed_data';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:convert/convert.dart';

import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/services.dart';

DateTime parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is DateTime) return value;
  return null;
}

bool isNullOrEmpty(dynamic input, {trimString = false}) {
  if (input != null && input is String) {
    input = input.trim();
  }

  return input == null || input.isEmpty;
}

Size textSize(String text, TextStyle style) {
  final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr)
    ..layout(minWidth: 0, maxWidth: double.infinity);
  return textPainter.size;
}

String formatPhoneNumber(String str) {
  // If the string is an email, we don't want to format it
  if (str.contains("@")) return str;
  if (str.length < 10) return str;
  String areaCode = "";

  String numberWithoutAreaCode = str;

  if (str.startsWith("+")) {
    areaCode = "+1 ";
    numberWithoutAreaCode = str.substring(2);
  }

  String formattedPhoneNumber = areaCode +
      "(" +
      numberWithoutAreaCode.substring(0, 3) +
      ") " +
      numberWithoutAreaCode.substring(3, 6) +
      "-" +
      numberWithoutAreaCode.substring(6, numberWithoutAreaCode.length);
  return formattedPhoneNumber;
}

bool sameAddress(String address1, String address2) {
  String formattedNumber1 = address1.replaceAll(RegExp(r'[-() ]'), '');
  String formattedNumber2 = address2.replaceAll(RegExp(r'[-() ]'), '');

  return formattedNumber1 == formattedNumber2 ||
      "+1" + formattedNumber1 == formattedNumber2 ||
      "+" + formattedNumber1 == formattedNumber2 ||
      "+1" + formattedNumber2 == formattedNumber1 ||
      "+" + formattedNumber2 == formattedNumber1;
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

String randomString(int length) {
  var rand = new Random();
  var codeUnits = new List.generate(length, (index) {
    return rand.nextInt(33) + 89;
  });

  return new String.fromCharCodes(codeUnits);
}

bool sameSender(Message first, Message second) {
  return (first != null &&
      second != null &&
      (first.isFromMe && second.isFromMe ||
          (!first.isFromMe &&
              !second.isFromMe &&
              (first.handle != null &&
                  second.handle != null &&
                  first.handle.address == second.handle.address))));
}

extension DateHelpers on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return now.day == this.day &&
        now.month == this.month &&
        now.year == this.year;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return yesterday.day == this.day &&
        yesterday.month == this.month &&
        yesterday.year == this.year;
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
    return Color.fromARGB(this.alpha, (this.red * f).round(),
        (this.green * f).round(), (this.blue * f).round());
  }

  Color lighten([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(
        this.alpha,
        this.red + ((255 - this.red) * p).round(),
        this.green + ((255 - this.green) * p).round(),
        this.blue + ((255 - this.blue) * p).round());
  }

  Color lightenOrDarken([double percent = 10]) {
    if (this.computeLuminance() >= 0.5) {
      return this.darken(percent);
    } else {
      return this.lighten(percent);
    }
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

Future<String> getGroupEventText(Message message) async {
  String text = "Unknown group event";
  String handle = "You";
  if (message.handleId != null && message.handle != null)
    handle = await ContactManager().getContactTitle(message.handle.address);

  if (message.itemType == 1 && message.groupActionType == 1) {
    text = "$handle removed someone from the conversation";
  } else if (message.itemType == 1 && message.groupActionType == 0) {
    text = "$handle added someone to the conversation";
  } else if (message.itemType == 3) {
    text = "$handle left the conversation";
  } else if (message.itemType == 2 && message.groupTitle != null) {
    text = "$handle named the conversation \"${message.groupTitle}\"";
  }

  return text;
}

Future<MemoryImage> loadAvatar(Chat chat, String address) async {
  if (chat != null) {
    // If the chat hasn't been saved, save it
    if (chat.id == null) await chat.save();

    // If there are no participants, get them
    if (isNullOrEmpty(chat.participants)) {
      await chat.getParticipants();
    }

    // If there are no participants, return
    if (chat.participants == null) return null;

    if (address == null) {
      address = chat.participants.first.address;
    }

    // See if the update contains the current conversation
    int matchIdx =
        chat.participants.map((i) => i.address).toList().indexOf(address);
    if (matchIdx == -1) return null;
  }

  // Get the contact
  Contact contact = await ContactManager().getCachedContact(address);
  if (isNullOrEmpty(contact?.avatar)) return null;

  // Set the contact image
  // NOTE: Don't compress this. It will increase load time significantly
  // NOTE: These don't need to be compressed. They are usually already small
  return MemoryImage(contact.avatar);
}

List<RegExpMatch> parseLinks(String text) {
  RegExp exp = new RegExp(
      r'(((h|H)ttps?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9\/()@:%_.~#?&=\*\[\]]{0,})');
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

bool validatePhoneNumber(String value) {
  value = value.trim();

  String phonePattern =
      r'^\+?(\+?\d{1,2}\s?)?\-?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}$';
  String emailPattern = r'^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$';
  RegExp regExpPhone = new RegExp(phonePattern);
  RegExp regExpEmail = new RegExp(emailPattern);
  return regExpPhone.hasMatch(value) || regExpEmail.hasMatch(value);
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
  if (str.length == 0) return [HexColor("686868"), HexColor("928E8E")];

  int total = 0;
  for (int i = 0; i < (str ?? "").length; i++) {
    total += str.codeUnitAt(i);
  }

  int seed = (total * str.length / 8).round();

  // These are my arbitrary weights. It's based on what I found
  // to be a good amount of each color
  if (seed < 901) {
    return [HexColor("fd678d"), HexColor("ff8aa8")]; // Pink
  } else if (seed >= 901 && seed < 915) {
    return [HexColor("6bcff6"), HexColor("94ddfd")]; // Blue
  } else if (seed >= 915 && seed < 925) {
    return [HexColor("fea21c"), HexColor("feb854")]; // Orange
  } else if (seed >= 925 && seed < 935) {
    return [HexColor("5ede79"), HexColor("8de798")]; // Green
  } else if (seed >= 935 && seed < 950) {
    return [HexColor("ffca1c"), HexColor("fcd752")]; // Yellow
  } else if (seed >= 950 && seed < 3000) {
    return [HexColor("ff534d"), HexColor("fd726a")]; // Red
  } else {
    return [HexColor("a78df3"), HexColor("bcabfc")]; // Purple
  }
}

bool shouldBeRainbow(Chat chat) {
  Chat theChat = chat;
  if (theChat == null) return false;
  return SettingsManager().settings.rainbowBubbles;
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

Brightness getBrightness(BuildContext context) {
  return AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ? Brightness.dark : Brightness.light;
}