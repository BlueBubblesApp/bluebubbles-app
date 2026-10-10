import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ListItem extends StatelessWidget {
  final Chat chat;
  final ConversationListController controller;
  final VoidCallback update;
  const ListItem({super.key, required this.chat, required this.controller, required this.update});

  MaterialSwipeAction get leftAction => SettingsSvc.settings.materialLeftAction.value;
  MaterialSwipeAction get rightAction => SettingsSvc.settings.materialRightAction.value;

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
        alignment: left ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: left ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            const SizedBox(
              width: 20,
            ),
            Icon(
              action == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : action == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                      : action == MaterialSwipeAction.delete
                          ? Icons.delete_forever_outlined
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
                              : (chat.isArchived! ? ' Unarchive' : ' Archive'),
              style: const TextStyle(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ConversationTile handles its own reactivity; this Obx only tracks an in-flight delete.
    final tile = Obx(() {
      final deleting = ChatsSvc.pendingDeletes.contains(chat.guid);
      return IgnorePointer(
        ignoring: deleting,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: deleting ? 0.4 : 1,
              duration: const Duration(milliseconds: 150),
              child: _tile,
            ),
            if (deleting)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text("Deleting…", style: context.theme.textTheme.labelLarge),
                  ),
                ),
              ),
          ],
        ),
      );
    });

    if (SettingsSvc.settings.swipableConversationTiles.value) {
      return _swipable(tile);
    } else {
      return tile;
    }
  }

  Widget get _tile => ConversationTile(
      key: Key(chat.guid),
      chat: chat,
      controller: controller,
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

  Widget _swipable(Widget tile) {
    return Dismissible(
        background: (kIsDesktop || kIsWeb) ? null : Obx(() => slideBackground(chat, false)),
        secondaryBackground: (kIsDesktop || kIsWeb) ? null : Obx(() => slideBackground(chat, true)),
        key: UniqueKey(),
        confirmDismiss: (direction) async {
          final action = direction == DismissDirection.endToStart ? leftAction : rightAction;
          if (action == MaterialSwipeAction.delete) {
            return ChatsSvc.recoverablyDeleteChat(chat);
          }
          return true;
        },
        onDismissed: (direction) {
          MaterialSwipeAction action;
          if (direction == DismissDirection.endToStart) {
            action = leftAction;
          } else {
            action = rightAction;
          }

          if (action == MaterialSwipeAction.pin) {
            final chatState = ChatsSvc.getChatState(chat.guid);
            ChatsSvc.setChatPinned(chatState?.chat ?? chat, !chat.isPinned!);
          } else if (action == MaterialSwipeAction.alerts) {
            final chatState = ChatsSvc.getChatState(chat.guid);
            if (chatState != null) {
              ChatsSvc.setChatMuted(chatState.chat, chat.muteType != "mute");
            } else {
              chat.toggleMuteAsync(chat.muteType != "mute");
            }
          } else if (action == MaterialSwipeAction.delete) {
            // Deletion completed in confirmDismiss so a failed server request
            // cancels the dismiss and leaves the local tile untouched.
          } else if (action == MaterialSwipeAction.mark_read) {
            final chatState = ChatsSvc.getChatState(chat.guid);
            if (chatState != null) {
              ChatsSvc.setChatHasUnread(chatState.chat, !chat.hasUnreadMessage!);
            } else {
              chat.toggleHasUnreadAsync(!chat.hasUnreadMessage!);
            }
          } else if (action == MaterialSwipeAction.archive) {
            final chatState = ChatsSvc.getChatState(chat.guid);
            ChatsSvc.setChatArchived(chatState?.chat ?? chat, !chat.isArchived!);
          }
          update.call();
        },
        child: tile,
      );
  }
}
