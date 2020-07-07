import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
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
  @override
  Widget build(BuildContext context) {
    if (ItemTypes.participantAdded.index == widget.message.itemType) {
      debugPrint(widget.message.toMap().toString());
      return Text(
        "participant added",
        style: Theme.of(context).textTheme.bodyText1,
      );
    } else if (ItemTypes.participantRemoved.index == widget.message.itemType) {
      debugPrint(widget.message.toMap().toString());
      return Text(
        "participant removed",
        style: Theme.of(context).textTheme.bodyText1,
      );
    } else if (ItemTypes.nameChanged.index == widget.message.itemType) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Column(
              children: <Widget>[
                RichText(
                  text: TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .subtitle2
                        .apply(fontSizeDelta: 1.5),
                    children: <TextSpan>[
                      TextSpan(
                        text: getContactTitle(
                          ContactManager().contacts,
                          widget.message.handle.address,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .subtitle2
                            .apply(fontWeightDelta: 20, fontSizeDelta: 1.5),
                      ),
                      TextSpan(
                        text: " named the conversation ",
                      ),
                    ],
                  ),
                ),
                Text(
                  "\"" + widget.message.groupTitle + "\"",
                  style: Theme.of(context)
                      .textTheme
                      .subtitle2
                      .apply(fontWeightDelta: 20, fontSizeDelta: 1.5),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (ItemTypes.participantLeft.index == widget.message.itemType) {
      return Text(
        "participant left",
        style: Theme.of(context).textTheme.bodyText1,
      );
    } else {
      return Text("not implemented " + widget.message.itemType.toString(),
          style: Theme.of(context).textTheme.bodyText1);
    }
  }
}
