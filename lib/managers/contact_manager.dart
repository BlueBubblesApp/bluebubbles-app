import 'dart:async';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:faker/faker.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();

  StreamController<List<String>> _stream = new StreamController.broadcast();

  StreamController<Map<String, Color>> _colorStream = new StreamController.broadcast();

  Stream<Map<String, Color>> get colorStream => _colorStream.stream;

  StreamController<Map<String, Color>> get colorStreamObject => _colorStream;

  Stream<List<String>> get stream => _stream.stream;

  ContactManager._internal();

  List<Contact> contacts;
  Map<String, Contact> handleToContact = new Map();
  Map<String, String> handleToFakeName = new Map();
  Map<String, ContactAvatarWidgetState> contactWidgetStates = new Map();

  // We need these so we don't have threads fetching at the same time
  Completer getContactsFuture;
  Completer getAvatarsFuture;
  int lastRefresh = 0;

  Future<Contact> getCachedContact(Handle handle) async {
    if (handle == null) return null;
    if (contacts == null || !handleToContact.containsKey(handle.address)) await getContacts();
    if (!handleToContact.containsKey(handle.address)) return null;
    return handleToContact[handle.address];
  }

  Contact getCachedContactSync(String address) {
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

  Future getContacts({bool headless = false, bool force = false}) async {
    if (!(await canAccessContacts())) return false;

    // If we are fetching the contacts, return the current future so we can await it
    if (getContactsFuture != null && !getContactsFuture.isCompleted) {
      debugPrint("[ContactManager] -> Already fetching contacts, returning future...");
      return getContactsFuture.future;
    }

    // Check if we've requested sometime in the last 5 minutes
    // If we have, exit, we don't need to re-fetch the chats again
    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (!force && lastRefresh != 0 && now < lastRefresh + (60000 * 5)) {
      debugPrint("[ContactManager] -> Not fetching contacts; Not enough time has elapsed");
      return;
    }

    // Set the last refresh time
    lastRefresh = now;

    // Start a new completer
    getContactsFuture = new Completer<bool>();

    // Fetch the current list of contacts
    debugPrint("ContactManager -> Fetching contacts");
    contacts = ((await ContactsService.getContacts(withThumbnails: false)) ?? []).toList();

    // Match handles to contacts
    List<Handle> handles = await Handle.find({});
    for (Handle handle in handles) {
      // If we already have a "match", skip
      if (handleToContact.containsKey(handle.address)) {
        continue;
      }

      // Find a contact match
      Contact contactMatch = await getContact(handle);
      handleToContact[handle.address] = contactMatch;

      // If we have a match, add it to the mapping, then break out
      // of the loop so we don't "over-process" more than we need
      if (contactMatch != null) {
        _stream.sink.add([handle.address]);
      }
    }

    handleToFakeName = Map.fromEntries(handleToContact.entries.map((entry) =>
        !handleToFakeName.keys.contains(entry.key) || handleToFakeName[entry.key] == null
            ? MapEntry(entry.key, faker.person.name())
            : MapEntry(entry.key, handleToFakeName[entry.key])));

    debugPrint("ContactManager -> Finished fetching contacts (${handleToContact.length})");
    getContactsFuture.complete(true);

    // Lazy load thumbnails after rendering initial contacts.
    getAvatars();
    return true;
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
      if (handleToContact[address] == null) continue;

      ContactsService.getAvatar(handleToContact[address], photoHighRes: false).then((avatar) {
        if (avatar == null) return;

        // Update the avatar in the master list
        contact.avatar = avatar;
        handleToContact[address].avatar = avatar;

        // Add the handle to the stream to update the subscribers
        _stream.sink.add([address]);
      });
    }

    debugPrint("ContactManager -> Finished fetching avatars");
    getAvatarsFuture.complete();
  }

  Future<Contact> getContact(Handle handle, {bool fetchAvatar = false}) async {
    if (handle == null) return null;
    Contact contact;

    // Get a list of comparable options
    dynamic opts = await getCompareOpts(handle);
    bool isEmail = handle.address.contains('@');
    String lastDigits = handle.address.substring(handle.address.length - 4, handle.address.length);

    // If the contact list is null, get the contacts
    try {
      if (contacts == null) await getContacts();
    } catch (ex) {
      return null;
    }

    for (Contact c in contacts ?? []) {
      // Get a phone number match
      if (!isEmail) {
        for (Item item in c?.phones ?? []) {
          if (!item.value.endsWith(lastDigits)) continue;

          if (sameAddress(opts, item.value)) {
            contact = c;
            break;
          }
        }
      }

      // Get an email match
      if (isEmail) {
        for (Item item in c?.emails ?? []) {
          if (item.value == handle.address) {
            contact = c;
            break;
          }
        }
      }

      // If we have a match, break out of the loop
      if (contact != null) break;
    }

    if (fetchAvatar) {
      contact.avatar = await ContactsService.getAvatar(contact, photoHighRes: false);
    }

    return contact;
  }

  Future<String> getContactTitle(Handle handle) async {
    if (handle == null) return "You";
    if (contacts == null) await getContacts();

    String address = handle.address;
    if (handleToContact.containsKey(address) && handleToContact[address] != null)
      return handleToContact[address].displayName;
    Contact contact = await getContact(handle);
    if (contact != null && contact.displayName != null) return contact.displayName;
    String contactTitle = address;
    if (contactTitle == address && !contactTitle.contains("@")) {
      return await formatPhoneNumber(contactTitle);
    }

    // If it's an email and starts with "e:", strip it out
    if (contactTitle.contains("@") && contactTitle.startsWith("e:")) {
      contactTitle = contactTitle.substring(2);
    }

    return contactTitle;
  }

  ContactAvatarWidgetState getState(String key) {
    if (contactWidgetStates.containsKey(key)) {
      return contactWidgetStates[key];
    }
    contactWidgetStates[key] = ContactAvatarWidgetState();
    return contactWidgetStates[key];
  }

  dispose() {
    _stream.close();
    _colorStream.close();
  }
}
