import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:get/get.dart';
import 'package:faker/faker.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();
  static final tag = 'ContactManager';

  StreamController<List<String>> _stream = new StreamController.broadcast();

  StreamController<Map<String, Color?>> _colorStream = new StreamController.broadcast();

  Stream<Map<String, Color?>> get colorStream => _colorStream.stream;

  StreamController<Map<String, Color?>> get colorStreamObject => _colorStream;

  Stream<List<String>> get stream => _stream.stream;

  ContactManager._internal();

  List<Contact> contacts = [];
  bool hasFetchedContacts = false;
  Map<String, Contact?> handleToContact = new Map();
  Map<String, String?> handleToFakeName = new Map();
  Map<String, ContactAvatarWidgetState> contactWidgetStates = new Map();

  // We need these so we don't have threads fetching at the same time
  Completer? getContactsFuture;
  Completer? getAvatarsFuture;
  int lastRefresh = 0;

  Future<Contact?> getCachedContact(Handle? handle) async {
    if (handle == null) return null;
    if (contacts.isEmpty) await getContacts();
    if (!handleToContact.containsKey(handle.address)) return null;
    return handleToContact[handle.address];
  }

  Contact? getCachedContactSync(String address) {
    if (!handleToContact.containsKey(address)) return null;
    return handleToContact[address];
  }

  Future<bool> canAccessContacts() async {
    if (kIsWeb || kIsDesktop) {
      String? version = await SettingsManager().getServerVersion();
      int? sum = version?.split(".").mapIndexed((index, e) {
        if (index == 0) return int.parse(e) * 100;
        if (index == 1) return int.parse(e) * 21;
        return int.parse(e);
      }).sum;
      return (sum ?? 0) >= 42;
    }
    try {
      PermissionStatus status = await Permission.contacts.status;
      if (status.isGranted) return true;
      Logger.info("Contacts Permission Status: ${status.toString()}", tag: tag);

      // If it's not permanently denied, request access
      if (!status.isPermanentlyDenied) {
        return (await Permission.contacts.request()).isGranted;
      }

      Logger.info("Contacts permissions are permanently denied...", tag: tag);
    } catch (ex) {
      Logger.error("Error getting access to contacts!", tag: tag);
      Logger.error(ex.toString(), tag: tag);
    }

    return false;
  }

  Future getContacts({bool headless = false, bool force = false}) async {
    // If we are fetching the contacts, return the current future so we can await it
    if (getContactsFuture != null && !getContactsFuture!.isCompleted) {
      Logger.info("Already fetching contacts, returning future...", tag: tag);
      return getContactsFuture!.future;
    }

    // Check if we've requested sometime in the last 5 minutes
    // If we have, exit, we don't need to re-fetch the chats again
    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (!force && lastRefresh != 0 && now < lastRefresh + (60000 * 5)) {
      Logger.info("Not fetching contacts; Not enough time has elapsed", tag: tag);
      return;
    }

    // Make sure we have contacts access
    if (!(await canAccessContacts())) return false;

    // Set the last refresh time
    lastRefresh = now;

    // Start a new completer
    getContactsFuture = new Completer<bool>();

    // Fetch the current list of contacts
    Logger.info("Fetching contacts", tag: tag);
    if (!kIsWeb && !kIsDesktop) {
      contacts = (await ContactsService.getContacts(withThumbnails: false)).toList();
    } else {
      contacts.clear();
      var vcfs = await SocketManager().sendMessage("get-vcf", {}, (_) {});
      for (var c in jsonDecode(vcfs['data'])) {
        c["avatar"] = Uint8List.fromList((c["avatar"] as List).cast<int>());
        contacts.add(Contact.fromMap(c));
      }
    }
    hasFetchedContacts = true;

    // Match handles in the database with contacts
    await this.matchHandles();

    Logger.info("Finished fetching contacts (${handleToContact.length})", tag: tag);
    if (getContactsFuture != null && !getContactsFuture!.isCompleted) {
      getContactsFuture!.complete(true);
    }

    // Lazy load thumbnails after rendering initial contacts.
    getAvatars();
    return true;
  }

  Future<void> matchHandles() async {
    // Match handles to contacts
    List<Handle> handles = await Handle.find({});
    for (Handle handle in handles) {
      // If we already have a "match", skip
      if (handleToContact.containsKey(handle.address)) {
        continue;
      }

      // Find a contact match
      Contact? contactMatch;

      try {
        contactMatch = await getContact(handle);
        handleToContact[handle.address] = contactMatch;
      } catch (ex) {
        Logger.error('Failed to match handle for address, "${handle.address}": ${ex.toString()}', tag: tag);
      }

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
  }

  Future<void> getAvatars() async {
    if (getAvatarsFuture != null && !getAvatarsFuture!.isCompleted) {
      return getAvatarsFuture!.future;
    }

    // Create a new completer for this
    getAvatarsFuture = new Completer();

    Logger.info("Fetching Avatars", tag: tag);
    for (String address in handleToContact.keys) {
      Contact? contact = handleToContact[address];
      if (handleToContact[address] == null || kIsWeb || kIsDesktop) continue;

      ContactsService.getAvatar(contact!, photoHighRes: !SettingsManager().settings.lowMemoryMode.value).then((avatar) {
        if (avatar == null) return;

        contact.avatar = avatar;
        handleToContact[address] = contact;

        // Add the handle to the stream to update the subscribers
        _stream.sink.add([address]);
      });
    }

    Logger.info("Finished fetching avatars", tag: tag);
    getAvatarsFuture!.complete();
  }

  Future<Contact?> getContact(Handle handle, {bool fetchAvatar = false}) async {
    Contact? contact;

    // Get a list of comparable options
    List<String> opts = await getCompareOpts(handle);
    bool isEmailAddr = handle.address.isEmail;
    String? lastDigits = handle.address.length < 4
        ? handle.address.numericOnly()
        : handle.address.substring(handle.address.length - 4, handle.address.length).numericOnly();

    // If the contact list is null, get the contacts
    try {
      if (!hasFetchedContacts && contacts.isEmpty) await getContacts();
    } catch (ex) {
      return null;
    }

    for (Contact c in contacts) {
      // Get a phone number match
      if (!isEmailAddr) {
        for (Item item in c.phones ?? []) {
          String compStr = "";
          if (item.value != null) {
            compStr = item.value!.replaceAll(" ", "").trim().numericOnly();
          }

          if (!compStr.endsWith(lastDigits)) continue;
          if (sameAddress(opts, compStr)) {
            contact = c;
            break;
          }
        }
      }

      // Get an email match
      if (isEmailAddr) {
        for (Item item in c.emails ?? []) {
          if (item.value == handle.address) {
            contact = c;
            break;
          }
        }
      }

      // If we have a match, break out of the loop
      if (contact != null) break;
    }

    if (fetchAvatar && !kIsDesktop && !kIsWeb) {
      Uint8List? avatar =
          await ContactsService.getAvatar(contact!, photoHighRes: !SettingsManager().settings.lowMemoryMode.value);
      contact.avatar = avatar;
    }

    return contact;
  }

  Future<String?> getContactTitle(Handle? handle) async {
    if (handle == null) return "You";
    if (contacts.isEmpty) await getContacts();

    String? address = handle.address;
    if (handleToContact.containsKey(address) && handleToContact[address] != null)
      return handleToContact[address]!.displayName;

    try {
      Contact? contact = await getContact(handle);
      if (contact != null && contact.displayName != null) return contact.displayName;
    } catch (ex) {
      Logger.error('Failed to getContact() in getContactTitle(), for address, "$address": ${ex.toString()}', tag: tag);
    }

    try {
      String contactTitle = address;
      bool isEmailAddr = contactTitle.isEmail;
      if (contactTitle == address && !isEmailAddr) {
        return await formatPhoneNumber(handle);
      }

      // If it's an email and starts with "e:", strip it out
      if (isEmailAddr && contactTitle.startsWith("e:")) {
        contactTitle = contactTitle.substring(2);
      }

      return contactTitle;
    } catch (ex) {
      Logger.error('Failed to formatPhoneNumber() in getContactTitle(), for address, "$address": ${ex.toString()}',
          tag: tag);
    }

    return address;
  }

  ContactAvatarWidgetState getState(String key) {
    if (contactWidgetStates.containsKey(key)) {
      return contactWidgetStates[key]!;
    }
    contactWidgetStates[key] = ContactAvatarWidgetState();
    return contactWidgetStates[key]!;
  }

  dispose() {
    _stream.close();
    _colorStream.close();
  }
}
