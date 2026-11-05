import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReplyBubble extends StatefulWidget {
  const ReplyBubble({
    super.key,
    required this.part,
    required this.showAvatar,
    required this.cvController,
  });

  final int part;
  final bool showAvatar;
  final ConversationViewController cvController;

  @override
  State<StatefulWidget> createState() => _ReplyBubbleState();
}

class _ReplyBubbleState extends State<ReplyBubble> with ThemeHelpers {
  late MessageState _ms;
  MessageState get controller => _ms;

  /// Resolves [widget.part] as a message-part id. Null when the part is missing —
  /// never substitutes another part.
  MessagePart? get part => controller.partById(widget.part);
  Message get message => controller.message;

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
  }

  void _openReplyThread(BuildContext context, String chatGuid, MessagePart? part) {
    if (part == null) return;
    showReplyThread(context, message, part, MessagesSvc(chatGuid), widget.cvController);
  }

  Color getBubbleColor() {
    Color bubbleColor = (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
        context.theme.colorScheme.surfaceContainerHighest;
    if (SettingsSvc.settings.colorfulBubbles.value && !message.isFromMe!) {
      final colorStr = controller.sender?.color.value;
      final address = controller.sender?.handle.address;
      if (colorStr == null) {
        bubbleColor = toColorGradient(address).first;
      } else {
        bubbleColor = HexColor(colorStr);
      }
    }
    return bubbleColor;
  }

  @override
  Widget build(BuildContext context) {
    final chatGuid = widget.cvController.chat.guid;
    final hasBackground = ChatStateScope.maybeOf(context)?.hasCustomWallpaper ?? false;
    final resolvedPart = part;
    if (!iOS) {
      String text;
      if (resolvedPart == null) {
        text = "Failed to parse thread parts!";
      } else {
        final previewMessage = Message(
          text: resolvedPart.text,
          subject: resolvedPart.subject,
          hasAttachments: resolvedPart.attachments.isNotEmpty,
        )
          ..dbAttachments.addAll(resolvedPart.attachments)
          ..mergeWith(message);
        text = previewMessage.getNotificationText();
      }
      return MouseRegion(
        cursor: MouseCursor.defer,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 30,
            minHeight: 30,
          ),
          child: GestureDetector(
            onTap: () => _openReplyThread(context, chatGuid, resolvedPart),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: hasBackground
                  ? BoxDecoration(
                      color: context.theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: controller.senderDisplayName,
                    style: context.textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w400, color: context.theme.colorScheme.outline),
                  ),
                  const TextSpan(text: "\n"),
                  TextSpan(
                    text: text,
                    style: context.textTheme.bodyMedium!.apply(fontSizeFactor: 1.15),
                  ),
                ]),
                style: context.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }

    final iOSContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: SizeTransition(
        sizeFactor: const AlwaysStoppedAnimation<double>(0.8),
        axisAlignment: 0,
        child: Align(
          alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
          child: Transform.scale(
            scale: 0.8,
            alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
            child: MouseRegion(
              cursor: MouseCursor.defer,
              child: GestureDetector(
                onTap: () => _openReplyThread(context, chatGuid, resolvedPart),
                behavior: HitTestBehavior.opaque,
                child: IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.showAvatar)
                        ContactAvatarWidget(
                          handle: message.handleRelation.target,
                          size: 30,
                          fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                          borderThickness: 0.1,
                        ),
                      ClipPath(
                        clipper: TailClipper(
                          isFromMe: message.isFromMe!,
                          showTail: true,
                          connectUpper: false,
                          connectLower: false,
                        ),
                        child: resolvedPart == null
                            ? Container(
                                color: hasBackground
                                    ? context.theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                    : null,
                                constraints: BoxConstraints(
                                  maxWidth: NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 30,
                                  minHeight: 30,
                                ),
                                child: CustomPaint(
                                  painter: TailPainter(
                                    isFromMe: message.isFromMe!,
                                    showTail: true,
                                    color: context.theme.colorScheme.errorContainer,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(
                                        EdgeInsets.only(
                                            left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
                                    child: Text(
                                      "Failed to parse thread parts!",
                                      style: (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
                                            color: context.theme.colorScheme.onErrorContainer,
                                          ),
                                    ),
                                  ),
                                ),
                              )
                            : message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive
                                ? ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 100),
                                    child: ReplyScope(
                                      child: InteractiveHolder(
                                        message: resolvedPart,
                                      ),
                                    ),
                                  )
                                : resolvedPart.attachments.isEmpty
                                    ? Container(
                                        color: hasBackground
                                            ? (message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor())
                                                .withValues(alpha: 0.4)
                                            : null,
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 30,
                                          minHeight: 30,
                                        ),
                                        child: CustomPaint(
                                          painter: TailPainter(
                                            isFromMe: message.isFromMe!,
                                            showTail: true,
                                            color: message.isFromMe!
                                                ? context.theme.colorScheme.primary
                                                : getBubbleColor(),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(
                                                EdgeInsets.only(
                                                    left: message.isFromMe! ? 0 : 10,
                                                    right: message.isFromMe! ? 10 : 0)),
                                            child: FutureBuilder<List<InlineSpan>>(
                                                future: buildEnrichedMessageSpans(
                                                  context,
                                                  resolvedPart,
                                                  message,
                                                  colorOverride: (message.isFromMe!
                                                          ? context.theme.colorScheme.primary
                                                          : getBubbleColor())
                                                      .themeLightenOrDarken(context, hasBackground ? 70 : 30),
                                                ),
                                                initialData: buildMessageSpans(
                                                  context,
                                                  resolvedPart,
                                                  message,
                                                  colorOverride: (message.isFromMe!
                                                          ? context.theme.colorScheme.primary
                                                          : getBubbleColor())
                                                      .themeLightenOrDarken(context, hasBackground ? 70 : 30),
                                                ),
                                                builder: (context, snapshot) {
                                                  if (snapshot.data != null) {
                                                    return RichText(
                                                      text: TextSpan(
                                                        children: snapshot.data!,
                                                      ),
                                                    );
                                                  }
                                                  return const SizedBox.shrink();
                                                }),
                                          ),
                                        ),
                                      )
                                    : ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 100),
                                        child: ReplyScope(
                                          child: AttachmentHolder(
                                            message: resolvedPart,
                                          ),
                                        ),
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return hasBackground ? iOSContent : Opacity(opacity: 0.6, child: iOSContent);
  }
}

class ReplyScope extends InheritedWidget {
  const ReplyScope({
    super.key,
    required super.child,
  });

  static ReplyScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ReplyScope>();
  }

  static ReplyScope of(BuildContext context) {
    final ReplyScope? result = maybeOf(context);
    assert(result != null, 'No ReplyScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ReplyScope oldWidget) => true;
}
