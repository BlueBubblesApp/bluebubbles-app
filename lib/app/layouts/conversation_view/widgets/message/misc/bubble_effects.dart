import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:particles_flutter/particles_engine.dart';
import 'package:particles_flutter/component/particle/particle.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

class BubbleEffects extends StatefulWidget {
  BubbleEffects({
    super.key,
    required this.child,
    required this.message,
    required this.part,
    required this.globalKey,
    required this.showTail,
  });

  final Widget child;
  final Message message;
  final int part;
  final GlobalKey? globalKey;
  final bool showTail;

  @override
  OptimizedState createState() => _BubbleEffectsState();
}

class _BubbleEffectsState extends OptimizedState<BubbleEffects> {
  Message get message => widget.message;
  String get effectStr => effectMap.entries.firstWhereOrNull((e) => e.value == message.expressiveSendStyleId)?.key ?? "unknown";
  MessageEffect get effect => stringToMessageEffect[effectStr] ?? MessageEffect.none;

  late MovieTween tween;
  Control controller = Control.stop;
  Size size = Size.zero;

  @override
  void initState() {
    getTween();

    eventDispatcher.stream.listen((event) async {
      if (event.item1 == 'play-bubble-effect' && event.item2 == '${widget.part}/${widget.message.guid}') {
        size = widget.globalKey?.currentContext?.size ?? Size.zero;
        setState(() {
          controller = Control.playFromStart;
        });
      }
    });

    super.initState();
  }

  void getTween() {
    if (effect == MessageEffect.gentle) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 1), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0))
        ..scene(begin: const Duration(milliseconds: 1), duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 0.0.tweenTo(1.2))
        ..scene(begin: const Duration(milliseconds: 1000), duration: const Duration(milliseconds: 800), curve: Curves.easeInOut)
            .tween("size", 1.2.tweenTo(1.0));
    } else if (effect == MessageEffect.loud) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 300), curve: Curves.easeIn)
            .tween("size", 1.0.tweenTo(3.0))
        ..scene(
            begin: const Duration(milliseconds: 200), duration: const Duration(milliseconds: 400), curve: Curves.linear)
            .tween("rotation", 0.0.tweenTo(2.0))
        ..scene(
            begin: const Duration(milliseconds: 400), duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
            .tween("size", 3.0.tweenTo(1.0));
    } else if (effect == MessageEffect.slam) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
            .tween("size", 1.0.tweenTo(5.0))
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
            .tween("rotation", 0.0.tweenTo(pi / 16 * (message.isFromMe! ? 1 : -1)))
        ..scene(
            begin: const Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
            .tween("size", 5.0.tweenTo(0.8))
        ..scene(
            begin: const Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
            .tween("rotation", (pi / 16 * (message.isFromMe! ? 1 : -1)).tweenTo(0))
        ..scene(
            begin: const Duration(milliseconds: 400), duration: const Duration(milliseconds: 100), curve: Curves.easeIn)
            .tween("size", 0.8.tweenTo(1.0));
    } else {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (message.expressiveSendStyleId == null) return widget.child;
    if (effect == MessageEffect.invisibleInk) {
      return GestureDetector(
        onHorizontalDragUpdate: controller == Control.stop ? null : (DragUpdateDetails details) {
          if (effect != MessageEffect.invisibleInk) return;
          if ((details.primaryDelta ?? 0).abs() > 1) {
            message.setPlayedDate();
            setState(() {
              controller = Control.stop;
            });
          }
        },
        child: AbsorbPointer(
          absorbing: controller != Control.stop,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (controller != Control.stop)
                ClipPath(
                  clipper: TailClipper(
                    isFromMe: message.isFromMe!,
                    showTail: widget.showTail,
                    connectLower: false,
                    connectUpper: false,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Particles(
                      key: UniqueKey(),
                      height: size.height,
                      width: size.width,
                      particles: List.generate(size.height * size.width ~/ 25, (index) =>
                          Particle(
                              color: Colors.white.withAlpha(150),
                              size: Random().nextDouble() * (size.height / 75).clamp(0.5, 1),
                              velocity: Offset(Random().nextDouble() * 10, Random().nextDouble() * 10),
                          )
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    getTween();
    return CustomAnimationBuilder<Movie>(
      control: controller,
      tween: tween,
      duration: Duration(
        milliseconds: effect == MessageEffect.loud ? 900 : effect == MessageEffect.slam ? 500 : 1800
      ),
      animationStatusListener: (status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            controller = Control.stop;
          });
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
            padding: EdgeInsets.only(top: size.height * (value1.clamp(1, 1.2) - 1)),
            child: Transform.scale(
              scale: controller == Control.stop ? 1 : value1,
              alignment: message.isFromMe! ? Alignment.bottomRight : Alignment.bottomLeft,
              child: child
            ),
          );
        }
        if (effect == MessageEffect.loud) {
          return Container(
            width: value1 == 1 ? null : size.width * value1,
            height: value1 == 1 ? null : size.height * value1,
            child: FittedBox(
              alignment: Alignment.bottomLeft,
              child: Transform.rotate(
                angle: sin(value2 * pi * 4) * pi / 24, alignment: Alignment.bottomCenter, child: child,
              ),
            ),
          );
        }
        if (effect == MessageEffect.slam) {
          return Container(
            width: value1 == 1 ? null : size.width * value1,
            height: value1 == 1 ? null : size.height * value1,
            child: FittedBox(
              alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
              child: Transform.rotate(angle: value2, alignment: Alignment.bottomCenter, child: child),
            ),
          );
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
