import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

/// What follows the finger: a pin over the pin area, a list tile anywhere else.
class ChatDragFeedback extends StatelessWidget {
  const ChatDragFeedback({
    super.key,
    required this.drag,
    required this.chat,
    required this.listWidth,
    required this.alwaysPin,
    this.look,
    this.listLook,
  });

  final PinDragController drag;
  final Chat chat;
  final double listWidth;

  /// A drag is always a pin; only a drop's flight into the list turns it into a row.
  final bool alwaysPin;

  /// Whether it looks like a pin, when set: the drag's own state no longer applies once it's dropped.
  final RxBool? look;

  /// Shown in place of the built tile look: a drop's flight shows the row it lands as.
  final Widget? listLook;

  @override
  Widget build(BuildContext context) {
    // A zero-size box at the pointer with the content centered on it, so whichever look is showing (and both,
    // mid-switch) sits under the finger.
    return Obx(() {
      // drag.moved first: a flight's look would otherwise short-circuit the only observable read here
      if (!drag.moved && look == null) return const SizedBox.shrink();
      return SizedBox.shrink(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Material(
            type: MaterialType.transparency,
            child: Obx(() {
              final asPin = look?.value ?? (drag.overPinArea || alwaysPin);
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.3, end: 1.0)
                        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                child: asPin
                    ? _PinLook(key: const ValueKey('pin'), chat: chat, avatarSize: drag.pinAvatarSize)
                    : KeyedSubtree(
                        key: const ValueKey('list'),
                        child: listLook ?? _ListTileLook(chat: chat, width: listWidth),
                      ),
              );
            }),
          ),
        ),
      );
    });
  }
}

class _PinLook extends StatelessWidget {
  const _PinLook({super.key, required this.chat, required this.avatarSize});

  final Chat chat;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: avatarSize + 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContactAvatarGroupWidget(chat: chat, size: avatarSize, editable: false),
          const SizedBox(height: 6),
          Text(
            pinnedChatTitle(chat),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            // Pins' titles render at 0.95 (ChatTitle).
            style: context.theme.textTheme.bodyMedium!
                .apply(color: context.theme.colorScheme.outline, fontSizeFactor: 0.95),
          ),
        ],
      ),
    );
  }
}

class _ListTileLook extends StatelessWidget {
  const _ListTileLook({required this.chat, required this.width});

  final Chat chat;
  final double width;

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getChatState(chat.guid);
    // Like the tiles, which go transparent under a desktop window effect.
    final opaque = SettingsSvc.settings.windowEffect.value == WindowEffect.disabled;
    final title = chatState?.title.value ?? chat.getTitle();
    final subtitle = chatState?.subtitle.value ?? chat.dbLatestMessage.target?.getNotificationText();
    final textTheme = context.theme.textTheme;
    return Material(
      elevation: opaque ? 6 : 0,
      color: opaque ? context.theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ContactAvatarGroupWidget(chat: chat, size: 44, editable: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium),
                    if (!isNullOrEmpty(subtitle))
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
