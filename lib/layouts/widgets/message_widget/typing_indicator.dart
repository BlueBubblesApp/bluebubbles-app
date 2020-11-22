import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'dart:math' as Math;

class TypingIndicator extends StatefulWidget {
  TypingIndicator({Key key, this.visible}) : super(key: key);
  final bool visible;

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  AnimationController _controller;
  Animation animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 700));
    _controller.addListener(() {});

    animation = Tween(
      begin: 0.0,
      end: Math.pi,
    ).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    _controller.addStatusListener((state) {
      if (state == AnimationStatus.completed && this.mounted) {
        _controller.forward(from: 0.0);
      }
    });

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      vsync: this,
      duration: Duration(milliseconds: 200),
      child: widget.visible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).accentColor,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      width: 10,
                      height: 10,
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 9, bottom: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).accentColor,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      width: 15,
                      height: 15,
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        top: 18,
                        left: 10,
                        right: 10,
                        bottom: 13,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width *
                            MessageWidgetMixin.MAX_SIZE,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).accentColor,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            children: [
                              buildDot(2),
                              buildDot(1),
                              buildDot(0),
                            ],
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Container(),
    );
  }

  Widget buildDot(int index) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).accentColor.lightenOrDarken(
                  (Math.sin(animation.value + (index) * Math.pi / 4).abs() * 20)
                      .clamp(1, 20)
                      .toDouble()),
              borderRadius: BorderRadius.circular(30),
            ),
            width: 10,
            height: 10,
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          );
        },
      );
}
