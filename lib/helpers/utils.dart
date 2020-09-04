import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:blurhash_flutter/blurhash.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

DateTime parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is DateTime) return value;
  return null;
}

String getContactTitle(int id, String address) {
  if (ContactManager().handleToContact.containsKey(address))
    return ContactManager().handleToContact[address].displayName;
  String contactTitle = address;
  if (contactTitle == address && !contactTitle.contains("@")) {
    return formatPhoneNumber(contactTitle);
  }
  return contactTitle;
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
  String formattedNumber = address1.replaceAll(RegExp(r'[-() ]'), '');

  return formattedNumber == address2 ||
      "+1" + formattedNumber == address2 ||
      "+" + formattedNumber == address2;
}

Contact getContact(String id) {
  Contact contact;

  for (Contact c in ContactManager().contacts) {
    // Get a phone number match
    for (Item item in c.phones) {
      if (sameAddress(item.value, id)) {
        contact = c;
        break;
      }
    }

    // Get an email match
    for (Item item in c.emails) {
      if (item.value == id) {
        contact = c;
        break;
      }
    }

    // If we have a match, break out of the loop
    if (contact != null) break;
  }

  return contact;
}

getInitials(String name, String delimeter) {
  if (name == null) return "";
  List array = name.split(delimeter);
  // If there is a comma, just return the "people" icon
  if (name.contains(", "))
    return Icon(Icons.people, color: Colors.white, size: 30);

  // If there is an & character, it's 2 people, format accordingly
  if (name.contains(' & ')) {
    List names = name.split(' & ');
    String first = names[0].startsWith("+") ? null : names[0][0];
    String second = names[1].startsWith("+") ? null : names[1][0];

    // If either first or second name is null, return the people icon
    if (first == null || second == null) {
      return Icon(Icons.people, color: Colors.white, size: 30);
    } else {
      return "${first.toUpperCase()}&${second.toUpperCase()}";
    }
  }

  // If the name is a phone number, return the "person" icon
  if (name.startsWith("+") || array[0].length < 1)
    return Icon(Icons.person, color: Colors.white, size: 30);

  switch (array.length) {
    case 1:
      return array[0][0].toUpperCase();
      break;
    default:
      if (array.length - 1 < 0 || array[array.length - 1].length < 1) return "";
      String first = array[0][0].toUpperCase();
      String last = array[array.length - 1][0].toUpperCase();
      if (!last.contains(new RegExp('[A-Za-z]'))) last = array[1][0];
      if (!last.contains(new RegExp('[A-Za-z]'))) last = "";
      return first + last;
  }
}

Future<Uint8List> blurHashDecode(String blurhash, int width, int height) async {
  List<int> result = await compute(blurHashDecodeCompute,
      jsonEncode({"hash": blurhash, "width": width, "height": height}));
  return Uint8List.fromList(result);
}

List<int> blurHashDecodeCompute(String data) {
  Map<String, dynamic> map = jsonDecode(data);
  Uint8List imageDataBytes = Decoder.decode(
      map["hash"],
      ((map["width"] / 200) as double).toInt(),
      ((map["height"] / 200) as double).toInt());
  return imageDataBytes.toList();
}

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
}

String sanitizeString(String input) {
  if (input == null) return "";
  input = input.replaceAll(String.fromCharCode(65532), '');
  input = input.trim();
  return input;
}

bool isEmptyString(String input) {
  if (input == null) return true;
  input = sanitizeString(input);
  return input.isEmpty;
}

String getGroupEventText(Message message) {
  String text = "Unknown group event";
  String handle = "You";
  if (message.handleId != null && message.handle != null)
    handle = getContactTitle(message.handleId, message.handle.address);

  if (message.itemType == ItemTypes.participantRemoved.index) {
    text = "$handle removed someone from the conversation";
  } else if (message.itemType == ItemTypes.participantAdded.index) {
    text = "$handle added someone to the conversation";
  } else if (message.itemType == ItemTypes.participantLeft.index) {
    text = "$handle left the conversation";
  } else if (message.itemType == ItemTypes.nameChanged.index) {
    text = "$handle renamed the conversation to \"${message.groupTitle}\"";
  }

  return text;
}

Future<MemoryImage> loadAvatar(Chat chat, List<String> addresses) async {
  // If the chat hasn't been saved, save it
  if (chat.id == null) await chat.save();

  // If there are no participants, get them
  if (chat.participants == null || chat.participants.length == 0) {
    chat = await chat.getParticipants();
  }

  // If there are no participants, return
  if (chat.participants == null || chat.participants.length != 1) return null;
  String address = chat.participants.first.address;

  if (addresses == null) addresses = [address];

  // See if the update contains the current conversation
  int matchIdx = addresses.indexOf(address);
  if (matchIdx == -1) return null;

  // Get the contact
  Contact contact = ContactManager().getCachedContact(addresses[matchIdx]);
  if (contact == null || contact.avatar.length == 0) return null;

  // Set the contact image
  return MemoryImage(
      await FlutterImageCompress.compressWithList(contact.avatar, quality: 50));
}

List<RegExpMatch> parseLinks(String text) {
  RegExp exp = new RegExp(
      r'((https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9\/()@:%_.~#?&=\*\[\]]{0,})\b');
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
