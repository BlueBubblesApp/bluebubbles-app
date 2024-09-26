import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/reactivity/reactive_chat.dart';
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
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    final leading = ChatLeading(controller: controller, unreadIcon: UnreadIcon(parentController: controller));
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: MouseCursor.defer,
        onTap: () => controller.onTap(context),
        onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
        onLongPress: controller.onLongPress,
        child: Obx(() => ListTile(
              mouseCursor: MouseCursor.defer,
              dense: ss.settings.denseChatTiles.value,
              visualDensity: ss.settings.denseChatTiles.value ? VisualDensity.compact : null,
              minVerticalPadding: ss.settings.denseChatTiles.value ? 7.5 : 10,
              title: Obx(() => ChatTitle(
                    parentController: controller,
                    style: context.theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: controller.shouldHighlight.value ? FontWeight.w600 : null,
                    ),
                  )),
              subtitle: controller.subtitle ??
                  Obx(() => ChatSubtitle(
                        parentController: controller,
                        style: context.theme.textTheme.bodyMedium!.copyWith(
                          color: controller.shouldHighlight.value ? context.theme.colorScheme.onBackground : context.theme.colorScheme.outline,
                          height: 1.5,
                        ),
                      )),
              leading: leading,
              trailing: SamsungTrailing(parentController: controller),
            )),
      ),
    );

    return Obx(() {
      ns.listener.value;
      return AnimatedContainer(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: controller.isSelected
              ? context.theme.colorScheme.primaryContainer.withOpacity(0.5)
              : shouldPartialHighlight
                  ? context.theme.colorScheme.properSurface
                  : shouldHighlight
                      ? context.theme.colorScheme.primaryContainer
                      : hoverHighlight
                          ? context.theme.colorScheme.properSurface.withOpacity(0.5)
                          : null,
        ),
        duration: const Duration(milliseconds: 100),
        child: ns.isAvatarOnly(context)
            ? InkWell(
                mouseCursor: MouseCursor.defer,
                onTap: () => controller.onTap(context),
                onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
                onLongPress: controller.onLongPress,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15),
                  child: Center(child: leading),
                ),
              )
            : child,
      );
    });
  }
}

class SamsungTrailing extends CustomStateful<ConversationTileController> {
  const SamsungTrailing({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungTrailingState();
}

class _SamsungTrailingState extends CustomState<SamsungTrailing, void, ConversationTileController> {

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unread = controller.reactiveChat.isUnread.value;
      final muteType = controller.reactiveChat.muteType.value;
      final latestMessage = controller.reactiveChat.latestMessage.value;
      final dateCreated = latestMessage?.dateCreated ?? DateTime.now();

      String indicatorText = "";
      if (ss.settings.statusIndicatorsOnChats.value && (latestMessage?.isFromMe ?? false) && !GlobalChatService.isGroupChat(controller.chatGuid)) {
        Indicator show = latestMessage?.indicatorToShow ?? Indicator.NONE;
        if (show != Indicator.NONE) {
          indicatorText = show.name.toLowerCase().capitalizeFirst!;
        }
      }

      ReactiveChat rChat = GlobalChatService.getChat(controller.chatGuid)!;

      return Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                (latestMessage?.error ?? 0) > 0 ? "Error" : "${indicatorText.isNotEmpty ? "$indicatorText\n" : ""}${buildDate(dateCreated)}",
                textAlign: TextAlign.right,
                style: context.theme.textTheme.bodySmall!.copyWith(
                  color: (latestMessage?.error ?? 0) > 0
                      ? context.theme.colorScheme.error
                      : controller.shouldHighlight.value || unread
                          ? context.theme.colorScheme.onBackground
                          : context.theme.colorScheme.outline,
                  fontWeight: controller.shouldHighlight.value ? FontWeight.w500 : null,
                ),
                overflow: TextOverflow.clip,
              )
            ),
            if (rChat.isPinned.value) const SizedBox(width: 5.0),
            if (muteType == "mute")
              Obx(() => Icon(
                    Icons.notifications_off,
                    color: controller.shouldHighlight.value || unread ? context.theme.colorScheme.onBackground : context.theme.colorScheme.outline,
                    size: 16,
                  )),
            if (muteType == "mute") const SizedBox(width: 2.0),
            if (rChat.isPinned.value) Icon(Icons.star, size: 16, color: context.theme.colorScheme.tertiary),
          ],
        ),
      );
    });
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unread = GlobalChatService.getChat(controller.chatGuid)?.isUnread.value ?? false;
      return (unread)
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.theme.colorScheme.primary,
              ),
              width: 15,
              height: 15,
            )
          : const SizedBox(width: 10, height: 10);
    });
  }
}
