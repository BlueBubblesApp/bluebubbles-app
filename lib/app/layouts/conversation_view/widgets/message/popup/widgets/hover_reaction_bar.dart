import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

/// Bar shown beside a message bubble while the mouse hovers over it (desktop only): the tapbacks (where they can be
/// sent), up to three quick actions picked from [DetailsMenuAction] in settings, and a "more" button for the full popup.
class HoverReactionBar extends StatelessWidget {
  const HoverReactionBar({super.key, required this.onMore, this.onReact, this.selfReaction, this.actions = const []});

  final VoidCallback onMore;

  /// Sends or removes a tapback; the tapbacks are hidden when null (e.g. SMS chats or no Private API).
  final void Function(String reaction)? onReact;

  /// The reaction the user has already placed on this message part, if any.
  final String? selfReaction;

  /// Quick actions to show, in order, with what to run when clicked.
  final List<(DetailsMenuAction, VoidCallback)> actions;

  static const double itemSize = 30;
  static const double padding = 3;

  /// Width of the bar, used by the holder to decide whether it fits beside the bubble.
  static double widthFor({required bool tapbacks, required int actions}) =>
      itemSize * ((tapbacks ? ReactionTypes.toList().length : 0) + actions + 1) + padding * 2;

  static double get height => itemSize + padding * 2;

  @override
  Widget build(BuildContext context) {
    final iOS = context.iOS;
    final colorScheme = context.theme.colorScheme;

    Widget button({required String tooltip, required VoidCallback? onTap, required Widget child, bool selected = false}) {
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

    // Clicking a button must not take keyboard focus: the bar hides right after the click, and focus would fall back
    // to the route instead of returning to the message field.
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
              if (onReact != null)
                ...ReactionTypes.toList().map((e) {
                  final selected = selfReaction == e;
                  return button(
                    tooltip: selected ? "Remove" : ReactionTypes.reactionToVerb[e]!.capitalizeFirst!,
                    onTap: () => onReact!(e),
                    selected: selected,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: _ReactionIcon(reaction: e, selected: selected, iOS: iOS),
                    ),
                  );
                }),
              for (final (action, onTap) in actions)
                button(
                  tooltip: action.text,
                  onTap: onTap,
                  child: Icon(iOS ? action.iosIcon : action.nonIosIcon, size: 17, color: colorScheme.outline),
                ),
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
