import 'dart:async';

import 'package:flutter/widgets.dart';

/// Waits for the old Find My card to collapse and the new one to finish
/// expanding, then positions the selected card just inside the drawer.
Future<void> ensureFindMyRowVisibleAfterExpansion(
  GlobalKey rowKey, {
  bool Function()? isCurrent,
  Duration expansionDuration = const Duration(milliseconds: 200),
  Duration scrollDuration = const Duration(milliseconds: 250),
  double topAlignment = 0.05,
}) async {
  await Future<void>.delayed(expansionDuration + const Duration(milliseconds: 16));
  final frame = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => frame.complete());
  WidgetsBinding.instance.scheduleFrame();
  await frame.future;
  if (isCurrent != null && !isCurrent()) return;

  final context = rowKey.currentContext;
  if (context == null || !context.mounted) return;
  await Scrollable.ensureVisible(
    context,
    duration: scrollDuration,
    curve: Curves.easeOut,
    alignment: topAlignment,
  );
}
