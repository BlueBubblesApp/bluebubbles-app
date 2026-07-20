import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:particles_flutter/engine.dart';
import 'package:particles_flutter/interactions.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

class BubbleEffects extends StatefulWidget {
  const BubbleEffects({
    super.key,
    required this.child,
    required this.part,
    required this.globalKey,
    required this.showTail,
  });

  final Widget child;
  final int part;
  final GlobalKey? globalKey;
  final bool showTail;

  @override
  State<StatefulWidget> createState() => _BubbleEffectsState();
}

class _BubbleEffectsState extends State<BubbleEffects> with SingleTickerProviderStateMixin {
  late MovieTween tween;
  final rxControl = Rx<Control>(Control.stop);
  Worker? _effectWorker;

  /// Cached reference to the nearest [MessageState]. Set in
  /// [didChangeDependencies] so it is safe to use inside async callbacks
  /// (e.g. animationStatusListener) where [context] may be deactivated.
  MessageState? _ms;

  /// True while an auto-triggered animation is in-flight. Set to false once
  /// the animation completes and [MessageState.markEffectPlayed] has been
  /// called. Manual replays do not set this flag, so they never mark played.
  bool _pendingAutoPlay = false;

  /// Drives the fade-out of the invisible-ink overlay when swiped away.
  /// Initialized eagerly in [initState] so that [dispose] never triggers the
  /// lazy initializer on a deactivated element.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  final Rx<Size> _size = Size.zero.obs;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _fadeAnimation = _fadeController;
  }

  /// Safely reads the size of [widget.globalKey]'s render object.
  /// Returns [Size.zero] if the render object has not yet been laid out.
  Size _readSize() {
    final renderBox = widget.globalKey?.currentContext?.findRenderObject() as RenderBox?;
    return (renderBox?.hasSize == true) ? renderBox!.size : Size.zero;
  }

  /// Schedules [callback] for the first post-frame where the render object
  /// keyed by [widget.globalKey] has a valid size. Retries each frame until
  /// layout is complete or the widget is unmounted.
  void _whenSized(void Function(Size s) callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = widget.globalKey?.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) {
        _whenSized(callback);
        return;
      }
      callback(renderBox.size);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_effectWorker == null) {
      final ms = MessageStateScope.maybeOf(context);
      _ms = ms;
      if (ms != null) {
        // Auto-play invisible ink on first appearance.
        final message = ms.message;
        final effectStr =
            effectMap.entries.firstWhereOrNull((e) => e.value == message.expressiveSendStyleId)?.key ?? "unknown";
        final effect = stringToMessageEffect[effectStr] ?? MessageEffect.none;
        if (effect == MessageEffect.invisibleInk) {
          // Set size first, then flip rxControl so the single Obx rebuild
          // that fires has the correct dimensions and BackdropFilter covers
          // the text from the very first animated frame.
          _whenSized((s) {
            _size.value = s;
            _fadeController.value = 1.0;
            rxControl.value = Control.play;
          });
        } else if (effect.isBubble && !ms.hasEffectPlayed.value) {
          _pendingAutoPlay = true;
          _whenSized((s) {
            _size.value = s;
            ms.triggerBubbleEffect(widget.part);
          });
        }

        _effectWorker = ever(ms.playEffectPart, (int? part) {
          if (part == widget.part) {
            _size.value = _readSize();
            _fadeController.value = 1.0;
            rxControl.value = Control.playFromStart;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _effectWorker?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void getTween(Message message, MessageEffect effect) {
    if (effect == MessageEffect.gentle) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 1), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0))
        ..scene(
                begin: const Duration(milliseconds: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut)
            .tween("size", 0.0.tweenTo(1.2))
        ..scene(
                begin: const Duration(milliseconds: 1000),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut)
            .tween("size", 1.2.tweenTo(1.0));
    } else if (effect == MessageEffect.loud) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 300), curve: Curves.easeIn)
            .tween("size", 1.0.tweenTo(3.0))
        ..scene(
                begin: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 400),
                curve: Curves.linear)
            .tween("rotation", 0.0.tweenTo(2.0))
        ..scene(
                begin: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn)
            .tween("size", 3.0.tweenTo(1.0));
    } else if (effect == MessageEffect.slam) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
            .tween("size", 1.0.tweenTo(5.0))
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
            .tween("rotation", 0.0.tweenTo(pi / 16 * (message.isFromMe! ? 1 : -1)))
        ..scene(
                begin: const Duration(milliseconds: 250),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeIn)
            .tween("size", 5.0.tweenTo(0.8))
        ..scene(
                begin: const Duration(milliseconds: 250),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeIn)
            .tween("rotation", (pi / 16 * (message.isFromMe! ? 1 : -1)).tweenTo(0))
        ..scene(
                begin: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeIn)
            .tween("size", 0.8.tweenTo(1.0));
    } else {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = MessageStateScope.of(context).message;
    final effectStr =
        effectMap.entries.firstWhereOrNull((e) => e.value == message.expressiveSendStyleId)?.key ?? "unknown";
    final effect = stringToMessageEffect[effectStr] ?? MessageEffect.none;
    if (message.expressiveSendStyleId == null) return widget.child;
    if (effect == MessageEffect.invisibleInk) {
      return NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          if (rxControl.value != Control.stop) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final newSize = _readSize();
              if (newSize != Size.zero) _size.value = newSize;
            });
          }
          return false;
        },
        child: Obx(() => GestureDetector(
              onHorizontalDragUpdate: rxControl.value == Control.stop
                  ? null
                  : (DragUpdateDetails details) {
                      if (effect != MessageEffect.invisibleInk) return;
                      if ((details.primaryDelta ?? 0).abs() > 1) {
                        message.setPlayedDate();
                        // Fade out, then mark stopped once the animation finishes.
                        _fadeController.animateTo(0.0).then((_) {
                          if (mounted) rxControl.value = Control.stop;
                        });
                      }
                    },
              child: AbsorbPointer(
                absorbing: rxControl.value != Control.stop,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizeChangedLayoutNotifier(child: widget.child),
                    if (rxControl.value != Control.stop)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ClipPath(
                          clipper: TailClipper(
                            isFromMe: message.isFromMe!,
                            showTail: widget.showTail,
                            connectLower: false,
                            connectUpper: false,
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Particles(
                              key: UniqueKey(),
                              height: _size.value.height,
                              width: _size.value.width,
                              interaction: ParticleInteraction.none(),
                              particles: List.generate(
                                  _size.value.height * _size.value.width ~/ 25,
                                  (index) => CircularParticle(
                                        color: Colors.white.withAlpha(150),
                                        radius: Random().nextDouble() * (_size.value.height / 75).clamp(0.5, 1),
                                        velocity: Offset(Random().nextDouble() * 10, Random().nextDouble() * 10),
                                      )),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )),
      );
    }
    getTween(message, effect);
    return Obx(() => CustomAnimationBuilder<Movie>(
          control: rxControl.value,
          tween: tween,
          duration: Duration(
              milliseconds: effect == MessageEffect.loud
                  ? 900
                  : effect == MessageEffect.slam
                      ? 500
                      : 1800),
          animationStatusListener: (status) {
            if (status == AnimationStatus.completed) {
              rxControl.value = Control.stop;
              if (_pendingAutoPlay) {
                _pendingAutoPlay = false;
                _ms?.markEffectPlayed();
              }
            }
          },
          builder: (context, anim, child) {
            double value1 = 1;
            double value2 = 0;
            if (effect == MessageEffect.gentle) {
              value1 = anim.get("size");
            } else if (effect == MessageEffect.loud || effect == MessageEffect.slam) {
              value1 = anim.get("size");
              value2 = anim.get("rotation");
            }
            if (effect == MessageEffect.gentle) {
              return Padding(
                padding: EdgeInsets.only(top: _size.value.height * (value1.clamp(1, 1.2) - 1)),
                child: Transform.scale(
                    scale: rxControl.value == Control.stop ? 1 : value1,
                    alignment: message.isFromMe! ? Alignment.bottomRight : Alignment.bottomLeft,
                    child: child),
              );
            }
            if (effect == MessageEffect.loud) {
              return SizedBox(
                width: value1 == 1 ? null : _size.value.width * value1,
                height: value1 == 1 ? null : _size.value.height * value1,
                child: FittedBox(
                  alignment: Alignment.bottomLeft,
                  child: Transform.rotate(
                    angle: sin(value2 * pi * 4) * pi / 24,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              );
            }
            if (effect == MessageEffect.slam) {
              return SizedBox(
                width: value1 == 1 ? null : _size.value.width * value1,
                height: value1 == 1 ? null : _size.value.height * value1,
                child: FittedBox(
                  alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                  child: Transform.rotate(angle: value2, alignment: Alignment.bottomCenter, child: child),
                ),
              );
            }
            return child!;
          },
          child: widget.child,
        ));
  }
}
