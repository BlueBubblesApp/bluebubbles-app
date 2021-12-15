import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:fast_contacts/fast_contacts.dart' hide Contact;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:faker/faker.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();
  static final tag = 'ContactManager';

  ContactManager._internal();

  List<Contact> contacts = [];
  bool hasFetchedContacts = false;
  Map<String, Contact?> handleToContact = {};
  Map<String, String?> handleToFakeName = {};
  Map<String, String> handleToFormattedAddress = {};

  // We need these so we don't have threads fetching at the same time
  Completer<bool>? getContactsFuture;
  Completer? getAvatarsFuture;
  int lastRefresh = 0;

  Contact? getCachedContact({String? address, Handle? handle}) {
    if (handle != null) {
      return handleToContact[handle.address];
    } else {
      return handleToContact[address];
    }
  }

  Future<bool> canAccessContacts() async {
    if (kIsWeb || kIsDesktop) {
      String? version = await SettingsManager().getServerVersion();
      int? sum = version?.split(".").mapIndexed((index, e) {
        if (index == 0) return int.parse(e) * 100;
        if (index == 1) return int.parse(e) * 21;
        return int.parse(e.split("-").firstOrNull ?? "0");
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

  Future<bool> getContacts({bool headless = false, bool force = false}) async {
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
      return false;
    }

    // Make sure we have contacts access
    if (!(await canAccessContacts())) return false;

    // Set the last refresh time
    lastRefresh = now;

    // Start a new completer
    getContactsFuture = Completer<bool>();

    // Fetch the current list of contacts
    Logger.info("Fetching contacts", tag: tag);
    if (!kIsWeb && !kIsDesktop) {
      contacts = (await FastContacts.allContacts).map((e) => Contact(
        displayName: e.displayName,
        emails: e.emails,
        phones: e.phones,
        structuredName: e.structuredName,
        id: e.id,
      )).toList();
    } else {
      await fetchContactsDesktop();
    }

    // Match handles in the database with contacts
    await matchHandles();

    Logger.info("Finished fetching contacts (${handleToContact.length})", tag: tag);
    if (getContactsFuture != null && !getContactsFuture!.isCompleted) {
      hasFetchedContacts = true;
      getContactsFuture!.complete(true);
    }

    // Lazy load thumbnails after rendering initial contacts.
    getAvatars();
    return true;
  }

  Future<void> fetchContactsDesktop({Function(String)? logger}) async {
    try {
      contacts.clear();
      logger?.call("Trying to fetch contacts from Android...");
      var vcfs = await SocketManager().sendMessage("get-vcf", {}, (_) {});
      if (vcfs['data'] != null) {
        logger?.call("Found Android contacts!");
        if (vcfs['data'] is String) {
          logger?.call("Parsing string into JSON...");
          vcfs['data'] = jsonDecode(vcfs['data']);
        }
        for (var c in vcfs['data']) {
          logger?.call("Parsing contact: ${c['displayName']}");
          contacts.add(Contact.fromMap(c));
        }
      }
    } catch (e, s) {
      print(e);
      print(s);
      logger?.call("Got exception: $e");
      logger?.call(s.toString());
    }
    if (contacts.isEmpty) {
      logger?.call("Android contacts didn't exist, falling back to macOS contacts...");
      try {
        var response = await api.contacts();
        logger?.call("Found macOS contacts!");
        for (Map<String, dynamic> map in response.data['data']) {
          logger?.call("Parsing contact: ${[map['firstName'], map['lastName']].where((e) => e != null).toList().join(" ")}");
          contacts.add(Contact(
            id: randomString(8),
            displayName: [map['firstName'], map['lastName']].where((e) => e != null).toList().join(" "),
            emails: (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList(),
            phones: (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList(),
          ));
        }
      } catch (e, s) {
        print(e);
        print(s);
        logger?.call("Got exception: $e");
        logger?.call(s.toString());
      }
    }
    logger?.call("Finished contacts sync");
  }

  Future<void> matchHandles() async {
    // Match handles to contacts
    List<Handle> handles = kIsWeb ? ChatBloc().cachedHandles : Handle.find();
    for (Handle handle in handles) {
      // If we already have a "match", skip
      if (handleToContact.containsKey(handle.address) && handleToContact[handle.address] != null) {
        continue;
      }

      // Find a contact match
      Contact? contactMatch;

      try {
        contactMatch = getContact(handle);
        handleToContact[handle.address] = contactMatch;
        if (!handle.address.isEmail) {
          handleToFormattedAddress[handle.address] = await formatPhoneNumber(handle.address);
        }
      } catch (ex) {
        Logger.error('Failed to match handle for address, "${handle.address}": ${ex.toString()}', tag: tag);
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
    getAvatarsFuture = Completer();

    Logger.info("Fetching Avatars", tag: tag);
    for (String address in handleToContact.keys) {
      Contact? contact = handleToContact[address];
      if (handleToContact[address] == null || kIsWeb || kIsDesktop) continue;

      FastContacts.getContactImage(contact!.id).then((avatar) {
        if (avatar == null) return;

        contact.avatar.value = avatar;
        handleToContact[address] = contact;
      });
    }

    Logger.info("Finished fetching avatars", tag: tag);
    getAvatarsFuture!.complete();
  }

  Contact? getContact(Handle handle) {
    Contact? contact;

    // Get a list of comparable options
    bool isEmailAddr = handle.address.isEmail;
    String? lastDigits = handle.address.length < 4
        ? handle.address.numericOnly()
        : handle.address.substring(handle.address.length - 4, handle.address.length).numericOnly();

    for (Contact c in contacts) {
      // Get a phone number match
      if (!isEmailAddr) {
        for (String item in c.phones) {
          String compStr = item.replaceAll(" ", "").trim().numericOnly();
          String? formattedAddress = handleToFormattedAddress[handle.address];
          if (!compStr.endsWith(lastDigits)) continue;
          List<String> compareOpts = [handle.address.replaceAll(" ", "").trim().numericOnly()];
          if (formattedAddress != null) compareOpts.add(formattedAddress.replaceAll(" ", "").trim().numericOnly());
          if (sameAddress(compareOpts, compStr)) {
            contact = c;
            break;
          }
        }
      }

      // Get an email match
      if (isEmailAddr) {
        for (String item in c.emails) {
          if (item.replaceAll(" ", "").trim() == handle.address.replaceAll(" ", "").trim()) {
            contact = c;
            break;
          }
        }
      }

      // If we have a match, break out of the loop
      if (contact != null) break;
    }

    return contact;
  }

  Future<Uint8List?> getAvatar(String id) async {
    return await FastContacts.getContactImage(id);
  }

  String getContactTitle(Handle? handle) {
    if (handle == null) return "You";

    String? address = handle.address;
    if (handleToContact.containsKey(address) && handleToContact[address] != null) {
      return handleToContact[address]!.displayName;
    }

    try {
      Contact? contact = getContact(handle);
      if (contact != null) return contact.displayName;
    } catch (ex) {
      Logger.error('Failed to getContact() in getContactTitle(), for address, "$address": ${ex.toString()}', tag: tag);
    }

    try {
      String contactTitle = address;
      bool isEmailAddr = contactTitle.isEmail;
      if (contactTitle == address && !isEmailAddr) {
        return handleToFormattedAddress[handle.address] ?? handle.address;
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
}
