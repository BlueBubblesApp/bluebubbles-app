import 'package:get/get.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
  static const Duration SEND_DURATION = Duration(milliseconds: 300);

  SendWidget({
    Key? key,
    this.text,
    this.tag,
    this.currentChat,
  }) : super(key: key);
  final String? text;
  final String? tag;
  final CurrentChat? currentChat;

  @override
  _SendWidgetState createState() => _SendWidgetState();
}

class _SendWidgetState extends State<SendWidget> {
  @override
  void initState() {
    super.initState();

    // We need to pop the "invisible" after the first frame renders
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget messageWidget = SentMessageHelper.buildMessageWithTail(
      context,
      null,
      true,
      false,
      false,
      padding: false,
      customContent: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            constraints: BoxConstraints(
              minWidth: Get.mediaQuery.size.width * 3 / 37,
            ),
            child: SentMessageHelper.buildMessageWithTail(
              context,
              null,
              false,
              false,
              false,
              customColor: Colors.transparent,
              currentChat: widget.currentChat,
              margin: false,
              customContent: RichText(
                text: TextSpan(
                  text: widget.text,
                  style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      currentChat: widget.currentChat,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
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
                autofocus: Get.mediaQuery.viewInsets.bottom > 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Hero(
                    flightShuttleBuilder: buildAnimation,
                    tag: widget.tag!,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Row(
                        children: [
                          Opacity(
                            child: messageWidget,
                            opacity: 0,
                          )
                        ],
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.max,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAnimation(flightContext, _animation, flightDirection, fromHeroContext, toHeroContext) {
    Animation<double> animation = _animation.drive(
      Tween<double>(
        end: Get.mediaQuery.size.width * 3 / 4 + 37,
        begin: 0,
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _animation.drive(
          Tween<double>(end: 0, begin: 10),
        ),
        child: SentMessageHelper.buildMessageWithTail(
          context,
          null,
          true,
          false,
          false,
          padding: false,
          customContent: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      minWidth: animation.value,
                      maxWidth: animation.value.clamp(
                        Get.mediaQuery.size.width * MessageWidgetMixin.MAX_SIZE,
                        Get.mediaQuery.size.width * 3 / 4 + 37,
                      ),
                    ),
                    child: child,
                  ),
                ],
              );
            },
            child: SentMessageHelper.buildMessageWithTail(
              context,
              null,
              false,
              false,
              false,
              customColor: Colors.transparent,
              currentChat: widget.currentChat,
              margin: false,
              customContent: RichText(
                text: TextSpan(
                  text: widget.text,
                  style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
                ),
              ),
            ),
          ),
          currentChat: widget.currentChat,
        ),
      ),
    );
  }
}

class SendPageBuilder extends PageRoute<void> {
  SendPageBuilder({
    required this.builder,
    RouteSettings? settings,
  })  : super(settings: settings, fullscreenDialog: false);

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final result = builder(context);
    return result;
  }

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => Duration(milliseconds: 0);

  @override
  Duration get reverseTransitionDuration => SendWidget.SEND_DURATION;
}
