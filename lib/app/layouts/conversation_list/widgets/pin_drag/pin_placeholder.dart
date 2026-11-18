import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/dashed_circle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// An empty pin where the first one goes, shown while a chat is dragged and there are no pins to drop on. It takes
/// exactly the room that pin will, so dropping it doesn't resize anything: a tile's [height], and a dashed circle of
/// [avatarSize] [avatarTop] down, where a tile draws its avatar.
class PinPlaceholder extends StatelessWidget {
  const PinPlaceholder({super.key, required this.avatarSize, required this.avatarTop, required this.height});

  final double avatarSize;
  final double avatarTop;
  final double height;

  @override
  Widget build(BuildContext context) {
    final outline = context.theme.colorScheme.outline;
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: avatarTop),
          child: CustomPaint(
            painter: DashedCirclePainter(outline),
            child: SizedBox.square(
              dimension: avatarSize,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    "Drag here to pin",
                    textAlign: TextAlign.center,
                    style: context.theme.textTheme.labelSmall!.copyWith(color: outline),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
