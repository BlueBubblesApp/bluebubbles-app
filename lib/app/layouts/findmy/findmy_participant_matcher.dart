import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;
import 'package:collection/collection.dart';

/// Matches Find My friends to conversation participants, including when they
/// use different identifiers (e.g. iCloud email in Find My vs phone in chat).
class FindMyParticipantMatcher {
  final List<Handle> participants;
  final Map<String, String> displayNamesByAddress;

  const FindMyParticipantMatcher({
    required this.participants,
    this.displayNamesByAddress = const {},
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
      for (final friendName in _friendNames(friend, resolvedFriendHandle)) {
        if (_namesMatch(contact.computedDisplayName, friendName)) return true;
        if (_namesMatch(contact.displayName, friendName)) return true;
        if (contact.nickname != null && _namesMatch(contact.nickname, friendName)) return true;
      }
    }

    final participantName = _participantDisplayName(handle);
    for (final friendName in _friendNames(friend, resolvedFriendHandle)) {
      if (_namesMatch(participantName, friendName)) return true;
    }

    return false;
  }

  String _participantDisplayName(Handle handle) =>
      displayNamesByAddress[handle.address] ?? handle.displayName;

  static bool friendIdentifiersMatch(FindMyFriend a, FindMyFriend b) {
    if (a.stableId != null && b.stableId != null && a.stableId == b.stableId) return true;
    for (final aId in friendIdentifiers(a)) {
      for (final bId in friendIdentifiers(b)) {
        if (identifiersMatch(aId, bId)) return true;
      }
    }
    final aName = (a.title ?? a.handle?.displayName ?? '').trim().toLowerCase();
    final bName = (b.title ?? b.handle?.displayName ?? '').trim().toLowerCase();
    return aName.isNotEmpty && namesMatch(aName, bName);
  }

  static Set<String> friendIdentifiers(FindMyFriend friend) => _friendIdentifiers(friend);

  static bool identifiersMatch(String a, String b) => _identifiersMatch(a, b);

  static bool namesMatch(String? a, String? b) => _namesMatch(a, b);

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
    final ids = <String>{handle.uniqueAddressAndService, handle.address};
    if (handle.uniqueAddressAndService.contains('/')) {
      ids.add(handle.uniqueAddressAndService.split('/').first);
    }
    return ids;
  }

  static Set<String> _friendIdentifiers(FindMyFriend friend) {
    final ids = <String>{};
    if (friend.stableId != null) ids.add(friend.stableId!);
    if (friend.handleAddress != null) ids.add(friend.handleAddress!);
    if (friend.subtitle != null) ids.add(friend.subtitle!);
    if (friend.handle != null) {
      ids.add(friend.handle!.address);
      ids.add(friend.handle!.uniqueAddressAndService);
    }
    if (friend.title != null) ids.add(friend.title!);
    return ids;
  }

  static Iterable<String> _friendNames(FindMyFriend friend, Handle? resolvedFriendHandle) sync* {
    if (friend.title != null && !friend.title!.contains('@')) yield friend.title!;
    if (friend.handle?.displayName != null) yield friend.handle!.displayName;
    if (resolvedFriendHandle != null) yield resolvedFriendHandle.displayName;
  }

  static bool _identifiersMatch(String a, String b) {
    if (a == b) return true;
    final aIsEmail = a.contains('@');
    final bIsEmail = b.contains('@');
    if (aIsEmail && bIsEmail) {
      return ContactV2.normalizeEmail(a) == ContactV2.normalizeEmail(b);
    }
    if (aIsEmail != bIsEmail) return false;
    final na = ContactV2.normalizePhoneNumber(a);
    final nb = ContactV2.normalizePhoneNumber(b);
    if (na.isNotEmpty && na == nb) return true;
    if (na.length >= 10 && nb.length >= 10) {
      return na.endsWith(nb.substring(nb.length - 10)) || nb.endsWith(na.substring(na.length - 10));
    }
    return false;
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

  static bool _namesMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    final na = a.trim().toLowerCase();
    final nb = b.trim().toLowerCase();
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;

    final aFirst = na.split(' ').where((s) => s.isNotEmpty).firstOrNull ?? '';
    final bFirst = nb.split(' ').where((s) => s.isNotEmpty).firstOrNull ?? '';
    return aFirst.length > 2 && aFirst == bFirst;
  }
}
