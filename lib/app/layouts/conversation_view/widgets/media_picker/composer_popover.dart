import 'dart:math' as math;

import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const double _margin = 12;

/// Opens [builder]'s content as a desktop popover above [anchorContext] (a composer button), as tall as fits up to
/// [height]. Click outside or press Escape to dismiss. Completes when it closes. Its content can hide it for a while
/// ([ComposerPopoverScope]).
Future<void> showComposerPopover(
  BuildContext anchorContext,
  ConversationViewController controller, {
  required WidgetBuilder builder,
  double width = 380,
  double height = 460,
}) async {
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final overlayBox = navigator.overlay!.context.findRenderObject() as RenderBox;
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  final anchor = anchorBox == null || !anchorBox.attached
      ? Rect.fromLTWH(_margin, overlayBox.size.height - _margin, 0, 0)
      : anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox) & anchorBox.size;

  // A route on the root navigator doesn't carry the conversation's Theme the way showDialog does
  final themes = InheritedTheme.capture(from: anchorContext, to: navigator.context);
  final hidden = ValueNotifier(false);
  controller.showingOverlays = true;
  try {
    await navigator.push(_PopoverRoute(
      hidden: hidden,
      pageBuilder: (context, _, _) {
        final size = MediaQuery.sizeOf(context);
        final w = math.min(width, size.width - _margin * 2);
        final h = math.min(height, anchor.top - _margin * 2).clamp(200.0, height);
        final left = anchor.left.clamp(_margin, math.max(_margin, size.width - w - _margin)).toDouble();
        final bottom = math.max(_margin, size.height - anchor.top + 8);
        return ValueListenableBuilder<bool>(
          valueListenable: hidden,
          builder: (_, isHidden, child) => IgnorePointer(
            ignoring: isHidden,
            child: Opacity(opacity: isHidden ? 0 : 1, child: child),
          ),
          child: Stack(
            children: [
              Positioned(
                left: left,
                bottom: bottom,
                width: w,
                height: h,
                child: ComposerPopoverScope(hidden: hidden, child: themes.wrap(Builder(builder: builder))),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    ));
  } finally {
    // `hidden` isn't disposed: the route still listens to it through its closing transition
    controller.showingOverlays = false;
  }
}

/// Lets a popover's content hide it without closing it: set [hidden] while a drag that started in it is over what's
/// underneath, and pop the route once the drag ends. Popping mid-drag would cancel the drag, since the navigator
/// cancels every pointer down when it navigates.
class ComposerPopoverScope extends InheritedWidget {
  const ComposerPopoverScope({super.key, required this.hidden, required super.child});

  /// While true the popover is invisible and lets every pointer through, its barrier included
  final ValueNotifier<bool> hidden;

  static ValueNotifier<bool>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ComposerPopoverScope>()?.hidden;

  @override
  bool updateShouldNotify(ComposerPopoverScope oldWidget) => oldWidget.hidden != hidden;
}

class _PopoverRoute extends RawDialogRoute<void> {
  _PopoverRoute({required this.hidden, required super.pageBuilder, required super.transitionBuilder})
    : super(
        barrierDismissible: true,
        barrierLabel: "Dismiss",
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 160),
      );

  final ValueListenable<bool> hidden;

  @override
  Widget buildModalBarrier() => ValueListenableBuilder<bool>(
    valueListenable: hidden,
    builder: (_, isHidden, child) => IgnorePointer(ignoring: isHidden, child: child),
    child: super.buildModalBarrier(),
  );
}

/// The popover's card: rounded, raised, closing on Escape.
class ComposerPopoverCard extends StatelessWidget {
  const ComposerPopoverCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
        child: child,
      ),
    );
  }
}
