import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;

/// Matches Find My friends to conversation participants when they use different
/// identifiers (e.g. iCloud email in Find My vs phone in chat).
///
/// Matching is intentionally conservative — only deterministic identity signals:
/// handle IDs, address equality (normalized), shared [ContactV2] records, and
/// contact phone/email entries. Display names are never compared.
class FindMyParticipantMatcher {
  final List<Handle> participants;

  const FindMyParticipantMatcher({
    required this.participants,
  });

  bool matches(FindMyFriend friend) => participants.any((handle) => matchesFriend(friend, handle));

  bool matchesFriend(FindMyFriend friend, Handle handle) {
    final resolvedFriendHandle = _resolveFriendHandle(friend);

    if (friend.handle != null) {
      if (friend.handle!.id != null && handle.id != null && friend.handle!.id == handle.id) return true;
      if (friend.handle!.uniqueAddressAndService == handle.uniqueAddressAndService) return true;
      if (_handlesShareContact(friend.handle!, handle)) return true;
    }

    if (resolvedFriendHandle != null && _handlesShareContact(resolvedFriendHandle, handle)) return true;

    for (final participantId in _handleIdentifiers(handle)) {
      for (final friendId in _friendIdentifiers(friend)) {
        if (_identifiersMatch(participantId, friendId)) return true;
      }
    }

    for (final contact in handle.contactsV2) {
      for (final friendId in _friendIdentifiers(friend)) {
        if (_contactMatchesIdentifier(contact, friendId)) return true;
      }
    }

    return false;
  }

  static bool friendIdentifiersMatch(FindMyFriend a, FindMyFriend b) {
    if (a.stableId != null && b.stableId != null && a.stableId == b.stableId) return true;
    for (final aId in friendIdentifiers(a)) {
      for (final bId in friendIdentifiers(b)) {
        if (identifiersMatch(aId, bId)) return true;
      }
    }
    return false;
  }

  static Set<String> friendIdentifiers(FindMyFriend friend) => _friendIdentifiers(friend);

  static bool identifiersMatch(String a, String b) => _identifiersMatch(a, b);

  static Handle? _resolveFriendHandle(FindMyFriend friend) {
    if (friend.handle != null) return friend.handle;
    for (final id in _friendIdentifiers(friend)) {
      final addr = id.contains('/') ? id.split('/').first : id;
      if (!addr.contains('@')) continue;
      final resolved = Handle.findOne(addressAndService: HandleLookupKey(addr, 'iMessage'));
      if (resolved != null) return resolved;
    }
    return null;
  }

  static bool _handlesShareContact(Handle a, Handle b) {
    for (final ca in a.contactsV2) {
      for (final cb in b.contactsV2) {
        if (ca.id == cb.id) return true;
      }
    }
    return false;
  }

  static Set<String> _handleIdentifiers(Handle handle) {
    final ids = <String>{
      handle.uniqueAddressAndService,
      handle.address,
      if (handle.formattedAddress != null) handle.formattedAddress!,
    };
    if (handle.uniqueAddressAndService.contains('/')) {
      ids.add(handle.uniqueAddressAndService.split('/').first);
    }
    return ids;
  }

  static Set<String> _friendIdentifiers(FindMyFriend friend) {
    final ids = <String>{};
    if (friend.stableId != null) ids.add(friend.stableId!);
    if (friend.handleAddress != null) ids.add(friend.handleAddress!);
    if (friend.handle != null) {
      ids.add(friend.handle!.address);
      ids.add(friend.handle!.uniqueAddressAndService);
    }
    if (friend.subtitle != null && _looksLikeAddress(friend.subtitle!)) {
      ids.add(friend.subtitle!);
    }
    if (friend.title != null && _looksLikeAddress(friend.title!)) {
      ids.add(friend.title!);
    }
    return ids;
  }

  /// True when [value] is an email or phone-like string, not a display name.
  static bool _looksLikeAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('@')) return true;
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 7;
  }

  static bool _identifiersMatch(String a, String b) {
    if (a == b) return true;

    final aIsEmail = a.contains('@');
    final bIsEmail = b.contains('@');
    if (aIsEmail != bIsEmail) return false;

    if (aIsEmail) {
      return ContactV2.normalizeEmail(a) == ContactV2.normalizeEmail(b);
    }

    final na = ContactV2.normalizePhoneNumber(a);
    final nb = ContactV2.normalizePhoneNumber(b);
    return na.isNotEmpty && na == nb;
  }

  static bool _contactMatchesIdentifier(ContactV2 contact, String identifier) {
    if (contact.hasMatchingAddress(identifier)) return true;
    for (final phone in contact.phoneNumbers) {
      if (_identifiersMatch(phone.number, identifier)) return true;
    }
    for (final email in contact.emailAddresses) {
      if (_identifiersMatch(email.address, identifier)) return true;
    }
    return false;
  }
}
