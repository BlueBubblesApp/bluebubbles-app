import 'package:bluebubbles/layouts/animations/celebration_class.dart';
import 'package:bluebubbles/layouts/animations/fireworks_rendering.dart';
import 'package:flutter/material.dart';

class Celebration extends LeafRenderObjectWidget {
  Celebration({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final CelebrationController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderFireworks(
      controller: controller,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFireworks renderObject) {
    renderObject.controller = controller;
  }
}