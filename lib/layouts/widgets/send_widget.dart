import 'package:bluebubble_messages/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/sent_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendWidget extends StatefulWidget {
  SendWidget({
    Key key,
    this.text,
    this.tag,
  }) : super(key: key);
  final String text;
  final String tag;

  @override
  _SendWidgetState createState() => _SendWidgetState();
}

class _SendWidgetState extends State<SendWidget> {
  bool showHero = false;

  @override
  void initState() {
    super.initState();
    // SystemChannels.textInput.invokeMethod('TextInput.show');
    Future.delayed(Duration(milliseconds: 50), () {
      setState(() {
        showHero = true;
      });
    });
    Future.delayed(Duration(milliseconds: 60), () {
      Navigator.of(context).pop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = (TextPainter(
            text: TextSpan(
                text: widget.text,
                style: TextStyle(
                  color: Colors.white,
                )),
            maxLines: 1,
            textScaleFactor: MediaQuery.of(context).textScaleFactor,
            textDirection: TextDirection.ltr)
          ..layout())
        .size;
    double initialPadding =
        (MediaQuery.of(context).size.width * (3 / 4) - size.width)
            .clamp(14, MediaQuery.of(context).size.width * (3 / 4))
            .toDouble();

    Widget messageWidget = MessageWidget(
      reactions: [],
      fromSelf: true,
      showHandle: false,
      newerMessage: null,
      olderMessage: null,
      customContent: <Widget>[
        Padding(
          padding: EdgeInsets.only(
              left: 14, top: 8, bottom: 8.1, right: initialPadding),
          child: Text(
            widget.text,
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        )
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: TextField(
              cursorColor: Colors.transparent,
              decoration: InputDecoration(
                fillColor: Colors.transparent,
                border: InputBorder.none,
              ),
              autofocus: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2, right: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                showHero
                    ? Hero(
                        flightShuttleBuilder: (flightContext, _animation,
                            flightDirection, fromHeroContext, toHeroContext) {
                          Animation animation = _animation.drive(Tween<double>(
                              end: initialPadding,
                              begin:
                                  14 > initialPadding ? initialPadding : 14));
                          return Material(
                            type: MaterialType.transparency,
                            child: MessageWidget(
                              reactions: [],
                              fromSelf: true,
                              showHandle: false,
                              newerMessage: null,
                              olderMessage: null,
                              customContent: <Widget>[
                                AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        left: 14,
                                        top: 8,
                                        bottom: 8.1,
                                        right: animation.value,
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    widget.text,
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        tag: widget.tag,
                        child: Material(
                          type: MaterialType.transparency,
                          // color: Colors.transparent,
                          // elevation: 0.0,
                          child: messageWidget,
                        ),
                      )
                    : messageWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SendPageBuilder extends PageRoute<void> {
  SendPageBuilder({
    @required this.builder,
    RouteSettings settings,
  })  : assert(builder != null),
        super(settings: settings, fullscreenDialog: false);

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color get barrierColor => null;

  @override
  String get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final result = builder(context);
    return result;
  }

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => Duration(milliseconds: 0);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: 500);
}
