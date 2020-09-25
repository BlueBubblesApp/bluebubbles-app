import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:flutter/material.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key key,
    this.initials,
    this.contactImage,
    this.size,
  }) : super(key: key);
  final initials;
  final ImageProvider contactImage;
  final double size;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: (widget.size != null) ? widget.size / 2 : 20,
      child: widget.contactImage == null
          ? Container(
              width: widget.size ?? 40,
              height: widget.size ?? 40,
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
