import 'package:bluebubbles/app/components/animated_dropdown_menu.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/add_participant.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/address_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/change_name.dart';
import 'package:bluebubbles/app/layouts/conversation_details/material/chat_photo_actions.dart' as photo_actions;
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The Material/Samsung hero header for the conversation details page — avatar, emphasized
/// title, supporting line, and a connected quick-action button group. Replaces the bare
/// `ContactTile` / plain `ListTile`s the `!iOS` branch of `ChatInfo` used to render.
class ExpressiveChatHeader extends StatelessWidget {
  final Chat chat;

  const ExpressiveChatHeader({super.key, required this.chat});

  bool get _canCall =>
      !kIsWeb &&
      !kIsDesktop &&
      !chat.chatIdentifier!.startsWith("urn:biz") &&
      (chat.handles.isNotEmpty &&
          ((chat.handles.first.contactsV2.firstOrNull?.phoneNumbers.isNotEmpty ?? false) ||
              !chat.handles.first.address.contains("@")));

  bool get _canAddPeople =>
      SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup;

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getChatState(chat.guid);
    final colorScheme = context.theme.colorScheme;

    return DeferredPointerHandler(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: chat.isGroup ? () => photo_actions.updatePhoto(context, chat) : null,
                    child: ContactAvatarGroupWidget(
                      size: 96,
                      editable: !chat.isGroup,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: DeferPointer(
                      child: AnimatedDropdownMenu(
                        trigger: (context, showMenu) => InkWell(
                          onTap: showMenu,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.surface, width: 2),
                              shape: BoxShape.circle,
                              color: colorScheme.primaryContainer,
                            ),
                            child: Icon(
                              Icons.edit,
                              color: colorScheme.onPrimaryContainer,
                              size: 16,
                            ),
                          ),
                        ),
                        menuBuilder: (overlayContext, hideMenu) => DropdownMenuCard(
                          width: 200,
                          children: [
                            const SizedBox(height: 4),
                            MenuItemRow(
                              icon: Icons.photo_outlined,
                              label: "Change photo",
                              onTap: () => hideMenu().then((_) => photo_actions.updatePhoto(overlayContext, chat)),
                            ),
                            Obx(() => chat.customAvatarPath != null
                                ? MenuItemRow(
                                    icon: Icons.close,
                                    label: "Remove photo",
                                    iconColor: colorScheme.error,
                                    onTap: () =>
                                        hideMenu().then((_) => photo_actions.deletePhoto(overlayContext, chat)),
                                  )
                                : const SizedBox.shrink()),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Obx(() => RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: context.theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      children: MessageHelper.buildEmojiText(
                        chatState?.title.value ?? chat.getTitle(),
                        context.theme.textTheme.headlineMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  )),
            ),
            _buildSupportingLine(context, chatState),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: M3EButtonGroup(items: _buildActions(context, chatState)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportingLine(BuildContext context, ChatState? chatState) {
    if (!chat.isGroup) {
      if (chatState == null || chatState.participants.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Obx(() {
          final address = chatState.participants.first.formattedAddress.value;
          if (address == null) return const SizedBox.shrink();
          return Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium!.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          );
        }),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        "${chat.handles.length} members · ${chat.isIMessage ? "iMessage" : "SMS"}",
        textAlign: TextAlign.center,
        style: context.theme.textTheme.bodyMedium!.copyWith(
          color: context.theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<M3EButtonGroupItem> _buildActions(BuildContext context, ChatState? chatState) {
    if (chat.isGroup) {
      return [
        if (_canAddPeople)
          M3EButtonGroupItem(
            icon: Icons.person_add_outlined,
            label: "Add people",
            onPressed: () => showAddParticipant(context, chat),
          ),
        M3EButtonGroupItem(
          icon: Icons.edit_outlined,
          label: "Rename",
          onPressed: () async {
            bool? papi = false;
            if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage) {
              papi = await photo_actions.showMethodDialog(context, chat, "Group Name Update Method");
            }
            if (papi == null) return;
            if (!context.mounted) return;
            showChangeName(chat, papi ? "private-api" : "local", context);
          },
        ),
        M3EButtonGroupItem(
          icon: (chatState?.muteType.value ?? chat.muteType) == "mute"
              ? Icons.notifications_off_outlined
              : Icons.notifications_outlined,
          label: "Mute",
          onPressed: () {
            final isMuted = (chatState?.muteType.value ?? chat.muteType) == "mute";
            if (chatState != null) {
              ChatsSvc.setChatMuted(chatState.chat, !isMuted);
            } else {
              chat.toggleMuteAsync(!isMuted);
            }
          },
        ),
        M3EButtonGroupItem(
          icon: Icons.search,
          label: "Search",
          onPressed: () => NavigationSvc.push(context, const SearchView()),
        ),
      ];
    }

    final contact = chat.handles.isNotEmpty ? chat.handles.first.contactsV2.firstOrNull : null;
    final hasContact = contact != null && contact.isNative;

    return [
      M3EButtonGroupItem(
        icon: Icons.message_outlined,
        label: "Message",
        onPressed: () => Navigator.of(context).pop(),
      ),
      if (_canCall)
        M3EButtonGroupItem(
          icon: Icons.call_outlined,
          label: "Call",
          onPressed: () => showAddressPicker(contact, chat.handles.first, context),
          onLongPress: () => showAddressPicker(contact, chat.handles.first, context, isLongPressed: true),
        ),
      if (!kIsWeb && !kIsDesktop)
        M3EButtonGroupItem(
          icon: Icons.video_call_outlined,
          label: "Video",
          onPressed: () => showAddressPicker(contact, chat.handles.first, context, video: true),
        ),
      if (chat.handles.isNotEmpty &&
          ((contact?.emailAddresses.isNotEmpty ?? false) || chat.handles.first.address.contains("@")))
        M3EButtonGroupItem(
          icon: Icons.email_outlined,
          label: "Mail",
          onPressed: () => showAddressPicker(contact, chat.handles.first, context, isEmail: true),
        ),
      if (!kIsWeb && !kIsDesktop)
        M3EButtonGroupItem(
          icon: hasContact ? Icons.info_outline : Icons.person_add_outlined,
          label: hasContact ? "Info" : "Add contact",
          onPressed: () async {
            if (!hasContact) {
              await MethodChannelSvc.actions.openContactForm(
                address: chat.handles.first.address,
                isEmail: chat.handles.first.address.isEmail,
              );
            } else {
              try {
                await MethodChannelSvc.actions.viewContactForm(nativeContactId: contact.nativeContactId);
              } catch (_) {
                showSnackbar("Error", "Failed to find contact on device!");
              }
            }
          },
        ),
    ];
  }
}
