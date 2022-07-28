import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ListItem extends StatelessWidget {
  final Chat chat;
  final ConversationListController controller;
  ListItem({required this.chat, required this.controller});

  MaterialSwipeAction get leftAction => SettingsManager().settings.materialLeftAction.value;
  MaterialSwipeAction get rightAction => SettingsManager().settings.materialRightAction.value;

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
            Icon(
              action == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : action == MaterialSwipeAction.alerts
                  ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                  : action == MaterialSwipeAction.delete
                  ? Icons.delete_forever
                  : action == MaterialSwipeAction.mark_read
                  ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                  : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              action == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : action == MaterialSwipeAction.alerts
                  ? (chat.muteType == "mute" ? ' Show Alerts' : ' Hide Alerts')
                  : action == MaterialSwipeAction.delete
                  ? " Delete"
                  : action == MaterialSwipeAction.mark_read
                  ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                  : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: left ? TextAlign.right : TextAlign.left,
            ),
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
      final tile = ConversationTile(
        key: Key(chat.guid),
        chat: chat,
        inSelectMode: controller.selectedChats.isNotEmpty,
        selected: controller.selectedChats,
        onSelect: (bool isSelected) {
          if (isSelected) {
            controller.selectedChats.add(chat);
            controller.updateSelectedChats();
          } else {
            controller.selectedChats.removeWhere((element) => element.guid == chat.guid);
            controller.updateSelectedChats();
          }
        },
      );

      if (SettingsManager().settings.swipableConversationTiles.value) {
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
              chat.togglePin(!chat.isPinned!);
            } else if (action == MaterialSwipeAction.alerts) {
              chat.toggleMute(chat.muteType != "mute");
            } else if (action == MaterialSwipeAction.delete) {
              ChatBloc().deleteChat(chat);
              Chat.deleteChat(chat);
            } else if (action == MaterialSwipeAction.mark_read) {
              ChatBloc().toggleChatUnread(chat, !chat.hasUnreadMessage!);
            } else if (action == MaterialSwipeAction.archive) {
              if (chat.isArchived!) {
                ChatBloc().unArchiveChat(chat);
              } else {
                ChatBloc().archiveChat(chat);
              }
            }
          },
          child: tile,
        );
      } else {
        return tile;
      }
    });
  }
}