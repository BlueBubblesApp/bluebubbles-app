import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/load_timer.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:fast_contacts/fast_contacts.dart' hide Contact, StructuredName;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

ContactsService cs = Get.isRegistered<ContactsService>() ? Get.find<ContactsService>() : Get.put(ContactsService());

class ContactsService extends GetxService {
  final tag = "ContactsService";

  /// The master list of contact objects
  List<Contact> contacts = [];

  bool _hasContactAccess = false;

  Future<bool> get hasContactAccess async {
    if (_hasContactAccess) return true;

    _hasContactAccess = await canAccessContacts();
    return _hasContactAccess;
  }

  Future<void> init() async {
    // Load the contact access state
    await hasContactAccess;

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
    if (!(await hasContactAccess)) return [];

    // Check if the user is on v1.5.2 or newer
    int serverVersion = (await ss.getServerDetails()).item4;
    // 100(major) + 21(minor) + 1(bug)
    bool isMin1_5_2 = serverVersion >= 207; // Server: v1.5.2

    final startTime = DateTime.now().millisecondsSinceEpoch;
    List<Contact> _contacts = [];
    final changedIds = <List<int>>[<int>[], <int>[]];

    _contacts = await fetchAllContacts();

    // compare loaded contacts to db contacts
    if (!kIsWeb) {
      final dbContacts = Database.contacts.getAll();
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
        final ids = Database.contacts.putMany(newContacts);
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
      handles.addAll(Database.handles.getAll());
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
      final handles = matchContactToHandles(c, handlesToSearch);
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
      Handle.bulkSave(handles, matchOnOriginalROWID: isMin1_5_2);
    } else {
      // dummy to make the full contacts UI refresh happen on web
      changedIds.last.add(handles.length);
      contacts = _contacts;
      for (Chat c in chats.chats) {
        c.webSyncParticipants();
      }
      chats.chats.refresh();
    }

    final endTime = DateTime.now().millisecondsSinceEpoch;
    Logger.debug("Contact refresh took ${endTime - startTime} ms");

    // only return contacts if things changed (or on web)
    return changedIds;
  }

  Future<List<Contact>> fetchAllContacts() async {
    final _contacts = <Contact>[];

    int startTime = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb || kIsDesktop) {
      _contacts.addAll(await fetchNetworkContacts());
      int endTime = DateTime.now().millisecondsSinceEpoch;
      Logger.debug("Contacts fetched in ${endTime - startTime} ms");
    } else {
      _contacts.addAll((await FastContacts.getAllContacts(
              fields: List<ContactField>.from(ContactField.values)
                ..removeWhere((e) => [
                      ContactField.company,
                      ContactField.department,
                      ContactField.jobDescription,
                      ContactField.emailLabels,
                      ContactField.phoneLabels
                    ].contains(e))))
          .map((e) => Contact(
                displayName: e.displayName,
                emails: e.emails.map((e) => e.address).toList(),
                phones: e.phones.map((e) => e.number).toList(),
                structuredName: e.structuredName == null
                    ? null
                    : StructuredName(
                        namePrefix: e.structuredName!.namePrefix,
                        givenName: e.structuredName!.givenName,
                        middleName: e.structuredName!.middleName,
                        familyName: e.structuredName!.familyName,
                        nameSuffix: e.structuredName!.nameSuffix,
                      ),
                id: e.id,
              )));

      int endTime = DateTime.now().millisecondsSinceEpoch;
      Logger.debug("Contacts fetched in ${endTime - startTime} ms");

      // get avatars
      startTime = DateTime.now().millisecondsSinceEpoch;
      for (Contact c in _contacts) {
        c.avatar = await getContactAvatar(c.id);
      }

      endTime = DateTime.now().millisecondsSinceEpoch;
      Logger.debug("Avatars fetched in ${endTime - startTime} ms");
    }

    return _contacts;
  }

  Future<Uint8List?> getContactAvatar(String id) async {
    Uint8List? avatar;

    try {
      avatar = await FastContacts.getContactImage(id, size: ContactImageSize.fullSize);
    } catch (e) {
      Logger.warn("Failed to get full size avatar for ID, $id!", error: e);
    }

    if (avatar == null) {
      try {
        avatar = await FastContacts.getContactImage(id);
      } catch (e) {
        Logger.warn("Failed to get small size avatar for ID, $id!", error: e);
      }
    }

    return avatar;
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
    final lowerEmails = c.emails.map((e) => e.toLowerCase()).toList();
    List<Handle> handleMatches = [];
    // multiply phones by 3 because a phone can be matched to iMessage / SMS / Android SMS
    int maxResults = c.phones.length * 3 + c.emails.length;
    for (Handle h in handles) {
      // Match emails (case-insensitive)
      if (h.address.contains("@") && lowerEmails.contains(h.address.toLowerCase())) {
        handleMatches.add(h);
        continue;
      }

      final numericAddress = h.address.numericOnly();

      // Match phone numbers (exact numeric match)
      if (numericPhones.contains(numericAddress)) {
        handleMatches.add(h);
        continue;
      }

      // try to match last 15 - 7 digits (bidirectional suffix matching)
      final matchLengths = [15, 14, 13, 12, 11, 10, 9, 8, 7];
      final handleLeadingZerosRemoved = int.tryParse(numericAddress)?.toString() ?? numericAddress;
      bool matched = false;
      for (String p in numericPhones) {
        // remove leading zeros which indicate "same country"
        final leadingZerosRemoved = int.tryParse(p)?.toString() ?? p;
        // check if handle ends with contact phone
        if (matchLengths.contains(leadingZerosRemoved.length) && handleLeadingZerosRemoved.endsWith(leadingZerosRemoved)) {
          handleMatches.add(h);
          matched = true;
          break;
        }
        // check if contact phone ends with handle (e.g. handle has no country code)
        if (matchLengths.contains(handleLeadingZerosRemoved.length) && leadingZerosRemoved.endsWith(handleLeadingZerosRemoved)) {
          handleMatches.add(h);
          matched = true;
          break;
        }
      }
      if (matched) continue;

      if (handleMatches.length >= maxResults) break;
    }

    return handleMatches;
  }

  Contact? matchHandleToContact(Handle h) {
    if (!_hasContactAccess) return null;

    Contact? contact;
    final numericAddress = h.address.numericOnly();
    final handleLeadingZerosRemoved = int.tryParse(numericAddress)?.toString() ?? numericAddress;
    for (Contact c in contacts) {
      final numericPhones = c.phones.map((e) => e.numericOnly()).toList();
      // Match emails (case-insensitive)
      if (h.address.contains("@") && c.emails.any((e) => e.toLowerCase() == h.address.toLowerCase())) {
        contact = c;
        break;
      } else {
        // if address is direct numeric match
        if (numericPhones.contains(numericAddress)) {
          contact = c;
          break;
        }
        // try to match last 15 - 7 digits (bidirectional suffix matching)
        final matchLengths = [15, 14, 13, 12, 11, 10, 9, 8, 7];
        for (String p in numericPhones) {
          final leadingZerosRemoved = int.tryParse(p)?.toString() ?? p;
          // check if handle ends with contact phone
          if (matchLengths.contains(leadingZerosRemoved.length) && handleLeadingZerosRemoved.endsWith(leadingZerosRemoved)) {
            contact = c;
            break;
          }
          // check if contact phone ends with handle
          if (matchLengths.contains(handleLeadingZerosRemoved.length) && leadingZerosRemoved.endsWith(handleLeadingZerosRemoved)) {
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
    final tempHandle = Handle(address: address);
    return matchHandleToContact(tempHandle);
  }

  Future<List<Contact>> fetchNetworkContacts({Function(String)? logger}) async {
    final networkContacts = <Contact>[];

    // On web, fetch contacts WITHOUT avatars first so names can be matched and
    // displayed immediately. The avatar payload is much larger (base64 images)
    // and is loaded in the background afterwards so it doesn't block the UI.
    if (kIsWeb) {
      logger?.call("Fetching contacts (no avatars)...");
      try {
        final response = await http.contacts();

        if (response.statusCode == 200 && !isNullOrEmpty(response.data['data'])) {
          logger?.call("Found contacts!");

          for (Map<String, dynamic> map in response.data['data']) {
            final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
            final emails = (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
            final phones = (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
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

      // Apply any cached avatars immediately so they render on first paint
      // (on reload) instead of waiting for the server avatar fetch.
      applyWebAvatarCache(networkContacts);
      LoadTimer.mark("Contacts fetched - no avatars (${networkContacts.length})");

      // Full avatar load/refresh is triggered by ChatsService once chats are
      // loaded — see loadContactAvatars (uses the cache when fresh).
      return networkContacts;
    }

    logger?.call("Fetching contacts (with avatars)...");
    try {
      final response = await http.contacts(withAvatars: true);

      if (response.statusCode == 200 && !isNullOrEmpty(response.data['data'])) {
        logger?.call("Found contacts!");
        for (Map<String, dynamic> map in response.data['data']) {
          final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
          final emails = (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
          final phones = (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
          logger?.call("Parsing contact: $displayName");

          // Log when a contact has no saved addresses
          if (emails.isEmpty && phones.isEmpty) {
            logger?.call("Contact has no saved addresses: $displayName");
          }

          networkContacts.add(Contact(
            id: (map['id'] ?? (phones.isNotEmpty ? phones : emails)).toString(),
            displayName: displayName,
            emails: emails,
            phones: phones,
            avatar: !isNullOrEmpty(map['avatar']) ? base64Decode(map['avatar'].toString()) : null,
          ));
        }
      } else {
        logger?.call("No contacts found!");
      }
      logger?.call("Finished contacts sync (with avatars)");
    } catch (e, s) {
      logger?.call("Got exception: $e");
      logger?.call(s.toString());
    }
    return networkContacts;
  }

  // Web avatar cache (localStorage via prefs) so reloads show avatars instantly
  // without re-fetching the multi-MB avatar payload from the server.
  static const _avatarCacheKey = 'web_avatar_cache_v1';
  static const _avatarCacheTtlMs = 6 * 60 * 60 * 1000; // 6 hours

  /// Apply cached avatars (web) to [contacts] by id so avatars render instantly
  /// on reload, before/without any server round-trip.
  void applyWebAvatarCache(List<Contact> contacts) {
    if (!kIsWeb) return;
    try {
      final raw = ss.prefs.getString(_avatarCacheKey);
      if (raw == null) return;
      final cache = jsonDecode(raw) as Map<String, dynamic>;
      final avatars = (cache['avatars'] as Map?)?.cast<String, dynamic>() ?? {};
      if (avatars.isEmpty) return;
      final byId = <String, Contact>{for (final c in contacts) c.id: c};
      avatars.forEach((id, b64) {
        final c = byId[id];
        if (c != null && c.avatar == null && b64 is String && b64.isNotEmpty) {
          try {
            c.avatar = base64Decode(b64);
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  bool _isAvatarCacheFresh() {
    try {
      final raw = ss.prefs.getString(_avatarCacheKey);
      if (raw == null) return false;
      final cache = jsonDecode(raw) as Map<String, dynamic>;
      final ts = (cache['ts'] as int?) ?? 0;
      return DateTime.now().millisecondsSinceEpoch - ts < _avatarCacheTtlMs;
    } catch (_) {
      return false;
    }
  }

  /// Persist avatars for the contacts currently in chats (a small subset, ~tens
  /// to low-hundreds of KB) so the next load can apply them instantly.
  void _saveWebAvatarCache() {
    try {
      final matched = chats.webCachedHandles.map((h) => h.contact).whereType<Contact>().toSet();
      final avatars = <String, String>{};
      for (final c in matched) {
        if (c.avatar != null && c.avatar!.isNotEmpty) {
          avatars[c.id] = base64Encode(c.avatar!);
        }
      }
      ss.prefs.setString(_avatarCacheKey,
          jsonEncode({'ts': DateTime.now().millisecondsSinceEpoch, 'avatars': avatars}));
    } catch (_) {}
  }

  /// Loads contact avatars on web. If a fresh local cache exists, the avatars
  /// have already been applied (see [applyWebAvatarCache]) and no network call
  /// is made. Otherwise fetches all avatars once, merges by id, refreshes the
  /// chat tiles, and updates the cache for next time.
  Future<void> loadContactAvatars({Function(String)? logger}) async {
    if (!kIsWeb) {
      LoadTimer.completeSubsystem('avatars');
      return;
    }
    try {
      if (_isAvatarCacheFresh()) {
        // Avatars were applied from cache during the no-avatar fetch; refresh
        // the tiles in case any were applied after first render.
        if (chats.chats.isNotEmpty) {
          chats.sort();
          for (final chat in chats.chats) {
            WebListeners.notifyChatUpdate(chat);
          }
        }
        LoadTimer.mark("Contact avatars loaded (from cache)");
        return;
      }
      logger?.call("Fetching contact avatars...");
      final response = await http.contacts(withAvatars: true);
      if (!isNullOrEmpty(response.data['data'])) {
        final byId = <String, Contact>{for (final c in contacts) c.id: c};
        for (Map<String, dynamic> map in response.data['data'].where((e) => !isNullOrEmpty(e['avatar']))) {
          final emails = (map['emails'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
          final phones = (map['phoneNumbers'] as List<dynamic>? ?? []).map((e) => e['address'].toString()).toList();
          final id = (map['id'] ?? (phones.isNotEmpty ? phones : emails)).toString();
          final contact = byId[id];
          if (contact != null) {
            contact.avatar = base64Decode(map['avatar'].toString());
          }
        }
      }
      logger?.call("Finished avatar sync");

      // Refresh the chat list so avatars appear without user interaction
      if (chats.chats.isNotEmpty) {
        chats.sort();
        for (final chat in chats.chats) {
          WebListeners.notifyChatUpdate(chat);
        }
      }
      eventDispatcher.emit('update-contacts', null);
      _saveWebAvatarCache();
      LoadTimer.mark("Contact avatars loaded (refreshed from server)");
    } catch (e, s) {
      logger?.call("Failed to load contact avatars: $e");
      Logger.error("Failed to load contact avatars", error: e, trace: s);
    } finally {
      LoadTimer.completeSubsystem('avatars');
    }
  }
}
