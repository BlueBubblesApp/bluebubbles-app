import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MaterialConversationTile extends CustomStateful<ConversationTileController> {
  const MaterialConversationTile({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _MaterialConversationTileState();
}

class _MaterialConversationTileState extends CustomState<MaterialConversationTile, void, ConversationTileController> {
  bool get shouldPartialHighlight => controller.shouldPartialHighlight.value;
  bool get shouldHighlight => controller.shouldHighlight.value;
  bool get hoverHighlight => controller.hoverHighlight.value;

  late bool unread = controller.chat.hasUnreadMessage ?? false;
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;

    if (!kIsWeb) {
      updateObx(() {
        final unreadQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
            .watch();
        sub = unreadQuery.listen((Query<Chat> query) async {
          final chat = controller.chat.id == null ? null : await runAsync(() {
            return chatBox.get(controller.chat.id!);
          });
          if (chat == null) return;
          if (chat.hasUnreadMessage != unread) {
            setState(() {
              unread = chat.hasUnreadMessage!;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onSecondaryTapUp: (details) => controller.onSecondaryTap(context, details),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          bottomLeft: Radius.circular(25),
        ),
        child: InkWell(
          mouseCursor: MouseCursor.defer,
          onTap: () => controller.onTap(context),
          onLongPress: controller.onLongPress,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: ss.settings.denseChatTiles.value,
            visualDensity: ss.settings.denseChatTiles.value ? VisualDensity.compact : null,
            minVerticalPadding: ss.settings.denseChatTiles.value ? 7.5 : 10,
            title: ChatTitle(
              parentController: controller,
              style: context.theme.textTheme.bodyMedium!.copyWith(
                fontWeight: unread
                    ? FontWeight.bold
                    : controller.shouldHighlight.value
                    ? FontWeight.w600
                    : null,
              ).apply(fontSizeFactor: 1.1),
            ),
            subtitle: controller.subtitle ?? ChatSubtitle(
              parentController: controller,
              style: context.theme.textTheme.bodySmall!.copyWith(
                fontWeight: unread
                    ? FontWeight.bold
                    : null,
                color: unread
                    ? context.textTheme.bodyMedium!.color
                    : context.theme.colorScheme.outline,
                height: 1.5,
              ).apply(fontSizeFactor: 1.05),
            ),
            contentPadding: const EdgeInsets.only(left: 6, right: 16),
            leading: ChatLeading(controller: controller),
            trailing: MaterialTrailing(parentController: controller),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: AnimatedContainer(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
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
      ),
    );
  }
}

class MaterialTrailing extends CustomStateful<ConversationTileController> {
  const MaterialTrailing({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _MaterialTrailingState();
}

class _MaterialTrailingState extends CustomState<MaterialTrailing, void, ConversationTileController> {
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
    cachedLatestMessage = controller.chat.latestMessage;
    cachedLatestMessageGuid = cachedLatestMessage?.guid;
    dateCreated = cachedLatestMessage?.dateCreated;
    // run query after render has completed
    if (!kIsWeb) {
      updateObx(() {
        final latestMessageQuery = (messageBox.query(Message_.dateDeleted.isNull())
          ..link(Message_.chat, Chat_.guid.equals(controller.chat.guid))
          ..order(Message_.dateCreated, flags: Order.descending))
            .watch();

        sub = latestMessageQuery.listen((Query<Message> query) async {
          final message = await runAsync(() {
            return query.findFirst();
          });
          cachedLatestMessage = message;
          // check if we really need to update this widget
          if (message != null && message.guid != cachedLatestMessageGuid) {
            if (dateCreated != message.dateCreated) {
              setState(() {
                dateCreated = message.dateCreated;
              });
            }
          }
          cachedLatestMessageGuid = message?.guid;
        });

        final unreadQuery = chatBox.query((Chat_.hasUnreadMessage.equals(true)
            .or(Chat_.muteType.equals("mute")))
            .and(Chat_.guid.equals(controller.chat.guid)))
            .watch();
        sub2 = unreadQuery.listen((Query<Chat> query) async {
          final chat = controller.chat.id == null ? null : await runAsync(() {
            return chatBox.get(controller.chat.id!);
          });
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
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      sub.cancel();
      sub2.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Obx(() {
                String indicatorText = "";
                if (ss.settings.statusIndicatorsOnChats.value && (cachedLatestMessage?.isFromMe ?? false) && !controller.chat.isGroup) {
                  Indicator show = cachedLatestMessage?.indicatorToShow ?? Indicator.NONE;
                  if (show != Indicator.NONE) {
                    indicatorText = describeEnum(show).toLowerCase().capitalizeFirst!;
                  }
                }

                return Text(
                  (cachedLatestMessage?.error ?? 0) > 0
                      ? "Error"
                      : "${indicatorText.isNotEmpty ? "$indicatorText\n" : ""}${buildChatListDateMaterial(dateCreated)}",
                  textAlign: TextAlign.right,
                  style: context.theme.textTheme.bodySmall!.copyWith(
                    color: (cachedLatestMessage?.error ?? 0) > 0
                        ? context.theme.colorScheme.error
                        : unread
                        ? context.theme.colorScheme.onBackground
                        : context.theme.colorScheme.outline,
                    fontWeight: unread
                        ? FontWeight.w600
                        : controller.shouldHighlight.value
                        ? FontWeight.w500 : null,
                  ).apply(fontSizeFactor: 1.1),
                  overflow: TextOverflow.clip,
                );
              }),
              if (muteType != "mute" && unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.chat.isPinned!)
                Icon(
                  Icons.push_pin_outlined,
                  size: 15, color: context.theme.colorScheme.outline
                ),
              const SizedBox(width: 5),
              if (muteType == "mute")
                Icon(
                  Icons.notifications_off_outlined,
                  color: unread
                      ? context.theme.colorScheme.primary
                      : context.theme.colorScheme.outline,
                  size: 15,
                ),
            ],
          ),
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
    if (!kIsWeb) {
      updateObx(() {
        final unreadQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
            .watch();
        sub = unreadQuery.listen((Query<Chat> query) async {
          final chat = controller.chat.id == null ? null : await runAsync(() {
            return chatBox.get(controller.chat.id!);
          });
          if (chat == null) return;
          if (chat.hasUnreadMessage != unread) {
            setState(() {
              unread = chat.hasUnreadMessage!;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5.0),
      child: (unread)
          ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          color: context.theme.colorScheme.primary,
        ),
        width: 10,
        height: 10,
      ) : const SizedBox(width: 10),
    );
  }
}