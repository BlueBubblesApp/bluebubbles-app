import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:flutter/material.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key key,
    this.initials,
    this.contactImage,
  }) : super(key: key);
  final initials;
  final ImageProvider contactImage;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      child: widget.contactImage == null
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  colors: [HexColor('a0a4af'), HexColor('848894')],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                child: (widget.initials is Icon)
                    ? widget.initials
                    : Text(widget.initials),
                alignment: AlignmentDirectional.center,
              ),
            )
          : CircleAvatar(
              backgroundImage: widget.contactImage,
            ),
    );
  }
}
