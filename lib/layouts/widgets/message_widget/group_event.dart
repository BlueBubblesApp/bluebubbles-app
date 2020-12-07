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
  bool complete = false;

  @override
  initState() {
    super.initState();
    getEventText();
  }

  void getEventText() {
    if (complete) return;

    getGroupEventText(widget.message).then((String text) {
      if (this.text != text) {
        this.text = text;
        if (this.mounted) {
          setState(() {
            complete = true;
          });
        }
      }
    });
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
