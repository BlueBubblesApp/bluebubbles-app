import 'dart:math';

import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
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

String getContact(List<Contact> contacts, String id) {
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
