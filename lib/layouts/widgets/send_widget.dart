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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    showHero = true;
    setState(() {});
    Future.delayed(Duration(milliseconds: 200), () {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget messageWidget = MessageWidget(
      reactions: [],
      fromSelf: true,
      showHandle: false,
      newerMessage: null,
      olderMessage: null,
      customContent: <Widget>[
        SizedBox(
          width: MediaQuery.of(context).size.width * (5 / 6),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            child: Text(
              widget.text,
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ),
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
