import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:path/path.dart' as p;

/// ContactV2Actions - Isolate-side logic for the new contact service
/// All operations here run in the GlobalIsolate to prevent UI jank
/// This follows the architecture outlined in FR-1.md
class ContactV2Actions {
  /// Completer to ensure syncContactsToHandles only runs once at a time
  static Completer<_ContactSyncStats>? _syncCompleter;

  /// Fetch all contacts from device and match them to existing handles
  /// This is the main operation described in Section II.A of FR-1.md
  ///
  /// Returns only the affected handle IDs — the shape every existing caller
  /// depends on. Use [syncContactsToHandlesWithStats] for the fetch/match
  /// counts as well (e.g. for diagnostic display).
  static Future<List<int>> syncContactsToHandles(dynamic data) async {
    final stats = await _syncContactsToHandlesInternal(data);
    return stats.affectedHandleIds;
  }

  /// Same operation as [syncContactsToHandles], but also returns the device
  /// contact count and matched-contact count — used by the Contacts
  /// Management page's manual refresh to show live diagnostic feedback.
  static Future<Map<String, dynamic>> syncContactsToHandlesWithStats(dynamic data) async {
    final stats = await _syncContactsToHandlesInternal(data);
    return stats.toMap();
  }

  static Future<_ContactSyncStats> _syncContactsToHandlesInternal(dynamic data) async {
    // If already processing, wait for the existing operation to complete
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      Logger.info('[ContactV2] Sync already in progress, waiting for completion...');
      return await _syncCompleter!.future;
    }

    // Create a new completer for this sync operation
    _syncCompleter = Completer<_ContactSyncStats>();

    // Optional account filter — set via the Contacts Management page. Null
    // means "all accounts" (the default, unfiltered behavior).
    final dataMap = data is Map ? data : const {};
    final accountName = dataMap['accountName'] as String?;
    final accountType = dataMap['accountType'] as String?;
    final account =
        (accountName != null && accountType != null) ? fc.Account(id: '', name: accountName, type: accountType) : null;

    final startTime = DateTime.now().millisecondsSinceEpoch;
    final affectedHandleIds = <int>[];
    int matchedContactCount = 0;

    try {
      List<fc.Contact> deviceContacts = [];
      List<ContactV2> networkContacts = [];
      final avatarPaths = <String, String?>{};

      if (kIsDesktop) {
        // Step 1: Fetch contacts from server
        Logger.info('[ContactV2] Starting contact fetch from server...');
        final response = await HttpSvc.contact.fetchAll(withAvatars: true);

        if (response.statusCode == 200 && !isNullOrEmpty(response.data['data'])) {
          for (Map<String, dynamic> map in response.data['data']) {
            final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
            final emails = (map['emails'] as List<dynamic>? ?? [])
                .map((e) => ContactEmail(address: e['address'].toString(), label: e['label']?.toString() ?? ''))
                .toList();
            final phones = (map['phoneNumbers'] as List<dynamic>? ?? [])
                .map((e) => ContactPhone(number: e['address'].toString(), label: e['label']?.toString() ?? ''))
                .toList();

            final contactId = (map['id'] ?? displayName).toString();
            if (!isNullOrEmpty(map['avatar'])) {
              try {
                final savedPath = await _saveContactAvatar(contactId, base64Decode(map['avatar'].toString()));
                // A null path means the disk write failed — leave the key unset so
                // the existing avatarPath is preserved instead of being wiped.
                if (savedPath != null) avatarPaths[contactId] = savedPath;
              } catch (_) {}
            } else {
              // Server reports no avatar for this contact — record the removal explicitly.
              avatarPaths[contactId] = null;
            }

            final nc = ContactV2(
              nativeContactId: contactId,
              displayName: displayName,
              firstName: map['firstName']?.toString(),
              lastName: map['lastName']?.toString(),
            );
            nc.phoneNumbers = phones;
            nc.emailAddresses = emails;
            networkContacts.add(nc);
          }
          Logger.info('[ContactV2] Fetched ${networkContacts.length} contacts from server');
        } else {
          Logger.info('[ContactV2] No server contacts found!');
        }
      } else {
        // Step 1: Fetch contacts using flutter_contacts
        Logger.info('[ContactV2] Starting contact fetch from device (flutter_contacts)'
            '${account != null ? ' for account ${account.name} (${account.type})' : ''}...');
        deviceContacts =
            await fc.FlutterContacts.getAll(properties: fc.ContactProperties.allProperties, account: account);
        Logger.info('[ContactV2] Fetched ${deviceContacts.length} contacts from device');
        if (deviceContacts.isEmpty) {
          // The OS permission check passed (we only reach this branch with contacts
          // access granted), yet the provider returned nothing. This is expected for
          // a genuinely empty address book, but it's also exactly what a privacy
          // sandbox that virtualizes the Contacts provider per-app (e.g. GrapheneOS's
          // Contact Scopes) looks like: the permission reads as granted, but the app
          // only sees whatever the user explicitly scoped in — zero, until configured.
          Logger.warn('[ContactV2] Contacts permission is granted but 0 device contacts were returned. '
              'If contacts are expected to exist, check for a privacy sandbox / contact '
              'scoping feature (e.g. GrapheneOS Contact Scopes) restricting this app\'s access.');
        }

        // Step 1.5: Pre-fetch and save all contact avatars (async operations must be done BEFORE transaction)
        for (final rawContact in deviceContacts) {
          if (rawContact.id == null) continue;
          try {
            final contactWithPhoto = await fc.FlutterContacts.get(
              rawContact.id!,
              properties: {fc.ContactProperty.photoFullRes, fc.ContactProperty.photoThumbnail},
            );
            final avatarData = contactWithPhoto?.photo?.fullSize ?? contactWithPhoto?.photo?.thumbnail;

            if (avatarData != null && avatarData.isNotEmpty) {
              final savedPath = await _saveContactAvatar(rawContact.id!, avatarData);
              // A null path means the disk write failed — leave the key unset so
              // the existing avatarPath is preserved instead of being wiped.
              if (savedPath != null) avatarPaths[rawContact.id!] = savedPath;
            } else if (contactWithPhoto != null) {
              // Fetch succeeded and the contact has no photo — record the removal explicitly.
              avatarPaths[rawContact.id!] = null;
            }
          } catch (e) {
            // Avatar fetch failed — leave the key unset so the existing avatarPath is kept.
          }
        }
      }

      // Step 2: Process and normalize contacts within a transaction (synchronous only!)
      Database.runInTransaction(TxMode.write, () {
        final contactsBox = Database.contactsV2;
        final handlesBox = Database.handles;
        final allHandles = handlesBox.getAll();

        final emailHandleMap = <String, List<Handle>>{};
        final phoneHandleMap = <String, List<Handle>>{};

        for (final handle in allHandles) {
          final isEmail = handle.address.contains('@');

          if (isEmail) {
            final normalized = ContactV2.normalizeEmail(handle.address);
            emailHandleMap.putIfAbsent(normalized, () => []).add(handle);

            if (handle.formattedAddress != null) {
              final formattedNormalized = ContactV2.normalizeEmail(handle.formattedAddress!);
              if (formattedNormalized != normalized) {
                emailHandleMap.putIfAbsent(formattedNormalized, () => []).add(handle);
              }
            }
          } else {
            // For phones, generate all variants and map them
            final variants = getPhoneNumberVariants(handle.address);
            for (final variant in variants) {
              phoneHandleMap.putIfAbsent(variant, () => []).add(handle);
            }

            if (handle.formattedAddress != null) {
              final formattedVariants = getPhoneNumberVariants(handle.formattedAddress!);
              for (final variant in formattedVariants) {
                phoneHandleMap.putIfAbsent(variant, () => []).add(handle);
              }
            }
          }
        }

        Logger.info(
            '[ContactV2] Built lookup maps: ${emailHandleMap.length} email keys, ${phoneHandleMap.length} phone variant keys');

        for (final rawContact in [...deviceContacts, ...networkContacts]) {
          // Normalize addresses
          final normalizedAddresses = <String>{};

          // Different data objects for desktop/mobile
          if (rawContact is fc.Contact) {
            // Add normalized phone numbers
            for (final phone in rawContact.phones) {
              final normalized = ContactV2.normalizePhoneNumber(phone.number);
              if (normalized.isNotEmpty) {
                normalizedAddresses.add(normalized);
              }
            }

            // Add normalized emails
            for (final email in rawContact.emails) {
              final normalized = ContactV2.normalizeEmail(email.address);
              if (normalized.isNotEmpty) {
                normalizedAddresses.add(normalized);
              }
            }
          } else if (rawContact is ContactV2) {
            // Add normalized phone numbers
            for (final phone in rawContact.phoneNumbers) {
              final normalized = ContactV2.normalizePhoneNumber(phone.number);
              if (normalized.isNotEmpty) {
                normalizedAddresses.add(normalized);
              }
            }

            // Add normalized emails
            for (final email in rawContact.emailAddresses) {
              final normalized = ContactV2.normalizeEmail(email.address);
              if (normalized.isNotEmpty) {
                normalizedAddresses.add(normalized);
              }
            }
          }

          if (normalizedAddresses.isEmpty) continue;

          String contactId = "";
          String displayName = "";
          String? firstName, lastName, middleName, namePrefix, nameSuffix, nickname, company;
          List<ContactPhone> contactPhones = [];
          List<ContactEmail> contactEmails = [];

          if (rawContact is fc.Contact) {
            if (rawContact.id == null || rawContact.displayName == null) {
              // Skip contacts without ID or display name
              continue;
            }

            contactId = rawContact.id!;
            displayName = rawContact.displayName!;

            final name = rawContact.name;
            firstName = name?.first;
            lastName = name?.last;
            middleName = name?.middle;
            namePrefix = name?.prefix;
            nameSuffix = name?.suffix;
            nickname = name?.nickname;

            if (rawContact.organizations.isNotEmpty) {
              final orgCompany = rawContact.organizations.first.name;
              if (orgCompany != null) company = orgCompany;
            }

            for (final phone in rawContact.phones) {
              final label =
                  phone.label.label == fc.PhoneLabel.custom ? phone.label.customLabel ?? '' : phone.label.label.name;
              contactPhones.add(ContactPhone(number: phone.number, label: label));
            }
            for (final email in rawContact.emails) {
              final label =
                  email.label.label == fc.EmailLabel.custom ? email.label.customLabel ?? '' : email.label.label.name;
              contactEmails.add(ContactEmail(address: email.address, label: label));
            }
          } else if (rawContact is ContactV2) {
            contactId = rawContact.nativeContactId;
            displayName = rawContact.displayName;
            firstName = rawContact.firstName;
            lastName = rawContact.lastName;
            contactPhones = rawContact.phoneNumbers;
            contactEmails = rawContact.emailAddresses;
          }

          // Get pre-fetched avatar path
          final avatarPath = avatarPaths[contactId];

          // Check if contact already exists
          final existingQuery = contactsBox.query(ContactV2_.nativeContactId.equals(contactId)).build();
          final existingContact = existingQuery.findFirst();
          existingQuery.close();

          ContactV2 contact;
          Set<int> existingHandleIds = {};

          if (existingContact != null) {
            // Update existing contact
            contact = existingContact;
            final oldComputedName = contact.computedDisplayName;
            final oldAvatarPath = contact.avatarPath;
            contact.displayName = displayName;
            contact.addresses = normalizedAddresses.toList();
            // Only touch avatarPath when the prefetch step produced a definitive
            // answer (photo saved, or confirmed no photo). An absent key means the
            // photo fetch failed — keep the existing path instead of wiping it.
            if (avatarPaths.containsKey(contactId)) {
              contact.avatarPath = avatarPath;
            }
            contact.firstName = firstName;
            contact.lastName = lastName;
            contact.middleName = middleName;
            contact.namePrefix = namePrefix;
            contact.nameSuffix = nameSuffix;
            contact.nickname = nickname;
            contact.company = company;
            contact.phoneNumbers = contactPhones;
            contact.emailAddresses = contactEmails;

            // Track existing handles to detect changes
            existingHandleIds = contact.handles.map((h) => h.id).whereType<int>().toSet();

            if (oldComputedName != contact.computedDisplayName || oldAvatarPath != contact.avatarPath) {
              // Mark all existing handles for this contact as affected (computed name or avatar changed)
              affectedHandleIds.addAll(existingHandleIds);
            }
          } else {
            // Create new contact
            contact = ContactV2(
              displayName: displayName,
              nativeContactId: contactId,
              avatarPath: avatarPath,
              addresses: normalizedAddresses.toList(),
              firstName: firstName,
              lastName: lastName,
              middleName: middleName,
              namePrefix: namePrefix,
              nameSuffix: nameSuffix,
              nickname: nickname,
              company: company,
            );
            contact.phoneNumbers = contactPhones;
            contact.emailAddresses = contactEmails;
          }

          // Mark contact as native only when it originates from flutter_contacts
          contact.isNative = rawContact is fc.Contact;

          // Step 3: Match contact to handles using lookup maps (O(addresses) instead of O(addresses × handles))
          final matchedHandles = <Handle>{};

          for (final address in normalizedAddresses) {
            final isEmail = address.contains('@');

            if (isEmail) {
              // Direct lookup for emails
              final handles = emailHandleMap[address];
              if (handles != null) {
                matchedHandles.addAll(handles);
              }
            } else {
              // For phones, check all variants
              final variants = getPhoneNumberVariants(address);
              for (final variant in variants) {
                final handles = phoneHandleMap[variant];
                if (handles != null) {
                  matchedHandles.addAll(handles);
                }
              }
            }
          }

          if (matchedHandles.isNotEmpty) matchedContactCount++;

          // Compare new handles with existing handles to detect changes
          final newHandleIds = matchedHandles.map((h) => h.id).whereType<int>().toSet();
          final handlesChanged = existingContact == null ||
              existingHandleIds.length != newHandleIds.length ||
              !existingHandleIds.containsAll(newHandleIds);

          // Always update handles on the in-memory object so the put below persists them.
          contact.handles.clear();
          contact.handles.addAll(matchedHandles);

          // Always persist the contact — this ensures phone/email JSON columns are
          // written to the DB regardless of whether handle assignments changed.
          try {
            contactsBox.put(contact);
          } on UniqueViolationException catch (e) {
            Logger.warn('[ContactV2] Unique violation for contact ${contact.nativeContactId}: $e');
          }

          if (handlesChanged) {
            // Mark all affected handles (both old and new) for UI refresh
            affectedHandleIds.addAll(existingHandleIds);
            affectedHandleIds.addAll(newHandleIds);

            // Link handles to chats without handles
            final chatsToUpdate = <Chat>{};
            for (final handle in matchedHandles) {
              final chatQuery = Database.chats.query(Chat_.guid.contains(';-;${handle.address}')).build();
              final chats = chatQuery.find();
              chatQuery.close();

              for (final chat in chats) {
                if (chat.handles.isEmpty) {
                  chat.handles.add(handle);
                  chatsToUpdate.add(chat);
                }
              }
            }

            if (chatsToUpdate.isNotEmpty) {
              Logger.info('[ContactV2] Updating ${chatsToUpdate.length} chats to link matched handles');
              Database.chats.putMany(chatsToUpdate.toList());
            }
          }
        }
      });

      final endTime = DateTime.now().millisecondsSinceEpoch;
      // De-duplicate — a handle can be marked affected by both a name/avatar
      // change and a handle-link change within the same sync.
      final uniqueAffected = affectedHandleIds.toSet().toList();
      Logger.info('[ContactV2] Contact fetch and match completed in ${endTime - startTime}ms');
      Logger.info('[ContactV2] Affected ${uniqueAffected.length} handles');

      final stats = _ContactSyncStats(
        affectedHandleIds: uniqueAffected,
        deviceContactCount: deviceContacts.length,
        matchedContactCount: matchedContactCount,
      );

      // Complete the completer with the result
      _syncCompleter?.complete(stats);
      return stats;
    } catch (e, stack) {
      // Logged with the exception's runtimeType called out explicitly so this is
      // distinguishable in exported logs from the "0 contacts, no exception" case
      // logged above — both currently end in an empty sync result, but only one
      // of them is an actual failure.
      Logger.error('[ContactV2] Error fetching and matching contacts (${e.runtimeType}): $e',
          error: e, trace: stack);

      // Complete the completer with an empty result on error
      const stats = _ContactSyncStats(affectedHandleIds: [], deviceContactCount: 0, matchedContactCount: 0);
      _syncCompleter?.complete(stats);
      return stats;
    }
  }

  /// Check for contact database changes by comparing native contact IDs
  /// This is used by the periodic background task (Section II.B of FR-1.md)
  static Future<bool> checkContactChanges(dynamic data) async {
    try {
      Logger.info('[ContactV2] Checking for contact changes...');

      // Get current device contact IDs (only fetch minimal data)
      final currentContacts = await fc.FlutterContacts.getAll(); // IDs only by default
      final currentIds = currentContacts.map((c) => c.id).toSet();

      // Get stored contact IDs
      final storedIds = Database.runInTransaction(TxMode.read, () {
        final contactsBox = Database.contactsV2;
        final allContacts = contactsBox.getAll();
        return allContacts.map((c) => c.nativeContactId).toSet();
      });

      // Check for differences
      final hasChanges = currentIds.length != storedIds.length ||
          !currentIds.containsAll(storedIds) ||
          !storedIds.containsAll(currentIds);

      if (hasChanges) {
        Logger.info('[ContactV2] Contact changes detected, triggering refresh');
        await syncContactsToHandles(<String, dynamic>{});
        return true;
      }

      Logger.info('[ContactV2] No contact changes detected');
      return false;
    } catch (e, stack) {
      Logger.error('[ContactV2] Error checking contact changes', error: e, trace: stack);
      return false;
    }
  }

  /// Get all stored ContactV2 IDs for comparison
  static Future<List<String>> getStoredContactIds(dynamic data) async {
    return await Database.runInTransaction(TxMode.read, () {
      final contactsBox = Database.contactsV2;
      final allContacts = contactsBox.getAll();
      return allContacts.map((c) => c.nativeContactId).toList();
    });
  }

  /// Find a single ContactV2 by native contact ID
  /// Returns the ObjectBox ID of the matching contact, or null if not found.
  static Future<int?> findOneContact(dynamic data) async {
    final dataMap = data as Map<dynamic, dynamic>;
    final nativeContactId = dataMap['nativeContactId'] as String;

    return await Database.runInTransaction(TxMode.read, () {
      final contactsBox = Database.contactsV2;
      final query = contactsBox.query(ContactV2_.nativeContactId.equals(nativeContactId)).build();
      query.limit = 1;
      final contact = query.findFirst();
      query.close();

      return contact?.id;
    });
  }

  /// Get ContactV2 IDs for a list of Handle IDs.
  /// Returns de-duplicated ObjectBox IDs so the interface can hydrate full objects.
  static Future<List<int>> getContactsForHandles(dynamic data) async {
    final dataMap = data as Map<dynamic, dynamic>;
    final handleIds = (dataMap['handleIds'] as List).cast<int>();

    return await Database.runInTransaction(TxMode.read, () {
      final handlesBox = Database.handles;
      final uniqueIds = <int>{};

      for (final handleId in handleIds) {
        final handle = handlesBox.get(handleId);
        if (handle != null) {
          for (final contact in handle.contactsV2) {
            if (contact.id != 0) uniqueIds.add(contact.id);
          }
        }
      }

      return uniqueIds.toList();
    });
  }

  /// Manually trigger a contact refresh
  static Future<List<int>> refreshContacts(dynamic data) async {
    return await syncContactsToHandles(data);
  }

  /// Save a contact avatar to disk and return the file path
  ///
  /// Optimizations:
  /// - Only writes if avatar doesn't exist or has changed
  /// - Uses file size comparison first (fast)
  /// - Falls back to hash comparison if sizes match
  static Future<String?> _saveContactAvatar(String contactId, Uint8List avatarData) async {
    try {
      final avatarsDir = Directory(FilesystemSvc.contactAvatarsPath);

      // Create the directory if it doesn't exist
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      // Save the avatar with the contact ID as filename. The ID is sanitized because
      // it isn't ours: macOS record IDs look like `<uuid>:ABPerson`, and the fallback
      // when the server sends no ID is the display name. A reserved character there
      // yields a path that later breaks anything parsing it as a URI (Windows toasts).
      final avatarFile = File(p.join(avatarsDir.path, '${sanitizeFileName(contactId)}.jpg'));

      // Check if avatar already exists and compare it to avoid unnecessary writes
      if (await avatarFile.exists()) {
        final existingData = await avatarFile.readAsBytes();

        // Quick size check first
        if (existingData.length == avatarData.length) {
          // If sizes match, do a hash comparison to be sure
          final existingHash = sha256.convert(existingData);
          final newHash = sha256.convert(avatarData);

          if (existingHash == newHash) {
            // Avatar hasn't changed, return existing path without writing
            return avatarFile.path;
          }
        }
      }

      // Avatar is new or has changed, write it to disk
      await avatarFile.writeAsBytes(avatarData);

      return avatarFile.path;
    } catch (e, stack) {
      Logger.error('[ContactV2] Error saving avatar for contact $contactId', error: e, trace: stack);
      return null;
    }
  }

  /// Get a contact by address (email or phone number).
  /// Returns the ObjectBox ID of the matching contact, or null if not found.
  static Future<int?> getContactByAddress(dynamic data) async {
    final dataMap = data as Map<dynamic, dynamic>;
    final address = dataMap['address'] as String;

    return await Database.runInTransaction(TxMode.read, () {
      final contactsBox = Database.contactsV2;

      // Normalize the search address
      final normalized =
          address.contains('@') ? ContactV2.normalizeEmail(address) : ContactV2.normalizePhoneNumber(address);

      // Search through all contacts for a match
      final allContacts = contactsBox.getAll();

      for (final contact in allContacts) {
        if (contact.hasMatchingAddress(normalized)) {
          return contact.id;
        }
      }

      return null;
    });
  }

  /// Get all contacts from the database.
  /// Returns a list of ObjectBox IDs so the interface can hydrate full objects.
  static Future<List<int>> getAllContacts(dynamic data) async {
    return await Database.runInTransaction(TxMode.read, () {
      final contactsBox = Database.contactsV2;
      final query = (contactsBox.query()..order(ContactV2_.displayName)).build();
      final allContacts = query.find();
      return allContacts.map((c) => c.id).toList();
    });
  }

  /// Get avatar data for a contact by native contact ID
  static Future<Uint8List?> getContactAvatar(dynamic data) async {
    final dataMap = data as Map<dynamic, dynamic>;
    final nativeContactId = dataMap['nativeContactId'] as String;

    try {
      // First try to get from disk (if we've already saved it)
      final avatarsDir = Directory(FilesystemSvc.contactAvatarsPath);
      final avatarFile = File(p.join(avatarsDir.path, '$nativeContactId.jpg'));

      if (await avatarFile.exists()) {
        return await avatarFile.readAsBytes();
      }

      // If not on disk, try to fetch it fresh
      if (!kIsWeb && !kIsDesktop) {
        Uint8List? avatar;

        try {
          final contact = await fc.FlutterContacts.get(
            nativeContactId,
            properties: {fc.ContactProperty.photoFullRes, fc.ContactProperty.photoThumbnail},
          );
          avatar = contact?.photo?.fullSize ?? contact?.photo?.thumbnail;
        } catch (e) {
          Logger.warn('[ContactV2] Failed to get avatar for ID $nativeContactId: $e');
        }

        // Save it to disk for future use
        if (avatar != null) {
          await _saveContactAvatar(nativeContactId, avatar);
        }

        return avatar;
      }

      return null;
    } catch (e, stack) {
      Logger.error('[ContactV2] Error getting contact avatar for $nativeContactId', error: e, trace: stack);
      return null;
    }
  }

  /// Uploads contacts to the server
  static Future<void> uploadContacts(dynamic data) async {
    final contacts = data['contacts'] as List<Map<String, dynamic>>;

    try {
      await HttpSvc.contact.create(contacts);
      Logger.info('[ContactV2] Successfully uploaded ${contacts.length} contacts to server');
    } catch (err, stack) {
      if (err is Response) {
        Logger.error(err.data["error"]["message"].toString(), error: err, trace: stack, tag: 'ContactV2Actions');
      } else {
        Logger.error('Failed to upload contacts!', error: err, trace: stack, tag: 'ContactV2Actions');
      }
    }
  }

  /// Returns each on-device account with contacts, plus a live contact count
  /// per account. Used by the Contacts Management page's account selector.
  /// Mobile only — desktop has no device accounts.
  static Future<List<Map<String, dynamic>>> getAccountContactCounts(dynamic data) async {
    if (kIsWeb || kIsDesktop) return [];

    try {
      final accounts = await fc.FlutterContacts.accounts.getAll();
      final results = <Map<String, dynamic>>[];

      for (final account in accounts) {
        final contacts = await fc.FlutterContacts.getAll(account: account);
        results.add({'name': account.name, 'type': account.type, 'count': contacts.length});
      }

      return results;
    } catch (e, stack) {
      Logger.error('[ContactV2] Error getting account contact counts', error: e, trace: stack);
      return [];
    }
  }
}

/// Result of a device/network contact fetch-and-match pass. Kept isolate-internal
/// (not returned directly across the isolate boundary — see
/// [ContactV2Actions.syncContactsToHandles] vs
/// [ContactV2Actions.syncContactsToHandlesWithStats]).
class _ContactSyncStats {
  final List<int> affectedHandleIds;
  final int deviceContactCount;
  final int matchedContactCount;

  const _ContactSyncStats({
    required this.affectedHandleIds,
    required this.deviceContactCount,
    required this.matchedContactCount,
  });

  Map<String, dynamic> toMap() => {
        'affectedHandleIds': affectedHandleIds,
        'deviceContactCount': deviceContactCount,
        'matchedContactCount': matchedContactCount,
      };
}
