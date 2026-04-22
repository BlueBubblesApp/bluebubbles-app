import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart' show SelectedContact;
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A single contact row inside the search results list.
///
/// For each [ContactV2], this widget renders one row per unique phone number
/// and one row per unique email address (duplicates are filtered out by their
/// numeric-only representation, matching the existing [ChatListSection] logic).
class SearchContactTile extends StatelessWidget {
  const SearchContactTile({
    super.key,
    required this.contact,
    required this.controller,
  });

  final ContactV2 contact;
  final ChatCreatorController controller;

  @override
  Widget build(BuildContext context) {
    // Deduplicate phone numbers and email addresses.
    final seenNumbers = <String>{};
    final uniquePhones = contact.phoneNumbers.where((p) => seenNumbers.add(p.number.numericOnly())).toList();

    final seenAddresses = <String>{};
    final uniqueEmails = contact.emailAddresses.where((e) => seenAddresses.add(e.address.trim())).toList();

    if (uniquePhones.isEmpty && uniqueEmails.isEmpty) return const SizedBox.shrink();

    return Obx(() {
      final hideInfo = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
      // Email addresses are only valid for iMessage
      final showEmails = controller.selectedService.value.isIMessageService;

      return Column(
        key: ValueKey(contact.nativeContactId),
        mainAxisSize: MainAxisSize.min,
        children: [
          ...uniquePhones.map(
            (p) => _ContactAddressRow(
              displayName: hideInfo ? 'Contact' : contact.computedDisplayName,
              address: hideInfo ? '' : p.number,
              label: hideInfo ? null : p.label,
              contact: contact,
              onTap: () {
                if (controller.selectedContacts.firstWhereOrNull((c) => c.address == p.number) != null) {
                  return;
                }
                controller.addSelected(
                  SelectedContact(
                    displayName: contact.computedDisplayName,
                    address: p.number,
                  ),
                );
              },
            ),
          ),
          if (showEmails)
            ...uniqueEmails.map(
              (e) => _ContactAddressRow(
                displayName: hideInfo ? 'Contact' : contact.computedDisplayName,
                address: hideInfo ? '' : e.address,
                label: hideInfo ? null : e.label,
                contact: contact,
                onTap: () {
                  if (controller.selectedContacts.firstWhereOrNull((c) => c.address == e.address) != null) {
                    return;
                  }
                  controller.addSelected(
                    SelectedContact(
                      displayName: contact.computedDisplayName,
                      address: e.address,
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}

class _ContactAddressRow extends StatelessWidget {
  const _ContactAddressRow({
    required this.displayName,
    required this.address,
    required this.contact,
    required this.onTap,
    this.label,
  });

  final String displayName;
  final String address;
  final String? label;
  final ContactV2 contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // When the display name is the same as the address (unnamed contact), avoid
    // showing the number twice. Just show the label below if there is one (#2610).
    final nameIsAddress = displayName.numericOnly() == address.numericOnly() && displayName.numericOnly().isNotEmpty;
    final String? subtitleText;
    if (nameIsAddress) {
      subtitleText = (label != null && label!.isNotEmpty) ? label : null;
    } else {
      subtitleText = (label != null && label!.isNotEmpty) ? '$address  •  $label' : address;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          dense: SettingsSvc.settings.denseChatTiles.value,
          minVerticalPadding: 10,
          leading: ContactAvatarWidget(
            handle: null,
            contact: contact,
            size: 40,
            borderThickness: 0.1,
          ),
          title: Text(
            displayName,
            style: context.theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitleText != null
              ? Text(
                  subtitleText,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        ),
      ),
    );
  }
}
