import 'dart:typed_data';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/contact_v2_actions.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:get_it/get_it.dart';

/// ContactV2Interface provides the bridge between the main isolate and the GlobalIsolate
/// for all ContactV2 operations. This follows the architecture outlined in FR-1.md
class ContactV2Interface {
  /// Builds the account-filter portion of the sync data map from the
  /// user-selected account (Contacts Management page). Empty when unset —
  /// "all accounts" is the default, unfiltered behavior.
  static Map<String, dynamic> _accountFilterData() {
    final accountName = SettingsSvc.settings.contactSyncAccountName.value;
    final accountType = SettingsSvc.settings.contactSyncAccountType.value;
    if (accountName == null || accountType == null) return {};
    return {'accountName': accountName, 'accountType': accountType};
  }

  /// Fetch all contacts from the device and match them to existing handles
  /// This operation is executed in the GlobalIsolate to prevent UI jank
  ///
  /// Returns a list of handle IDs that were affected by the matching
  static Future<List<int>> syncContactsToHandles() async {
    final data = _accountFilterData();
    if (isIsolate) {
      return await ContactV2Actions.syncContactsToHandles(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<List<int>>(IsolateRequestType.syncContactsToHandles, input: data);
    }
  }

  /// Same as [syncContactsToHandles], but also returns the device contact
  /// count and matched-contact count for diagnostic display (Contacts
  /// Management page's manual refresh).
  static Future<Map<String, dynamic>> syncContactsToHandlesWithStats() async {
    final data = _accountFilterData();
    if (isIsolate) {
      return await ContactV2Actions.syncContactsToHandlesWithStats(data);
    } else {
      return await GetIt.I<GlobalIsolate>()
          .send<Map<String, dynamic>>(IsolateRequestType.syncContactsToHandlesWithStats, input: data);
    }
  }

  /// Returns each on-device account with contacts, plus a live contact count
  /// per account (`{'name': String, 'type': String, 'count': int}`), for the
  /// Contacts Management page's account selector.
  static Future<List<Map<String, dynamic>>> getAccountContactCounts() async {
    if (isIsolate) {
      return await ContactV2Actions.getAccountContactCounts(<String, dynamic>{});
    } else {
      // Received as untyped List<dynamic> across the isolate boundary — cast each
      // entry explicitly rather than requesting List<Map<String, dynamic>> from
      // send<T>() directly, since a concrete nested-generic type isn't guaranteed
      // to survive the isolate message copy.
      final result = await GetIt.I<GlobalIsolate>()
          .send<List<dynamic>>(IsolateRequestType.getAccountContactCounts, input: <String, dynamic>{});
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  /// Get all stored ContactV2 IDs (nativeContactId) for comparison
  /// Used by the periodic checker to detect changes
  static Future<List<String>> getStoredContactIds() async {
    if (isIsolate) {
      return await ContactV2Actions.getStoredContactIds(<String, dynamic>{});
    } else {
      return await GetIt.I<GlobalIsolate>()
          .send<List<String>>(IsolateRequestType.getStoredContactIds, input: <String, dynamic>{});
    }
  }

  /// Find a single ContactV2 by native contact ID
  static Future<ContactV2?> findOneContact({
    required String nativeContactId,
  }) async {
    final data = {
      'nativeContactId': nativeContactId,
    };

    final int? id;
    if (isIsolate) {
      id = await ContactV2Actions.findOneContact(data);
    } else {
      id = await GetIt.I<GlobalIsolate>().send<int?>(IsolateRequestType.findOneContact, input: data);
    }

    if (id == null) return null;
    return Database.contactsV2.get(id);
  }

  /// Get ContactV2 entities for a list of Handle IDs
  static Future<List<ContactV2>> getContactsForHandles({
    required List<int> handleIds,
  }) async {
    final data = {
      'handleIds': handleIds,
    };

    final List<int> ids;
    if (isIsolate) {
      ids = await ContactV2Actions.getContactsForHandles(data);
    } else {
      ids = await GetIt.I<GlobalIsolate>().send<List<int>>(IsolateRequestType.getContactsForHandles, input: data);
    }

    return Database.contactsV2.getMany(ids).whereType<ContactV2>().toList();
  }

  /// Get a contact by address (email or phone number)
  static Future<ContactV2?> getContactByAddress({
    required String address,
  }) async {
    final data = {
      'address': address,
    };

    final int? id;
    if (isIsolate) {
      id = await ContactV2Actions.getContactByAddress(data);
    } else {
      id = await GetIt.I<GlobalIsolate>().send<int?>(IsolateRequestType.getContactByAddress, input: data);
    }

    if (id == null) return null;
    return Database.contactsV2.get(id);
  }

  /// Get all contacts from the database
  static Future<List<ContactV2>> getAllContacts() async {
    final List<int> ids;
    if (isIsolate) {
      ids = await ContactV2Actions.getAllContacts(<String, dynamic>{});
    } else {
      ids =
          await GetIt.I<GlobalIsolate>().send<List<int>>(IsolateRequestType.getAllContacts, input: <String, dynamic>{});
    }

    return Database.contactsV2.getMany(ids).whereType<ContactV2>().toList();
  }

  /// Returns live flutter_contacts Contact objects so the chat creator can
  /// display contacts not yet linked to existing handles.
  static Future<List<fc.Contact>> getAddressBook() async {
    return await fc.FlutterContacts.getAll(
        properties: {...fc.ContactProperties.allProperties, fc.ContactProperty.photoThumbnail});
  }

  /// Get avatar data for a contact
  static Future<Uint8List?> getContactAvatar({
    required String nativeContactId,
  }) async {
    final data = {
      'nativeContactId': nativeContactId,
    };

    if (isIsolate) {
      return await ContactV2Actions.getContactAvatar(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<Uint8List?>(IsolateRequestType.getContactAvatar, input: data);
    }
  }

  /// Uploads contacts to the server
  static Future<void> uploadContacts(List<Map<String, dynamic>> contacts) async {
    final data = {'contacts': contacts};

    if (isIsolate) {
      return await ContactV2Actions.uploadContacts(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.uploadContactsV2, input: data);
    }
  }
}
