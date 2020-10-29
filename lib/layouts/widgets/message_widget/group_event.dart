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

  @override
  initState() {
    super.initState();
    getEventText();
  }

  @override
  didChangeDependencies() {
    super.didChangeDependencies();
    getEventText();
  }

  void getEventText() {
    getGroupEventText(widget.message).then((String text) {
      if (this.text != text) {
        this.text = text;
        if (this.mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .subtitle2,
          ),
        ],
      ),
    );
  }
}
