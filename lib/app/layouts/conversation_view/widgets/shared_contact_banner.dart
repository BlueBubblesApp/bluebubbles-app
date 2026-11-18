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
  bool _expanded = false;
  Uint8List? _myAvatar;
  StreamSubscription<SharedNameAndPhoto>? _sharedSub;
  late final StreamSubscription<DispatchedEvent> _unhideSub;

  @override
  void initState() {
    super.initState();
    _load();
    _unhideSub = EventDispatcherSvc.stream.listen((e) {
      if (e.type != 'shared-contacts-unhidden' || e.data != chat.guid || !mounted) return;
      setState(() {
        _adds.clear();
        _updates.clear();
        _offerShare = false;
        _expanded = false;
      });
      _load();
    });
  }

  void _load() {
    _sharedSub?.cancel();
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
    _unhideSub.cancel();
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

  /// Folds the list back up once one person or none is left, so later arrivals start behind View
  void _remove(List<SharedNameAndPhoto> list, SharedNameAndPhoto shared) {
    list.remove(shared);
    if (_adds.length + _updates.length <= 1) _expanded = false;
  }

  Future<void> _addContact(SharedNameAndPhoto shared) async {
    setState(() => _remove(_adds, shared));
    await NameAndPhotoSharingSvc.openAddContactForm(shared);
  }

  Future<void> _updatePhoto(SharedNameAndPhoto shared) async {
    setState(() => _remove(_updates, shared));
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

  String _photoTitle(SharedNameAndPhoto shared) =>
      chat.isGroup ? "New photo available from ${shared.handle.reactionDisplayName}" : "New contact photo available";

  Future<void> _ignorePhoto(SharedNameAndPhoto shared) async {
    setState(() => _remove(_updates, shared));
    await NameAndPhotoSharingSvc.dismissPhoto(shared);
  }

  void _ignoreAdd(SharedNameAndPhoto shared) {
    setState(() => _remove(_adds, shared));
    NameAndPhotoSharingSvc.dismissAdd(shared);
  }

  Widget _addCard(SharedNameAndPhoto shared) => _BannerCard(
        key: ValueKey('add ${shared.handle.address}'),
        avatars: [shared.avatar],
        text: "New contact information",
        subtitle: shared.name ?? shared.handle.displayName,
        actionBelow: true,
        action: "Add to Contacts",
        onAction: () => _addContact(shared),
        onDismiss: () => _ignoreAdd(shared),
      );

  Widget _updateCard(SharedNameAndPhoto shared) => _BannerCard(
        key: ValueKey('update ${shared.handle.address}'),
        avatars: [shared.avatar],
        text: _photoTitle(shared),
        actionBelow: true,
        action: "Update Contact",
        onAction: () => _updatePhoto(shared),
        onDismiss: () => _ignorePhoto(shared),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final redacted = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
      if (redacted || (_adds.isEmpty && _updates.isEmpty && !_offerShare)) return const SizedBox.shrink();
      final people = [..._adds.map(_addCard), ..._updates.map(_updateCard)];
      final cards = <Widget>[
        if (people.length > 1)
          _BannerCard(
            key: const ValueKey('people'),
            avatars: [..._adds.map((c) => c.avatar), ..._updates.map((c) => c.avatar)],
            text: "${people.length} people updated contact information",
            actionBelow: true,
            action: _expanded ? "Hide" : "View",
            onAction: () => setState(() => _expanded = !_expanded),
          ),
        if (people.length == 1 || _expanded) ...people,
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
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: cards),
            ),
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
    super.key,
    this.avatars = const [null],
    required this.text,
    this.subtitle,
    this.actionBelow = false,
    required this.action,
    required this.onAction,
    this.onDismiss,
  });

  final List<Uint8List?> avatars;
  final String text;
  final String? subtitle;

  /// Bolds [text] and moves the action under it, after [subtitle]
  final bool actionBelow;
  final String action;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: actionBelow
                        ? context.theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)
                        : context.theme.textTheme.bodyMedium,
                  ),
                  if (actionBelow)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (subtitle != null) ...[
                          Flexible(
                            child: Text(
                              subtitle!,
                              style: context.theme.textTheme.bodySmall!.copyWith(
                                color: context.theme.colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _InlineAction(action, onAction),
                      ],
                    ),
                ],
              ),
            ),
            if (!actionBelow) TextButton(onPressed: onAction, child: Text(action)),
            if (onDismiss != null)
              IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: onDismiss)
            else
              // Holds the close button's space, so every banner is the same height and width
              const SizedBox.square(dimension: kMinInteractiveDimension),
          ],
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction(this.text, this.onPressed);

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        text,
        style: context.theme.textTheme.bodySmall!.copyWith(
          color: context.theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
