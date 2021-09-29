import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

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

    childOffset = Offset(
        offset.dx - (increaseWidth ? 35 : 0),
        offset.dy -
            (doNotIncreaseHeight
                ? 0
                : widget.message.getReactions().isNotEmpty
                    ? 20.0
                    : 23.0));
    childSize = Size(
        size.width + (increaseWidth ? 35 : 0),
        size.height +
            (doNotIncreaseHeight
                ? 0
                : widget.message.getReactions().isNotEmpty
                    ? 20.0
                    : 23.0));
  }

  void openMessageDetails() async {
    EventDispatcher().emit("unfocus-keyboard", null);
    HapticFeedback.lightImpact();
    getOffset();

    CurrentChat? currentChat = CurrentChat.of(context);
    if (mounted) {
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                childOffset =
                    Offset(childOffset.dx - context.mediaQuerySize.width + constraints.maxWidth, childOffset.dy);
                return MessageDetailsPopup(
                  currentChat: currentChat,
                  child: widget.popupChild,
                  childOffset: childOffset,
                  childSize: childSize,
                  message: widget.message,
                );
              },
            ),
          );
        },
        fullscreenDialog: true,
        opaque: false,
      ),
    );

    if (mounted) {
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
          ? openMessageDetails
          : SettingsManager().settings.enableQuickTapback.value
              ? () {
                  HapticFeedback.lightImpact();
                  sendReaction(SettingsManager().settings.quickTapbackType.value);
                }
              : null,
      onLongPress: openMessageDetails,
      onSecondaryTapUp: (details) async {
        if (!kIsWeb && !kIsDesktop) return;
        if (kIsWeb) {
          (await html.document.onContextMenu.first).preventDefault();
        }
        openMessageDetails();
      },
      child: Opacity(
        child: widget.child,
        opacity: visible ? 1 : 0,
      ),
    );
  }
}
