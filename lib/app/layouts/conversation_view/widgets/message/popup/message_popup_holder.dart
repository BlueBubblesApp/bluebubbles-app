import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/widgets/hover_reaction_bar.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/shared/message_clone_scope.dart';
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

  // Desktop hover tapback bar
  final LayerLink _hoverBarLink = LayerLink();
  final OverlayPortalController _hoverBarController = OverlayPortalController();
  Timer? _hoverBarHideTimer;
  bool _hoverBarBeside = true;
  double _hoverBarGap = 6;

  Message get message => widget.controller.message;

  @override
  void dispose() {
    _hoverBarHideTimer?.cancel();
    super.dispose();
  }

  bool get _canShowHoverBar =>
      kIsDesktop &&
      SettingsSvc.settings.desktopHoverReactions.value &&
      SettingsSvc.settings.enablePrivateAPI.value &&
      SettingsSvc.serverDetails.isMinSierra &&
      widget.cvController.chat.isIMessage &&
      !widget.isEditing &&
      !widget.controller.isSending.value &&
      !widget.controller.hasError.value &&
      !MessageCloneScope.of(context);

  /// The user's current (non-removed) tapback on the hovered part, if any.
  String? get _selfReaction {
    final part = _effectivePartIndex;
    final reactions = getUniqueReactionMessages(widget.controller.associatedMessages
        .where((e) =>
            ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")) &&
            (e.associatedMessagePart ?? 0) == part)
        .toList());
    final self = reactions.firstWhereOrNull((e) => e.isFromMe!)?.associatedMessageType;
    return (self?.contains("-") ?? true) ? null : self;
  }

  void _onHoverEnter() {
    _hoverBarHideTimer?.cancel();
    if (_hoverBarController.isShowing) return;
    if (widget.cvController.showingOverlays || widget.cvController.inSelectMode.value) return;

    final box = globalKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final bubble = box.localToGlobal(Offset.zero) & box.size;
    // Bounds of the message list, so the bar never spills over the chat list or off the window
    final listBox = Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final list = listBox != null && listBox.hasSize
        ? listBox.localToGlobal(Offset.zero) & listBox.size
        : Offset.zero & MediaQuery.sizeOf(context);

    // Leave room for the existing tapback badges, which overhang the outer top corner of the bubble
    final hasReactions = widget.controller.associatedMessages.any((e) =>
        ReactionTypes.toList().contains(e.associatedMessageType) &&
        (e.associatedMessagePart ?? 0) == _effectivePartIndex);
    _hoverBarGap = hasReactions ? 26 : 6;
    final room = message.isFromMe! ? bubble.left - list.left : list.right - bubble.right;
    _hoverBarBeside = room >= HoverReactionBar.width + _hoverBarGap + 4;
    _hoverBarController.show();
  }

  void _onHoverExit() {
    _hoverBarHideTimer?.cancel();
    // Grace period so the pointer can travel from the bubble to the bar
    _hoverBarHideTimer = Timer(const Duration(milliseconds: 250), _hideHoverBar);
  }

  void _hideHoverBar() {
    _hoverBarHideTimer?.cancel();
    if (mounted && _hoverBarController.isShowing) _hoverBarController.hide();
  }

  Widget _buildHoverBar(BuildContext context) {
    final isFromMe = message.isFromMe!;
    final Alignment targetAnchor;
    final Alignment followerAnchor;
    final Offset offset;
    if (_hoverBarBeside) {
      // Bottom-aligned beside the bubble, on the side facing the middle of the chat
      targetAnchor = isFromMe ? Alignment.bottomLeft : Alignment.bottomRight;
      followerAnchor = isFromMe ? Alignment.bottomRight : Alignment.bottomLeft;
      offset = Offset(isFromMe ? -_hoverBarGap : _hoverBarGap, 0);
    } else {
      // Not enough room beside a wide bubble: sit just above it, away from the tapback badges
      targetAnchor = isFromMe ? Alignment.topRight : Alignment.topLeft;
      followerAnchor = isFromMe ? Alignment.bottomRight : Alignment.bottomLeft;
      offset = const Offset(0, 2);
    }
    return CompositedTransformFollower(
      link: _hoverBarLink,
      showWhenUnlinked: false,
      targetAnchor: targetAnchor,
      followerAnchor: followerAnchor,
      offset: offset,
      child: Align(
        alignment: followerAnchor,
        child: MouseRegion(
          onEnter: (_) => _hoverBarHideTimer?.cancel(),
          onExit: (_) => _onHoverExit(),
          child: Obx(() {
            // Reads the observable tapback list, so the user's current one stays highlighted
            final selfReaction = _selfReaction;
            return HoverReactionBar(
              selfReaction: selfReaction,
              onReact: (reaction) {
                _hideHoverBar();
                sendTapback(selfReaction == reaction ? "-$reaction" : reaction, _effectivePartIndex);
              },
              onMore: () {
                _hideHoverBar();
                openPopup();
              },
            );
          }),
        ),
      ),
    );
  }

  void openPopup() async {
    _hideHoverBar();
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
      final detector = GestureDetector(
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
      if (!kIsDesktop) return detector;

      final canShowHoverBar = _canShowHoverBar;
      if (!canShowHoverBar && _hoverBarController.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _hideHoverBar());
      }
      return CompositedTransformTarget(
        link: _hoverBarLink,
        child: OverlayPortal(
          controller: _hoverBarController,
          overlayChildBuilder: _buildHoverBar,
          child: MouseRegion(
            onEnter: canShowHoverBar ? (_) => _onHoverEnter() : null,
            onExit: (_) => _onHoverExit(),
            child: detector,
          ),
        ),
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
