import 'dart:convert';

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

class _SharedContactBannerState extends State<SharedContactBanner> {
  /// Chats whose banners were dismissed this session
  static final Set<String> _dismissed = {};

  Chat get chat => widget.chat;
  final List<_SharedCard> _adds = [];
  final List<_SharedCard> _updates = [];
  bool _offerShare = false;

  @override
  void initState() {
    super.initState();
    if (!SettingsSvc.settings.enablePrivateAPI.value ||
        !SettingsSvc.serverDetails.supportsNameSharing ||
        !chat.isIMessage ||
        _dismissed.contains(chat.guid)) {
      return;
    }
    _loadOffer();
    _loadSharedCards();
  }

  Future<void> _loadOffer() async {
    try {
      final offer = (await HttpSvc.chat.shouldShareContact(chat.guid)).data['data'] == true;
      if (offer && mounted) setState(() => _offerShare = true);
    } catch (e) {
      Logger.warn('Could not check name and photo sharing for ${chat.guid}', error: e, tag: 'SharedContact');
    }
  }

  Future<void> _loadSharedCards() async {
    final participants = chat.participants.isNotEmpty ? chat.participants : chat.handles.toList();
    for (final handle in participants) {
      final card = await _fetchCard(handle);
      if (card == null || !mounted) continue;
      if (handle.contactsV2.isEmpty) {
        setState(() => _adds.add(card));
      } else if (!kIsDesktop &&
          card.contact != null &&
          card.photoHash != null &&
          PrefsSvc.messaging.getSeenSharedPhoto(handle.address) != card.photoHash) {
        setState(() => _updates.add(card));
      }
    }
  }

  Future<_SharedCard?> _fetchCard(Handle handle) async {
    try {
      final data = (await HttpSvc.icloud.getAccountContact(address: handle.address)).data['data'];
      if (data is! Map) return null;
      final name = data['name'] as String?;
      final avatar = data['avatar'] as String?;
      if (isNullOrEmpty(name) && isNullOrEmpty(avatar)) return null;
      return _SharedCard(handle, isNullOrEmpty(name) ? null : name, isNullOrEmpty(avatar) ? null : base64Decode(avatar!));
    } catch (e) {
      Logger.warn('Could not read the contact card ${handle.address} shared', error: e, tag: 'SharedContact');
      return null;
    }
  }

  void _dismiss() {
    _dismissed.add(chat.guid);
    // A dismissed photo isn't offered again until they share a different one
    for (final card in _updates) {
      PrefsSvc.messaging.setSeenSharedPhoto(card.handle.address, card.photoHash!);
    }
    setState(() {
      _adds.clear();
      _updates.clear();
      _offerShare = false;
    });
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
    if (!kIsDesktop) {
      await MethodChannelSvc.actions.openContactForm(
        address: address,
        isEmail: address.isEmail,
        name: card.name,
        avatar: card.avatar,
      );
      return;
    }
    // Desktop contacts come from the server, so the contact is created there
    final name = card.name ?? address;
    try {
      await HttpSvc.contact.create([
        {
          'displayName': name,
          'firstName': name.split(' ').first,
          'lastName': name.contains(' ') ? name.substring(name.indexOf(' ') + 1) : null,
          'phoneNumbers': [if (!address.isEmail) address],
          'emails': [if (address.isEmail) address],
          'avatar': card.avatar == null ? null : base64Encode(card.avatar!),
        }
      ]);
      await ContactsSvcV2.syncContactsToHandles();
      showSnackbar("Contact Added", "$name was added to your contacts");
    } catch (e) {
      Logger.warn('Could not add $address to contacts', error: e, tag: 'SharedContact');
      showSnackbar("Error", "Couldn't add $name to your contacts", type: SnackbarType.error);
    }
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
            avatar: _adds.single.avatar,
            text: "${_adds.single.name ?? _adds.single.handle.displayName} shared their name and photo",
            action: "Add to Contacts",
            onAction: () => _addContact(_adds.single),
            onDismiss: _dismiss,
          ),
        if (_adds.length > 1)
          _BannerCard(
            text: "${_adds.length} people shared their name and photo",
            action: "View",
            onAction: () => _showList(_adds, "Add", _addContact),
            onDismiss: _dismiss,
          ),
        if (_updates.length == 1)
          _BannerCard(
            avatar: _updates.single.avatar,
            text: "${_updates.single.label} shared a new photo",
            action: "Update",
            onAction: () => _updatePhoto(_updates.single),
            onDismiss: _dismiss,
          ),
        if (_updates.length > 1)
          _BannerCard(
            text: "${_updates.length} contacts shared new photos",
            action: "View",
            onAction: () => _showList(_updates, "Update", _updatePhoto),
            onDismiss: _dismiss,
          ),
        if (_offerShare)
          _BannerCard(
            text: "Share your name and photo?",
            action: "Share",
            onAction: _share,
            onDismiss: _dismiss,
          ),
      ];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: cards.expandIndexed((i, card) => [if (i > 0) const SizedBox(height: 8), card]).toList(),
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
    this.avatar,
    required this.text,
    required this.action,
    required this.onAction,
    required this.onDismiss,
  });

  final Uint8List? avatar;
  final String text;
  final String action;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Row(
          children: [
            _SharedAvatar(avatar),
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
