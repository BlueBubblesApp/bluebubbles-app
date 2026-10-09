import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/widgets/reaction_details.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/shared/message_error_helper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class ReactionWidget extends StatefulWidget {
  const ReactionWidget({
    super.key,
    required this.reaction,
    this.reactions,
    this.chatGuid,
    this.tailDirection,
    this.tailType = ReactionTailType.standard,
  });

  final Message reaction;
  final List<Message>? reactions;

  /// Explicit chat GUID used when outside a [MessageStateScope] (e.g. pinned tile context).
  /// Allows [ReactionWidgetState] to resolve MessageState from the correct
  /// MessagesService rather than falling back to [ChatsSvc.activeChat].
  final String? chatGuid;

  /// When set, overrides the computed tail direction for the reaction clippers.
  /// Useful in contexts with no [MessageStateScope] (e.g. pinned tiles) where
  /// the fallback would produce the wrong arc orientation.
  /// Bubble coloring is always driven by the reaction's own [isFromMe] field.
  final ReactionTailDirection? tailDirection;

  final ReactionTailType tailType;

  @override
  ReactionWidgetState createState() => ReactionWidgetState();
}

class ReactionWidgetState extends State<ReactionWidget> with ThemeHelpers {
  List<Message>? get reactions => widget.reactions;

  /// Parent [Message] resolved live from the nearest [MessageStateScope].
  /// Returns null when outside a scope (e.g. pinned-tile context).
  Message? get _parentMessage => MessageStateScope.maybeOf(context)?.message;

  // Observe the reaction from parent message's associatedMessages list
  // This is already an RxList in MessageState, so changes propagate automatically
  Message get reaction {
    // Resolution order:
    //  1. widget.chatGuid – explicitly provided (e.g. from a pinned tile)
    //  2. parent message's chat relation – used in conversation view
    //  3. ChatsSvc.activeChat – last-resort fallback
    final chatGuid = widget.chatGuid ?? _parentMessage?.chat.target?.guid ?? ChatsSvc.activeChat?.chat.guid;
    final parentController =
        chatGuid != null ? maybeFindMessagesSvc(chatGuid)?.getMessageStateIfExists(_parentMessage?.guid ?? '') : null;
    if (parentController != null) {
      // Find our reaction in the observable associatedMessages list
      final found = parentController.associatedMessages.firstWhereOrNull((m) =>
          m.guid == widget.reaction.guid ||
          (m.associatedMessageType == widget.reaction.associatedMessageType &&
              m.associatedMessagePart == widget.reaction.associatedMessagePart &&
              m.isFromMe == widget.reaction.isFromMe));
      if (found != null) return found;
    }
    // Fallback to widget.reaction if not found in MessageState
    return widget.reaction;
  }

  /// Guard against isFromMe being null on partially-hydrated messages.
  bool get reactionIsFromMe => reaction.isFromMe ?? false;
  bool get messageIsFromMe => _parentMessage?.isFromMe ?? true;

  /// Effective tail direction for the clippers.
  /// Matches the [messageIsFromMe] semantics: sent (right) vs received (left).
  /// Can be overridden via [widget.tailDirection] (e.g. pinned tile context).
  ReactionTailDirection get _effectiveTailDirection =>
      widget.tailDirection ?? (messageIsFromMe ? ReactionTailDirection.left : ReactionTailDirection.right);

  /// Layout follows [_effectiveTailDirection] so icon + clip stay consistent.
  bool get _alignToEnd => _effectiveTailDirection == ReactionTailDirection.left;

  /// Guard against associatedMessageType being null.
  /// An empty string produces no SVG match, which is handled in build().
  String get reactionType => reaction.associatedMessageType ?? '';

  MessageState? get reactionController {
    // Use same resolution order as reaction getter
    final chatGuid = widget.chatGuid ?? _parentMessage?.chat.target?.guid ?? ChatsSvc.activeChat?.chat.guid;
    if (chatGuid == null || reaction.guid == null) return null;
    return maybeFindMessagesSvc(chatGuid)?.getMessageStateIfExists(reaction.guid!);
  }

  static const double iosSize = 35;

  /// Inside tails extend ~5px past [iosSize] on y.
  static const double iosClipHeight = 40;

  double get _clipHeight => widget.tailType == ReactionTailType.inside ? iosClipHeight : iosSize;

  @override
  Widget build(BuildContext context) {
    // When there is no parent message (e.g. pinned-tile context), there is no
    // MessageState or MessageWidgetController to observe.  Wrapping in Obx with
    // no observables causes GetX to emit "improper use" and suppresses the render.
    // Use a plain Builder for this case so we just render the reaction statically.
    if (_parentMessage == null) {
      return _buildStatic(context, widget.reaction);
    }

    // Full conversation-view path: wrap in Obx so we reactively follow any
    // changes to the parent's associatedMessages RxList (e.g. temp→real GUID).
    return Obx(() {
      // Reading `reaction` subscribes to MessageState.associatedMessages so the
      // widget rebuilds when the reaction changes (temp→real GUID, error state…).
      final _ = reaction;

      // Guard: if the reaction type is unknown we cannot render the SVG asset safely.
      if (reactionType.isEmpty) return const SizedBox.shrink();

      if (SettingsSvc.settings.skin.value != Skins.iOS) {
        return Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: reactionIsFromMe
                  ? context.theme.colorScheme.primary
                  : ((context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
                      context.theme.colorScheme.surfaceContainerHighest),
              border: Border.all(color: context.theme.colorScheme.surface),
              shape: BoxShape.circle,
            ),
            child: GestureDetector(
              onTap: () {
                if (reactions == null) return;
                // Capture the conversation's theme before pushing \u2014 if adaptive
                // theming is active, context.theme is already the per-chat theme.
                final capturedTheme = context.theme;
                final capturedIsM3 = ThemeSvc.isMaterialYouActive(context);
                final capturedBubbleExt = capturedTheme.extensions[BubbleColors] as BubbleColors?;
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (routeCtx, animation, secondaryAnimation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 1.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                        child: Theme(
                          data: capturedTheme.copyWith(
                            // in case some components still use legacy theming
                            primaryColor: capturedBubbleExt?.iMessageBubbleColor ?? capturedTheme.colorScheme.primary,
                            colorScheme: capturedTheme.colorScheme.copyWith(
                              primary: capturedBubbleExt?.iMessageBubbleColor ?? capturedTheme.colorScheme.primary,
                              onPrimary:
                                  capturedBubbleExt?.oniMessageBubbleColor ?? capturedTheme.colorScheme.onPrimary,
                              surface: capturedIsM3 ? null : capturedBubbleExt?.receivedBubbleColor,
                              onSurface: capturedIsM3 ? null : capturedBubbleExt?.onReceivedBubbleColor,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(routeCtx).pop();
                                },
                              ),
                              Positioned(
                                  bottom: 10, left: 15, right: 15, child: ReactionDetails(reactions: reactions!)),
                            ],
                          ),
                        ),
                      );
                    },
                    fullscreenDialog: true,
                    opaque: false,
                    barrierDismissible: true,
                  ),
                );
              },
              child: Center(
                child: Builder(builder: (context) {
                  final text = Text(
                    ReactionTypes.reactionToEmoji[reactionType] ?? "X",
                    style: const TextStyle(fontSize: 15, fontFamily: 'Apple Color Emoji'),
                    textAlign: TextAlign.center,
                  );
                  // rotate thumbs down to match iOS
                  if (reactionType == "dislike") {
                    return Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: FractionalOffset.center,
                      child: text,
                    );
                  }
                  return text;
                }),
              ),
            ));
      }
      return Stack(
        alignment: _alignToEnd ? Alignment.centerRight : Alignment.centerLeft,
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -1,
            left: _alignToEnd ? 0 : -1,
            right: !_alignToEnd ? 0 : -1,
            child: ClipPath(
              clipper: ReactionBorderClipper(
                tailDirection: _effectiveTailDirection,
                tailType: widget.tailType,
              ),
              child: Container(
                width: iosSize + 2,
                height: _clipHeight + 2,
                color: context.theme.colorScheme.surface,
              ),
            ),
          ),
          ClipPath(
              clipper: ReactionClipper(
                tailDirection: _effectiveTailDirection,
                tailType: widget.tailType,
              ),
              child: Obx(() {
                // reactionController is null when no MessageState exists for the reaction (typical).
                // Fall back to checking the GUID prefix so temp reactions always show as pending.
                final isSending = reactionController?.isSending.value ??
                    (reaction.guid?.startsWith('temp') == true && reaction.error == 0);
                return Container(
                    width: iosSize,
                    height: _clipHeight,
                    color: reactionIsFromMe
                        ? context.theme.colorScheme.primary.darkenAmount(isSending ? 0.2 : 0)
                        : ((context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
                            context.theme.colorScheme.surfaceContainerHighest),
                    alignment: _alignToEnd ? Alignment.topRight : Alignment.topLeft,
                    child: SizedBox(
                      width: iosSize * 0.8,
                      height: iosSize * 0.8,
                      child: Center(
                          child: Padding(
                        padding:
                            const EdgeInsets.all(6.5).add(EdgeInsets.only(right: reactionType == "emphasize" ? 1 : 0)),
                        child: SvgPicture.asset(
                          'assets/reactions/$reactionType-black.svg',
                          colorFilter: ColorFilter.mode(
                              reactionType == "love"
                                  ? Colors.pink
                                  : (reactionIsFromMe
                                      ? context.theme.colorScheme.onPrimary
                                      : context.theme.colorScheme.onSurfaceVariant),
                              BlendMode.srcIn),
                        ),
                      )),
                    ));
              })),
          Positioned(
            left: !_alignToEnd ? 0 : -75,
            right: _alignToEnd ? 0 : -75,
            child: Obx(() {
              final hasError = reactionController?.hasError.value ?? false;
              if (reaction.error > 0 || hasError) {
                final errorCode = reaction.error;
                final errorText = ErrorHelper.getErrorText(reaction);

                return DeferPointer(
                  child: GestureDetector(
                    child: Icon(
                      SettingsSvc.settings.skin.value == Skins.iOS
                          ? CupertinoIcons.exclamationmark_circle
                          : Icons.error_outline,
                      color: context.theme.colorScheme.error,
                    ),
                    onTap: () {
                      final chat = ChatStateScope.maybeChatOf(context) ??
                          ChatsSvc.getChatState(widget.chatGuid ?? _parentMessage?.chat.target?.guid ?? '')?.chat ??
                          ChatsSvc.activeChat!.chat;
                      final selected = maybeFindMessagesSvc(chat.guid)
                              ?.getMessageStateIfExists(reaction.associatedMessageGuid!)
                              ?.message ??
                          _parentMessage;
                      if (selected == null) return;

                      showDialog(
                        context: context,
                        builder: (BuildContext context) => MessageErrorDialog(
                          errorCode: errorCode,
                          errorText: errorText,
                          chatId: chat.id!,
                          onRetry: () => retryReaction(
                            reaction: reaction,
                            chat: chat,
                            selected: selected,
                          ),
                          onRemove: () => removeReaction(
                            reaction: reaction,
                            chat: chat,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          )
        ],
      );
    }); // Close outer Obx
  }

  /// Static (non-reactive) render used when there is no parent [message]
  /// (e.g. pinned-tile context).  Reads straight from [reaction] without
  /// subscribing to any RxList so GetX never fires the "improper use" warning.
  Widget _buildStatic(BuildContext context, Message reaction) {
    final rType = reaction.associatedMessageType ?? '';
    final isFromMe = reaction.isFromMe ?? false;
    final tailDirection = widget.tailDirection ?? (isFromMe ? ReactionTailDirection.left : ReactionTailDirection.right);
    final tailIsRight = tailDirection == ReactionTailDirection.right;

    if (rType.isEmpty) return const SizedBox.shrink();

    if (SettingsSvc.settings.skin.value != Skins.iOS) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isFromMe
              ? context.theme.colorScheme.primary
              : ((context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
                  context.theme.colorScheme.surfaceContainerHighest),
          border: Border.all(color: context.theme.colorScheme.surface),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Builder(builder: (ctx) {
            final text = Text(
              ReactionTypes.reactionToEmoji[rType] ?? "X",
              style: const TextStyle(fontSize: 15, fontFamily: 'Apple Color Emoji'),
              textAlign: TextAlign.center,
            );
            if (rType == "dislike") {
              return Transform(
                transform: Matrix4.identity()..rotateY(pi),
                alignment: FractionalOffset.center,
                child: text,
              );
            }
            return text;
          }),
        ),
      );
    }

    // iOS skin — the pinned tile only shows reactions received (isFromMe==false).
    // Use isFromMe to orient the clipper correctly.
    // Shadow wraps outside the ClipPath so it is not clipped.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: !tailIsRight ? Alignment.centerRight : Alignment.centerLeft,
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -1,
            left: !tailIsRight ? 0 : -1,
            right: tailIsRight ? 0 : -1,
            child: ClipPath(
              clipper: ReactionBorderClipper(
                tailDirection: tailDirection,
                tailType: widget.tailType,
              ),
              child: Container(
                width: iosSize + 2,
                height: _clipHeight + 2,
                color: context.theme.colorScheme.surface,
              ),
            ),
          ),
          ClipPath(
            clipper: ReactionClipper(
              tailDirection: tailDirection,
              tailType: widget.tailType,
            ),
            child: Container(
              width: iosSize,
              height: _clipHeight,
              color: isFromMe
                  ? context.theme.colorScheme.primary
                  : ((context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
                      context.theme.colorScheme.surfaceContainerHighest),
              alignment: !tailIsRight ? Alignment.topRight : Alignment.topLeft,
              child: SizedBox(
                width: iosSize * 0.8,
                height: iosSize * 0.8,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6.5).add(EdgeInsets.only(right: rType == "emphasize" ? 1 : 0)),
                    child: SvgPicture.asset(
                      'assets/reactions/$rType-black.svg',
                      colorFilter: ColorFilter.mode(
                        rType == "love"
                            ? Colors.pink
                            : (isFromMe
                                ? context.theme.colorScheme.onPrimary
                                : context.theme.colorScheme.onSurfaceVariant),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
