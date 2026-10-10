import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

/// Compact tapback row shown beside a message bubble while the mouse hovers over it (desktop only).
///
/// Mirrors the reaction row in `MessagePopup`, plus a trailing "more" button that opens the full popup.
class HoverReactionBar extends StatelessWidget {
  const HoverReactionBar({
    super.key,
    required this.selfReaction,
    required this.onReact,
    required this.onMore,
  });

  /// The reaction the user has already placed on this message part, if any.
  final String? selfReaction;
  final void Function(String reaction) onReact;
  final VoidCallback onMore;

  static const double itemSize = 30;
  static const double padding = 3;

  /// Width of the bar, used by the holder to decide whether it fits beside the bubble.
  static double get width => itemSize * (ReactionTypes.toList().length + 1) + padding * 2;

  static double get height => itemSize + padding * 2;

  @override
  Widget build(BuildContext context) {
    final iOS = context.iOS;
    final colorScheme = context.theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.lightenOrDarken(iOS ? 0 : 10),
      elevation: 3,
      borderRadius: BorderRadius.circular(height / 2),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...ReactionTypes.toList().map((e) {
              final selected = selfReaction == e;
              return Tooltip(
                message: selected ? "Remove" : ReactionTypes.reactionToVerb[e]!.capitalizeFirst!,
                waitDuration: const Duration(milliseconds: 600),
                child: Material(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onReact(e),
                    child: SizedBox(
                      width: itemSize,
                      height: itemSize,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: _ReactionIcon(reaction: e, selected: selected, iOS: iOS),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Tooltip(
              message: "More options",
              waitDuration: const Duration(milliseconds: 600),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onMore,
                  child: SizedBox(
                    width: itemSize,
                    height: itemSize,
                    child: Icon(Icons.more_horiz, size: 18, color: colorScheme.outline),
                  ),
                ),
              ),
            ),
          ],
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
      return Transform(
        transform: Matrix4.identity()..rotateY(pi),
        alignment: FractionalOffset.center,
        child: text,
      );
    }
    return text;
  }
}
