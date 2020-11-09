import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:flutter/material.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key key,
    this.initials,
    this.contactImage,
    this.size,
    this.fontSize,
    this.color,
  }) : super(key: key);
  final initials;
  final ImageProvider contactImage;
  final double size;
  final double fontSize;
  final Color color;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  @override
  Widget build(BuildContext context) {
    Color color1 = widget.color;
    Color color2 = widget.color;
    if (color1 == null) {
      color1 = HexColor('a0a4af');
      color2 = HexColor('848894');
    } else {
      color2 = widget.color.withAlpha(225);
    }

    return CircleAvatar(
      radius: (widget.size != null) ? widget.size / 2 : 20,
      child: widget.contactImage == null
          ? Container(
              width: widget.size ?? 40,
              height: widget.size ?? 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  colors: [color2, color1],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                child: (widget.initials is Icon)
                    ? widget.initials
                    : Text(widget.initials,
                        style: TextStyle(
                            fontSize: (widget.fontSize == null)
                                ? 18
                                : widget.fontSize)),
                alignment: AlignmentDirectional.center,
              ),
            )
          : CircleAvatar(
              backgroundImage: widget.contactImage,
            ),
    );
  }
}