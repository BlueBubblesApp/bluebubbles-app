import 'dart:async';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();

  StreamController<List<Contact>> _stream = new StreamController.broadcast();

  Stream<List<Contact>> get stream => _stream.stream;

  ContactManager._internal();
  List<Contact> contacts = <Contact>[];
  Map<String, Contact> handleToContact = new Map();

  Future<void> getContacts({bool headless = false}) async {
    bool hasPermission =
        !headless ? await Permission.contacts.request().isGranted : true;
    if (!headless && !hasPermission) return;

    // Fetch the current list of contacts
    contacts =
        (await ContactsService.getContacts(withThumbnails: false)).toList();

    // Lazy load thumbnails after rendering initial contacts.
    getAvatars();

    // Match handles to contacts
    List<Handle> handles = await Handle.find({});
    for (Handle handle in handles) {
      // If we already have a "match", skip
      if (handleToContact.containsKey(handle.address)) continue;

      // Find a contact match
      Contact contactMatch = getContact(handle.address);

      // If we have a match, add it to the mapping, then break out
      // of the loop so we don't "over-process" more than we need
      if (contactMatch != null) {
        handleToContact[handle.address] = contactMatch;
      }
    }
  }

  Future<void> getAvatars() async {
    for (int i = 0; i < contacts.length; i++) {
      final avatar = await ContactsService.getAvatar(contacts[i]);
      if (avatar == null) continue;

      contacts[i].avatar = avatar;
      _stream.sink.add([contacts[i]]);
    }
  }
}
