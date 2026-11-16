import 'package:flutter/material.dart';

/// Opens from nothing to its child's height.
class GrowIn extends StatefulWidget {
  const GrowIn({super.key, required this.child});

  final Widget child;

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
        sizeFactor: CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        alignment: Alignment.topCenter,
        child: widget.child,
      );
}
