import 'package:bluebubble_messages/singleton.dart';
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

void getContacts() async {
  if (await Permission.contacts.request().isGranted) {
    var contacts =
        (await ContactsService.getContacts(withThumbnails: false)).toList();
    Singleton().contacts = contacts;
    // Lazy load thumbnails after rendering initial contacts.
    for (final Contact contact in Singleton().contacts) {
      ContactsService.getAvatar(contact).then((avatar) {
        if (avatar == null) return; // Don't redraw if no change.
        contact.avatar = avatar;
      });
    }
  }
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
