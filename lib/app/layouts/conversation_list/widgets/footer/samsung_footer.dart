import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SamsungFooter extends CustomStateful<ConversationListController> {
  const SamsungFooter({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungFooterState();
}

class _SamsungFooterState extends CustomState<SamsungFooter, void, ConversationListController> {
  bool get showArchived => controller.showArchivedChats;
  bool get showUnknown => controller.showUnknownSenders;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
      child: controller.selectedChats.isEmpty
          ? const SizedBox.shrink()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (([0, controller.selectedChats.length])
                    .contains(controller.selectedChats.where((element) => element.hasUnreadMessage!).length))
                  IconButton(
                    onPressed: () {
                      for (Chat element in controller.selectedChats) {
                        final chatState = ChatsSvc.getChatState(element.guid);
                        if (chatState != null) {
                          ChatsSvc.setChatHasUnread(chatState.chat, !element.hasUnreadMessage!);
                        } else {
                          element.toggleHasUnreadAsync(!element.hasUnreadMessage!);
                        }
                      }
                      controller.clearSelectedChats();
                    },
                    icon: Icon(
                      controller.selectedChats[0].hasUnreadMessage!
                          ? Icons.mark_chat_read_outlined
                          : Icons.mark_chat_unread_outlined,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                if (([0, controller.selectedChats.length])
                    .contains(controller.selectedChats.where((element) => element.muteType == "mute").length))
                  IconButton(
                    onPressed: () {
                      for (Chat element in controller.selectedChats) {
                        final chatState = ChatsSvc.getChatState(element.guid);
                        if (chatState != null) {
                          ChatsSvc.setChatMuted(chatState.chat, element.muteType != "mute");
                        } else {
                          element.toggleMuteAsync(element.muteType != "mute");
                        }
                      }
                      controller.clearSelectedChats();
                    },
                    icon: Icon(
                      controller.selectedChats[0].muteType == "mute"
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                if (([0, controller.selectedChats.length])
                    .contains(controller.selectedChats.where((element) => element.isPinned!).length))
                  IconButton(
                    onPressed: () {
                      for (Chat element in controller.selectedChats) {
                        final chatState = ChatsSvc.getChatState(element.guid);
                        ChatsSvc.setChatPinned(chatState?.chat ?? element, !element.isPinned!);
                      }
                      controller.clearSelectedChats();
                    },
                    icon: Icon(
                      controller.selectedChats[0].isPinned! ? Icons.push_pin_outlined : Icons.push_pin,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  onPressed: () {
                    for (Chat element in controller.selectedChats) {
                      final chatState = ChatsSvc.getChatState(element.guid);
                      ChatsSvc.setChatArchived(chatState?.chat ?? element, !element.isArchived!);
                    }
                    controller.clearSelectedChats();
                  },
                  icon: Icon(
                    showArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    color: context.theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    for (Chat element in controller.selectedChats) {
                      ChatsSvc.removeChat(element);
                      ChatsSvc.softDeleteChat(element);
                    }
                    controller.clearSelectedChats();
                  },
                  icon: Icon(
                    Icons.delete_outlined,
                    color: context.theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
    );
  }
}
