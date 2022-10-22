import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/indicator.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SamsungConversationTile extends CustomStateful<ConversationTileController> {
  const SamsungConversationTile({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungConversationTileState();
}

class _SamsungConversationTileState extends CustomState<SamsungConversationTile, void, ConversationTileController> {
  bool get shouldPartialHighlight => controller.shouldPartialHighlight.value;
  bool get shouldHighlight => controller.shouldHighlight.value;
  bool get hoverHighlight => controller.hoverHighlight.value;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onSecondaryTapUp: (details) => controller.onSecondaryTap(context, details),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: MouseCursor.defer,
          onTap: () => controller.onTap(context),
          onLongPress: controller.onLongPress,
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: ss.settings.denseChatTiles.value,
            title: ChatTitle(
              parentController: controller,
              style: context.theme.textTheme.bodyMedium!.copyWith(
                fontWeight: controller.shouldHighlight.value
                    ? FontWeight.w600
                    : null,
              ),
            ),
            subtitle: controller.subtitle ?? ChatSubtitle(
              parentController: controller,
              style: context.theme.textTheme.bodySmall!.copyWith(
                color: context.theme.colorScheme.outline,
                height: 1.5,
              ),
            ),
            minVerticalPadding: 10,
            leading: ChatLeading(controller: controller, unreadIcon: UnreadIcon(parentController: controller)),
            trailing: SamsungTrailing(parentController: controller),
          ),
        ),
      ),
    );

    return AnimatedContainer(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: controller.isSelected
            ? context.theme.colorScheme.primaryContainer.withOpacity(0.5)
            : shouldPartialHighlight || hoverHighlight
            ? context.theme.colorScheme.properSurface
            : shouldHighlight
            ? context.theme.colorScheme.primaryContainer
            : null,
      ),
      duration: const Duration(milliseconds: 100),
      child: child,
    );
  }
}

class SamsungTrailing extends CustomStateful<ConversationTileController> {
  const SamsungTrailing({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungTrailingState();
}

class _SamsungTrailingState extends CustomState<SamsungTrailing, void, ConversationTileController> {
  late final MessageMarkers? markers = ChatManager().getChatController(controller.chat)?.messageMarkers;

  DateTime? dateCreated;
  bool unread = false;
  String muteType = "";
  late final StreamSubscription<Query<Message>> sub;
  late final StreamSubscription<Query<Chat>> sub2;
  String? cachedLatestMessageGuid = "";
  Message? cachedLatestMessage;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    cachedLatestMessage = controller.chat.latestMessageGetter != null
        ? controller.chat.latestMessageGetter!
        : controller.chat.latestMessage;
    cachedLatestMessageGuid = cachedLatestMessage?.guid;
    dateCreated = cachedLatestMessage?.dateCreated;
    // run query after render has completed
    updateObx(() {
      final latestMessageQuery = (messageBox.query(Message_.dateDeleted.isNull())
        ..link(Message_.chat, Chat_.guid.equals(controller.chat.guid))
        ..order(Message_.dateCreated, flags: Order.descending))
          .watch();

      sub = latestMessageQuery.listen((Query<Message> query) {
        final message = query.findFirst();
        cachedLatestMessage = message;
        // check if we really need to update this widget
        if (message?.guid != cachedLatestMessageGuid) {
          DateTime newDateCreated = controller.chat.latestMessageDate ?? DateTime.now();
          if (message != null) {
            newDateCreated = message.dateCreated ?? newDateCreated;
          }
          if (dateCreated != newDateCreated) {
            setState(() {
              dateCreated = newDateCreated;
            });
          }
        }
        cachedLatestMessageGuid = message?.guid;
      });

      final unreadQuery = chatBox.query((Chat_.hasUnreadMessage.equals(true)
          .or(Chat_.muteType.equals("mute")))
          .and(Chat_.guid.equals(controller.chat.guid)))
          .watch();
      sub2 = unreadQuery.listen((Query<Chat> query) {
        final chat = query.findFirst();
        final newUnread = chat?.hasUnreadMessage ?? false;
        final newMute = chat?.muteType ?? "";
        if (chat != null && unread != newUnread) {
          setState(() {
            unread = newUnread;
          });
        } else if (chat == null && unread) {
          setState(() {
            unread = false;
          });
        } else if (muteType != newMute) {
          setState(() {
            muteType = newMute;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    sub2.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.chat.isPinned!)
            Icon(
                Icons.star,
                size: 15, color: context.theme.colorScheme.tertiary
            ),
          if (muteType == "mute")
            Icon(
              Icons.notifications_off,
              color: context.theme.colorScheme.onBackground,
              size: 15,
            ),
          Obx(() {
            String indicatorText = "";
            if (ss.settings.statusIndicatorsOnChats.value && markers != null) {
              Indicator show = shouldShow(
                  cachedLatestMessage,
                  markers!.myLastMessage.value,
                  markers!.lastReadMessage.value,
                  markers!.lastDeliveredMessage.value
              );
              indicatorText = describeEnum(show).toLowerCase().capitalizeFirst!;
            }

            return Text(
              (cachedLatestMessage?.error ?? 0) > 0
                  ? "Error"
                  : "${indicatorText.isNotEmpty ? "$indicatorText\n" : ""}${buildDate(dateCreated)}",
              textAlign: TextAlign.right,
              style: context.theme.textTheme.bodySmall!.copyWith(
                color: (cachedLatestMessage?.error ?? 0) > 0
                    ? context.theme.colorScheme.error
                    : context.theme.colorScheme.outline,
                fontWeight: controller.shouldHighlight.value
                    ? FontWeight.w500 : null,
              ),
              overflow: TextOverflow.clip,
            );
          }),
        ],
      ),
    );
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {
  bool unread = false;
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    unread = controller.chat.hasUnreadMessage ?? false;
    updateObx(() {
      final unreadQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
          .watch();
      sub = unreadQuery.listen((Query<Chat> query) {
        final chat = query.findFirst()!;
        if (chat.hasUnreadMessage != unread) {
          setState(() {
            unread = chat.hasUnreadMessage!;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return (unread) ? Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.theme.colorScheme.primary,
      ),
      width: 15,
      height: 15,
    ) : const SizedBox(width: 10, height: 10);
  }
}