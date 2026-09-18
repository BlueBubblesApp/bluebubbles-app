import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';

/// Stateful widget that animates a reaction pop-in only once
class _ReactionAnimator extends StatefulWidget {
  const _ReactionAnimator({
    super.key,
    required this.stableKey,
    required this.shouldAnimate,
    required this.child,
  });

  final String stableKey;
  final bool shouldAnimate;
  final Widget child;

  @override
  State<_ReactionAnimator> createState() => _ReactionAnimatorState();
}

class _ReactionAnimatorState extends State<_ReactionAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    // Animate in only if this is a new reaction
    if (widget.shouldAnimate) {
      _controller.forward();
    } else {
      // Skip animation - set to final state immediately
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

class ReactionHolder extends StatefulWidget {
  const ReactionHolder({
    super.key,
    required this.reactions,
    this.tailType = ReactionTailType.standard,
    this.tailDirection,
  });

  final Iterable<Message> reactions;
  final ReactionTailType tailType;
  final ReactionTailDirection? tailDirection;

  @override
  State<ReactionHolder> createState() => _ReactionHolderState();
}

class _ReactionHolderState extends State<ReactionHolder> {
  Iterable<Message> get reactions => getUniqueReactionMessages(widget.reactions.toList());

  // Cache the unique reactions to prevent unnecessary rebuilds
  late List<Message> _cachedReactions;

  // Track which reaction keys have been animated
  // This prevents re-animation on rebuilds, but allows animation on first appearance
  final Set<String> _seenReactionKeys = {};

  @override
  void initState() {
    super.initState();
    _cachedReactions = reactions.toList();
  }

  @override
  void didUpdateWidget(ReactionHolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild if reactions actually changed
    if (!_reactionsEqual(oldWidget.reactions, widget.reactions)) {
      _cachedReactions = reactions.toList();
    }
  }

  /// Check if two reaction lists are equal by comparing GUIDs
  /// This prevents unnecessary rebuilds when the same data is passed
  bool _reactionsEqual(Iterable<Message> a, Iterable<Message> b) {
    final listA = a.toList();
    final listB = b.toList();
    if (listA.length != listB.length) return false;
    for (int i = 0; i < listA.length; i++) {
      if (listA[i].guid != listB[i].guid) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // If the reactions are empty, return nothing
    if (_cachedReactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final isFromMe = MessageStateScope.of(context).isFromMe.value;
    // Explicit tailDirection stacks along that edge (e.g. collection trailing).
    final stackFromEnd = widget.tailDirection != null
        ? widget.tailDirection == ReactionTailDirection.left
        : isFromMe;
    return SizedBox(
      height: widget.tailType == ReactionTailType.inside ? 40 : 35,
      width: 35,
      child: Stack(
        clipBehavior: Clip.none,
        children: _cachedReactions
            .asMap()
            .entries
            .map((entry) {
              final i = entry.key;
              final e = entry.value;
              // Use a stable key based on parent + reaction type + sender
              // This prevents re-animation when temp GUID -> real GUID replacement happens
              final sender = e.isFromMe! ? 0 : e.handleId ?? 0;
              final stableKey = '${e.associatedMessageGuid}-${e.associatedMessageType}-$sender';

              // Check if this is a new reaction that should animate
              final shouldAnimate = !_seenReactionKeys.contains(stableKey);
              if (shouldAnimate) {
                // Mark as seen for future rebuilds
                _seenReactionKeys.add(stableKey);
              }

              return Positioned(
                key: ValueKey(stableKey),
                top: 0,
                left: stackFromEnd ? -i * 2.0 : null,
                right: stackFromEnd ? null : -i * 2.0,
                child: DeferPointer(
                  child: _ReactionAnimator(
                    key: ValueKey(stableKey),
                    stableKey: stableKey,
                    shouldAnimate: shouldAnimate,
                    child: ReactionWidget(
                      reaction: e,
                      reactions: _cachedReactions,
                      tailType: widget.tailType,
                      tailDirection: widget.tailDirection,
                    ),
                  ),
                ),
              );
            })
            .toList()
            .reversed
            .toList(),
      ),
    );
  }
}
