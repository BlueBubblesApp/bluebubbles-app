import 'dart:async';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

enum ItemTypes {
  participantAdded,
  participantRemoved,
  nameChanged,
  participantLeft,
}

class GroupEvent extends StatefulWidget {
  GroupEvent({
    Key key,
    @required this.message,
  }) : super(key: key);
  final Message message;

  @override
  _GroupEventState createState() => _GroupEventState();
}

class _GroupEventState extends State<GroupEvent> {
  String text = "";
  Completer<void> completer;

  @override
  initState() {
    super.initState();
    getEventText();
  }

  Future<void> getEventText() async {
    // If we've already completed the task, don't do it again
    if (completer != null && completer.isCompleted) return;

    // If we haven't completed the task, return the pending task
    if (completer != null && !completer.isCompleted) return completer.future;

    // If we've never started the task, create a new one and fetch the group event text
    completer = new Completer<void>();

    getGroupEventText(widget.message).then((String text) {
      if (this.text == text) return;

      this.text = text;
      completer.complete();
      if (this.mounted) setState(() {});
    }).catchError((e) {
      completer.completeError(e);
    });

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: Axis.horizontal,
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .subtitle2,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ]
    );
  }
}
