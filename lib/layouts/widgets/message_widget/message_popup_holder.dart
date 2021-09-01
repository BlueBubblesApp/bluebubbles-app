import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessagePopupHolder extends StatefulWidget {
  final Widget child;
  final Widget popupChild;
  final Message message;
  final Message? olderMessage;
  final Message? newerMessage;

  MessagePopupHolder({
    Key? key,
    required this.child,
    required this.popupChild,
    required this.message,
    required this.olderMessage,
    required this.newerMessage,
  }) : super(key: key);

  @override
  _MessagePopupHolderState createState() => _MessagePopupHolderState();
}

class _MessagePopupHolderState extends State<MessagePopupHolder> {
  GlobalKey containerKey = GlobalKey();
  Offset childOffset = Offset(0, 0);
  Size? childSize;
  bool visible = true;

  void getOffset() {
    RenderBox renderBox = containerKey.currentContext!.findRenderObject() as RenderBox;
    Size size = renderBox.size;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    bool increaseWidth = !MessageHelper.getShowTail(context, widget.message, widget.newerMessage) &&
        (SettingsManager().settings.alwaysShowAvatars.value || (CurrentChat.of(context)?.chat.isGroup() ?? false));
    bool doNotIncreaseHeight = ((widget.message.isFromMe ?? false) ||
        !(CurrentChat.of(context)?.chat.isGroup() ?? false) ||
        !sameSender(widget.message, widget.olderMessage) ||
        !widget.message.dateCreated!.isWithin(widget.olderMessage!.dateCreated!, minutes: 30));

    this.childOffset = Offset(
        offset.dx - (increaseWidth ? 35 : 0),
        offset.dy -
            (doNotIncreaseHeight
                ? 0
                : widget.message.getReactions().length > 0
                    ? 20.0
                    : 23.0));
    childSize = Size(
        size.width + (increaseWidth ? 35 : 0),
        size.height +
            (doNotIncreaseHeight
                ? 0
                : widget.message.getReactions().length > 0
                    ? 20.0
                    : 23.0));
  }

  void openMessageDetails() async {
    HapticFeedback.lightImpact();
    getOffset();

    CurrentChat? currentChat = CurrentChat.of(context);
    if (this.mounted) {
      setState(() {
        visible = false;
      });
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        settings: RouteSettings(arguments: {"hideTail": true}),
        transitionDuration: Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
              opacity: animation,
              child: MessageDetailsPopup(
                currentChat: currentChat,
                child: widget.popupChild,
                childOffset: childOffset,
                childSize: childSize,
                message: widget.message,
              ));
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

  void sendReaction(String type) {
    Logger.info("Sending reaction type: " + type);
    ActionHandler.sendReaction(CurrentChat.of(context)!.chat, widget.message, type);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: containerKey,
      onDoubleTap: SettingsManager().settings.doubleTapForDetails.value && !widget.message.guid!.startsWith('temp')
          ? this.openMessageDetails
          : SettingsManager().settings.enableQuickTapback.value
              ? () {
                  HapticFeedback.lightImpact();
                  this.sendReaction(SettingsManager().settings.quickTapbackType.value);
                }
              : null,
      onLongPress: this.openMessageDetails,
      child: Opacity(
        child: widget.child,
        opacity: visible ? 1 : 0,
      ),
    );
  }
}
