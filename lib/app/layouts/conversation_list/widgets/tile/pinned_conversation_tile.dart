import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_indicator.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/chat_drag_source.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// A pin's title: for a DM, the nickname if set, otherwise the first name, like iOS. ChatState handles redacted mode.
String pinnedChatTitle(Chat chat) {
  final chatState = ChatsSvc.getChatState(chat.guid);
  final isDm = !chat.isGroup && isNullOrEmpty(chat.displayName);
  if (isDm && chatState != null && chatState.participants.isNotEmpty) {
    return chatState.participants.first.reactionDisplayName.value ?? chatState.title.value ?? chat.getTitle();
  }
  return chatState?.title.value ?? chat.getTitle();
}

class PinnedConversationTile extends CustomStateful<ConversationTileController> {
  final double avatarSize;

  /// Makes the tile draggable in the pinned grid, with this drag state: hold then drag on touch, click and drag with
  /// a mouse.
  final PinDragController? pinDrag;

  PinnedConversationTile({
    super.key,
    required Chat chat,
    required ConversationListController controller,
    required this.avatarSize,
    this.pinDrag,
  }) : super(
            parentController: Get.isRegistered<ConversationTileController>(tag: chat.guid)
                ? Get.find<ConversationTileController>(tag: chat.guid)
                : Get.put(
                    ConversationTileController(
                      chatState: ChatsSvc.getOrCreateChatState(chat),
                      listController: controller,
                    ),
                    tag: "${chat.guid}-pinned"));

  @override
  State<PinnedConversationTile> createState() => _PinnedConversationTileState();
}

class _PinnedConversationTileState extends CustomState<PinnedConversationTile, void, ConversationTileController> {
  /// How far a text bubble may reach past the avatar. The tile's margin (4) and padding (8) leave at least 12 beside
  /// it, so neighbors' bubbles stay at least 10 apart.
  static const double _bubbleReach = 7;

  ConversationListController get listController => controller.listController;
  Offset? longPressPosition;
  StreamSubscription? _activeSub;

  @override
  void initState() {
    super.initState();

    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;

    _activeSub = ChatsSvc.activeChatGuid.listen((guid) {
      Future.microtask(() {
        if (mounted) controller.shouldHighlight.value = NavigationSvc.isTabletMode(context) && guid == controller.chat.guid;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // isTabletMode reads MediaQuery, so it can't run in initState
    controller.shouldHighlight.value = NavigationSvc.isTabletMode(context) && ChatsSvc.activeChatGuid.value == controller.chat.guid;
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    super.dispose();
  }

  /// Material and Samsung select on long press, like their list tiles, so the header actions apply to pins.
  bool get _selectable => !iOS;

  bool get _touch => !kIsDesktop && !kIsWeb;

  /// A hold on touch: peek on iOS, select on Material and Samsung.
  Future<void> _onHold() async {
    if (_selectable) return _toggleSelected();
    await peekChat(context, controller.chat, longPressPosition ?? Offset.zero);
  }

  /// The hold a drag starts with, and how to undo it once the finger moves.
  VoidCallback? _holdForDrag(Offset position) {
    if (_selectable) {
      _toggleSelected(haptic: false);
      return () => _toggleSelected(haptic: false);
    }
    if (NavigationSvc.isTabletMode(context)) return null;
    peekChat(context, controller.chat, position);
    return closeChatPeek;
  }

  void _toggleSelected({bool haptic = true}) {
    controller.toggleListSelection();
    if (haptic) HapticFeedback.lightImpact();
    // The drag can move this tile to another row mid-hold, disposing this state before the undo runs.
    controller.updateWidgets<PinnedConversationTile>(null);
  }

  @override
  Widget build(BuildContext context) {
    final drag = widget.pinDrag;
    final tile = _buildTile(context, holdHandledByDrag: drag != null);
    if (drag == null) return tile;
    return ChatDragSource(
      key: ValueKey(controller.chat.guid),
      drag: drag,
      chat: controller.chat,
      startsInPinArea: true,
      onHold: _holdForDrag,
      child: tile,
    );
  }

  Widget _buildTile(BuildContext context, {required bool holdHandledByDrag}) {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 4, top: 1),
      child: Obx(() {
        NavigationSvc.listener.value;
        final selected = _selectable && controller.isSelected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          clipBehavior: Clip.none,
          decoration: BoxDecoration(
            color: selected
                ? context.theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : controller.shouldPartialHighlight.value
                    ? context.theme.colorScheme.surfaceContainerHighest.lightenOrDarken(10)
                    : controller.shouldHighlight.value
                        ? context.theme.colorScheme.bubble(context, controller.chat.isIMessage)
                        : Colors.transparent,
            borderRadius: BorderRadius.circular(
                selected || controller.shouldHighlight.value || controller.shouldPartialHighlight.value ? 8 : 0),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Listener(
              onPointerDown: (event) => longPressPosition = event.position,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectable && listController.selectedChats.isNotEmpty
                    ? _toggleSelected()
                    : controller.onTap(context),
                onLongPress: _touch && !holdHandledByDrag ? _onHold : null,
                onSecondaryTapUp: (details) => controller.onSecondaryTap(context, details),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 4,
                    left: 8,
                    right: 8,
                    bottom: 2,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.avatarSize),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: <Widget>[
                        Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                ContactAvatarGroupWidget(
                                  chat: controller.chat,
                                  size: widget.avatarSize,
                                  editable: false,
                                ),
                                MuteIcon(width: widget.avatarSize, parentController: controller),
                                PinnedIndicators(width: widget.avatarSize, controller: controller),
                                // SenderIcon is inside the avatar Stack so its Positioned
                                // coordinates are unambiguously relative to the avatar bounds.
                                SenderIcon(width: widget.avatarSize, parentController: controller),
                                ReactionIcon(width: widget.avatarSize, parentController: controller),
                                if (selected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: widget.avatarSize * 0.3,
                                      height: widget.avatarSize * 0.3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context.theme.colorScheme.primary,
                                        border: Border.all(color: context.theme.colorScheme.surface, width: 2),
                                      ),
                                      child: Icon(Icons.check,
                                          size: widget.avatarSize * 0.2, color: context.theme.colorScheme.onPrimary),
                                    ),
                                  ),
                                // Group bubble: anchored so its bottom aligns with the
                                // sender avatar bottom (senderSize=0.25w, top=0.375w, bottom=0.625w).
                                if (controller.chat.isGroup)
                                  Positioned(
                                    bottom: widget.avatarSize * 0.575,
                                    left: widget.avatarSize * 0.05,
                                    width: widget.avatarSize * 0.95 + _bubbleReach,
                                    child: PinnedTileTextBubble(
                                      chat: controller.chat,
                                      size: widget.avatarSize,
                                      parentController: controller,
                                    ),
                                  ),
                              ],
                            ),
                            ChatTitle(width: widget.avatarSize, parentController: controller),
                          ],
                        ),
                        // DM bubble: wider than the avatar so the bubble has room to grow.
                        if (!controller.chat.isGroup)
                          Positioned(
                            top: 0,
                            width: widget.avatarSize + 2 * _bubbleReach,
                            child: PinnedTileTextBubble(
                              chat: controller.chat,
                              size: widget.avatarSize,
                              parentController: controller,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({super.key, required this.width, required super.parentController});

  final double width;

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unread = ChatsSvc.getChatState(controller.chat.guid)?.hasUnreadMessage.value ?? false;
      return unread
          ? Positioned(
              left: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
              top: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
              child: Container(
                width: widget.width * 0.2,
                height: widget.width * 0.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.theme.colorScheme.primary,
                ),
                margin: const EdgeInsets.only(right: 3),
              ),
            )
          : const SizedBox.shrink();
    });
  }
}

class MuteIcon extends CustomStateful<ConversationTileController> {
  const MuteIcon({super.key, required this.width, required super.parentController});

  final double width;

  @override
  State<StatefulWidget> createState() => _MuteIconState();
}

class _MuteIconState extends CustomState<MuteIcon, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final muteType = controller.chat.muteType;
      final unread = ChatsSvc.getChatState(controller.chat.guid)?.hasUnreadMessage.value ?? false;

      return muteType == "mute"
          ? Positioned(
              left: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
              top: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
              child: Container(
                width: widget.width * 0.2,
                height: widget.width * 0.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      unread ? context.theme.colorScheme.primaryContainer : context.theme.colorScheme.tertiaryContainer,
                ),
                child: Icon(
                  CupertinoIcons.bell_slash_fill,
                  size: widget.width * 0.14,
                  color: unread
                      ? context.theme.colorScheme.onPrimaryContainer
                      : context.theme.colorScheme.onTertiaryContainer,
                ),
              ),
            )
          : const SizedBox.shrink();
    });
  }
}

class ChatTitle extends CustomStateful<ConversationTileController> {
  final double width;

  const ChatTitle({super.key, required this.width, required super.parentController});

  @override
  State<StatefulWidget> createState() => _ChatTitleState();
}

class _ChatTitleState extends CustomState<ChatTitle, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Obx(() {
        final isPinned = controller.chatState.isPinned.value;
        final style = context.theme.textTheme.bodyMedium!.apply(
          color: controller.shouldHighlight.value
              ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
              : context.theme.colorScheme.outline,
          fontSizeFactor: isPinned ? 0.95 : 1,
        );

        final chatState = ChatsSvc.getChatState(controller.chat.guid);
        final _title = pinnedChatTitle(controller.chat);
        final unread = chatState?.hasUnreadMessage.value ?? false;

        // Reserve equal horizontal space on both sides so the text stays
        // visually centered while the dot floats to its left.
        const double dotSize = 10.0;
        const double dotHSpace = dotSize + 6.0;

        return SizedBox(
          height: style.height! * style.fontSize!,
          child: OverflowBox(
            maxWidth: widget.width + 40,
            alignment: Alignment.topCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: dotHSpace,
                  child: unread
                      ? Center(
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      children: MessageHelper.buildEmojiText(_title, style),
                      style: style,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
                // Mirror slot keeps text optically centered
                const SizedBox(width: dotHSpace),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class PinnedIndicators extends StatelessWidget {
  final ConversationTileController controller;
  final double width;

  const PinnedIndicators({super.key, required this.width, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showTypingIndicator = cvc(controller.chat).showTypingIndicator.value;
      if (showTypingIndicator) {
        return Positioned(
          top: -sqrt(width / 2) + width * 0.05,
          right: -sqrt(width / 2) + width * 0.025,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: width / 3),
            child: const FittedBox(
              child: TypingIndicator(visible: true),
            ),
          ),
        );
      }

      // Read the reactive status from ChatState so that delivery/read-receipt
      // updates on the same message propagate to the tile without a GUID change.
      final chatState = ChatsSvc.getChatState(controller.chat.guid);
      final showMarker = chatState?.latestMessageStatus.value ?? MessageStatusIndicator.NONE;
      if (SettingsSvc.settings.statusIndicatorsOnChats.value &&
          !controller.chat.isGroup &&
          showMarker != MessageStatusIndicator.NONE) {
        return Positioned(
          left: sqrt(width) - width * 0.05 * sqrt(2),
          top: width - width * 0.13 * 2,
          child: Container(
            width: width * 0.27,
            height: width * 0.27,
            decoration: BoxDecoration(
              border: Border.all(color: context.theme.colorScheme.surface, width: 1),
              borderRadius: BorderRadius.circular(30),
              color: context.theme.colorScheme.tertiaryContainer,
            ),
            child: Transform.rotate(
              angle: showMarker != MessageStatusIndicator.SENT ? pi / 2 : 0,
              child: Icon(
                showMarker == MessageStatusIndicator.DELIVERED
                    ? CupertinoIcons.location_north_fill
                    : showMarker == MessageStatusIndicator.READ
                        ? CupertinoIcons.location_north
                        : CupertinoIcons.location_fill,
                color: context.theme.colorScheme.onTertiaryContainer,
                size: width * 0.14,
              ),
            ),
          ),
        );
      }

      return const SizedBox.shrink();
    });
  }
}

class ReactionIcon extends CustomStateful<ConversationTileController> {
  const ReactionIcon({super.key, required this.width, required super.parentController});

  final double width;

  @override
  State<StatefulWidget> createState() => _ReactionIconState();
}

class _ReactionIconState extends CustomState<ReactionIcon, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unread = ChatsSvc.getChatState(controller.chat.guid)?.hasUnreadMessage.value ?? false;
      final latestMsg = controller.chat.dbLatestMessage.target;
      final isReaction = latestMsg?.isReaction ?? false;
      // Null-safe isFromMe: treat null as "from me" so we don't show the icon
      // for messages with unknown sender, mirroring the text-bubble behavior.
      final isNotFromMe = latestMsg?.isFromMe == false;

      return latestMsg != null && unread && isReaction && isNotFromMe
          ? controller.chat.isGroup
              // Groups: same anchor as the text bubble — bottom of sender avatar,
              // left edge of avatar area, growing rightward.
              ? Positioned(
                  bottom: widget.width * 0.575,
                  left: widget.width * 0.05,
                  child: ReactionWidget(
                    reaction: latestMsg,
                    chatGuid: controller.chat.guid,
                    tailDirection: ReactionTailDirection.left,
                  ),
                )
              // DMs: top-right of the avatar.
              : Positioned(
                  top: -sqrt(widget.width / 2) + widget.width * 0.05,
                  right: -sqrt(widget.width / 2) + widget.width * 0.025,
                  child: ReactionWidget(
                    reaction: latestMsg,
                    chatGuid: controller.chat.guid,
                    tailDirection: ReactionTailDirection.left,
                  ),
                )
          : const SizedBox.shrink();
    });
  }
}

class SenderIcon extends CustomStateful<ConversationTileController> {
  const SenderIcon({super.key, required this.width, required super.parentController});

  final double width;

  @override
  State<StatefulWidget> createState() => _SenderIconState();
}

class _SenderIconState extends CustomState<SenderIcon, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.chat.isGroup) return const SizedBox.shrink();

    return Obx(() {
      final chatState = ChatsSvc.getChatState(controller.chat.guid);
      final unread = chatState?.hasUnreadMessage.value ?? false;
      final lastMessage = chatState?.latestMessage.value;

      if (!unread || lastMessage == null || lastMessage.isFromMe == true) {
        return const SizedBox.shrink();
      }

      final sender = lastMessage.handleRelation.target;
      if (sender == null) return const SizedBox.shrink();

      final double senderSize = widget.width * 0.25;

      return Positioned(
        top: (widget.width - senderSize) / 2,
        left: -senderSize / 2,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.theme.colorScheme.surface,
              width: 1.5,
            ),
          ),
          child: ContactAvatarWidget(
            handle: sender,
            size: senderSize,
            editable: false,
            borderThickness: 0,
          ),
        ),
      );
    });
  }
}
