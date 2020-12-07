import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';

class ContactAvatarGroupWidget extends StatefulWidget {
  ContactAvatarGroupWidget(
      {Key key,
      @required this.participants,
      this.width,
      this.height,
      @required this.chat})
      : super(key: key);
  final List<Handle> participants;
  final Chat chat;
  final double width;
  final double height;

  @override
  _ContactAvatarGroupWidgetState createState() =>
      _ContactAvatarGroupWidgetState();
}

class _ContactAvatarGroupWidgetState extends State<ContactAvatarGroupWidget> {
  List<dynamic> icons;
  List<Handle> participants = [];

  @override
  Widget build(BuildContext context) {
    participants = widget.participants;
    if (participants.length > 2) {
      participants = participants.sublist(0, 2);
    }

    if (participants.length == 0) {
      return Container(
        width: widget.width ?? 40,
        height: widget.height ?? 40,
      );
    }

    return Container(
      width: widget.width ?? 40,
      height: widget.height ?? 40,
      child: participants.length > 1
          ? Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: ContactAvatarWidget(
                    handle: participants[0],
                    size: 26,
                    fontSize: 12,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: ContactAvatarWidget(
                    handle: participants[1],
                    size: 26,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : ContactAvatarWidget(
              handle: participants.first,
              borderThickness: 0.1,
            ),
    );
  }
}
