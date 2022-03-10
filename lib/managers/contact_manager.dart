import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:fast_contacts/fast_contacts.dart' hide Contact;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:version/version.dart';

class ContactManager {
  factory ContactManager() {
    return _manager;
  }

  static final ContactManager _manager = ContactManager._internal();
  static final tag = 'ContactManager';

  ContactManager._internal();

  /// The master list of contact objects
  List<Contact> contacts = [];

  /// A flag letting everyone know if we've fetched contacts at least once
  bool hasFetchedContacts = false;

  /// Maps emails to contact objects
  final Map<String, Contact> _emailToContactMap = {};

  /// Maps phone numbers to contact objects
  final Map<String, Contact> _phoneToContactMap = {};

  /// Maps addresses to formatted versions
  final Map<String, String> _addressToFormatted = {};

  // We need these so we don't have threads fetching at the same time
  Completer<bool>? getContactsFuture;
  Completer? getAvatarsFuture;
  int lastRefresh = 0;

  Future<bool> canAccessContacts({headless = false}) async {
    if (kIsWeb || kIsDesktop) {
      String? str = await SettingsManager().getServerVersion();
      if (str == null) return false;
      Version version = Version.parse(str);
      int sum = version.major * 100 + version.minor * 21 + version.patch;
      return sum >= 42;
    }

    try {
      PermissionStatus status = await Permission.contacts.status;
      if (status.isGranted) return true;
      Logger.info("Contacts Permission Status: ${status.toString()}", tag: tag);

      // If it's not permanently denied, request access
      if (!status.isPermanentlyDenied) {
        if (headless) {
          Logger.warn('Unable to prompt for contact access since headless = true');
        } else {
          return (await Permission.contacts.request()).isGranted;
        }
      } else {
        Logger.info("Contacts permissions are permanently denied...", tag: tag);
      }
    } catch (ex) {
      Logger.error("Error getting access to contacts!", tag: tag);
      Logger.error(ex.toString(), tag: tag);
    }

    return false;
  }

  String? findAddressMatch(String address) {
    String addr = address.numericOnly();

    // If the address exists in the map, return it as-is
    if (_phoneToContactMap.containsKey(addr)) return address;

    // If the address doesn't exist, we need to match the last 'x' digits.
    // We are going to try as many times as indexes in `matchList`.
    // For each number in `matchList` we try and match the last 'x' digits
    List<int> matchList = [7, 6, 5];
    for (int i in matchList) {
      if (addr.length < i) continue;
      String lastDigits = addr.substring(addr.length - i, addr.length);
      String? addressMatch = _phoneToContactMap.keys.firstWhereOrNull((i) => i.endsWith(lastDigits));
      if (addressMatch == null) continue;
      return addressMatch;
    }

    // If no matches are found, return null
    return null;
  }

  /// Fetches contact from the cache maps
  Contact? getContact(String? address) {
    if (address == null || address.isEmpty || address == "John Doe") return null;
    if (address.contains('@')) {
      return _emailToContactMap[address];
    }

    String saniAddress = address.numericOnly();
    Contact? match = _phoneToContactMap[saniAddress];

    // If we can't find the match, we want to match based on last 7 digits
    if (match == null) {
      String? matchedAddress = findAddressMatch(saniAddress);
      if (matchedAddress != null) {
        match = _phoneToContactMap[matchedAddress];
      }
    }

    return match;
  }

  Future<bool> loadContacts({headless = false, force = false, loadAvatars = false}) async {
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
    if (!(await canAccessContacts(headless: headless))) return false;

    // Set the last refresh time
    lastRefresh = now;

    // Start a new completer
    getContactsFuture = Completer<bool>();

    // Fetch the current list of contacts
    Logger.info("Fetching contacts", tag: tag);
    if (!kIsWeb && !kIsDesktop) {
      contacts = (await FastContacts.allContacts)
          .map((e) => Contact(
                displayName: e.displayName,
                emails: e.emails,
                phones: e.phones,
                structuredName: e.structuredName,
                id: e.id,
              ))
          .toList();
    } else {
      await fetchContactsDesktop();
    }

    // This is _reuquired_ for the `getContacts()` function to be used
    await buildCacheMap();

    loadFakeInfo();

    Logger.info("Finished fetching contacts (${contacts.length})", tag: tag);
    Logger.info("Contacts map size: ${_emailToContactMap.length + _phoneToContactMap.length}", tag: tag);
    if (getContactsFuture != null && !getContactsFuture!.isCompleted) {
      hasFetchedContacts = true;
      getContactsFuture!.complete(true);
    }

    // Lazy load thumbnails after rendering initial contacts.
    if (loadAvatars) {
      getAvatars();
    }

    return getContactsFuture!.future;
  }

  Future<void> buildCacheMap({loadFromChats = true, loadFormatted = true}) async {
    for (Contact c in contacts) {
      for (String p in c.phones) {
        String saniPhone = p.numericOnly();
        _phoneToContactMap[saniPhone] = c;

        if (loadFormatted) {
          _addressToFormatted[saniPhone] = await formatPhoneNumber(saniPhone);
        }
      }

      for (String e in c.emails) {
        _emailToContactMap[e] = c;
      }
    }

    // Get loaded chats and add participants to the formatted address cache.
    // This is in case any members of chats that don't have associated contacts,
    // still get their address formatted correctly.
    List<Chat> chats = ChatBloc().chats.isEmpty && !kIsWeb ? await Chat.getChats(limit: 1000) : ChatBloc().chats;
    for (Chat c in chats) {
      for (Handle h in c.participants) {
        if (!h.address.contains('@')) {
          String saniPhone = h.address.numericOnly();
          if (!_addressToFormatted.containsKey(saniPhone)) {
            _addressToFormatted[saniPhone] = await formatPhoneNumber(saniPhone);
          }
        }
      }
    }
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
          logger?.call(
              "Parsing contact: ${[map['firstName'], map['lastName']].where((e) => e != null).toList().join(" ")}");
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

  void loadFakeInfo() {
    for (Contact c in contacts) {
      c.fakeName ??= faker.person.name();

      if (c.phones.isNotEmpty || c.emails.isEmpty) {
        c.fakeAddress ??=
            faker.phoneNumber.random.fromPattern(["+###########", "+# ###-###-####", "+# (###) ###-####"]);
      } else if (c.emails.isNotEmpty) {
        c.fakeAddress ??= faker.internet.email();
      }
    }
  }

  Future<void> getAvatars() async {
    if (getAvatarsFuture != null && !getAvatarsFuture!.isCompleted) {
      return getAvatarsFuture!.future;
    }

    // Create a new completer for this
    getAvatarsFuture = Completer();

    Logger.info("Fetching Avatars", tag: tag);
    for (Contact c in contacts) {
      try {
        await loadContactAvatar(c);
      } catch (ex) {
        Logger.warn('Failed to fetch avatar for contact (${c.displayName}): ${ex.toString()}');
      }
    }

    Logger.info("Finished fetching avatars", tag: tag);
    getAvatarsFuture!.complete();
    return getAvatarsFuture!.future;
  }

  Future<void> getAvatarsForChat(Chat chat) async {
    if (kIsDesktop || kIsWeb) return;
    if (chat.participants.isEmpty) {
      chat.getParticipants();
    }

    for (Handle h in chat.participants) {
      Contact? contact = getContact(h.address);
      if (contact != null) {
        await loadContactAvatar(contact);
      }
    }
  }

  /// Fetch a contact's avatar, first trying the full size image, then the thumbnail if unavailable
  Future<void> loadContactAvatar(Contact contact) async {
    if (kIsDesktop || kIsWeb) return;
    contact.avatar.value ??= await FastContacts.getContactImage(contact.id);
    if (contact.avatarHiRes.value == null) {
      FastContacts.getContactImage(contact.id, size: ContactImageSize.fullSize).then((value) {
        contact.avatarHiRes.value = value;
      }).onError((error, stackTrace) => null);
    }
  }

  String getContactTitle(Handle? handle) {
    if (handle == null) return "You";
    String address = handle.address;
    Contact? contact = getContact(address);
    if (contact != null) return contact.displayName;


    if (address.startsWith("e:")) {
      address = address.substring(2);
    }

    try {
      bool isEmailAddr = address.isEmail;
      if (!isEmailAddr) {
        return _addressToFormatted[address.numericOnly()] ?? address;
      }
    } catch (ex) {
      Logger.error('Failed to getContactTitle(), for address, "${handle.address}": ${ex.toString()}', tag: tag);
    }

    return address;
  }

  /// Converts a string into initials
  ///
  /// Transform something like "John Doe" to "JD"
  String? _getInitials(String value, {int maxCharCount = 2}) {
    // Remove any numbers, certain symbols, and non-alphabet characters
    String importantChars = value.replaceAll(RegExp(r'[^a-zA-Z _-]'), "").trim();
    if (importantChars.isEmpty) return null;

    // Split by a space or special character delimiter, take each of the items and
    // reduce it to just the capitalized first letter. Then join the array by an empty char
    String reduced = importantChars
        .split(RegExp(r' |-|_'))
        .take(maxCharCount)
        .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
        .join('');
    return reduced.isEmpty ? null : reduced;
  }

  String? getContactInitials(Handle? handle) {
    if (handle == null) return "Y";
    Contact? contact = getContact(handle.address);
    late String comparedTo;

    // If we have a contact, use the display name to get the initials
    if (contact != null) {
      comparedTo = contact.displayName;
    } else if (handle.address.contains('@')) {
      // If we don't have a contact and the address is an email, return the first letter.
      // Remove the `e:` prefix if necessary
      String saniAddr = handle.address;
      if (saniAddr.startsWith('e:')) {
        saniAddr = saniAddr.substring(2);
      }

      return saniAddr[0].toUpperCase();
    } else {
      // If we don't have a contact, and it's not an email, use the address
      // to generate the initials
      comparedTo = handle.address;
    }

    return _getInitials(comparedTo);
  }
}
