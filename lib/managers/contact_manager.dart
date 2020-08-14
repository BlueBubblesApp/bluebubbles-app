import 'dart:async';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();

  StreamController<List<String>> _stream = new StreamController.broadcast();

  Stream<List<String>> get stream => _stream.stream;

  ContactManager._internal();
  List<Contact> contacts = <Contact>[];
  Map<String, Contact> handleToContact = new Map();

  // We need these so we don't have threads fetching at the same time
  bool isGettingContacts = false;
  bool isGettingAvatars = false;

  Contact getCachedContact(String address) {
    if (!handleToContact.containsKey(address)) return null;
    return handleToContact[address];
  }

  Future<void> getContacts({bool headless = false}) async {
    bool hasPermission =
        !headless ? await Permission.contacts.request().isGranted : true;
    if (!headless && !hasPermission) return;
    if (isGettingContacts) return;

    isGettingContacts = true;

    // Fetch the current list of contacts
    contacts =
        (await ContactsService.getContacts(withThumbnails: false)).toList();

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
        _stream.sink.add([handle.address]);
      }
    }

    isGettingContacts = false;

    // Lazy load thumbnails after rendering initial contacts.
    getAvatars();
  }

  Future<void> getAvatars() async {
    if (isGettingAvatars) return;
    isGettingAvatars = true;

    for (String address in handleToContact.keys) {
      Contact contact = handleToContact[address];
      final avatar = await ContactsService.getAvatar(contact);
      if (avatar == null) continue;

      // Update the avatar in the master list
      contact.avatar = avatar;
      handleToContact[address] = contact;

      // Add the handle to the stream to update the subscribers
      _stream.sink.add([address]);
    }

    isGettingAvatars = false;
  }

  dispose() {
    _stream.close();
  }
}
