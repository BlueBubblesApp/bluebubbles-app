import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class ContactAvatarGroupWidget extends StatefulWidget {
  ContactAvatarGroupWidget(
      {Key key, this.participants, this.width, this.height})
      : super(key: key);
  final List<Handle> participants;
  final double width;
  final double height;

  @override
  _ContactAvatarGroupWidgetState createState() =>
      _ContactAvatarGroupWidgetState();
}

class _ContactAvatarGroupWidgetState extends State<ContactAvatarGroupWidget> {
  List<dynamic> icons;
  List<Handle> participants;

  @override
  void initState() {
    super.initState();
    if (widget.participants.length > 2) {
      participants = widget.participants.sublist(0, 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participants.length == 0)
      return Container(
        width: widget.width ?? 40,
        height: widget.height ?? 40,
      );
    return Container(
      width: widget.width ?? 40,
      height: widget.height ?? 40,
      child: widget.participants.length > 1
          ? Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: ContactAvatarWidget(
                    handle: widget.participants[0],
                    size: 26,
                    fontSize: 12,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: ContactAvatarWidget(
                    handle: widget.participants[1],
                    size: 26,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : ContactAvatarWidget(
              handle: widget.participants.first,
            ),
    );
  }
}
