import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
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
      child: controller.selectedChats.isEmpty ? const SizedBox.shrink() : Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (([0, controller.selectedChats.length])
              .contains(controller.selectedChats.where((element) => GlobalChatService.isChatUnread(element)).length))
            IconButton(
              onPressed: () {
                for (String element in controller.selectedChats) {
                  GlobalChatService.toggleReadStatus(element);
                }
                controller.clearSelectedChats();
              },
              icon: Icon(
                GlobalChatService.isChatUnread(controller.selectedChats[0])
                    ? Icons.mark_chat_read_outlined
                    : Icons.mark_chat_unread_outlined,
                color: context.theme.colorScheme.primary,
              ),
            ),
          if (([0, controller.selectedChats.length])
              .contains(controller.selectedChats.where((element) => GlobalChatService.isChatMuted(element)).length))
            IconButton(
              onPressed: () {
                for (String element in controller.selectedChats) {
                  GlobalChatService.toggleMuteStatus(element);
                }
                controller.clearSelectedChats();
              },
              icon: Icon(
                GlobalChatService.isChatMuted(controller.selectedChats[0])
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: context.theme.colorScheme.primary,
              ),
            ),
          if (([0, controller.selectedChats.length])
              .contains(controller.selectedChats.where((element) => GlobalChatService.isChatPinned(element)).length))
            IconButton(
              onPressed: () {
                for (String element in controller.selectedChats) {
                  GlobalChatService.togglePinStatus(element);
                }
                controller.clearSelectedChats();
              },
              icon: Icon(
                GlobalChatService.isChatPinned(controller.selectedChats[0]) ? Icons.push_pin_outlined : Icons.push_pin,
                color: context.theme.colorScheme.primary,
              ),
            ),
          IconButton(
            onPressed: () {
              for (String element in controller.selectedChats) {
                GlobalChatService.toggleArchivedStatus(element);
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
              for (String element in controller.selectedChats) {
                GlobalChatService.removeChat(element);
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
