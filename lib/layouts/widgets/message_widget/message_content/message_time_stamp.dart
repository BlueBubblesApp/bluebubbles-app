import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageTimeStamp extends StatelessWidget {
  const MessageTimeStamp({Key key, this.message, this.offset})
      : super(key: key);
  final Message message;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: (-offset).clamp(0, 70).toDouble(),
      duration: Duration(milliseconds: offset == 0 ? 150 : 0),
      child: Text(
        DateFormat('h:mm a').format(message.dateCreated).toLowerCase(),
        style: Theme.of(context).textTheme.subtitle1,
        overflow: TextOverflow.clip,
        maxLines: 1,
      ),
    );
  }
}
