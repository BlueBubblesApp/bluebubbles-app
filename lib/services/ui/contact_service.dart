import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:fast_contacts/fast_contacts.dart' hide Contact, StructuredName;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

ContactsService cs = Get.isRegistered<ContactsService>() ? Get.find<ContactsService>() : Get.put(ContactsService());

class ContactsService extends GetxService {
  final tag = "ContactsService";
  /// The master list of contact objects
  List<Contact> contacts = [];

  Future<void> init() async {
    if (!kIsWeb) {
      contacts = Contact.getContacts();
    } else {
      await fetchNetworkContacts();
    }
  }

  Future<bool> canAccessContacts() async {
    if (kIsWeb || kIsDesktop) {
      int versionCode = (await ss.getServerDetails()).item4;
      return versionCode >= 42;
    } else {
      return (await Permission.contacts.status).isGranted;
    }
  }

  Future<List<List<int>>> refreshContacts() async {
    if (!(await cs.canAccessContacts())) return [];
    final _contacts = <Contact>[];
    final changedIds = <List<int>>[<int>[], <int>[]];
    if (kIsWeb || kIsDesktop) {
      _contacts.addAll(await cs.fetchNetworkContacts());
    } else {
      _contacts.addAll((await FastContacts.allContacts).map((e) => Contact(
        displayName: e.displayName,
        emails: e.emails,
        phones: e.phones,
        structuredName: e.structuredName == null ? null : StructuredName(
          namePrefix: e.structuredName!.namePrefix,
          givenName: e.structuredName!.givenName,
          middleName: e.structuredName!.middleName,
          familyName: e.structuredName!.familyName,
          nameSuffix: e.structuredName!.nameSuffix,
        ),
        id: e.id,
      )));
      // get avatars
      for (Contact c in _contacts) {
        try {
          c.avatar = await FastContacts.getContactImage(c.id, size: ContactImageSize.fullSize);
        } catch (_) {
          c.avatar = await FastContacts.getContactImage(c.id);
        }
      }
    }
    // compare loaded contacts to db contacts
    if (!kIsWeb) {
      final dbContacts = contactBox.getAll();
      // save any updated contacts
      for (Contact c in dbContacts) {
        final refreshedContact = _contacts.firstWhereOrNull((element) => element.id == c.id);
        if (refreshedContact != null) {
          refreshedContact.dbId = c.dbId;
          if (c != refreshedContact) {
            changedIds.first.add(c.dbId!);
            refreshedContact.save();
          }
        }
      }
      // save any new contacts
      final newContacts = _contacts.where((e) => !dbContacts.map((e2) => e2.id).contains(e.id)).toList();
      if (newContacts.isNotEmpty) {
        final ids = contactBox.putMany(newContacts);
        for (int i = 0; i < newContacts.length; i++) {
          newContacts[i].dbId = ids[i];
        }
      }
    }
    // load stored handles
    final List<Handle> handles = [];
    if (kIsWeb) {
      handles.addAll(chats.webCachedHandles);
    } else {
      handles.addAll(handleBox.getAll());
    }
    // get formatted addresses
    for (Handle h in handles) {
      if (!h.address.contains("@") && h.formattedAddress == null) {
        h.formattedAddress = await formatPhoneNumber(h.address);
      }
    }
    // match handles to contacts and save match
    final handlesToSearch = List<Handle>.from(handles);
    for (Contact c in _contacts) {
      final handles = cs.matchContactToHandles(c, handlesToSearch);
      final addressesAndServices = handles.map((e) => e.uniqueAddressAndService).toList();
      if (handles.isNotEmpty) {
        handlesToSearch.removeWhere((e) => addressesAndServices.contains(e.uniqueAddressAndService));

        // we have changes if the handle doesn't have an associated contact,
        // even if there were no contact changes in the first place
        final matches = handles.where((e) => addressesAndServices.contains(e.uniqueAddressAndService));
        for (Handle h in matches) {
          if (kIsWeb) {
            h.webContact = c;
            continue;
          }

          if (h.contactRelation.target == null) {
            changedIds.last.add(h.id!);
          }

          h.contactRelation.target = c;
        }
      }
    }
    if (!kIsWeb) {
      Handle.bulkSave(handles);
    }
    if (kIsWeb) {
      contacts = _contacts;
    }
    // only return contacts if things changed (or on web)
    return changedIds;
  }

  Future<void> resetContacts() async {
    if (!(await cs.canAccessContacts())) return;
    List<Contact> _contacts = [];

    // Clear all the contacts from the contact box (non-web only)
    if (!kIsWeb) {
      contactBox.removeAll();
    }

    // Fetch all the contacts (network and/or DB)
    _contacts = await cs.fetchAllContacts();

    // Save the contacts to the contactBox (non-web only)
    if (!kIsWeb) {
      List<int> contactIds = contactBox.putMany(_contacts);
      
      // Just in case, if the length of IDs we get back don't match what
      // we tried to save, just refresh them from the DB entirely.
      // Otherwise, just insert t
      if (contactIds.length == _contacts.length) {
        for (int i = 0; i < contactIds.length; i++) {
          _contacts[i].dbId = contactIds[i];
        }
      } else {
        _contacts = await cs.fetchAllContacts();
      }
    }

    // Load handles (DB or web-cache)
    final List<Handle> handles = [];
    if (kIsWeb) {
      handles.addAll(chats.webCachedHandles);
    } else {
      handles.addAll(handleBox.getAll());
    }

    // Set the formatted addresses.
    // Clear all contact relations (DB) and/or web contacts
    for (Handle h in handles) {
      if (!h.address.contains("@") && h.formattedAddress == null) {
        h.formattedAddress = await formatPhoneNumber(h.address);
      }

      if (kIsWeb) {
        h.webContact = null;
      } else {
        h.contactRelation.target = null;
      }
    }

    // Save the handles without contact relationships (DB only)
    if (!kIsWeb) {
      handleBox.putMany(handles);
    }

    // Match handles to contacts and save match
    for (Contact c in _contacts) {
      // Find matching handles
      final matchingHandles = cs.matchContactToHandles(c, handles);
      if (matchingHandles.isEmpty) continue;

      // Get a list of the unique addresses for handles matching the contact
      final addressesAndServices = matchingHandles.map((e) => e.uniqueAddressAndService).toList();

      // Insert the relationship for all handles that have contacts
      final matches = handles.where((e) => addressesAndServices.contains(e.uniqueAddressAndService));
      for (Handle h in matches) {
        if (kIsWeb) {
          h.webContact = c;
        } else {
          h.contactRelation.target = c;
        }
      }
    }

    // Save all the updated handles (with contacts now)
    if (!kIsWeb) {
      Handle.bulkSave(handles);
    }

    // Only store the contacts globally if web.
    // We don't need them for Android/Desktop because
    // the contacts should be stored with the handles
    if (kIsWeb) {
      contacts = _contacts;
    }
  }

  Future<List<Contact>> fetchAllContacts() async {
    final _contacts = <Contact>[];

    // Fetch all the contacts
    if (kIsWeb || kIsDesktop) {
      _contacts.addAll(await cs.fetchNetworkContacts());
    } else {
      _contacts.addAll((await FastContacts.allContacts).map((e) => Contact(
        displayName: e.displayName,
        emails: e.emails,
        phones: e.phones,
        structuredName: e.structuredName == null ? null : StructuredName(
          namePrefix: e.structuredName!.namePrefix,
          givenName: e.structuredName!.givenName,
          middleName: e.structuredName!.middleName,
          familyName: e.structuredName!.familyName,
          nameSuffix: e.structuredName!.nameSuffix,
        ),
        id: e.id,
      )));

      // Get avatars on ANdroid
      for (Contact c in _contacts) {
        try {
          c.avatar = await FastContacts.getContactImage(c.id, size: ContactImageSize.fullSize);
        } catch (_) {
          c.avatar = await FastContacts.getContactImage(c.id);
        }
      }
    }

    return _contacts;
  }

  void completeContactsRefresh(List<Contact> refreshedContacts, {List<List<int>>? reloadUI}) {
    if (refreshedContacts.isNotEmpty) {
      contacts = refreshedContacts;
      if (reloadUI != null) {
        eventDispatcher.emit('update-contacts', reloadUI);
      }
    }
  }

  List<Handle> matchContactToHandles(Contact c, List<Handle> handles) {
    final numericPhones = c.phones.map((e) => e.numericOnly()).toList();
    List<Handle> handleMatches = [];
    // multiply phones by 3 because a phone can be matched to iMessage / SMS / Android SMS
    int maxResults = c.phones.length * 3 + c.emails.length;
    for (Handle h in handles) {
      // Match emails
      if (h.address.contains("@") && c.emails.contains(h.address)) {
        handleMatches.add(h);
        continue;
      }

      final numericAddress = h.address.numericOnly();

      // Match phone numbers (exact)
      if (c.phones.contains(numericAddress)) {
        handleMatches.add(h);
        continue;
      }

      // try to match last 15 - 7 digits
      for (String p in numericPhones) {
        final matchLengths = [15, 14, 13, 12, 11, 10, 9, 8, 7];
        if (matchLengths.contains(p.length) && numericAddress.endsWith(p)) {
          handleMatches.add(h);
          continue;
        }
      }

      if (handleMatches.length >= maxResults) break;
    }

    return handleMatches;
  }

  Contact? matchHandleToContact(Handle h) {
    Contact? contact;
    final numericAddress = h.address.numericOnly();
    for (Contact c in contacts) {
      final numericPhones = c.phones.map((e) => e.numericOnly()).toList();
      if (h.address.contains("@") && c.emails.contains(h.address)) {
        contact = c;
        break;
      } else {
        // if address is direct match
        if (c.phones.contains(numericAddress)) {
          contact = c;
          break;
        }
        // try to match last 11 - 7 digits
        for (String p in numericPhones) {
          final matchLengths = [11, 10, 9, 8, 7];
          if (matchLengths.contains(p.length) && numericAddress.endsWith(p)) {
            contact = c;
            break;
          }
        }
        if (contact != null) break;
      }
    }
    return contact;
  }

  Contact? getContact(String address) {
    final tempHandle = Handle(
      address: address
    );
    return matchHandleToContact(tempHandle);
  }

  Future<List<Contact>> fetchNetworkContacts({Function(String)? logger}) async {
    final networkContacts = <Contact>[];
    // refresh UI on web without waiting for avatars
    if (kIsWeb) {
      logger?.call("Fetching contacts (no avatars)...");
      try {
        final response = await http.contacts();

        if (response.statusCode == 200 && !isNullOrEmpty(response.data['data'])!) {
          logger?.call("Found contacts!");

          for (Map<String, dynamic> map in response.data['data']) {
            final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
            final emails = (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
            final phones = (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
            logger?.call("Parsing contact: $displayName");
            networkContacts.add(Contact(
              id: (map['id'] ?? (phones.isNotEmpty ? phones : emails)).toString(),
              displayName: displayName,
              emails: emails,
              phones: phones,
            ));
          }
        } else {
          logger?.call("No contacts found!");
        }
        logger?.call("Finished contacts sync (no avatars)");
      } catch (e, s) {
        logger?.call("Got exception: $e");
        logger?.call(s.toString());
      }
      final handlesToSearch = List<Handle>.from(chats.webCachedHandles);
      for (Contact c in contacts) {
        final handles = cs.matchContactToHandles(c, handlesToSearch);
        final addressesAndServices = handles.map((e) => e.uniqueAddressAndService).toList();
        if (handles.isNotEmpty) {
          handlesToSearch.removeWhere((e) => addressesAndServices.contains(e.uniqueAddressAndService));
          for (Handle h in handles) {
            if (addressesAndServices.contains(h.uniqueAddressAndService)) {
              h.webContact = c;
            }
          }
        }
      }
      eventDispatcher.emit('update-contacts', null);
    }

    logger?.call("Fetching contacts (with avatars)...");
    try {
      if (kIsWeb) {
        http.contacts(withAvatars: true).then((response) async {
          if (!isNullOrEmpty(response.data['data'])!) {
            logger?.call("Found contacts!");
            for (Map<String, dynamic> map in response.data['data'].where((e) => !isNullOrEmpty(e['avatar'])!)) {
              final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
              logger?.call("Adding avatar for contact: $displayName");
              final emails = (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
              final phones = (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
              for (Contact contact in contacts) {
                bool match = contact.id == (map['id'] ?? (phones.isNotEmpty ? phones : emails)).toString();

                // Ensure contact first name matches to avoid issues with shared numbers (landlines)
                if (!match && map['firstName'] != null && !contact.displayName.startsWith(map['firstName'])) continue;

                List<String> addresses = [...contact.phones, ...contact.emails];
                List<String> _addresses = [...phones, ...emails];
                for (String a in addresses) {
                  if (match) {
                    break;
                  }
                  String? formatA = a.contains("@") ? a.toLowerCase() : await formatPhoneNumber(a.numericOnly());
                  if (formatA.isEmpty) continue;
                  for (String _a in _addresses) {
                    String? _formatA = _a.contains("@") ? _a.toLowerCase() : await formatPhoneNumber(_a.numericOnly());
                    if (formatA == _formatA) {
                      match = true;
                      break;
                    }
                  }
                }

                if (match && contact.avatar == null) {
                  contact.avatar = base64Decode(map['avatar'].toString());
                }
              }
            }
          } else {
            logger?.call("No contacts found!");
          }
          logger?.call("Finished contacts sync (with avatars)");
        });
      } else {
        final response = await http.contacts(withAvatars: true);

        if (response.statusCode == 200 && !isNullOrEmpty(response.data['data'])!) {
          logger?.call("Found contacts!");
          for (Map<String, dynamic> map in response.data['data']) {
            final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
            final emails = (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
            final phones = (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
            logger?.call("Parsing contact: $displayName");
            networkContacts.add(Contact(
              id: (map['id'] ?? (phones.isNotEmpty ? phones : emails)).toString(),
              displayName: displayName,
              emails: emails,
              phones: phones,
              avatar: !isNullOrEmpty(map['avatar'])! ? base64Decode(map['avatar'].toString()) : null,
            ));
          }
        } else {
          logger?.call("No contacts found!");
        }
        logger?.call("Finished contacts sync (with avatars)");
      }
    } catch (e, s) {
      logger?.call("Got exception: $e");
      logger?.call(s.toString());
    }
    return networkContacts;
  }
}
