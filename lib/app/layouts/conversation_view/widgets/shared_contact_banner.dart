import 'dart:convert';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Messages' name and photo sharing: offers to add someone who isn't a contact with the name and photo they shared,
/// and offers to share yours. A shared name is only ever a suggestion, never used as the person's display name.
class SharedContactBanner extends StatefulWidget {
  const SharedContactBanner({super.key, required this.chat});

  final Chat chat;

  @override
  State<SharedContactBanner> createState() => _SharedContactBannerState();
}

class _SharedContactBannerState extends State<SharedContactBanner> {
  /// Chats whose banners were dismissed this session
  static final Set<String> _dismissed = {};

  Chat get chat => widget.chat;
  Handle? _sender;
  String? _sharedName;
  Uint8List? _sharedAvatar;
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
    _loadSharedCard();
  }

  Future<void> _loadOffer() async {
    try {
      final offer = (await HttpSvc.chat.shouldShareContact(chat.guid)).data['data'] == true;
      if (offer && mounted) setState(() => _offerShare = true);
    } catch (e) {
      Logger.warn('Could not check name and photo sharing for ${chat.guid}', error: e, tag: 'SharedContact');
    }
  }

  Future<void> _loadSharedCard() async {
    final sender = chat.isGroup ? null : (chat.participants.firstOrNull ?? chat.handles.firstOrNull);
    if (sender == null || (!kIsWeb && sender.contactsV2.isNotEmpty)) return;
    try {
      final data = (await HttpSvc.icloud.getAccountContact(address: sender.address)).data['data'];
      if (data is! Map) return;
      final name = data['name'] as String?;
      final avatar = data['avatar'] as String?;
      if (isNullOrEmpty(name) && isNullOrEmpty(avatar)) return;
      if (!mounted) return;
      setState(() {
        _sender = sender;
        _sharedName = isNullOrEmpty(name) ? null : name;
        _sharedAvatar = isNullOrEmpty(avatar) ? null : base64Decode(avatar!);
      });
    } catch (e) {
      Logger.warn('Could not read the contact card ${sender.address} shared', error: e, tag: 'SharedContact');
    }
  }

  void _dismiss() {
    _dismissed.add(chat.guid);
    setState(() {
      _sender = null;
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

  Future<void> _addContact() async {
    final sender = _sender!;
    setState(() => _sender = null);
    if (!kIsDesktop) {
      await MethodChannelSvc.actions.openContactForm(
        address: sender.address,
        isEmail: sender.address.isEmail,
        name: _sharedName,
        avatar: _sharedAvatar,
      );
      return;
    }
    // Desktop contacts come from the server, so the contact is created there
    final name = _sharedName ?? sender.address;
    try {
      await HttpSvc.contact.create([
        {
          'displayName': name,
          'firstName': name.split(' ').first,
          'lastName': name.contains(' ') ? name.substring(name.indexOf(' ') + 1) : null,
          'phoneNumbers': [if (!sender.address.isEmail) sender.address],
          'emails': [if (sender.address.isEmail) sender.address],
          'avatar': _sharedAvatar == null ? null : base64Encode(_sharedAvatar!),
        }
      ]);
      await ContactsSvcV2.syncContactsToHandles();
      showSnackbar("Contact Added", "$name was added to your contacts");
    } catch (e) {
      Logger.warn('Could not add ${sender.address} to contacts', error: e, tag: 'SharedContact');
      showSnackbar("Error", "Couldn't add $name to your contacts", type: SnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final redacted = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
      if (redacted || (_sender == null && !_offerShare)) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sender != null)
              _BannerCard(
                avatar: _sharedAvatar,
                text: "${_sharedName ?? "They"} shared their name and photo",
                action: "Add to Contacts",
                onAction: _addContact,
                onDismiss: _dismiss,
              ),
            if (_sender != null && _offerShare) const SizedBox(height: 8),
            if (_offerShare)
              _BannerCard(
                text: "Share your name and photo?",
                action: "Share",
                onAction: _share,
                onDismiss: _dismiss,
              ),
          ],
        ),
      );
    });
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
            CircleAvatar(
              radius: 18,
              backgroundColor: context.theme.colorScheme.primaryContainer,
              foregroundImage: avatar == null ? null : MemoryImage(avatar!),
              child: Icon(Icons.person_rounded, color: context.theme.colorScheme.onPrimaryContainer),
            ),
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
