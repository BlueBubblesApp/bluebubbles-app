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
  @override
  void initState() {
    super.initState();
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
    Widget messageWidget = MessageWidget(
      reactions: [],
      showHandle: false,
      newerMessage: null,
      olderMessage: null,
      shouldFadeIn: false,
      fromSelf: true,
      customContent: <Widget>[
        Container(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width * 3 / 4,
          ),
          child: Text(
            widget.text,
            style: Theme.of(context).textTheme.bodyText1,
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
                Hero(
                  flightShuttleBuilder: (flightContext, _animation,
                      flightDirection, fromHeroContext, toHeroContext) {
                    Animation animation = _animation.drive(
                      Tween<double>(
                        end: MediaQuery.of(context).size.width * 3 / 4,
                        begin: 0,
                      ),
                    );
                    return Material(
                      type: MaterialType.transparency,
                      child: FadeTransition(
                        opacity: _animation.drive(
                          Tween<double>(end: 0, begin: 1),
                        ),
                        child: MessageWidget(
                          reactions: [],
                          fromSelf: true,
                          showHandle: false,
                          newerMessage: null,
                          olderMessage: null,
                          shouldFadeIn: false,
                          customContent: <Widget>[
                            AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Container(
                                  constraints: BoxConstraints(
                                    minWidth: animation.value,
                                  ),
                                  child: child,
                                );
                              },
                              child: Text(
                                widget.text,
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  tag: widget.tag,
                  child: Material(
                    type: MaterialType.transparency,
                    // color: Colors.transparent,
                    // elevation: 0.0,
                    child: Opacity(
                      child: messageWidget,
                      opacity: 0,
                    ),
                  ),
                )
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
