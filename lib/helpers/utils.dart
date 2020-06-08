import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:blurhash/blurhash.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

DateTime parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is DateTime) return value;
}

// String getInitials(name) {
//   List<String> names = name.split(" ");
//   String initials = "";
//   int numWords = 2;

//   if (numWords == names.length) {
//     numWords = 1;
//   }
//   for (var i = 0; i < numWords; i++) {
//     initials += '${names[i][0]}';
//   }
//   debugPrint("initials are: " + initials);
//   return initials;
// }

String getContactTitle(List<Contact> contacts, String id) {
  if (contacts == null) return id;
  String contactTitle = id;
  contacts.forEach((Contact contact) {
    contact.phones.forEach((Item item) {
      String formattedNumber = item.value.replaceAll(RegExp(r'[-() ]'), '');
      if (formattedNumber == id || "+1" + formattedNumber == id) {
        contactTitle = contact.displayName;
        return contactTitle;
      }
    });
    contact.emails.forEach((Item item) {
      if (item.value == id) {
        contactTitle = contact.displayName;
        return contactTitle;
      }
    });
  });
  return contactTitle;
}

Contact getContact(List<Contact> contacts, String id) {
  Contact contact;
  contacts.forEach((Contact _contact) {
    _contact.phones.forEach((Item item) {
      String formattedNumber = item.value.replaceAll(RegExp(r'[-() ]'), '');
      if (formattedNumber == id || "+1" + formattedNumber == id) {
        contact = _contact;
        return contact;
      }
    });
    _contact.emails.forEach((Item item) {
      if (item.value == id) {
        contact = _contact;
        return contact;
      }
    });
  });
  return contact;
}

getInitials(String name, String delimeter) {
  List array = name.split(delimeter);
  if (array[0].length < 1) return "";

  switch (array.length) {
    case 1:
      return array[0][0].toUpperCase();

      break;
    default:
      if (array.length - 1 < 0 || array[array.length - 1].length < 1) return "";
      return array[0][0].toUpperCase() +
          array[array.length - 1][0].toUpperCase();
  }
}

Future<Uint8List> blurHashDecode(String blurhash) async {
  Uint8List imageDataBytes;
  try {
    imageDataBytes = await BlurHash.decode(blurhash, 20, 12);
  } on PlatformException catch (e) {
    print(e.message);
  }
  return imageDataBytes;
}

String randomString(int length) {
  var rand = new Random();
  var codeUnits = new List.generate(length, (index) {
    return rand.nextInt(33) + 89;
  });

  return new String.fromCharCodes(codeUnits);
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
