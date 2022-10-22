import 'dart:convert';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/repository/models/models.dart';
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
  List<Handle> handles = [];

  Future<void> init({bool headless = false}) async {
    if (headless) return;
    if (!kIsWeb) {
      contacts = Contact.getContacts();
      handles = Handle.find();
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

  Future<List<Map<String, dynamic>>> refreshContacts({bool reloadUI = true}) async {
    if (!(await cs.canAccessContacts())) return [];
    final contacts = <Contact>[];
    bool hasChanges = false;
    if (kIsWeb || kIsDesktop) {
      contacts.addAll(await cs.fetchNetworkContacts());
    } else {
      contacts.addAll((await FastContacts.allContacts).map((e) => Contact(
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
      for (Contact c in contacts) {
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
        final refreshedContact = contacts.firstWhereOrNull((element) => element.id == c.id);
        if (refreshedContact != null && c != refreshedContact) {
          hasChanges = true;
          refreshedContact.save();
        }
      }
      // save any new contacts
      final newContacts = contacts.where((e) => !dbContacts.map((e) => e.id).contains(e.id)).toList();
      if (newContacts.isNotEmpty) {
        hasChanges = true;
        contactBox.putMany(newContacts);
      }
    }
    // load stored handles
    final List<Handle> handles = [];
    if (kIsWeb) {
      handles.addAll(ChatBloc().cachedHandles);
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
    for (Contact c in contacts) {
      final handle = cs.matchContactToHandle(c, handlesToSearch);
      if (handle != null) {
        handlesToSearch.removeWhere((e) => e.address == handle.address);
        if (!kIsWeb) {
          // we have changes if the handle doesn't have an associated contact,
          // even if there were no contact changes in the first place
          if (handles.firstWhere((e) => e.address == handle.address).contactRelation.target == null) {
            hasChanges = true;
          }
          handles.firstWhere((e) => e.address == handle.address).contactRelation.target = c;
        } else {
          handles.firstWhere((e) => e.address == handle.address).webContact = c;
        }
      }
    }
    if (!kIsWeb) {
      Handle.bulkSave(handles);
    }
    // only return contacts if things changed (or on web)
    return kIsWeb || hasChanges ? contacts.map((e) => e.toMap()).toList() : [];
  }

  void completeContactsRefresh(List<Contact> refreshedContacts, {bool reloadUI = true}) {
    handles = Handle.find();
    if (refreshedContacts.isNotEmpty) {
      contacts = refreshedContacts;
      if (reloadUI) {
        eventDispatcher.emit('update-contacts', null);
      }
    }
  }

  Handle? matchContactToHandle(Contact c, List<Handle> handles) {
    final numericPhones = c.phones.map((e) => e.numericOnly()).toList();
    Handle? handle;
    for (Handle h in handles) {
      if (h.address.contains("@") && c.emails.contains(h.address)) {
        handle = h;
        break;
      } else {
        final numericAddress = h.address.numericOnly();
        // if address is direct match
        if (c.phones.contains(numericAddress)) {
          handle = h;
          break;
        }
        // try to match last 11 - 7 digits
        for (String p in numericPhones) {
          final matchLengths = [11, 10, 9, 8, 7];
          if (matchLengths.contains(p.length) && numericAddress.endsWith(p)) {
            handle = h;
            break;
          }
        }
        if (handle != null) break;
      }
    }
    return handle;
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
        // try to match last 10 - 7 digits
        for (String p in numericPhones) {
          final matchLengths = [10, 9, 8, 7];
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
      final handlesToSearch = List<Handle>.from(ChatBloc().cachedHandles);
      for (Contact c in contacts) {
        final handle = cs.matchContactToHandle(c, handlesToSearch);
        if (handle != null) {
          handlesToSearch.removeWhere((e) => e.address == handle.address);
          handles.firstWhere((e) => e.address == handle.address).webContact = c;
        }
      }
      eventDispatcher.emit('update-contacts', null);
    }

    logger?.call("Fetching contacts (with avatars)...");
    try {
      http.contacts(withAvatars: true).then((response) async {
        if (!isNullOrEmpty(response.data['data'])!) {
          logger?.call("Found contacts!");
          // desktop, save everything; web, only check with contacts avatars
          if (!kIsWeb) {
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
          }
        } else {
          logger?.call("No contacts found!");
        }
        logger?.call("Finished contacts sync (with avatars)");
      });
    } catch (e, s) {
      logger?.call("Got exception: $e");
      logger?.call(s.toString());
    }
    return networkContacts;
  }
}