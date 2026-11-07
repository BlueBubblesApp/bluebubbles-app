import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
NameAndPhotoSharingService get NameAndPhotoSharingSvc => GetIt.I<NameAndPhotoSharingService>();

/// Messages' "Share Name and Photo", as the server exposes it: whether to offer sharing yours with a chat, and the
/// names and photos participants shared with you. This only reads what was shared and remembers what the user
/// dismissed. Anything written to the device address book goes through [ContactsSvcV2].
class NameAndPhotoSharingService {
  static const String _tag = 'NameAndPhotoSharing';

  /// How long a read card is reused, so reopening a chat doesn't ask the server again
  static const Duration _cardTtl = Duration(minutes: 30);

  /// Each participant's card is a Private API call, so larger groups aren't looked up
  static const int _maxLookedUpParticipants = 10;

  /// Chats whose add or share offers were dismissed this session
  final Set<String> _dismissedAdds = {};
  final Set<String> _dismissedShares = {};

  /// Cards read recently, by address (empty for your own)
  final Map<String, ({DateTime readAt, ({String? name, Uint8List? avatar})? card})> _cards = {};

  /// Name and photo sharing needs the Private API, a server that supports it, and an iMessage chat
  bool isAvailableIn(Chat chat) =>
      SettingsSvc.settings.enablePrivateAPI.value && SettingsSvc.serverDetails.supportsNameSharing && chat.isIMessage;

  /// Your own shared photo when Messages would offer to share your name and photo with [chat], or null when it
  /// wouldn't (already shared, dismissed, unavailable, or the server couldn't say).
  Future<({Uint8List? avatar})?> shareOffer(Chat chat) async {
    if (!isAvailableIn(chat) || _dismissedShares.contains(chat.guid)) return null;
    try {
      final offer = (await HttpSvc.chat.shouldShareContact(chat.guid)).data['data'] == true;
      if (!offer) return null;
      return (avatar: (await _readCard())?.avatar);
    } catch (e) {
      Logger.warn('Could not check name and photo sharing for ${chat.guid}', error: e, tag: _tag);
      return null;
    }
  }

  /// What [chat]'s participants shared that's worth offering, as each is read: a new contact to add, or a photo that
  /// differs from the last one offered for an existing device contact. Cancelling the subscription stops the lookups.
  Stream<SharedNameAndPhoto> sharedWithYouIn(Chat chat) async* {
    // Desktop has no address book to add to or update
    if (kIsDesktop || !isAvailableIn(chat)) return;
    final participants = chat.participants.isNotEmpty ? chat.participants : chat.handles.toList();
    if (participants.length > _maxLookedUpParticipants) return;
    for (final handle in participants) {
      // Photo updates need a native contact to write to
      if (handle.contactsV2.isNotEmpty && !handle.contactsV2.any((c) => c.isNative)) continue;
      if (handle.contactsV2.isEmpty && _dismissedAdds.contains(chat.guid)) continue;
      final card = await _readCard(address: handle.address);
      if (card == null) continue;
      final shared = SharedNameAndPhoto(handle, card.name, card.avatar);
      if (shared.isNewContact ||
          (shared.photoHash != null && PrefsSvc.messaging.getSeenSharedPhoto(handle.address) != shared.photoHash)) {
        yield shared;
      }
    }
  }

  void dismissAdds(Chat chat) => _dismissedAdds.add(chat.guid);

  void dismissShare(Chat chat) => _dismissedShares.add(chat.guid);

  /// A dismissed photo isn't offered again until they share a different one
  Future<void> dismissPhoto(SharedNameAndPhoto shared) =>
      PrefsSvc.messaging.setSeenSharedPhoto(shared.handle.address, shared.photoHash!);

  /// Shares your name and photo with [chat]. Returns whether the server accepted it.
  Future<bool> shareYours(Chat chat) async {
    try {
      await HttpSvc.chat.shareContact(chat.guid);
      return true;
    } catch (e) {
      Logger.warn('Could not share name and photo with ${chat.guid}', error: e, tag: _tag);
      return false;
    }
  }

  /// Opens the device's new contact form, filled in with what [shared] shared
  Future<void> openAddContactForm(SharedNameAndPhoto shared) {
    final address = shared.handle.address;
    return MethodChannelSvc.actions.openContactForm(
      address: address,
      isEmail: address.isEmail,
      name: shared.name,
      avatar: shared.avatar,
    );
  }

  /// Saves the photo [shared] shared to their device contact. Once saved, that photo isn't offered again.
  Future<ContactPhotoUpdate> savePhoto(SharedNameAndPhoto shared) async {
    final result = await ContactsSvcV2.setNativeContactPhoto(shared.contact!.nativeContactId, shared.avatar!);
    if (result == ContactPhotoUpdate.updated) await dismissPhoto(shared);
    return result;
  }

  /// The card [address] shared with you, or your own without one. Null when nothing was shared or it couldn't be read.
  Future<({String? name, Uint8List? avatar})?> _readCard({String? address}) async {
    final key = address ?? '';
    final cached = _cards[key];
    if (cached != null && DateTime.now().difference(cached.readAt) < _cardTtl) return cached.card;
    try {
      final data = (await HttpSvc.icloud.getAccountContact(address: address)).data['data'];
      final name = data is Map ? data['name'] as String? : null;
      final avatar = data is Map ? data['avatar'] as String? : null;
      final card = isNullOrEmpty(name) && isNullOrEmpty(avatar)
          ? null
          : (name: isNullOrEmpty(name) ? null : name, avatar: isNullOrEmpty(avatar) ? null : base64Decode(avatar!));
      final now = DateTime.now();
      _cards.removeWhere((_, entry) => now.difference(entry.readAt) >= _cardTtl);
      _cards[key] = (readAt: now, card: card);
      return card;
    } catch (e) {
      // Not cached, so the next open tries again
      Logger.warn('Could not read the contact card ${address ?? 'of this account'}', error: e, tag: _tag);
      return null;
    }
  }
}
