import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/hover_action.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

/// Compact quick-action bar shown beside a message bubble while the mouse hovers over it (desktop only).
///
/// Shows [actions] in order — tapbacks mirror the reaction row in `MessagePopup` — followed by a "more" button that
/// opens the full popup. The holder passes only the actions that apply to the hovered message part.
class HoverReactionBar extends StatelessWidget {
  const HoverReactionBar({
    super.key,
    required this.actions,
    required this.onMore,
    this.selfReaction,
    this.onReact,
    this.onReply,
    this.onCopy,
    this.onCopySelection,
  });

  /// Actions to show, in display order.
  final List<HoverAction> actions;
  final VoidCallback onMore;

  /// The reaction the user has already placed on this message part, if any.
  final String? selfReaction;

  /// Sends or removes a tapback.
  final void Function(String reaction)? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onCopySelection;

  static const double itemSize = 30;
  static const double padding = 3;

  /// Width of a bar showing [actions], used by the holder to decide whether it fits beside the bubble.
  static double widthFor(List<HoverAction> actions) {
    final items = actions.fold<int>(
      1,
      (sum, a) => sum + (a == HoverAction.Tapbacks ? ReactionTypes.toList().length : 1),
    );
    return itemSize * items + padding * 2;
  }

  static double get height => itemSize + padding * 2;

  @override
  Widget build(BuildContext context) {
    final iOS = context.iOS;
    final colorScheme = context.theme.colorScheme;

    Widget button({
      required String tooltip,
      required VoidCallback? onTap,
      required Widget child,
      bool selected = false,
    }) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: selected ? colorScheme.primary : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: itemSize, height: itemSize, child: child),
          ),
        ),
      );
    }

    Widget iconButton(HoverAction action, VoidCallback? onTap) => button(
      tooltip: action.label,
      onTap: onTap,
      child: Icon(action.icon, size: 17, color: colorScheme.outline),
    );

    // Clicking a button must not take keyboard focus: the bar hides right after the click, and focus would fall back
    // to the route instead of returning to the message field, leaving it unable to take input until reopened.
    return ExcludeFocus(
      child: Material(
        color: colorScheme.surfaceContainerHighest.lightenOrDarken(iOS ? 0 : 10),
        elevation: 3,
        borderRadius: BorderRadius.circular(height / 2),
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions)
                ...switch (action) {
                  HoverAction.Tapbacks => ReactionTypes.toList().map((e) {
                    final selected = selfReaction == e;
                    return button(
                      tooltip: selected ? "Remove" : ReactionTypes.reactionToVerb[e]!.capitalizeFirst!,
                      onTap: onReact == null ? null : () => onReact!(e),
                      selected: selected,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: _ReactionIcon(reaction: e, selected: selected, iOS: iOS),
                      ),
                    );
                  }),
                  HoverAction.Reply => [iconButton(action, onReply)],
                  HoverAction.Copy => [iconButton(action, onCopy)],
                  HoverAction.CopySelection => [iconButton(action, onCopySelection)],
                },
              button(
                tooltip: "More options",
                onTap: onMore,
                child: Icon(Icons.more_horiz, size: 18, color: colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionIcon extends StatelessWidget {
  const _ReactionIcon({required this.reaction, required this.selected, required this.iOS});

  final String reaction;
  final bool selected;
  final bool iOS;

  @override
  Widget build(BuildContext context) {
    if (iOS) {
      return SvgPicture.asset(
        'assets/reactions/$reaction-black.svg',
        colorFilter: ColorFilter.mode(
          reaction == ReactionTypes.LOVE && selected
              ? Colors.pink
              : (selected ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.outline),
          BlendMode.srcIn,
        ),
      );
    }
    final text = FittedBox(
      child: Text(
        ReactionTypes.reactionToEmoji[reaction] ?? "X",
        style: const TextStyle(fontFamily: 'Apple Color Emoji'),
        textAlign: TextAlign.center,
      ),
    );
    // rotate thumbs down to match iOS
    if (reaction == ReactionTypes.DISLIKE) {
      return Transform(transform: Matrix4.identity()..rotateY(pi), alignment: FractionalOffset.center, child: text);
    }
    return text;
  }
}
