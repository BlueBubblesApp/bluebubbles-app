import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shimmer-style placeholder shown in place of a chart/section while its data
/// is still computing. Each chart owns its own skeleton rather than gating the
/// whole page behind one spinner.
class SectionSkeleton extends StatefulWidget {
  const SectionSkeleton({super.key, this.height = 120.0});

  final double height;

  @override
  State<SectionSkeleton> createState() => _SectionSkeletonState();
}

class _SectionSkeletonState extends State<SectionSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final highlight = context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _controller.value),
            borderRadius: BorderRadius.circular(14.0),
          ),
        );
      },
    );
  }
}
