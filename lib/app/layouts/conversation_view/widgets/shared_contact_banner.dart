import 'dart:convert';
import 'dart:ui';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:get/get.dart';

/// Messages' name and photo sharing: offers to add or update contacts from what people shared, and to share yours.
/// A shared name is only a suggestion, never a display name.
class SharedContactBanner extends StatefulWidget {
  const SharedContactBanner({super.key, required this.chat});

  final Chat chat;

  @override
  State<SharedContactBanner> createState() => _SharedContactBannerState();
}

/// What one participant shared
class _SharedCard {
  _SharedCard(this.handle, this.name, this.avatar)
      : contact = handle.contactsV2.firstWhereOrNull((c) => c.isNative),
        photoHash = avatar == null ? null : md5.convert(avatar).toString();

  final Handle handle;
  final String? name;
  final Uint8List? avatar;
  final ContactV2? contact;
  final String? photoHash;

  String get label => contact?.displayName ?? name ?? handle.displayName;
}

typedef _Card = ({String? name, Uint8List? avatar});

class _SharedContactBannerState extends State<SharedContactBanner> {
  /// Chats whose add or share offers were dismissed this session
  static final Set<String> _dismissedAdds = {};
  static final Set<String> _dismissedShares = {};

  /// Cards read recently, by address (empty for your own), so reopening a chat doesn't ask the server again
  static final Map<String, ({DateTime readAt, _Card? card})> _cards = {};
  static const Duration _cardTtl = Duration(minutes: 30);

  /// Each participant's card is a Private API call, so larger groups aren't looked up
  static const int _maxLookedUpParticipants = 10;

  Chat get chat => widget.chat;
  final List<_SharedCard> _adds = [];
  final List<_SharedCard> _updates = [];
  bool _offerShare = false;
  Uint8List? _myAvatar;

  @override
  void initState() {
    super.initState();
    if (!SettingsSvc.settings.enablePrivateAPI.value ||
        !SettingsSvc.serverDetails.supportsNameSharing ||
        !chat.isIMessage) {
      return;
    }
    if (!_dismissedShares.contains(chat.guid)) _loadOffer();
    // Desktop has no address book to add to or update
    if (!kIsDesktop) _loadSharedCards();
  }

  Future<void> _loadOffer() async {
    try {
      final offer = (await HttpSvc.chat.shouldShareContact(chat.guid)).data['data'] == true;
      if (!offer) return;
      final myCard = await _readCard();
      if (mounted) {
        setState(() {
          _offerShare = true;
          _myAvatar = myCard?.avatar;
        });
      }
    } catch (e) {
      Logger.warn('Could not check name and photo sharing for ${chat.guid}', error: e, tag: 'SharedContact');
    }
  }

  /// The card [address] shared with you, or your own without one
  Future<_Card?> _readCard({String? address}) async {
    final key = address ?? '';
    final cached = _cards[key];
    if (cached != null && DateTime.now().difference(cached.readAt) < _cardTtl) return cached.card;
    try {
      final data = (await HttpSvc.icloud.getAccountContact(address: address)).data['data'];
      final name = data is Map ? data['name'] as String? : null;
      final avatar = data is Map ? data['avatar'] as String? : null;
      final _Card? card = isNullOrEmpty(name) && isNullOrEmpty(avatar)
          ? null
          : (name: isNullOrEmpty(name) ? null : name, avatar: isNullOrEmpty(avatar) ? null : base64Decode(avatar!));
      final now = DateTime.now();
      _cards.removeWhere((_, entry) => now.difference(entry.readAt) >= _cardTtl);
      _cards[key] = (readAt: now, card: card);
      return card;
    } catch (e) {
      Logger.warn('Could not read the contact card ${address ?? 'of this account'}', error: e, tag: 'SharedContact');
      return null;
    }
  }

  Future<void> _loadSharedCards() async {
    final participants = chat.participants.isNotEmpty ? chat.participants : chat.handles.toList();
    if (participants.length > _maxLookedUpParticipants) return;
    for (final handle in participants) {
      // Photo updates need a native contact to write to
      if (handle.contactsV2.isNotEmpty && !handle.contactsV2.any((c) => c.isNative)) continue;
      if (handle.contactsV2.isEmpty && _dismissedAdds.contains(chat.guid)) continue;
      final card = await _fetchCard(handle);
      if (!mounted) return;
      if (card == null) continue;
      if (handle.contactsV2.isEmpty) {
        setState(() => _adds.add(card));
      } else if (card.photoHash != null &&
          PrefsSvc.messaging.getSeenSharedPhoto(handle.address) != card.photoHash) {
        setState(() => _updates.add(card));
      }
    }
  }

  Future<_SharedCard?> _fetchCard(Handle handle) async {
    final card = await _readCard(address: handle.address);
    return card == null ? null : _SharedCard(handle, card.name, card.avatar);
  }

  void _dismissAdds() {
    _dismissedAdds.add(chat.guid);
    setState(() => _adds.clear());
  }

  void _dismissUpdates() {
    // A dismissed photo isn't offered again until they share a different one
    for (final card in _updates) {
      PrefsSvc.messaging.setSeenSharedPhoto(card.handle.address, card.photoHash!);
    }
    setState(() => _updates.clear());
  }

  void _dismissShare() {
    _dismissedShares.add(chat.guid);
    setState(() => _offerShare = false);
  }

  Future<void> _share() async {
    setState(() => _offerShare = false);
    try {
      await HttpSvc.chat.shareContact(chat.guid);
      showSnackbar("Shared", "Your name and photo were shared with this conversation");
    } catch (e) {
      Logger.warn('Could not share name and photo with ${chat.guid}', error: e, tag: 'SharedContact');
      showSnackbar("Error", "Couldn't share your name and photo", type: SnackbarType.error);
    }
  }

  Future<void> _addContact(_SharedCard card) async {
    setState(() => _adds.remove(card));
    final address = card.handle.address;
    await MethodChannelSvc.actions.openContactForm(
      address: address,
      isEmail: address.isEmail,
      name: card.name,
      avatar: card.avatar,
    );
  }

  Future<void> _updatePhoto(_SharedCard card) async {
    setState(() => _updates.remove(card));
    try {
      if (await fc.FlutterContacts.permissions.request(fc.PermissionType.readWrite) != fc.PermissionStatus.granted) {
        showSnackbar("Error", "BlueBubbles needs permission to edit your contacts", type: SnackbarType.error);
        return;
      }
      // Fetched with every property, since an update writes the whole contact back
      final contact = await fc.FlutterContacts.get(card.contact!.nativeContactId, properties: fc.ContactProperties.all);
      if (contact == null) return;
      await fc.FlutterContacts.update(contact.copyWith(photo: fc.Photo(fullSize: card.avatar)));
      await PrefsSvc.messaging.setSeenSharedPhoto(card.handle.address, card.photoHash!);
      await ContactsSvcV2.syncContactsToHandles();
      showSnackbar("Photo Updated", "${card.label}'s photo was updated");
    } catch (e) {
      Logger.warn('Could not update the photo of ${card.handle.address}', error: e, tag: 'SharedContact');
      showSnackbar("Error", "Couldn't update ${card.label}'s photo", type: SnackbarType.error);
    }
  }

  /// Lists several people, each with its own button
  Future<void> _showList(List<_SharedCard> cards, String action, Future<void> Function(_SharedCard) onAction) {
    return showBBDialog(
      context: context,
      title: "Shared Names and Photos",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: cards
            .map((card) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _SharedAvatar(card.avatar),
                  title: Text(card.label),
                  subtitle: card.contact == null ? Text(card.handle.displayName) : null,
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      onAction(card);
                    },
                    child: Text(action),
                  ),
                ))
            .toList(),
      ),
      actions: [BBDialogAction(text: "Close", onPressed: () => Navigator.of(context, rootNavigator: true).pop())],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final redacted = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
      if (redacted || (_adds.isEmpty && _updates.isEmpty && !_offerShare)) return const SizedBox.shrink();
      final cards = <Widget>[
        if (_adds.length == 1)
          _BannerCard(
            avatars: [_adds.single.avatar],
            text: "${_adds.single.name ?? _adds.single.handle.displayName} shared their name and photo",
            action: "Add to Contacts",
            onAction: () => _addContact(_adds.single),
            onDismiss: _dismissAdds,
          ),
        if (_adds.length > 1)
          _BannerCard(
            avatars: _adds.map((c) => c.avatar).toList(),
            text: "${_adds.length} people shared their name and photo",
            action: "View",
            onAction: () => _showList(_adds, "Add", _addContact),
            onDismiss: _dismissAdds,
          ),
        if (_updates.length == 1)
          _BannerCard(
            avatars: [_updates.single.avatar],
            text: "New contact photo available",
            action: "Update",
            onAction: () => _updatePhoto(_updates.single),
            onDismiss: _dismissUpdates,
          ),
        if (_updates.length > 1)
          _BannerCard(
            avatars: _updates.map((c) => c.avatar).toList(),
            text: "${_updates.length} people updated contact information",
            action: "View",
            onAction: () => _showList(_updates, "Update", _updatePhoto),
            onDismiss: _dismissUpdates,
          ),
        if (_offerShare)
          _BannerCard(
            avatars: [_myAvatar],
            text: "Share your name and photo?",
            action: "Share",
            onAction: _share,
            onDismiss: _dismissShare,
          ),
      ];
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
              border: Border(
                bottom: BorderSide(color: context.theme.colorScheme.outlineVariant.withValues(alpha: 0.25), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: cards),
          ),
        ),
      );
    });
  }
}

class _SharedAvatar extends StatelessWidget {
  const _SharedAvatar(this.avatar);

  final Uint8List? avatar;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: context.theme.colorScheme.primaryContainer,
      foregroundImage: avatar == null ? null : MemoryImage(avatar!),
      child: Icon(Icons.person_rounded, color: context.theme.colorScheme.onPrimaryContainer),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    this.avatars = const [null],
    required this.text,
    required this.action,
    required this.onAction,
    required this.onDismiss,
  });

  final List<Uint8List?> avatars;
  final String text;
  final String action;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  Widget _avatarStack(BuildContext context) {
    final shown = avatars.take(3).toList();
    if (shown.length == 1) return _SharedAvatar(shown.single);
    return SizedBox(
      width: 36 + (shown.length - 1) * 16,
      height: 36,
      child: Stack(
        children: shown
            .mapIndexed((i, avatar) => Positioned(
                  left: i * 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: context.theme.colorScheme.surfaceContainerHigh, width: 1.5),
                    ),
                    child: _SharedAvatar(avatar),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Row(
          children: [
            _avatarStack(context),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: context.theme.textTheme.bodyMedium)),
            TextButton(onPressed: onAction, child: Text(action)),
            IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}
