import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class MessageProperties extends StatefulWidget {
  const MessageProperties({
    super.key,
    required this.part,
    this.globalKey,
  });

  final MessagePart part;
  final GlobalKey? globalKey;

  @override
  State<StatefulWidget> createState() => _MessagePropertiesState();
}

class _MessagePropertiesState extends State<MessageProperties> with ThemeHelpers {
  late MessageState _ms;
  MessageState get controller => _ms;
  late final String _chatGuid;
  Message get message => controller.message;
  MessagesService get service => MessagesSvc(_chatGuid);

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
    _chatGuid = controller.cvController?.chat.guid ?? ChatStateScope.readChatOnce(context).guid;
  }

  List<TextSpan> getProperties() {
    final properties = <TextSpan>[];
    // Collections are per-attachment for replies (native iMessage). Skip the
    // aggregate bubble-level count; open threads via per-card popup instead.
    final replyList = widget.part.isMediaCollection
        ? const <Message>[]
        : service.struct.threadsForParts(
            message.guid!,
            widget.part.attachmentPartIndices ?? [widget.part.part],
            returnOriginator: false,
          );
    if (message.expressiveSendStyleId != null) {
      final effect =
          effectMap.entries.firstWhereOrNull((element) => element.value == message.expressiveSendStyleId)?.key ??
              "unknown";
      properties.add(TextSpan(
          text: "↺ sent with $effect",
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (stringToMessageEffect[effect] == MessageEffect.echo) {
                showSnackbar("Notice", "Echo animation is not supported at this time.");
                return;
              }
              HapticFeedback.mediumImpact();
              if ((stringToMessageEffect[effect] ?? MessageEffect.none).isBubble) {
                MessageStateScope.of(context).triggerBubbleEffect(widget.part.part);
              } else if (widget.globalKey != null) {
                EventDispatcherSvc.emit('play-effect', {
                  'type': effect,
                  'size': widget.globalKey!.globalPaintBounds(context),
                });
              }
            }));
    }
    if (replyList.isNotEmpty) {
      properties.add(TextSpan(
          text: "${replyList.length} repl${replyList.length > 1 ? "ies" : "y"}",
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (controller.cvController == null) return;
              showReplyThread(context, message, widget.part, service, controller.cvController!);
            }));
    }
    if (widget.part.isEdited) {
      properties.add(TextSpan(
          text: "Edited",
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              controller.showEdits.toggle();
            }));
    }

    return properties;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Observe granular MessageState fields for thread replies and edits
      controller.associatedMessages.length;
      // Also observe showEdits since that's toggled directly
      controller.showEdits.value;

      final props = getProperties();
      return AnimatedSize(
        curve: Curves.easeInOut,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 250),
        child: props.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15).add(const EdgeInsets.only(top: 3)),
                child: Text.rich(
                  TextSpan(
                    children: intersperse(const TextSpan(text: " • "), props).toList(),
                  ),
                  style: context.theme.textTheme.labelSmall!
                      .copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              )
            : const SizedBox.shrink(),
      );
    });
  }
}
