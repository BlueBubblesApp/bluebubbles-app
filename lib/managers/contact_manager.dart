import 'dart:async';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();

  StreamController<List<String>> _stream = new StreamController.broadcast();

  Stream<List<String>> get stream => _stream.stream;

  ContactManager._internal();
  List<Contact> contacts;
  Map<String, Contact> handleToContact = new Map();

  // We need these so we don't have threads fetching at the same time
  Completer getContactsFuture;
  Completer getAvatarsFuture;

  Future<Contact> getCachedContact(String address) async {
    if (contacts == null || !handleToContact.containsKey(address)) await getContacts();
    if (!handleToContact.containsKey(address)) return null;
    return handleToContact[address];
  }

  Future<bool> canAccessContacts() async {
    bool output = false;

    try {
      bool granted = await Permission.contacts.isGranted;
      if (granted) return true;

      bool totallyDisabled = await Permission.contacts.isPermanentlyDenied;
      if (!totallyDisabled) {
        return await Permission.contacts.request().isGranted;
      }
    } catch (ex) {
      debugPrint("Error getting access to contacts!");
      debugPrint(ex.toString());
    }

    return output;
  }

  Future<void> getContacts({bool headless = false}) async {
    if (!(await canAccessContacts())) return;

    // If we are fetching the contacts, return the current future so we can await it
    if (getContactsFuture != null && !getContactsFuture.isCompleted) {
      return getContactsFuture.future;
    }

    // Start a new completer
    getContactsFuture = new Completer();

    // Fetch the current list of contacts
    debugPrint("ContactManager -> Fetching Contacts");
    contacts =
        (await ContactsService.getContacts(withThumbnails: false)).toList();

    // Match handles to contacts
    List<Handle> handles = await Handle.find({});
    for (Handle handle in handles) {
      // If we already have a "match", skip
      if (handleToContact.containsKey(handle.address)) continue;

      // Find a contact match
      Contact contactMatch = await getContact(handle.address);
      handleToContact[handle.address] = contactMatch;

      // If we have a match, add it to the mapping, then break out
      // of the loop so we don't "over-process" more than we need
      if (contactMatch != null) {
        _stream.sink.add([handle.address]);
      }
    }

    getContactsFuture.complete();

    // Lazy load thumbnails after rendering initial contacts.
    getAvatars();
  }

  Future<void> getAvatars() async {
    if (getAvatarsFuture != null && !getAvatarsFuture.isCompleted) {
      return getAvatarsFuture.future;
    }

    // Create a new completer for this
    getAvatarsFuture = new Completer();

    debugPrint("ContactManager -> Fetching Avatars");
    for (String address in handleToContact.keys) {
      Contact contact = handleToContact[address];
      if (contact == null) continue;

      final avatar = await ContactsService.getAvatar(contact);
      if (avatar == null) continue;

      // Update the avatar in the master list
      contact.avatar = avatar;
      handleToContact[address] = contact;

      // Add the handle to the stream to update the subscribers
      _stream.sink.add([address]);
    }

    getAvatarsFuture.complete();
  }

  Future<Contact> getContact(String address) async {
    if (address == null) return null;
    Contact contact;

    // If the contact list is null, get the contacts
    if (contacts == null) await getContacts();
    for (Contact c in contacts) {
      // Get a phone number match
      for (Item item in c.phones) {
        if (sameAddress(item.value, address)) {
          contact = c;
          break;
        }
      }

      // Get an email match
      for (Item item in c.emails) {
        if (item.value == address) {
          contact = c;
          break;
        }
      }

      // If we have a match, break out of the loop
      if (contact != null) break;
    }

    return contact;
  }

  Future<String> getContactTitle(String address) async {
    if (address == null) return "You";
    if (contacts == null) await getContacts();

    if (handleToContact.containsKey(address) && handleToContact[address] != null)
      return handleToContact[address].displayName;
    String contactTitle = address;
    if (contactTitle == address && !contactTitle.contains("@")) {
      return formatPhoneNumber(contactTitle);
    }
    return contactTitle;
  }

  dispose() {
    _stream.close();
  }
}
