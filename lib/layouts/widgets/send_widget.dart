import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// This widget is responsible for the send animation.
/// This is probably the weirdest and hackiest thing in the codebase
/// In order to achieve the iOS style send animation, I rely on a [Hero] widget,
/// which animate a widget on page b to the same widget page a when navigating.
/// This widget is very similar to the iOS send animation and thus I decided to use it.
///
/// However when sending, obviously you aren't navigating to different pages, or are you?
/// Yeah so basically, when you hit the send button, for a split second you are navigated to
/// an "invisible" page, with no background or other widgets other than a sent message widget
///
/// Then this invisible page is popped back to the convo view and the message is animated to the
/// correct place in the messages list by flutter [Hero] widget automatically
///
/// Okay, now that that is out of the way, let's talk about the actual code
///
/// @param [text] is the text from the textfield to send
/// @param [tag] is the tag of the hero widget. This is typically "first"

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

    // We need to pop the "invisible" after the first frame renders
    SchedulerBinding.instance
        .addPostFrameCallback((_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    Widget messageWidget = SentMessageHelper.buildMessageWithTail(
      context,
      null,
      true,
      false,
      customContent: Container(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width * 3 / 4 + 37,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 3 / 4 - 30,
              ),
              child: RichText(
                text: TextSpan(
                  text: widget.text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyText2
                      .apply(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.bottomRight,
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
            padding: const EdgeInsets.only(bottom: 12, right: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Hero(
                  flightShuttleBuilder: (flightContext, _animation,
                      flightDirection, fromHeroContext, toHeroContext) {
                    Animation animation = _animation.drive(
                      Tween<double>(
                        end: MediaQuery.of(context).size.width * 3 / 4 + 40,
                        begin: 0,
                      ),
                    );
                    return Material(
                      type: MaterialType.transparency,
                      child: FadeTransition(
                        opacity: _animation.drive(
                          Tween<double>(end: 0, begin: 2),
                        ),
                        child: SentMessageHelper.buildMessageWithTail(
                          context,
                          null,
                          true,
                          false,
                          customContent: AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Container(
                                constraints: BoxConstraints(
                                  minWidth: animation.value,
                                ),
                                child: child,
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                                3 /
                                                4 -
                                            30,
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      text: widget.text,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          .apply(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  tag: widget.tag,
                  child: Material(
                    type: MaterialType.transparency,
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
  Duration get reverseTransitionDuration => Duration(milliseconds: 300);
}
