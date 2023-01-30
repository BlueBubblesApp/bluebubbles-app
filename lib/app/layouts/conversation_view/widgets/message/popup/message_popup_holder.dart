import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_html/html.dart' as html;

class MessagePopupHolder extends StatefulWidget {
  MessagePopupHolder({
    Key? key,
    required this.child,
    required this.part,
    required this.controller,
    required this.cvController,
  }) : super(key: key);

  final Widget child;
  final MessagePart part;
  final MessageWidgetController controller;
  final ConversationViewController cvController;

  @override
  OptimizedState createState() => _MessagePopupHolderState();
}

class _MessagePopupHolderState extends OptimizedState<MessagePopupHolder> {
  final GlobalKey globalKey = GlobalKey();

  Message get message => widget.controller.message;

  void openPopup(BuildContext context) async {
    widget.cvController.focusNode.unfocus();
    widget.cvController.subjectFocusNode.unfocus();
    HapticFeedback.lightImpact();
    final size = globalKey.currentContext?.size;
    final childPos = (globalKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
    if (size == null || childPos == null) return;
    final tuple = await ss.getServerDetails();
    final version = tuple.item4;
    final minSierra = await ss.isMinSierra;
    final minBigSur = await ss.isMinBigSur;
    eventDispatcher.emit('popup-pushed', true);
    if (!iOS) {
      widget.cvController.selected.add(message);
    }
    final result = await Navigator.push(
      Get.context!,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Theme(
              data: context.theme.copyWith(
                // in case some components still use legacy theming
                primaryColor: context.theme.colorScheme.bubble(context, true),
                colorScheme: context.theme.colorScheme.copyWith(
                  primary: context.theme.colorScheme.bubble(context, true),
                  onPrimary: context.theme.colorScheme.onBubble(context, true),
                  surface: ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                  onSurface: ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                ),
              ),
              child: MessagePopup(
                childPosition: childPos,
                size: size,
                child: widget.child,
                part: widget.part,
                controller: widget.controller,
                cvController: widget.cvController,
                serverDetails: Tuple3(minSierra, minBigSur, version > 100),
                sendTapback: sendTapback,
                widthContext: context,
              ),
            ),
          );
        },
        fullscreenDialog: true,
        opaque: false,
        barrierDismissible: true,
      ),
    );
    if (result != false) {
      widget.cvController.selected.clear();
    }
    if (kIsDesktop || kIsWeb) {
      widget.cvController.focusNode.requestFocus();
    }
    eventDispatcher.emit('popup-pushed', false);
  }

  void sendTapback([String? type, int? part]) {
    HapticFeedback.lightImpact();
    final reaction = type ?? ss.settings.quickTapbackType.value;
    Logger.info("Sending reaction type: $reaction");
    outq.queue(OutgoingItem(
      type: QueueType.sendMessage,
      chat: message.getChat() ?? cm.activeChat!.chat,
      message: Message(
        associatedMessageGuid: message.guid,
        associatedMessageType: reaction,
        associatedMessagePart: part,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
      ),
      selected: message,
      reaction: reaction,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: globalKey,
      onDoubleTap: ss.settings.doubleTapForDetails.value || message.guid!.startsWith('temp')
        ? () => openPopup(context)
        : ss.settings.enableQuickTapback.value && widget.cvController.chat.isIMessage
        ? () => sendTapback(null, widget.part.part)
        : null,
      onLongPress: ss.settings.doubleTapForDetails.value &&
        ss.settings.enableQuickTapback.value &&
        widget.cvController.chat.isIMessage &&
        !message.guid!.startsWith('temp')
        ? () => sendTapback(null, widget.part.part)
        : () => openPopup(context),
      onSecondaryTapUp: (details) async {
        if (!kIsWeb && !kIsDesktop) return;
        if (kIsWeb) {
          (await html.document.onContextMenu.first).preventDefault();
        }
        openPopup(context);
      },
      child: widget.child,
    );
  }
}
