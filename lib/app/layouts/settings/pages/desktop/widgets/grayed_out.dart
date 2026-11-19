import 'package:flutter/material.dart';

/// Dims [child] and stops it taking input while [grayed], e.g. a setting the notification has no room for.
class GrayedOut extends StatelessWidget {
  const GrayedOut({super.key, required this.grayed, required this.child});
  final bool grayed;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: grayed,
    child: AnimatedOpacity(opacity: grayed ? 0.5 : 1, duration: const Duration(milliseconds: 200), child: child),
  );
}
