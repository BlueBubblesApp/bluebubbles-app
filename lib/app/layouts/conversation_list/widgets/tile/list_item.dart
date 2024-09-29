import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/classes/aliases.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ListItem extends StatelessWidget {
  final ChatGuid chatGuid;
  final ConversationListController controller;
  final VoidCallback update;
  ListItem({required this.chatGuid, required this.controller, required this.update});

  MaterialSwipeAction get leftAction => ss.settings.materialLeftAction.value;
  MaterialSwipeAction get rightAction => ss.settings.materialRightAction.value;

  Widget slideBackground(Chat chat, bool left) {
    MaterialSwipeAction action;
    if (left) {
      action = leftAction;
    } else {
      action = rightAction;
    }

    return Container(
      color: action == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : action == MaterialSwipeAction.alerts
          ? Colors.purple
          : action == MaterialSwipeAction.delete
          ? Colors.red
          : action == MaterialSwipeAction.mark_read
          ? Colors.blue
          : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: left ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            const SizedBox(
              width: 20,
            ),
            Obx(() => Icon(
              action == MaterialSwipeAction.pin
                  ? (chat.observables.isPinned.value ? Icons.star_outline : Icons.star)
                  : action == MaterialSwipeAction.alerts
                  ? (chat.observables.muteType.value == "mute" ? Icons.notifications_active : Icons.notifications_off)
                  : action == MaterialSwipeAction.delete
                  ? Icons.delete_forever_outlined
                  : action == MaterialSwipeAction.mark_read
                  ? (chat.observables.isUnread.value ? Icons.mark_chat_read : Icons.mark_chat_unread)
                  : (chat.observables.isArchived.value ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            )),
            Obx(() => Text(
              action == MaterialSwipeAction.pin
                  ? (chat.observables.isPinned.value ? " Unpin" : " Pin")
                  : action == MaterialSwipeAction.alerts
                  ? (chat.observables.muteType.value == "mute" ? ' Show Alerts' : ' Hide Alerts')
                  : action == MaterialSwipeAction.delete
                  ? " Delete"
                  : action == MaterialSwipeAction.mark_read
                  ? (chat.observables.isUnread.value ? ' Mark Read' : ' Mark Unread')
                  : (chat.observables.isArchived.value ? ' Unarchive' : ' Archive'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: left ? TextAlign.right : TextAlign.left,
            )),
            const SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: left ? Alignment.centerRight : Alignment.centerLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chat = GlobalChatService.getChat(chatGuid)!;
      final tile = ConversationTile(
        key: Key(chat.guid),
        chatGuid: chat.guid,
        controller: controller,
        onSelect: (bool isSelected) {
          if (isSelected) {
            controller.selectedChats.add(chat.guid);
            controller.updateSelectedChats();
          } else {
            controller.selectedChats.removeWhere((element) => element == chat.guid);
            controller.updateSelectedChats();
          }
        },
      );

      if (ss.settings.swipableConversationTiles.value) {
        return Dismissible(
          background: (kIsDesktop || kIsWeb)
              ? null
              : Obx(() => slideBackground(chat, false)),
          secondaryBackground: (kIsDesktop || kIsWeb)
              ? null
              : Obx(() => slideBackground(chat, true)),
          key: UniqueKey(),
          onDismissed: (direction) {
            MaterialSwipeAction action;
            if (direction == DismissDirection.endToStart) {
              action = leftAction;
            } else {
              action = rightAction;
            }

            if (action == MaterialSwipeAction.pin) {
              chat.toggleIsPinned(null);
            } else if (action == MaterialSwipeAction.alerts) {
              chat.toggleMuteType(null);
            } else if (action == MaterialSwipeAction.delete) {
              chat.toggleIsDeleted(null);
            } else if (action == MaterialSwipeAction.mark_read) {
              chat.toggleUnreadStatus(null);
            } else if (action == MaterialSwipeAction.archive) {
              chat.toggleIsArchived(null);
            }
            update.call();
          },
          child: tile,
        );
      } else {
        return tile;
      }
    });
  }
}