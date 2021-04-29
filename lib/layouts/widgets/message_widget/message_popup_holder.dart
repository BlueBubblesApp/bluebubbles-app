import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessagePopupHolder extends StatefulWidget {
  final Widget child;
  final Message message;
  MessagePopupHolder({
    Key key,
    @required this.child,
    @required this.message,
  }) : super(key: key);

  @override
  _MessagePopupHolderState createState() => _MessagePopupHolderState();
}

class _MessagePopupHolderState extends State<MessagePopupHolder> {
  GlobalKey containerKey = GlobalKey();
  Offset childOffset = Offset(0, 0);
  Size childSize;
  bool visible = true;

  void getOffset() {
    RenderBox renderBox = containerKey.currentContext.findRenderObject();
    Size size = renderBox.size;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      this.childOffset = Offset(offset.dx, offset.dy);
      childSize = size;
    });
  }

  void openMessageDetails() async {
    HapticFeedback.lightImpact();
    getOffset();

    CurrentChat currentChat = CurrentChat.of(context);
    if (this.mounted) {
      setState(() {
        visible = false;
      });
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 0),
        pageBuilder: (context, animation, secondaryAnimation) {
          return MessageDetailsPopup(
            currentChat: currentChat,
            child: widget.child,
            childOffset: childOffset,
            childSize: childSize,
            message: widget.message,
          );
        },
        fullscreenDialog: true,
        opaque: false,
      ),
    );

    if (this.mounted) {
      setState(() {
        visible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: containerKey,
      onDoubleTap: SettingsManager().settings.doubleTapForDetails
          ? this.openMessageDetails
          : null,
      onLongPress: this.openMessageDetails,
      child: Opacity(
        child: widget.child,
        opacity: visible ? 1 : 0,
      ),
    );
  }
}
