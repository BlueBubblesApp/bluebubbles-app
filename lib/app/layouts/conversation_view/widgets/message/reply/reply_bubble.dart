import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/show_reply_thread.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReplyBubble extends CustomStateful<MessageWidgetController> {
  ReplyBubble({
    Key? key,
    required super.parentController,
    required this.part,
    required this.showAvatar,
  }) : super(key: key);

  final int part;
  final bool showAvatar;

  @override
  _ReplyBubbleState createState() => _ReplyBubbleState();
}

class _ReplyBubbleState extends CustomState<ReplyBubble, void, MessageWidgetController> {
  MessagePart get part => controller.parts[widget.part];
  Message get message => controller.message;
  Message? get olderMessage => controller.oldMwc?.message;
  Message? get newerMessage => controller.newMwc?.message;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  Color getBubbleColor() {
    Color bubbleColor = context.theme.colorScheme.properSurface;
    if (ss.settings.colorfulBubbles.value && !message.isFromMe!) {
      if (message.handle?.color == null) {
        bubbleColor = toColorGradient(message.handle?.address).first;
      } else {
        bubbleColor = HexColor(message.handle!.color!);
      }
    }
    return bubbleColor;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Transform.scale(
        scale: 0.8,
        alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            showReplyThread(context, message, ms(message.chat.target!.guid));
          },
          behavior: HitTestBehavior.opaque,
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.showAvatar)
                  ContactAvatarWidget(
                    handle: message.handle,
                    size: 30,
                    fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                    borderThickness: 0.1,
                  ),
                controller.parts.length <= widget.part ? ClipPath(
                  clipper: TailClipper(
                    isFromMe: message.isFromMe!,
                    showTail: true,
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
                      minHeight: 30,
                    ),
                    child: CustomPaint(
                      painter: TailPainter(
                        isFromMe: message.isFromMe!,
                        showTail: true,
                        color: context.theme.colorScheme.errorContainer,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
                        child: Text(
                          "Failed to parse thread parts!",
                          style: (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
                            color: context.theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ) : message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 70),
                  child: InteractiveHolder(
                    parentController: controller,
                    message: part,
                  ),
                ) : part.attachments.isEmpty ? ClipPath(
                  clipper: TailClipper(
                    isFromMe: message.isFromMe!,
                    showTail: true,
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
                      minHeight: 30,
                    ),
                    child: CustomPaint(
                      painter: TailPainter(
                        isFromMe: message.isFromMe!,
                        showTail: true,
                        color: message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
                        child: FutureBuilder<List<InlineSpan>>(
                          future: buildEnrichedMessageSpans(
                            context,
                            part,
                            message,
                            colorOverride: (message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor()).lightenOrDarken(30),
                          ),
                          initialData: buildMessageSpans(
                            context,
                            part,
                            message,
                            colorOverride: (message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor()).lightenOrDarken(30),
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
                          }
                        ),
                      ),
                    ),
                  ),
                ) : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 70),
                  child: AttachmentHolder(
                    parentController: controller,
                    message: part,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
