import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';

/// A Find My friend's matching chat [Handle] and/or address-book [ContactV2].
/// Used by the list, map markers, and popups for name and avatar.
class FindMyFriendIdentity {
  const FindMyFriendIdentity({this.handle, this.contact});

  final Handle? handle;
  final ContactV2? contact;

  /// Contact name, then handle name, then the formatted Find My address.
  String displayName(FindMyFriend friend) {
    if (contact != null && !isNullOrEmpty(contact!.computedDisplayName)) {
      return contact!.computedDisplayName;
    }
    if (handle != null) return handle!.displayName;
    final raw = friend.handleAddress ?? friend.title;
    if (isNullOrEmpty(raw)) return 'Unknown Friend';
    return raw!.contains('@') ? raw : formatPhoneNumber(raw);
  }

  /// Handle to pass to [ContactAvatarWidget]. Never null: the widget treats a null handle
  /// as the current user and would show *their* avatar on this friend. Unmatched friends get
  /// an unsaved placeholder so the gradient and initials still come from the Find My address.
  Handle avatarHandle(FindMyFriend friend) =>
      handle ?? Handle(address: friend.handleAddress ?? friend.title ?? 'Unknown');

  /// Whether the avatar may open the color picker / contact form. Placeholder handles
  /// aren't in the DB, so editing one would fail.
  bool get avatarEditable => handle?.id != null;
}

/// Resolves Find My friends to a [Handle] and/or [ContactV2].
///
/// Find My identifies friends by Apple ID email (or phone). Sometimes, this may not
/// have a corresponding chat, or may be linked to a different handle.
///
/// 1. Look up a [Handle] with this exact address
/// 2. Otherwise look up a [ContactV2] that lists this email or phone.
/// 3. If that contact has a handle already linked to a 1:1 chat, use that
///    handle instead. Otherwise fall back to any other handle on the contact.
///
/// If nothing matches, [FindMyFriendIdentity.displayName] uses the raw Find My
/// address.
///
/// Owned by `FindMyController`: the email/phone → contact index lives only as long as the
/// Find My page, and the controller calls [reset] when contacts change.
class FindMyHandleMatcher {
  /// [_addressKey] → [ContactV2.id]. Null until [load] completes (and always on web).
  Map<String, int>? _index;
  Future<void>? _loading;

  /// Builds the contact index off the UI thread. Safe to call repeatedly; only the first
  /// call after construction or [reset] does any work.
  Future<void> load() {
    if (kIsWeb) return Future.value();
    final pending = _loading;
    if (pending != null) return pending;

    late final Future<void> loading;
    loading = Database.contactsV2.getAllAsync().then((contacts) {
      // A [reset] while this was in flight means these contacts may be stale.
      if (identical(_loading, loading)) _index = _buildIndex(contacts);
    }).catchError((Object e, StackTrace s) {
      Logger.warn('Failed to build Find My contact index', error: e, trace: s, tag: 'FindMyHandleMatcher');
    });
    return _loading = loading;
  }

  /// Drops the index so the next [load] rebuilds it from the current contacts.
  void reset() {
    _index = null;
    _loading = null;
  }

  /// Returns the [Handle] and/or [ContactV2] for [friend], following the class lookup order.
  /// Contact matching is skipped until [load] has completed.
  FindMyFriendIdentity resolve(FindMyFriend friend) {
    final handle = friend.handle ?? _findHandle(friend);
    if (handle != null) return FindMyFriendIdentity(handle: handle);

    final contact = _findContact(friend);
    if (contact == null) return const FindMyFriendIdentity();
    return FindMyFriendIdentity(handle: _linkedHandle(contact, friend), contact: contact);
  }

  /// Exact iMessage, then SMS, handle for any address on [friend].
  static Handle? _findHandle(FindMyFriend friend) {
    for (final addr in _addresses(friend)) {
      final iMessage = Handle.findOne(addressAndService: HandleLookupKey(addr, 'iMessage'));
      if (iMessage != null) return iMessage;
      final sms = Handle.findOne(addressAndService: HandleLookupKey(addr, 'SMS'));
      if (sms != null) return sms;
    }
    return null;
  }

  /// Contact whose indexed emails/phones include an address on [friend].
  ContactV2? _findContact(FindMyFriend friend) {
    final index = _index;
    if (index == null) return null;
    for (final addr in _addresses(friend)) {
      final key = _addressKey(addr);
      if (key == null) continue;
      final id = index[key];
      // Re-read on the UI isolate so the contact's handles relation is attached to this store.
      final contact = id == null ? null : Database.contactsV2.get(id);
      if (contact != null) return contact;
    }
    return null;
  }

  /// Distinct addresses from [FindMyFriend.handleAddress] and [FindMyFriend.title].
  /// Truncates at `/` — some Find My payloads use `address/suffix`.
  static Iterable<String> _addresses(FindMyFriend friend) {
    return {friend.handleAddress, friend.title}
        .whereType<String>()
        .map((value) {
          final trimmed = value.trim();
          return trimmed.contains('/') ? trimmed.split('/').first : trimmed;
        })
        .where((addr) => addr.isNotEmpty);
  }

  /// Map of [_addressKey] → contact id.
  ///
  /// Keys are exact (lowercased email or E.164 phone), never the guessed country-code-stripped
  /// variants contact sync uses: a false match here would put someone else's name on a live
  /// location. Addresses claimed by two different contacts are dropped rather than guessed.
  static Map<String, int> _buildIndex(List<ContactV2> contacts) {
    final index = <String, ContactV2>{};
    final ambiguous = <String>{};
    for (final contact in contacts) {
      for (final address in contact.addresses) {
        final key = _addressKey(address);
        if (key != null) _addToIndex(index, ambiguous, key, contact);
      }
    }
    return index.map((key, contact) => MapEntry(key, contact.id));
  }

  static void _addToIndex(Map<String, ContactV2> index, Set<String> ambiguous, String key, ContactV2 contact) {
    if (ambiguous.contains(key)) return;
    final existing = index[key];
    if (existing == null || existing.id == contact.id) {
      index[key] = contact;
      return;
    }
    // A device contact and a server-synced contact sharing an address are usually the same
    // person: keep the device one, as Handle.displayName does.
    if (existing.isNative != contact.isNative) {
      if (contact.isNative) index[key] = contact;
      return;
    }
    // Two distinct contacts claim this address — don't guess which one is at this location.
    index.remove(key);
    ambiguous.add(key);
  }

  /// Best [Handle] already linked to [contact] after a contact-only match.
  /// Skips [friend]'s Find My address; prefers a 1:1 iMessage chat, then SMS, then any other.
  static Handle? _linkedHandle(ContactV2 contact, FindMyFriend friend) {
    final skip = _addresses(friend).map(_addressKey).whereType<String>().toSet();

    Handle? inChatIMessage;
    Handle? inChatSms;
    Handle? anyIMessage;
    Handle? anySms;
    for (final handle in contact.handles) {
      if (skip.contains(_addressKey(handle.address, region: handle.country))) continue;
      final used = _usedInDirectChat(handle);
      if (handle.service == 'iMessage') {
        if (used) {
          inChatIMessage ??= handle;
        } else {
          anyIMessage ??= handle;
        }
      } else if (used) {
        inChatSms ??= handle;
      } else {
        anySms ??= handle;
      }
    }
    return inChatIMessage ?? inChatSms ?? anyIMessage ?? anySms;
  }

  /// Exact match key for an email or phone: lowercased email, or E.164 phone. Phones that
  /// can't be parsed fall back to their digits, which then only match the identical digits.
  /// [region] is used for numbers without a `+` (default: the device's country).
  static String? _addressKey(String address, {String? region}) {
    if (address.contains('@')) {
      final email = ContactV2.normalizeEmail(address);
      return email.isEmpty ? null : email;
    }
    final key = normalizeToE164(address, region: region) ?? ContactV2.normalizePhoneNumber(address);
    return key.isEmpty ? null : key;
  }

  /// Whether [handle] is a participant in a non-deleted 1:1 chat (guid `service;-;address`).
  /// Uses the chat ↔ handle relation rather than matching the address inside the guid, which
  /// would also hit longer addresses that merely contain it. Group chats are ignored.
  static bool _usedInDirectChat(Handle handle) {
    if (kIsWeb || handle.id == null) return false;
    final query = (Database.chats.query(Chat_.guid.contains(';-;') & Chat_.dateDeleted.isNull())
          ..linkMany(Chat_.handles, Handle_.id.equals(handle.id!)))
        .build();
    query.limit = 1;
    final found = query.findFirst() != null;
    query.close();
    return found;
  }
}
