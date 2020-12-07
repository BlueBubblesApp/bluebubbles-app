import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class MessageTail extends StatelessWidget {
  final Color color;
  final Message message;

  const MessageTail({Key key, @required this.message, this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isFromMe = message?.isFromMe ?? true;
    return Stack(
      alignment: isFromMe
          ? AlignmentDirectional.bottomEnd
          : AlignmentDirectional.bottomStart,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: isFromMe ? 0.0 : 4.0,
            right: isFromMe ? 4.0 : 0.0,
            bottom: 1,
          ),
          width: 20,
          height: 15,
          decoration: BoxDecoration(
            color: color
                ?? Theme.of(context).primaryColor,
            borderRadius: BorderRadius.only(
              bottomRight: isFromMe ? Radius.zero : Radius.circular(12),
              bottomLeft: isFromMe ? Radius.circular(12) : Radius.zero,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(bottom: 2),
          height: 28,
          width: 11,
          decoration: BoxDecoration(
            color: Theme.of(context).backgroundColor,
            borderRadius: BorderRadius.only(
              bottomRight:isFromMe ? Radius.zero : Radius.circular(8),
              bottomLeft:isFromMe ? Radius.circular(8) : Radius.zero,
            ),
          ),
        ),
      ],
    );
  }
}
