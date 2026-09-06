import 'dart:async';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;
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
}

/// Resolves a Find My friend to a [Handle] and/or [ContactV2].
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
/// The email/phone → contact index is process-lifetime; contact sync
/// calls [clearContactIndex], which emits [indexCleared] so Find My can refresh.
/// 
class FindMyHandleMatcher {
  FindMyHandleMatcher._();

  static Map<String, ContactV2>? _index;
  static final _indexCleared = StreamController<void>.broadcast(sync: true);

  /// Broadcast after [clearContactIndex] so Find My can rebuild names/avatars.
  static Stream<void> get indexCleared => _indexCleared.stream;

  /// Drops the cached contact index and emits [indexCleared]. Called after contact sync.
  static void clearContactIndex() {
    _index = null;
    _indexCleared.add(null);
  }

  /// Returns the [Handle] and/or [ContactV2] for [friend], following the class lookup order.
  static FindMyFriendIdentity resolveIdentity(FindMyFriend friend) {
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
  static ContactV2? _findContact(FindMyFriend friend) {
    final index = _contactIndex();
    if (index == null) return null;
    for (final addr in _addresses(friend)) {
      if (addr.contains('@')) {
        final hit = index[ContactV2.normalizeEmail(addr)];
        if (hit != null) return hit;
      } else {
        for (final key in getPhoneNumberVariants(addr)) {
          final hit = index[key];
          if (hit != null) return hit;
        }
      }
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

  /// Lazy map of normalized contact email/phone → [ContactV2]. Null on web.
  static Map<String, ContactV2>? _contactIndex() {
    if (kIsWeb) return null;
    if (_index != null) return _index;

    final index = <String, ContactV2>{};
    for (final contact in Database.contactsV2.getAll()) {
      for (final address in contact.addresses) {
        if (address.contains('@')) {
          final email = ContactV2.normalizeEmail(address);
          if (email.isNotEmpty) index[email] = contact;
        } else {
          for (final key in getPhoneNumberVariants(address)) {
            if (key.isNotEmpty) index[key] = contact;
          }
        }
      }
    }
    return _index = index;
  }

  /// Best [Handle] already linked to [contact] after a contact-only match.
  /// Skips [friend]'s Find My address; prefers a 1:1 iMessage chat, then SMS, then any other.
  static Handle? _linkedHandle(ContactV2 contact, FindMyFriend friend) {
    final skip = {
      for (final addr in _addresses(friend)) _normalizeAddress(addr),
    };

    Handle? inChatIMessage;
    Handle? inChatSms;
    Handle? anyIMessage;
    Handle? anySms;
    for (final handle in contact.handles) {
      if (skip.contains(_normalizeAddress(handle.address))) continue;
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

  static String _normalizeAddress(String address) {
    return address.contains('@') ? ContactV2.normalizeEmail(address) : ContactV2.normalizePhoneNumber(address);
  }

  /// Whether [handle] appears in a 1:1 chat guid (`service;-;address`). Group chats are ignored.
  static bool _usedInDirectChat(Handle handle) {
    if (kIsWeb || handle.address.isEmpty) return false;
    final query = Database.chats.query(Chat_.guid.contains(';-;${handle.address}')).build();
    query.limit = 1;
    final found = query.findFirst() != null;
    query.close();
    return found;
  }
}
