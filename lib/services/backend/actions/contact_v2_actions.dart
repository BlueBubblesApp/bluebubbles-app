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
  static Completer<List<int>>? _syncCompleter;

  /// Generate multiple normalized variants of a phone number to handle country code mismatches
  ///
  /// Returns a set of normalized phone numbers including:
  /// - The original normalized number (digits + plus sign only)
  /// - Variant without country code (if one exists)
  /// - Variant with country code removed but assuming it started with +
  ///
  /// This handles cases where:
  /// - Contact has "1234567890" but Handle has "+11234567890"
  /// - Contact has "+11234567890" but Handle has "1234567890"
  /// - Works with any country code, not just +1
  static Set<String> _getPhoneNumberVariants(String phone) {
    final variants = <String>{};
    final normalized = ContactV2.normalizePhoneNumber(phone);

    if (normalized.isEmpty) return variants;

    // Always include the base normalized version
    variants.add(normalized);

    // If it starts with +, add variant without the +
    if (normalized.startsWith('+')) {
      variants.add(normalized.substring(1));

      // Also try removing common country codes (1-3 digits after +)
      // Country codes can be 1-3 digits (e.g., +1, +44, +852, +1246)
      for (int i = 1; i <= 3 && i < normalized.length; i++) {
        final withoutCountryCode = normalized.substring(i + 1);
        if (withoutCountryCode.isNotEmpty) {
          variants.add(withoutCountryCode);
        }
      }
    } else {
      // If no +, try adding + and common country code lengths
      // This handles cases where the stored number doesn't have + but the contact does
      variants.add('+$normalized');

      // Try removing 1-3 digit prefixes as potential country codes
      for (int i = 1; i <= 3 && i < normalized.length; i++) {
        final withoutPrefix = normalized.substring(i);
        if (withoutPrefix.isNotEmpty) {
          variants.add(withoutPrefix);
          variants.add('+$withoutPrefix');
        }
      }
    }

    return variants;
  }

  /// Fetch all contacts from device and match them to existing handles
  /// This is the main operation described in Section II.A of FR-1.md
  static Future<List<int>> syncContactsToHandles(dynamic data) async {
    // If already processing, wait for the existing operation to complete
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      Logger.info('[ContactV2] Sync already in progress, waiting for completion...');
      return await _syncCompleter!.future;
    }

    // Create a new completer for this sync operation
    _syncCompleter = Completer<List<int>>();

    final startTime = DateTime.now().millisecondsSinceEpoch;
    final affectedHandleIds = <int>[];

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
        Logger.info('[ContactV2] Starting contact fetch from device (flutter_contacts)...');
        deviceContacts = await fc.FlutterContacts.getAll(properties: fc.ContactProperties.allProperties);
        Logger.info('[ContactV2] Fetched ${deviceContacts.length} contacts from device');

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
            final variants = _getPhoneNumberVariants(handle.address);
            for (final variant in variants) {
              phoneHandleMap.putIfAbsent(variant, () => []).add(handle);
            }

            if (handle.formattedAddress != null) {
              final formattedVariants = _getPhoneNumberVariants(handle.formattedAddress!);
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
                  email.label == fc.EmailLabel.custom ? email.label.customLabel ?? '' : email.label.label.name;
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
              final variants = _getPhoneNumberVariants(address);
              for (final variant in variants) {
                final handles = phoneHandleMap[variant];
                if (handles != null) {
                  matchedHandles.addAll(handles);
                }
              }
            }
          }

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

      // Complete the completer with the result
      _syncCompleter?.complete(uniqueAffected);
      return uniqueAffected;
    } catch (e, stack) {
      Logger.error('[ContactV2] Error fetching and matching contacts', error: e, trace: stack);

      // Complete the completer with an empty list on error
      _syncCompleter?.complete([]);
      return [];
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

      // Save the avatar with the contact ID as filename
      final avatarFile = File(p.join(avatarsDir.path, '$contactId.jpg'));

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
}
