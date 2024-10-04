import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SamsungFooter extends CustomStateful<ConversationListController> {
  const SamsungFooter({Key? key, required super.parentController});

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
      child: controller.selectedChats.isEmpty ? const SizedBox.shrink() : Obx(() {
        List<Chat> selectedChats = controller.selectedChats.map((e) => GlobalChatService.getChat(e)!).toList();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (([0, selectedChats.length])
                .contains(selectedChats.where((element) => element.observables.isUnread.value).length))
              IconButton(
                onPressed: () {
                  for (Chat element in selectedChats) {
                    element.toggleUnreadStatus(null);
                  }

                  controller.clearSelectedChats();
                },
                icon: Icon(
                  selectedChats.first.observables.isUnread.value
                      ? Icons.mark_chat_read_outlined
                      : Icons.mark_chat_unread_outlined,
                  color: context.theme.colorScheme.primary,
                ),
              ),
            if (([0, selectedChats.length])
                .contains(selectedChats.where((element) => element.isChatMuted).length))
              IconButton(
                onPressed: () {
                  for (Chat element in selectedChats) {
                    element.toggleMuteType(null);
                  }

                  controller.clearSelectedChats();
                },
                icon: Icon(
                  selectedChats.first.isChatMuted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: context.theme.colorScheme.primary,
                ),
              ),
            if (([0, selectedChats.length])
                .contains(selectedChats.where((element) => element.observables.isPinned.value).length))
              IconButton(
                onPressed: () {
                  for (Chat element in selectedChats) {
                    element.toggleIsPinned(null);
                  }

                  controller.clearSelectedChats();
                },
                icon: Icon(
                  selectedChats.first.observables.isPinned.value ? Icons.push_pin_outlined : Icons.push_pin,
                  color: context.theme.colorScheme.primary,
                ),
              ),
            IconButton(
              onPressed: () {
                for (Chat element in selectedChats) {
                  element.toggleIsArchived(null);
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
                for (Chat element in selectedChats) {
                  element.toggleIsDeleted(null);
                }

                controller.clearSelectedChats();
              },
              icon: Icon(
                Icons.delete_outlined,
                color: context.theme.colorScheme.primary,
              ),
            ),
          ],
        );
      })
    );
  }
}
