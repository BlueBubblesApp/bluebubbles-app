import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Messages' name and photo sharing: offers to add or update contacts from what people shared, and to share yours.
/// What to offer comes from [NameAndPhotoSharingSvc]; this only shows it.
class SharedContactBanner extends StatefulWidget {
  const SharedContactBanner({super.key, required this.chat});

  final Chat chat;

  @override
  State<SharedContactBanner> createState() => _SharedContactBannerState();
}

class _SharedContactBannerState extends State<SharedContactBanner> {
  Chat get chat => widget.chat;
  final List<SharedNameAndPhoto> _adds = [];
  final List<SharedNameAndPhoto> _updates = [];
  bool _offerShare = false;
  Uint8List? _myAvatar;
  StreamSubscription<SharedNameAndPhoto>? _sharedSub;

  @override
  void initState() {
    super.initState();
    if (!NameAndPhotoSharingSvc.isAvailableIn(chat)) return;
    _loadOffer();
    _sharedSub = NameAndPhotoSharingSvc.sharedWithYouIn(chat).listen((shared) {
      if (mounted) setState(() => (shared.isNewContact ? _adds : _updates).add(shared));
    });
  }

  @override
  void dispose() {
    // Stops looking up the rest of the participants
    _sharedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOffer() async {
    final offer = await NameAndPhotoSharingSvc.shareOffer(chat);
    if (offer == null || !mounted) return;
    setState(() {
      _offerShare = true;
      _myAvatar = offer.avatar;
    });
  }

  void _dismissAdds() {
    NameAndPhotoSharingSvc.dismissAdds(chat);
    setState(() => _adds.clear());
  }

  void _dismissUpdates() {
    for (final shared in _updates) {
      NameAndPhotoSharingSvc.dismissPhoto(shared);
    }
    setState(() => _updates.clear());
  }

  void _dismissShare() {
    NameAndPhotoSharingSvc.dismissShare(chat);
    setState(() => _offerShare = false);
  }

  Future<void> _share() async {
    setState(() => _offerShare = false);
    if (await NameAndPhotoSharingSvc.shareYours(chat)) {
      showSnackbar("Shared", "Your name and photo were shared with this conversation");
    } else {
      showSnackbar("Error", "Couldn't share your name and photo", type: SnackbarType.error);
    }
  }

  Future<void> _addContact(SharedNameAndPhoto shared) async {
    setState(() => _adds.remove(shared));
    await NameAndPhotoSharingSvc.openAddContactForm(shared);
  }

  Future<void> _updatePhoto(SharedNameAndPhoto shared) async {
    setState(() => _updates.remove(shared));
    switch (await NameAndPhotoSharingSvc.savePhoto(shared)) {
      case ContactPhotoUpdate.updated:
        showSnackbar("Photo Updated", "${shared.label}'s photo was updated");
      case ContactPhotoUpdate.noPermission:
        showSnackbar("Error", "BlueBubbles needs permission to edit your contacts", type: SnackbarType.error);
      case ContactPhotoUpdate.missing:
        break;
      case ContactPhotoUpdate.failed:
        showSnackbar("Error", "Couldn't update ${shared.label}'s photo", type: SnackbarType.error);
    }
  }

  /// Lists several people, each with its own button
  Future<void> _showList(List<SharedNameAndPhoto> cards, String action, Future<void> Function(SharedNameAndPhoto) onAction) {
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
