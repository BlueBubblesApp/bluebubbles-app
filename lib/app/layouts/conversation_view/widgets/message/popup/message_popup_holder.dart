import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class MessagePopupHolder extends StatefulWidget {
  const MessagePopupHolder({
    super.key,
    required this.child,
    required this.part,
    required this.controller,
    required this.cvController,
    required this.isEditing,
    this.enableGestures = true,
  });

  final Widget child;
  final MessagePart part;
  final MessageState controller;
  final ConversationViewController cvController;
  final bool isEditing;

  /// When false, skips the [GestureDetector] and passes [child] through unchanged.
  /// Used when deferring gestures to a descendant (e.g. collection cards).
  final bool enableGestures;

  @override
  State<StatefulWidget> createState() => _MessagePopupHolderState();
}

class _MessagePopupHolderState extends State<MessagePopupHolder> with ThemeHelpers {
  final GlobalKey globalKey = GlobalKey();

  Message get message => widget.controller.message;

  void openPopup() async {
    HapticFeedback.lightImpact();
    final size = globalKey.currentContext?.size;
    Offset? childPos = (globalKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
    widget.cvController.focusNode.unfocus();
    widget.cvController.subjectFocusNode.unfocus();
    if (size == null || childPos == null) return;
    childPos = Offset(
        childPos.dx -
            MediaQueryData.fromView(View.of(context)).padding.left -
            (iOS ? 0 : NavigationSvc.widthChatListLeft(context)),
        childPos.dy);
    final serverDetails = SettingsSvc.serverDetails;
    final version = serverDetails.serverVersionCode;
    final minSierra = serverDetails.isMinSierra;
    final minBigSur = serverDetails.isMinBigSur;
    if (!iOS) {
      widget.cvController.selected.add(message);
    }

    if (kIsDesktop || kIsWeb) {
      widget.cvController.showingOverlays = true;
    }
    final chatState = ChatStateScope.of(context);
    // Capture the conversation's theme before pushing the route — if adaptive
    // theming is active, context.theme is already the per-chat theme.
    final capturedTheme = context.theme;
    final capturedIsM3 = ThemeSvc.isMaterialYouActive(context);
    final capturedBubbleExt = capturedTheme.extensions[BubbleColors] as BubbleColors?;
    final result = await Navigator.push(
      iOS ? Get.context! : context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Theme(
              data: capturedTheme.copyWith(
                // in case some components still use legacy theming
                primaryColor: capturedBubbleExt?.iMessageBubbleColor ?? capturedTheme.colorScheme.primary,
                colorScheme: capturedTheme.colorScheme.copyWith(
                  primary: capturedBubbleExt?.iMessageBubbleColor ?? capturedTheme.colorScheme.primary,
                  onPrimary: capturedBubbleExt?.oniMessageBubbleColor ?? capturedTheme.colorScheme.onPrimary,
                  surface: capturedIsM3 ? null : capturedBubbleExt?.receivedBubbleColor,
                  onSurface: capturedIsM3 ? null : capturedBubbleExt?.onReceivedBubbleColor,
                ),
              ),
              child: ChatStateScope(
                chatState: chatState,
                child: PopupScope(
                  child: MessagePopup(
                    childPosition: childPos!,
                    size: size,
                    part: widget.part,
                    controller: widget.controller,
                    cvController: widget.cvController,
                    serverDetails: MessagePopupServerDetails(
                        minSierra: minSierra, minBigSur: minBigSur, supportsOriginalDownload: version > 100),
                    sendTapback: sendTapback,
                    widthContext: () => mounted ? context : null,
                    child: widget.child,
                  ),
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
      } else {
        // This delay is necessary because there is a second instance of the focus node in the popup which gets focused otherwise
        // The autofocus doesn't seem to work on desktop
        Future.delayed(const Duration(milliseconds: 500),
            () => widget.cvController.editing.last.controller.focusNode?.requestFocus());
      }
    }
  }

  void sendTapback([String? type, int? part]) {
    HapticFeedback.lightImpact();
    final reaction = type ?? SettingsSvc.settings.quickTapbackType.value;
    Logger.info("Sending reaction type: $reaction");

    final tempMessage = Message(
      associatedMessageGuid: message.guid,
      associatedMessageType: reaction,
      associatedMessagePart: part,
      dateCreated: DateTime.now(),
      hasAttachments: false,
      isFromMe: true,
      handleId: 0,
    );

    Logger.debug("[sendTapback] Creating temp reaction: type=$reaction, parent=${message.guid}",
        tag: "MessageReactivity");

    OutgoingMsgHandler.queue(
      OutgoingReaction(
        chat: message.chat.target ?? ChatStateScope.chatOf(context),
        message: tempMessage,
        selectedMessage: message,
        reaction: reaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableGestures) return widget.child;

    return Obx(() {
      final isTempMessage = widget.controller.isSending.value;
      return GestureDetector(
        key: globalKey,
        onDoubleTap: widget.isEditing
            ? null
            : SettingsSvc.settings.doubleTapForDetails.value || isTempMessage
                ? () => openPopup()
                : SettingsSvc.settings.enableQuickTapback.value && widget.cvController.chat.isIMessage
                    ? () => sendTapback(null, widget.part.part)
                    : null,
        onLongPress: widget.isEditing
            ? null
            : SettingsSvc.settings.doubleTapForDetails.value &&
                    SettingsSvc.settings.enableQuickTapback.value &&
                    widget.cvController.chat.isIMessage &&
                    !isTempMessage
                ? () => sendTapback(null, widget.part.part)
                : () => openPopup(),
        onSecondaryTapUp: widget.isEditing
            ? null
            : (details) async {
                if (!kIsWeb && !kIsDesktop) return;
                if (kIsWeb) {
                  (await html.document.onContextMenu.first).preventDefault();
                }
                openPopup();
              },
        child: widget.child,
      );
    });
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
    assert(result != null, 'No PopupScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(PopupScope oldWidget) => true;
}
