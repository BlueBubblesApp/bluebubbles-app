import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class MessageTail extends StatelessWidget {
  final Color color;
  final bool isFromMe;

  const MessageTail({Key? key, required this.isFromMe, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ModalRoute? routeCtx = ModalRoute.of(context);
    bool hideTail = ((routeCtx?.settings.arguments ?? {"hideTail": false}) as Map)["hideTail"] ?? false;
    if (hideTail) return Container();

    return ClipPath(
      clipper: TailClipper(isFromMe),
      child: Container(
        margin: EdgeInsets.only(
          left: isFromMe ? 0.0 : 4.0,
          right: isFromMe ? 4.0 : 0.0,
          bottom: 1,
        ),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            bottomRight: isFromMe ? Radius.zero : Radius.circular(12),
            bottomLeft: isFromMe ? Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class TailClipper extends CustomClipper<Path> {
  bool isFromMe;

  TailClipper(this.isFromMe);

  @override
  Path getClip(Size size) {
    Path path = Path();
    if (!isFromMe) {
      path.moveTo(2, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2 - 2, 0);
      path.lineTo(size.width / 2 - 2, size.height / 3.5);
      path.quadraticBezierTo(size.width / 2 - 2, size.height - 1.5, 2, size.height - 1.5);
    } else {
      path.moveTo(size.width - 2, size.height);
      path.lineTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width / 2 + 2, 0);
      path.lineTo(size.width / 2 + 2, size.height / 3.5);
      path.quadraticBezierTo(size.width / 2 + 2, size.height - 1.5, size.width + 2, size.height - 1.5);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return false;
  }
}
