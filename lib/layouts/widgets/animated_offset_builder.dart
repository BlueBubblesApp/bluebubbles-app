import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class AnimationOptions {
  AnimationOptions({
    this.curve = Curves.linear,
    @required this.duration,
    this.onEnd,
  });

  final Curve curve;
  final Duration duration;
  final VoidCallback onEnd;
}

typedef WithOffsetBuilder = Widget Function(BuildContext context, Offset offset);

class AnimatedCompositedTransformFollower extends StatelessWidget {
  /// Creates a composited transform target widget.
  ///
  /// The [link] property must not be null. If it was also provided to a
  /// [CompositedTransformTarget], that widget must come earlier in the paint
  /// order.
  ///
  /// The [showWhenUnlinked] and [offset] properties must also not be null.
  const AnimatedCompositedTransformFollower({
    Key key,
    @required this.link,
    this.showWhenUnlinked = true,
    this.offset = Offset.zero,
    @required this.options,
    this.child,
  })  : assert(link != null),
        assert(showWhenUnlinked != null),
        assert(offset != null),
        super(key: key);

  final Widget child;

  final AnimationOptions options;

  /// The link object that connects this [CompositedTransformFollower] with a
  /// [CompositedTransformTarget].
  ///
  /// This property must not be null.
  final LayerLink link;

  /// Whether to show the widget's contents when there is no corresponding
  /// [CompositedTransformTarget] with the same [link].
  ///
  /// When the widget is linked, the child is positioned such that it has the
  /// same global position as the linked [CompositedTransformTarget].
  ///
  /// When the widget is not linked, then: if [showWhenUnlinked] is true, the
  /// child is visible and not repositioned; if it is false, then child is
  /// hidden.
  final bool showWhenUnlinked;

  /// The offset to apply to the origin of the linked
  /// [CompositedTransformTarget] to obtain this widget's origin.
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedOffset(
      offset: offset,
      curve: options.curve,
      duration: options.duration,
      onEnd: options.onEnd,
      builder: (context, animatedOffset) => CompositedTransformFollower(
        offset: animatedOffset,
        link: link,
        showWhenUnlinked: showWhenUnlinked,
        child: child,
      ),
    );
  }
}

class AnimatedOffset extends ImplicitlyAnimatedWidget {
  AnimatedOffset({
    Key key,
    this.offset,
    WithOffsetBuilder builder,
    Widget child,
    Curve curve = Curves.linear,
    @required Duration duration,
    VoidCallback onEnd,
  })  : builder = builder ?? translateBuilder(child),
        super(key: key, curve: curve, duration: duration, onEnd: onEnd);

  final WithOffsetBuilder builder;

  // note hit tests will not overflow outside of container
  static WithOffsetBuilder translateBuilder(
    Widget child, {

    /// Whether hit testing should be affected by the slide animation.
    ///
    /// If false, hit testing will proceed as if the child was not translated at
    /// all. Setting this value to false is useful for fast animations where you
    /// expect the user to commonly interact with the child widget in its final
    /// location and you want the user to benefit from "muscle memory".
    bool transformHitTests,

    /// The direction to use for the x offset described by the [position].
    ///
    /// If [textDirection] is null, the x offset is applied in the coordinate
    /// system of the canvas (so positive x offsets move the child towards the
    /// right).
    ///
    /// If [textDirection] is [TextDirection.rtl], the x offset is applied in the
    /// reading direction such that x offsets move the child towards the left.
    ///
    /// If [textDirection] is [TextDirection.ltr], the x offset is applied in the
    /// reading direction such that x offsets move the child towards the right.
    TextDirection textDirection,
  }) =>
      (c, offset) {
        if (textDirection == TextDirection.rtl) {
          offset = Offset(-offset.dx, offset.dy);
        }
        return Transform.translate(
          offset: offset,
          transformHitTests: transformHitTests,
          child: child,
        );
      };

  final Offset offset;

  @override
  _AnimatedPositionedState createState() => _AnimatedPositionedState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('offset.dx', offset.dx, defaultValue: null));
    properties.add(DoubleProperty('offset.dy', offset.dy, defaultValue: null));
  }
}

class _AnimatedPositionedState extends AnimatedWidgetBaseState<AnimatedOffset> {
  Tween<double> _dx;
  Tween<double> _dy;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _dx = visitor(_dx, widget.offset.dx, (dynamic value) => Tween<double>(begin: value));
    _dy = visitor(_dy, widget.offset.dy, (dynamic value) => Tween<double>(begin: value));
  }

  @override
  Widget build(BuildContext context) {
    Offset offset = Offset(
      _dx?.evaluate(animation),
      _dy?.evaluate(animation),
    );
    return widget.builder(context, offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(ObjectFlagProperty<Tween<double>>.has('offset.dx', _dx));
    description.add(ObjectFlagProperty<Tween<double>>.has('offset.dy', _dy));
  }
}
