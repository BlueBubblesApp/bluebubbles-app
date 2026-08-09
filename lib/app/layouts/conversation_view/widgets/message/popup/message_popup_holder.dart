import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
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
    this.galleryCurrentIndex,
  });

  final Widget child;
  final MessagePart part;
  final MessageState controller;
  final ConversationViewController cvController;
  final bool isEditing;

  /// For gallery parts: tracks which attachment is currently at the front.
  /// When set, [openPopup] scopes the popup to just the selected attachment.
  final ValueNotifier<int>? galleryCurrentIndex;

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

    // For gallery parts, scope the popup to the currently visible attachment.
    final galleryIdx = widget.galleryCurrentIndex?.value;
    final effectivePart = (galleryIdx != null && widget.part.attachments.isNotEmpty)
        ? MessagePart(
            part: widget.part.partIndexForAttachment(galleryIdx),
            attachments: [widget.part.attachments[galleryIdx]],
            shouldRedact: widget.part.shouldRedact,
            mentions: const [],
            edits: const [],
            isUnsent: widget.part.isUnsent,
          )
        : widget.part;
    final effectiveChild = (galleryIdx != null && widget.part.attachments.isNotEmpty)
        ? MessageStateScope(
            messageState: widget.controller,
            child: AttachmentHolder(
              message: effectivePart,
              transparentBackground: true,
              showCardShadow: true,
              galleryAttachments: widget.part.attachments,
            ),
          )
        : widget.child;

    // For gallery selections, recompute the size to match the actual rendered
    // height of the selected attachment (ImageViewer self-sizes to
    // dh * min(1, halfWidth / dw)). The full gallery size.height is the
    // tallest card in the fan, which may be much taller than the selected
    // image — causing the reaction picker to float too high.
    Size effectiveSize = size;
    if (galleryIdx != null && widget.part.attachments.isNotEmpty) {
      final selectedAttachment = widget.part.attachments[galleryIdx];
      final halfWidth = NavigationSvc.width(context) * 0.5;
      double attachmentHeight;
      if (selectedAttachment.hasValidSize) {
        final dw = selectedAttachment.displayWidth!.toDouble();
        final dh = selectedAttachment.displayHeight!.toDouble();
        attachmentHeight = dh * min(1.0, halfWidth / dw);
      } else {
        // No dimension metadata — use the default aspect ratio (0.78 portrait)
        attachmentHeight = halfWidth / 0.78;
      }
      effectiveSize = Size(size.width, attachmentHeight);
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
                    size: effectiveSize,
                    part: effectivePart,
                    controller: widget.controller,
                    cvController: widget.cvController,
                    serverDetails: MessagePopupServerDetails(
                        minSierra: minSierra, minBigSur: minBigSur, supportsOriginalDownload: version > 100),
                    sendTapback: sendTapback,
                    widthContext: () => mounted ? context : null,
                    child: effectiveChild,
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

  /// The part index to use for quick-tapbacks (double-tap / long-press shortcuts).
  /// For gallery parts, returns the part index of the currently visible attachment.
  int get _effectivePartIndex {
    final galleryIdx = widget.galleryCurrentIndex?.value;
    if (galleryIdx != null && widget.part.attachments.isNotEmpty) {
      return widget.part.partIndexForAttachment(galleryIdx);
    }
    return widget.part.part;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isTempMessage = widget.controller.isSending.value;
      return GestureDetector(
        key: globalKey,
        onDoubleTap: widget.isEditing
            ? null
            : SettingsSvc.settings.doubleTapForDetails.value || isTempMessage
                ? () => openPopup()
                : SettingsSvc.settings.enableQuickTapback.value && widget.cvController.chat.isIMessage
                    ? () => sendTapback(null, _effectivePartIndex)
                    : null,
        onLongPress: widget.isEditing
            ? null
            : SettingsSvc.settings.doubleTapForDetails.value &&
                    SettingsSvc.settings.enableQuickTapback.value &&
                    widget.cvController.chat.isIMessage &&
                    !isTempMessage
                ? () => sendTapback(null, _effectivePartIndex)
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
    assert(result != null, 'No ReplyScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(PopupScope oldWidget) => true;
}
