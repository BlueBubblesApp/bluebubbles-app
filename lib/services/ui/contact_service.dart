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

  /// Bumped whenever contact avatar bytes are applied/merged on web. Avatar
  /// widgets observe this so they repaint the instant images become available.
  /// (A contact's `avatar` is a plain field, not an observable, so widgets that
  /// already built would otherwise never know the bytes arrived and would keep
  /// showing initials until an unrelated rebuild happened seconds later.)
  final RxInt webAvatarGeneration = 0.obs;

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

      LoadTimer.mark("Contacts fetched - no avatars (${networkContacts.length})");

      // Avatars are fetched separately, targeted to the handles actually in
      // chats, once chats are loaded — see loadContactAvatars. Always fresh
      // from the server (no local avatar cache).
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

  /// In-chat handle addresses whose avatars we've already fetched this session.
  /// Repeated calls to [loadContactAvatars] only request newly-arrived handles,
  /// so we never re-pull avatars we already have (and never pull all contacts).
  final Set<String> _webAvatarFetchedAddresses = {};

  /// Loads contact avatars on web by fetching ONLY the avatars for the handles
  /// currently in chats — a small, targeted payload, always fresh from the
  /// server (no local avatar cache). Safe to call repeatedly as chats stream
  /// in; each call requests only the handles not fetched yet.
  ///
  /// Pass [completeMilestone] = false for an early (partial) call so the
  /// "Everything loaded" milestone isn't marked until the final call (once all
  /// chats are present) actually finishes.
  Future<void> loadContactAvatars({bool completeMilestone = true, Function(String)? logger}) async {
    if (!kIsWeb) {
      LoadTimer.completeSubsystem('avatars');
      return;
    }
    try {
      // Only the in-chat handles we haven't fetched avatars for yet.
      final addresses = chats.webCachedHandles
          .map((h) => h.address)
          .toSet()
          .where((a) => a.isNotEmpty && !_webAvatarFetchedAddresses.contains(a))
          .toList();
      if (addresses.isEmpty) return;

      logger?.call("Fetching avatars for ${addresses.length} in-chat handles...");
      final response = await http.contactByAddresses(addresses, withAvatars: true);
      // Mark as fetched only after a successful response so failures can retry.
      _webAvatarFetchedAddresses.addAll(addresses);

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

      // Repaint avatar widgets now that the fetched images are merged in (the
      // bump schedules a rebuild on the next frame). The chat list/title side
      // updates via chats.refresh(); only the open chat needs a stream nudge.
      webAvatarGeneration.value++;
      eventDispatcher.emit('update-contacts', null);
      LoadTimer.mark("Contact avatars loaded (${addresses.length} in-chat handles)");
    } catch (e, s) {
      logger?.call("Failed to load contact avatars: $e");
      Logger.error("Failed to load contact avatars", error: e, trace: s);
    } finally {
      if (completeMilestone) LoadTimer.completeSubsystem('avatars');
    }
  }
}
