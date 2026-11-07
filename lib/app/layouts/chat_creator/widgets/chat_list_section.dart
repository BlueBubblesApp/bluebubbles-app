import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_creator_tile.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Extracted widget for the chat/contact list to isolate rebuilds
/// Only rebuilds when filteredChats or filteredContacts changes
class ChatListSection extends StatelessWidget {
  const ChatListSection({
    super.key,
    required this.filteredChats,
    required this.filteredContacts,
    required this.onChatTap,
    required this.onContactTap,
    required this.selectedContacts,
  });

  final List<Chat> filteredChats;
  final List<ContactV2> filteredContacts;
  final Function(List<SelectedContact>) onChatTap;
  final Function(SelectedContact) onContactTap;
  final List<SelectedContact> selectedContacts;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: ThemeSwitcher.getScrollPhysics(),
      slivers: <Widget>[
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (filteredChats.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Loading existing chats...",
                      style: context.theme.textTheme.labelLarge,
                    ),
                  ),
                  buildProgressIndicator(context, size: 15),
                ],
              );
            }
            final chat = filteredChats[index];

            return Obx(() {
              final chatState = ChatsSvc.getChatState(chat.guid);
              final title = chatState?.title.value ?? chat.getTitle();
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    onChatTap(chat.people
                        .where((e) => selectedContacts.firstWhereOrNull((c) => c.address == e.address) == null)
                        .map((e) => SelectedContact(
                              displayName: e.displayName,
                              address: e.address,
                              serviceType: chat.service,
                            ))
                        .toList());
                  },
                  child: ChatCreatorTile(
                    key: ValueKey(chat.guid),
                    title: title,
                    subtitle: chatState?.chatCreatorSubtitle.value ?? chat.getChatCreatorSubtitle(),
                    chat: chat,
                  ),
                ),
              );
            });
          },
              childCount:
                  filteredChats.length.clamp(ChatsSvc.loadedAllChats.isCompleted ? 0 : 1, double.infinity).toInt()),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final contact = filteredContacts[index];
              // Dedup by phone number / email address, preserving labels
              final seenNumbers = <String>{};
              final uniquePhones = contact.phoneNumbers.where((p) => seenNumbers.add(p.number.numericOnly())).toList();
              final seenAddresses = <String>{};
              final uniqueEmails = contact.emailAddresses.where((e) => seenAddresses.add(e.address.trim())).toList();

              return Obx(() {
                final hideInfo = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value;
                return Column(
                  key: ValueKey(contact.nativeContactId),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...uniquePhones.map((p) => Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (selectedContacts.firstWhereOrNull((c) => c.address == p.number) != null) return;
                              onContactTap(
                                  SelectedContact(displayName: contact.computedDisplayName, address: p.number));
                            },
                            child: ChatCreatorTile(
                              title: hideInfo ? "Contact" : contact.computedDisplayName,
                              subtitle: hideInfo ? "" : p.number,
                              label: hideInfo ? null : p.label,
                              contact: contact,
                              format: true,
                            ),
                          ),
                        )),
                    ...uniqueEmails.map((e) => Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (selectedContacts.firstWhereOrNull((c) => c.address == e.address) != null) return;
                              onContactTap(
                                  SelectedContact(displayName: contact.computedDisplayName, address: e.address));
                            },
                            child: ChatCreatorTile(
                              title: hideInfo ? "Contact" : contact.computedDisplayName,
                              subtitle: hideInfo ? "" : e.address,
                              label: hideInfo ? null : e.label,
                              contact: contact,
                            ),
                          ),
                        )),
                  ],
                );
              });
            },
            childCount: filteredContacts.length,
          ),
        ),
      ],
    );
  }
}
