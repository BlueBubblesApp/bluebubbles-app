import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();

  ContactManager._internal();
  List<Contact> contacts = <Contact>[];
  Map<String, Contact> handleToContact = new Map();

  Future<void> getContacts({bool headless = false}) async {
    if (contacts.length > 0) return;
    if (headless || await Permission.contacts.request().isGranted) {
      var contacts =
          (await ContactsService.getContacts(withThumbnails: false)).toList();
      _manager.contacts = contacts;
      // Lazy load thumbnails after rendering initial contacts.
      getAvatars(contacts);

      List<Handle> handles = await Handle.find({});
      for (Handle handle in handles) {
        if (handleToContact.containsKey(handle.id)) continue;
        for (Contact contact in contacts) {
          contact.phones.forEach((Item item) {
            String formattedNumber =
                item.value.replaceAll(RegExp(r'[-() ]'), '');
            if (formattedNumber == handle.address ||
                "+1" + formattedNumber == handle.address) {
              handleToContact[handle.address] = contact;
            }
          });
          contact.emails.forEach((Item item) {
            if (item.value == handle.address) {
              handleToContact[handle.address] = contact;
            }
          });
        }
      }
    }
  }

  void getAvatars(List<Contact> _contacts) {
    for (final Contact contact in _contacts) {
      ContactsService.getAvatar(contact).then((avatar) {
        if (avatar == null) return; // Don't redraw if no change.
        contact.avatar = avatar;
      });
    }
  }
}
