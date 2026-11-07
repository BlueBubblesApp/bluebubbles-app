import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/shared/chat_title_mixin.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Shared progress indicator for all header types
/// Displays send progress for the current chat
class HeaderProgressIndicator extends StatelessWidget {
  const HeaderProgressIndicator({
    super.key,
    required this.chat,
  });

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Obx(
        () => TweenAnimationBuilder<double>(
          duration: chat.sendProgress.value == 0
              ? Duration.zero
              : chat.sendProgress.value == 1
                  ? const Duration(milliseconds: 250)
                  : const Duration(seconds: 10),
          curve: chat.sendProgress.value == 1 ? Curves.easeInOut : Curves.easeOutExpo,
          tween: Tween<double>(
            begin: 0,
            end: chat.sendProgress.value,
          ),
          builder: (context, value, _) => AnimatedOpacity(
            opacity: value == 1 ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.transparent,
              minHeight: 3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared back button icon with unread count badge
/// Used by Cupertino header
class BackButtonWithBadge extends StatelessWidget {
  const BackButtonWithBadge({
    super.key,
    required this.controller,
  });

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3.0, right: 3),
          child: Obx(() {
            final icon = controller.inSelectMode.value ? CupertinoIcons.xmark : CupertinoIcons.back;
            return Text(
              String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: 36,
                color: context.theme.colorScheme.primary,
              ),
            );
          }),
        ),
        const SizedBox(width: 2),
        Obx(() {
          final count = controller.inSelectMode.value ? controller.selected.length : ChatsSvc.unreadCount.value;
          if (count == 0) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              height: 25.0,
              width: 25.0,
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: count > 99 ? const EdgeInsets.symmetric(horizontal: 2.5) : EdgeInsets.zero,
                child: Text(
                  count.toString(),
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: context.theme.colorScheme.onPrimary,
                    fontSize: count > 99
                        ? context.textTheme.bodyMedium!.fontSize! - 1.0
                        : context.textTheme.bodyMedium!.fontSize,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Shared chat title and avatar component
/// Optimized with title controller to prevent duplicate queries
class ChatTitleAndAvatar extends StatefulWidget {
  const ChatTitleAndAvatar({
    super.key,
    required this.chat,
    required this.controller,
    required this.layout,
    this.maxTitleWidth,
    this.showChevron = true,
    this.showSubtitle = false,
  });

  final Chat chat;
  final ConversationViewController controller;
  final HeaderLayout layout;
  final double? maxTitleWidth;
  final bool showChevron;
  final bool showSubtitle;

  @override
  State<ChatTitleAndAvatar> createState() => _ChatTitleAndAvatarState();
}

class _ChatTitleAndAvatarState extends State<ChatTitleAndAvatar> with ChatTitleMixin {
  late final RxnString title;

  @override
  void initState() {
    super.initState();
    title = getChatTitleObservable(widget.chat);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getChatState(widget.chat.guid);

    if (widget.layout == HeaderLayout.cupertino) {
      return _buildCupertinoLayout(chatState);
    } else {
      return _buildMaterialLayout(chatState);
    }
  }

  Widget _buildCupertinoLayout(ChatState? chatState) {
    final children = [
      const IgnorePointer(
        ignoring: true,
        child: ContactAvatarGroupWidget(
          size: 54,
        ),
      ),
      const SizedBox(height: 5, width: 5),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxTitleWidth ?? NavigationSvc.width(context) / 2.5,
            ),
            child: Obx(() {
              String displayTitle = title.value ?? '';
              return RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: context.theme.textTheme.bodyMedium,
                  children: MessageHelper.buildEmojiText(
                    displayTitle,
                    context.theme.textTheme.bodyMedium!,
                  ),
                ),
              );
            }),
          ),
          if (widget.showChevron)
            Icon(
              CupertinoIcons.chevron_right,
              size: context.theme.textTheme.bodyMedium!.fontSize!,
              color: context.theme.colorScheme.outline,
            ),
        ],
      ),
    ];

    if (context.orientation == Orientation.landscape && Platform.isAndroid) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
  }

  Widget _buildMaterialLayout(ChatState? chatState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12.5),
          child: IgnorePointer(
            ignoring: true,
            child: ContactAvatarGroupWidget(
              size: !widget.chat.isGroup ? 35 : 40,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                String displayTitle = title.value ?? '';

                if (widget.controller.inSelectMode.value) {
                  displayTitle = "${widget.controller.selected.length} selected";
                }

                return Text(
                  displayTitle,
                  style: context.theme.textTheme.titleLarge!.apply(
                    color: context.theme.colorScheme.onSurface,
                    fontSizeFactor: 0.85,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                );
              }),
              if (widget.showSubtitle &&
                  (widget.chat.isGroup ||
                      (!(title.value?.isPhoneNumber ?? false) && !(title.value?.isEmail ?? false))) &&
                  chatState != null &&
                  (chatState.chatCreatorSubtitle.value?.isNotEmpty ?? false))
                Text(
                  widget.chat.isGroup ? "${widget.chat.people.length} recipients" : widget.chat.handles[0].address,
                  style: context.theme.textTheme.labelLarge!.apply(
                    color: context.theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum HeaderLayout {
  cupertino,
  material,
}
