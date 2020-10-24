import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:flutter/material.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key key,
    this.initials,
    this.contactImage,
    this.radius,
    this.height,
    this.width,
    this.fontSize,
  }) : super(key: key);
  final initials;
  final ImageProvider contactImage;
  final double radius;
  final double height;
  final double width;
  final double fontSize;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.contactImage != null) {
      return CircleAvatar(
        backgroundImage: widget.contactImage,
        backgroundColor: Theme.of(context).backgroundColor,
        radius: widget.radius ?? 20,
      );
    }

    if (widget.initials is Transform) {
      return Container(
        color: Theme.of(context).backgroundColor,
        width: widget.height ?? 40,
        height: widget.width ?? 40,
        child: widget.initials,
      );
    }

    return CircleAvatar(
      backgroundColor: Theme.of(context).backgroundColor,
      radius: widget.radius ?? 20,
      child: Container(
        width: widget.width ?? 40,
        height: widget.height ?? 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            colors: [HexColor('a0a4af'), HexColor('848894')],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          child: (widget.initials is String)
              ? Text(
                  widget.initials,
                  style: TextStyle(
                    fontSize: (widget.fontSize == null) ? 18 : widget.fontSize,
                    color: Theme.of(context).textTheme.bodyText1.color,
                  ),
                )
              : widget.initials,
          alignment: AlignmentDirectional.center,
        ),
      ),
    );
  }
}
