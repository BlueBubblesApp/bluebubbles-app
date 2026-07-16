import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/contact_v2_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

// ignore: non_constant_identifier_names
ContactServiceV2 get ContactsSvcV2 => GetIt.I<ContactServiceV2>();

/// ContactServiceV2 - UI-side service for the new contact architecture
/// This service manages the state and triggers isolate operations
/// Follows the architecture outlined in FR-1.md Section III
class ContactServiceV2 {
  final tag = "ContactServiceV2";

  /// Trailing debounce for device contact change events while the app is in the
  /// foreground — an account sync (e.g. Google Contacts) fires many change events
  /// in a burst, and each full sync is an expensive Contacts Provider sweep.
  static const Duration _contactChangeDebounce = Duration(seconds: 30);

  /// Whether we have permission to access contacts
  bool _hasContactAccess = false;

  void Function(void)? _contactChangeListener;
  StreamSubscription<void>? _contactChangeSubscription;
  Timer? _contactChangeDebounceTimer;

  /// Set when contact change events arrive while the app is backgrounded;
  /// consumed by [runPendingContactSync] on the next app resume.
  bool _pendingContactSync = false;

  bool get hasContactAccessSync {
    return _hasContactAccess;
  }

  /// Check if we have contact access permission
  Future<bool> get hasContactAccess async {
    if (_hasContactAccess) return true;
    _hasContactAccess = await _canAccessContacts();
    return _hasContactAccess;
  }

  /// Check if we can access contacts
  Future<bool> _canAccessContacts() async {
    if (kIsWeb || kIsDesktop) {
      return SettingsSvc.getServerDetails().supportsContactsApi;
    } else {
      return (await Permission.contacts.status).isGranted;
    }
  }

  /// Request contact permission from the user
  Future<bool> requestContactPermission() async {
    if (kIsWeb || kIsDesktop) return false;

    final status = await Permission.contacts.request();
    _hasContactAccess = status.isGranted;

    if (_hasContactAccess) {
      Logger.info('[ContactServiceV2] Contact permission granted');
    } else {
      Logger.warn('[ContactServiceV2] Contact permission denied');
    }

    return _hasContactAccess;
  }

  /// Initialize the contact service
  /// [headless] - If true, skips operations that require UI or user interaction (for isolate usage)
  Future<void> init({bool headless = false}) async {
    Logger.info('[ContactServiceV2] Initializing... (headless: $headless)');

    // We only want to call the sync operations if we're not in heardless mode.
    // The UI thread will invoke these methods on init, but should not wait for them to complete.
    // The isolate does not need to perform these operations on startup as no state is required.
    // The UI thread will use the notifyHandlesUpdated method to update UI components as needed.
    if (!headless) {
      await hasContactAccess;
      Logger.info('[ContactServiceV2] Contact access: $_hasContactAccess');
      await syncContactsToHandles(wait: false);

      // Subscribe to device contact change events (mobile only)
      if (!kIsDesktop && !kIsWeb) {
        _contactChangeListener = (_) => _onContactsDbChanged();
        _contactChangeSubscription = fc.FlutterContacts.onDatabaseChange.listen(_contactChangeListener!);
      }
    } else {
      Logger.info('[ContactServiceV2] Headless mode, skipping contact sync opeerations');
    }

    Logger.info('[ContactServiceV2] Initialization complete');
  }

  bool get _isAppAlive {
    if (!GetIt.I.isRegistered<LifecycleService>() || !GetIt.I.isReadySync<LifecycleService>()) return true;
    return LifecycleSvc.isAlive;
  }

  /// Handle a device contacts DB change event.
  ///
  /// While backgrounded, a full sync per change event hammers the Contacts Provider
  /// from a cached process — this is what triggered the "excessive binder traffic
  /// during cached" kills during overnight account syncs. Instead, mark a pending
  /// sync and run it once on the next app resume ([runPendingContactSync]).
  /// While foregrounded, coalesce event bursts with a trailing debounce.
  void _onContactsDbChanged() {
    _contactChangeDebounceTimer?.cancel();

    if (!_isAppAlive) {
      _pendingContactSync = true;
      Logger.debug('[ContactServiceV2] Contacts changed while backgrounded — deferring sync to next app resume');
      return;
    }

    _contactChangeDebounceTimer = Timer(_contactChangeDebounce, () {
      // The app may have been backgrounded while the debounce was pending.
      if (!_isAppAlive) {
        _pendingContactSync = true;
        return;
      }
      Logger.info('[ContactServiceV2] Contacts changed — running debounced sync');
      syncContactsToHandles(wait: false);
    });
  }

  /// Run a contact sync that was deferred because change events arrived while the
  /// app was backgrounded. Called on app resume; no-op when nothing is pending.
  Future<void> runPendingContactSync() async {
    if (!_pendingContactSync) return;
    _pendingContactSync = false;
    Logger.info('[ContactServiceV2] Running contact sync deferred from background');
    await syncContactsToHandles(wait: false);
  }

  Future<List<int>> syncContactsToHandles({bool wait = true}) async {
    final access = await hasContactAccess;
    if (!access) {
      Logger.warn('[ContactServiceV2] Cannot fetch contacts without permission');
      return [];
    }

    try {
      Logger.info('[ContactServiceV2] Starting contact fetch and match...');
      List<int> affectedHandleIds = [];

      if (wait) {
        affectedHandleIds = await ContactV2Interface.syncContactsToHandles();
        notifyHandlesUpdated(affectedHandleIds);
      } else {
        // Fire and forget
        ContactV2Interface.syncContactsToHandles().then((affectedHandleIds) {
          Logger.info(
              '[ContactServiceV2] Completed contact sync, notifying UI of ${affectedHandleIds.length} affected handles');
          notifyHandlesUpdated(affectedHandleIds);
        }).catchError((e, stack) {
          Logger.error('[ContactServiceV2] Error in async contact fetch and match', error: e, trace: stack);
        });
      }

      Logger.info('[ContactServiceV2] Completed contact fetch and match');
      return affectedHandleIds;
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error fetching and matching contacts', error: e, trace: stack);
      return [];
    }
  }

  /// Get a ContactV2 for a specific handle ID
  /// This retrieves the contact from the isolate/database
  Future<ContactV2?> getContactForHandle(int handleId) async {
    final access = await hasContactAccess;
    if (!access) return null;

    try {
      final contacts = await ContactV2Interface.getContactsForHandles(
        handleIds: [handleId],
      );

      if (contacts.isEmpty) return null;
      return contacts.first;
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error getting contact for handle $handleId', error: e, trace: stack);
      return null;
    }
  }

  /// Get ContactV2 entities for multiple handle IDs
  Future<List<ContactV2>> getContactsForHandles(List<int> handleIds) async {
    final access = await hasContactAccess;
    if (!access) return [];

    try {
      return await ContactV2Interface.getContactsForHandles(
        handleIds: handleIds,
      );
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error getting contacts for handles', error: e, trace: stack);
      return [];
    }
  }

  /// Notify the UI that certain handles have been updated.
  /// Pushes fresh DB data into the HandleState registry so reactive Obx() widgets rebuild.
  void notifyHandlesUpdated(List<int> handleIds) {
    if (handleIds.isEmpty) return;

    // Push refreshed Handle data into the HandleState registry
    if (!kIsWeb) {
      final refreshed = handleIds.map((id) => Database.handles.get(id)).whereType<Handle>().toList();
      if (refreshed.isNotEmpty) HandleSvc.updateHandleStates(refreshed);
    }

    // Update chats that have these handles as participants
    // This ensures chat titles and headers reflect the new contact names
    if (!kIsWeb) {
      _updateChatsForHandles(handleIds);
    }
  }

  /// Update chats that contain the affected handles
  void _updateChatsForHandles(List<int> handleIds) {
    try {
      // Check if ChatsService is available yet (it might not be during initial startup)
      if (!GetIt.I.isRegistered<ChatsService>()) {
        return;
      }

      // Single pass: load chats once and match participants against the handle
      // ID set, instead of re-querying all chats (and lazily loading each
      // chat's handles) once per affected handle.
      final idSet = handleIds.toSet();
      final query = Database.chats.query(Chat_.dateDeleted.isNull()).build();
      final allChats = query.find();
      query.close();

      final ChatsService chats = GetIt.I<ChatsService>();
      for (final chat in allChats) {
        if (chat.handles.any((p) => idSet.contains(p.id))) {
          // Debounced (immediate: false) so a large sync batches into one
          // chat-list version bump instead of one rebuild per chat.
          chats.updateChat(chat, override: true, immediate: false);
        }
      }
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error updating chats for handles', error: e, trace: stack);
    }
  }

  /// Get a contact by address (email or phone number)
  /// This will search through all contacts to find a match
  Future<ContactV2?> getContact(String address) async {
    try {
      return await ContactV2Interface.getContactByAddress(address: address);
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error getting contact by address', error: e, trace: stack);
      return null;
    }
  }

  /// Match a handle to its associated contact
  /// Returns the contact if found, null otherwise
  Future<ContactV2?> matchHandleToContact(Handle handle) async {
    if (!_hasContactAccess) return null;

    try {
      final contact = await getContactForHandle(handle.id!);
      return contact;
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error matching handle to contact', error: e, trace: stack);
      return null;
    }
  }

  /// Get all contacts from the database
  /// Returns a list of all ContactV2 entities
  Future<List<ContactV2>> getAllContacts() async {
    try {
      return await ContactV2Interface.getAllContacts();
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error getting all contacts', error: e, trace: stack);
      return [];
    }
  }

  /// Get avatar data for a contact by ID
  /// Returns the avatar as Uint8List if available
  Future<Uint8List?> getContactAvatar(String nativeContactId) async {
    try {
      return await ContactV2Interface.getContactAvatar(nativeContactId: nativeContactId);
    } catch (e, stack) {
      Logger.error('[ContactServiceV2] Error getting contact avatar', error: e, trace: stack);
      return null;
    }
  }

  /// Fetch contacts from the server with optional verbose logging.
  /// This is a diagnostic/troubleshoot helper — primary sync uses [syncContactsToHandles].
  Future<List<ContactV2>> fetchNetworkContacts({Function(String)? logger}) async {
    final networkContacts = <ContactV2>[];
    logger?.call("Fetching contacts from server...");
    try {
      final response = await HttpSvc.contact.fetchAll(withAvatars: true);

      if (response.statusCode == 200 && !isNullOrEmpty(response.data['data'])) {
        logger?.call("Found contacts!");
        for (Map<String, dynamic> map in response.data['data']) {
          final displayName = getDisplayName(map['displayName'], map['firstName'], map['lastName']);
          final phones = (map['phoneNumbers'] as List<dynamic>? ?? [])
              .map((e) => ContactPhone(number: e['address'].toString(), label: e['label']?.toString() ?? ''))
              .toList();
          final emails = (map['emails'] as List<dynamic>? ?? [])
              .map((e) => ContactEmail(address: e['address'].toString(), label: e['label']?.toString() ?? ''))
              .toList();

          if (emails.isEmpty && phones.isEmpty) {
            logger?.call("Contact has no saved addresses: $displayName");
          }
          logger?.call("Parsing contact: $displayName");

          final c = ContactV2(
            nativeContactId: (map['id'] ?? displayName).toString(),
            displayName: displayName,
            firstName: map['firstName']?.toString(),
            lastName: map['lastName']?.toString(),
          );
          c.phoneNumbers = phones;
          c.emailAddresses = emails;

          if (!isNullOrEmpty(map['avatar'])) {
            try {
              final bytes = base64Decode(map['avatar'].toString());
              final avatarsDir = Directory(FilesystemSvc.contactAvatarsPath);
              if (!avatarsDir.existsSync()) avatarsDir.createSync(recursive: true);
              final file = File('${avatarsDir.path}/${c.nativeContactId}.jpg');
              await file.writeAsBytes(bytes);
              c.avatarPath = file.path;
            } catch (_) {}
          }

          networkContacts.add(c);
        }
      } else {
        logger?.call("No contacts found!");
      }
      logger?.call("Finished contacts sync");
    } catch (e, s) {
      logger?.call("Got exception: $e");
      logger?.call(s.toString());
    }
    return networkContacts;
  }

  /// Remove the contact change listener and release resources
  void dispose() {
    _contactChangeDebounceTimer?.cancel();
    _contactChangeDebounceTimer = null;
    if (_contactChangeListener != null) {
      _contactChangeSubscription?.cancel();
      _contactChangeListener = null;
    }
  }
}
