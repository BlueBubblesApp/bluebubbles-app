import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();

  ContactManager._internal();
  List<Contact> contacts = <Contact>[];

  void getContacts() async {
    if (await Permission.contacts.request().isGranted) {
      var contacts =
          (await ContactsService.getContacts(withThumbnails: false)).toList();
      _manager.contacts = contacts;
      // Lazy load thumbnails after rendering initial contacts.
      for (final Contact contact in _manager.contacts) {
        ContactsService.getAvatar(contact).then((avatar) {
          if (avatar == null) return; // Don't redraw if no change.
          contact.avatar = avatar;
        });
      }
    }
  }
}
