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
    required this.isEditing,
  }) : super(key: key);

  final Widget child;
  final MessagePart part;
  final MessageWidgetController controller;
  final ConversationViewController cvController;
  final bool isEditing;

  @override
  OptimizedState createState() => _MessagePopupHolderState();
}

class _MessagePopupHolderState extends OptimizedState<MessagePopupHolder> {
  final GlobalKey globalKey = GlobalKey();

  Message get message => widget.controller.message;

  void openPopup() async {
    widget.cvController.focusNode.unfocus();
    widget.cvController.subjectFocusNode.unfocus();
    HapticFeedback.lightImpact();
    final size = globalKey.currentContext?.size;
    Offset? childPos = (globalKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
    if (size == null || childPos == null) return;
    childPos = Offset(childPos.dx - MediaQueryData.fromView(View.of(context)).padding.left, childPos.dy);
    final tuple = await ss.getServerDetails();
    final version = tuple.item4;
    final minSierra = await ss.isMinSierra;
    final minBigSur = await ss.isMinBigSur;
    if (!iOS) {
      widget.cvController.selected.add(message);
    }

    if (kIsDesktop || kIsWeb) {
      widget.cvController.showingOverlays = true;
    }
    final result = await Navigator.push(
      Get.context!,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Theme(
              data: ctx.theme.copyWith(
                // in case some components still use legacy theming
                primaryColor: ctx.theme.colorScheme.bubble(ctx, true),
                colorScheme: ctx.theme.colorScheme.copyWith(
                  primary: ctx.theme.colorScheme.bubble(ctx, true),
                  onPrimary: ctx.theme.colorScheme.onBubble(ctx, true),
                  surface: ss.settings.monetTheming.value == Monet.full ? null : (ctx.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                  onSurface: ss.settings.monetTheming.value == Monet.full ? null : (ctx.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                ),
              ),
              child: PopupScope(
                child: MessagePopup(
                  childPosition: childPos!,
                  size: size,
                  child: widget.child,
                  part: widget.part,
                  controller: widget.controller,
                  cvController: widget.cvController,
                  serverDetails: Tuple3(minSierra, minBigSur, version > 100),
                  sendTapback: sendTapback,
                  widthContext: () => mounted ? context : null,
                ),
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
      widget.cvController.showingOverlays = false;
      if (widget.cvController.editing.isEmpty) {
        widget.cvController.focusNode.requestFocus();
      }
    } else if (widget.cvController.editing.isNotEmpty) {
      // there needs to be a delay here for some random reason, otherwise the keyboard is put down again immediately
      await Future.delayed(const Duration(milliseconds: 500));
      widget.cvController.editing.first.item4.requestFocus();
    }
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
      onDoubleTap: widget.isEditing ? null
        : ss.settings.doubleTapForDetails.value || message.guid!.startsWith('temp')
        ? () => openPopup()
        : ss.settings.enableQuickTapback.value && widget.cvController.chat.isIMessage
        ? () => sendTapback(null, widget.part.part)
        : null,
      onLongPress: widget.isEditing ? null
        : ss.settings.doubleTapForDetails.value &&
        ss.settings.enableQuickTapback.value &&
        widget.cvController.chat.isIMessage &&
        !message.guid!.startsWith('temp')
        ? () => sendTapback(null, widget.part.part)
        : () => openPopup(),
      onSecondaryTapUp: widget.isEditing ? null : (details) async {
        if (!kIsWeb && !kIsDesktop) return;
        if (kIsWeb) {
          (await html.document.onContextMenu.first).preventDefault();
        }
        openPopup();
      },
      child: widget.child,
    );
  }
}

class PopupScope extends InheritedWidget {
  const PopupScope({
    super.key,
    required super.child,
  });

  static PopupScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PopupScope>();
  }

  static PopupScope of(BuildContext context) {
    final PopupScope? result = maybeOf(context);
    assert(result != null, 'No ReplyScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(PopupScope oldWidget) => true;
}