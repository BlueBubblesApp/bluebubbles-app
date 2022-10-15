import 'dart:convert';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:faker/faker.dart';
import 'package:fast_contacts/fast_contacts.dart' hide Contact, StructuredName;
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

ContactsService cs = Get.isRegistered<ContactsService>() ? Get.find<ContactsService>() : Get.put(ContactsService());

class ContactsService extends GetxService {
  final tag = "ContactsService";
  /// The master list of contact objects
  List<Contact> contacts = [];
  List<Handle> handles = [];

  Future<void> init() async {
    if (!kIsWeb) {
      contacts = Contact.getContacts();
      handles = Handle.find();
    } else {
      await fetchNetworkContacts();
    }
  }

  Future<bool> canAccessContacts() async {
    if (kIsWeb || kIsDesktop) {
      int versionCode = (await settings.getServerDetails()).item4;
      return versionCode >= 42;
    } else {
      return (await Permission.contacts.status).isGranted;
    }
  }

  Future<void> refreshContacts() async {
    final contacts = [];
    if (kIsWeb || kIsDesktop) {
      contacts.addAll(await fetchNetworkContacts());
    } else {
      contacts.addAll((await FastContacts.allContacts)
          .map((e) => Contact(
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
    }
  }

  Future<List<Contact>> fetchNetworkContacts({Function(String)? logger}) async {
    final contacts = <Contact>[];
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
          contacts.add(Contact(
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

    /*await buildCacheMap();
    EventDispatcher().emit('update-contacts', null);*/

    logger?.call("Fetching contacts (with avatars)...");
    try {
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

              if (match && contact.getAvatar() == null) {
                contact.avatar = base64Decode(map['avatar'].toString());
                contact.avatarHiRes = base64Decode(map['avatar'].toString());
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
    return contacts;
  }
}