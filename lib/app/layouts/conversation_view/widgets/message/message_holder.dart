import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/chat_event/chat_event.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/bubble_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_properties.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_sender.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/select_checkbox.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_line_painter.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/delivered_indicator.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/message_timestamp.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/timestamp_separator.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class MessageHolder extends CustomStateful<MessageWidgetController> {
  MessageHolder({
    Key? key,
    required this.cvController,
    this.oldMessageGuid,
    this.newMessageGuid,
    required this.message,
    this.isReplyThread = false,
    this.replyPart,
  }) : super(key: key, parentController: getActiveMwc(message.guid!) ?? mwc(message));

  final Message message;
  final String? oldMessageGuid;
  final String? newMessageGuid;
  final ConversationViewController cvController;
  final bool isReplyThread;
  final int? replyPart;

  @override
  _MessageHolderState createState() => _MessageHolderState();
}

class _MessageHolderState extends CustomState<MessageHolder, void, MessageWidgetController> {
  Message get message => controller.message;
  Message? get olderMessage => controller.oldMessage;
  Message? get newerMessage => controller.newMessage;
  Message? get replyTo => message.threadOriginatorGuid == null
      ? null
      : ss.settings.repliesToPrevious.value
      ? (service.struct.getPreviousReply(message.threadOriginatorGuid!, message.guid!) ?? service.struct.getThreadOriginator(message.threadOriginatorGuid!))
      : service.struct.getThreadOriginator(message.threadOriginatorGuid!);
  Chat get chat => widget.cvController.chat;
  MessagesService get service => ms(widget.cvController.chat.guid);
  bool get canSwipeToReply => ss.settings.enablePrivateAPI.value && ss.settings.swipeToReply.value && chat.isIMessage && !widget.isReplyThread;
  bool get showSender => !message.isGroupEvent && (!message.sameSender(olderMessage) || (olderMessage?.isGroupEvent ?? false)
      || (olderMessage == null || !message.dateCreated!.isWithin(olderMessage!.dateCreated!, minutes: 30)));
  bool get showAvatar => (!iOS || chat.isGroup) && !samsung;

  List<MessagePart> messageParts = [];
  List<RxDouble> replyOffsets = [];
  List<GlobalKey> keys = [];
  bool gaveHapticFeedback = false;
  final RxBool tapped = false.obs;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
    if (widget.isReplyThread) {
      if (widget.replyPart != null) {
        messageParts = [controller.parts[widget.replyPart!]];
      } else {
        messageParts = controller.parts;
      }
    } else {
      controller.cvController = widget.cvController;
      controller.oldMessageGuid = widget.oldMessageGuid;
      controller.newMessageGuid = widget.newMessageGuid;
      buildMessageParts();
      // fallback - build from the actual message
      if (messageParts.isEmpty) {
        messageParts.addAll(message.attachments.map((e) => MessagePart(
          attachments: [e!],
          part: 0,
        )));
        if (message.fullText.isNotEmpty || message.isGroupEvent) {
          messageParts.add(MessagePart(
            subject: message.subject,
            text: message.text,
            part: 0,
          ));
        }
      }
      controller.parts = messageParts;
      replyOffsets = List.generate(messageParts.length, (_) => 0.0.obs);
      keys = List.generate(messageParts.length, (_) => GlobalKey());
    }
  }

  void buildMessageParts() {
    // go through the attributed body
    if (message.attributedBody.firstOrNull?.runs.isNotEmpty ?? false) {
      messageParts = attributedBodyToMessagePart(message.attributedBody.first);
    }
    // add edits
    if (message.messageSummaryInfo.firstOrNull?.editedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.editedParts) {
        final edits = message.messageSummaryInfo.first.editedContent[part.toString()] ?? [];
        final existingPart = messageParts.firstWhereOrNull((element) => element.part == part);
        if (existingPart != null) {
          existingPart.edits.addAll(edits
              .where((e) => e.text?.values.isNotEmpty ?? false)
              .map((e) => attributedBodyToMessagePart(e.text!.values.first).firstOrNull)
              .where((e) => e != null).map((e) => e!).toList());
          existingPart.edits.removeLast();
        }
      }
    }
    // add unsends
    if (message.messageSummaryInfo.firstOrNull?.retractedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.retractedParts) {
        messageParts.add(MessagePart(
          part: part,
          isUnsent: true,
        ));
      }
    }
    messageParts.sort((a, b) => a.part.compareTo(b.part));
  }

  List<MessagePart> attributedBodyToMessagePart(AttributedBody body) {
    final mainString = body.string;
    final list = <MessagePart>[];
    body.runs.forEachIndexed((i, e) {
      if (e.attributes?.messagePart == null) return;
      final existingPart = list.firstWhereOrNull((element) => element.part == e.attributes!.messagePart!);
      // this should only happen if there is a mention in the middle breaking up the text
      if (existingPart != null) {
        final newText = mainString.substring(e.range.first, e.range.first + e.range.last);
        existingPart.text = (existingPart.text ?? "") + newText;
        if (e.hasMention) {
          existingPart.mentions.add(Mention(
            mentionedAddress: e.attributes?.mention,
            range: [existingPart.text!.indexOf(newText), existingPart.text!.indexOf(newText) + e.range.last],
          ));
          existingPart.mentions.sort((a, b) => a.range.first.compareTo(b.range.first));
        }
      } else {
        list.add(MessagePart(
          subject: i == 0 ? message.subject : null,
          text: e.isAttachment ? null : mainString.substring(e.range.first, e.range.first + e.range.last),
          attachments: e.isAttachment ? [
            service.struct.getAttachment(e.attributes!.attachmentGuid!) ?? Attachment.findOne(e.attributes!.attachmentGuid!)
          ].where((e) => e != null).map((e) => e!).toList() : [],
          mentions: !e.hasMention ? [] : [Mention(
            mentionedAddress: e.attributes?.mention,
            range: [0, e.range.last],
          )],
          part: e.attributes!.messagePart!,
        ));
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final stickers = message.associatedMessages.where((e) => e.associatedMessageType == "sticker");
    final reactions = message.associatedMessages.where((e) => ReactionTypes.toList().contains(e.associatedMessageType));
    /// Layout tree
    /// - Timestamp
    /// - Stack (see code comment)
    ///    - avatar | message row
    ///                - spacing (for avatar) | message column | message timestamp
    ///                                          - message part column
    ///                                             - message sender
    ///                                             - reaction spacing box
    ///                                             - previous edits
    ///                                             - message content row
    ///                                                - text / attachment / chat event / interactive | slide to reply
    ///                                                   |-> stack: stickers & reactions
    ///                                             - message properties
    ///                                          - delivered indicator
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: message.guid!.contains("temp") ? EdgeInsets.zero : EdgeInsets.only(
        top: olderMessage != null && !message.sameSender(olderMessage!) ? 5.0 : 0,
        bottom: newerMessage != null && !message.sameSender(newerMessage!) ? 5.0 : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // large timestamp between messages
          TimestampSeparator(olderMessage: olderMessage, message: message),
          // use stack so avatar can be placed at bottom
          Row(
            children: [
              if (!message.isFromMe! && !message.isGroupEvent)
                SelectCheckbox(message: message, controller: widget.cvController),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // message column
                    ...messageParts.mapIndexed((index, e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // add previous edits if needed
                          if (e.isEdited)
                            Padding(
                              padding: showAvatar || ss.settings.alwaysShowAvatars.value
                                  ? const EdgeInsets.only(left: 35.0) : EdgeInsets.zero,
                              child: Obx(() => AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                alignment: Alignment.bottomCenter,
                                curve: controller.showEdits.value ? Curves.easeOutBack : Curves.easeOut,
                                child: controller.showEdits.value ? Opacity(
                                  opacity: 0.75,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: e.edits.map((edit) => ClipPath(
                                      clipper: TailClipper(
                                        isFromMe: message.isFromMe!,
                                        showTail: message.showTail(newerMessage) && e.part == controller.parts.length - 1,
                                        connectLower: iOS ? false : (e.part != 0 && e.part != controller.parts.length - 1)
                                            || (e.part == 0 && controller.parts.length > 1),
                                        connectUpper: iOS ? false : e.part != 0,
                                      ),
                                      child: TextBubble(
                                        parentController: controller,
                                        message: edit,
                                      ),
                                    )).toList(),
                                  ),
                                ) : Container(
                                  height: 0,
                                  constraints: BoxConstraints(
                                    maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30
                                )),
                              )),
                            ),
                          if (iOS && index == 0 && !widget.isReplyThread
                              && olderMessage != null
                              && message.threadOriginatorGuid != null
                              && message.showUpperMessage(olderMessage!)
                              && replyTo != null
                              && getActiveMwc(replyTo!.guid!) != null)
                            Padding(
                              padding: EdgeInsets.only(left: (showAvatar || ss.settings.alwaysShowAvatars.value) && replyTo!.isFromMe! ? 35 : 0),
                              child: DecoratedBox(
                                decoration: replyTo!.isFromMe == message.isFromMe ? ReplyLineDecoration(
                                  isFromMe: message.isFromMe!,
                                  color: context.theme.colorScheme.properSurface,
                                  connectUpper: false,
                                  connectLower: true,
                                  context: context,
                                ) : const BoxDecoration(),
                                child: Container(
                                  width: double.infinity,
                                  alignment: replyTo!.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                                  child: ReplyBubble(
                                    parentController: getActiveMwc(replyTo!.guid!)!,
                                    part: replyTo!.guid! == message.threadOriginatorGuid ? message.normalizedThreadPart : 0,
                                    showAvatar: (chat.isGroup || ss.settings.alwaysShowAvatars.value || !iOS) && !replyTo!.isFromMe!,
                                  ),
                                ),
                              ),
                            ),
                          // show sender, if needed
                          if (chat.isGroup
                              && !message.isFromMe!
                              && showSender
                              && e.part == (messageParts.firstWhereOrNull((e) => !e.isUnsent)?.part))
                            Padding(
                              padding: showAvatar || ss.settings.alwaysShowAvatars.value
                                  ? const EdgeInsets.only(left: 35.0) : EdgeInsets.zero,
                              child: MessageSender(olderMessage: olderMessage, message: message),
                            ),
                          // add a box to account for height of reactions
                          if (reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part).isNotEmpty)
                            const SizedBox(height: 12.5),
                          if (!iOS && index == 0 && !widget.isReplyThread
                              && olderMessage != null
                              && message.threadOriginatorGuid != null
                              && message.showUpperMessage(olderMessage!)
                              && replyTo != null
                              && getActiveMwc(replyTo!.guid!) != null)
                            Padding(
                              padding: showAvatar || ss.settings.alwaysShowAvatars.value
                                  ? const EdgeInsets.only(left: 45.0, right: 10) : const EdgeInsets.symmetric(horizontal: 10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.fromBorderSide(BorderSide(color: context.theme.colorScheme.properSurface)),
                                ),
                                child: ReplyBubble(
                                  parentController: getActiveMwc(replyTo!.guid!)!,
                                  part: replyTo!.guid! == message.threadOriginatorGuid ? message.normalizedThreadPart : 0,
                                  showAvatar: (chat.isGroup || ss.settings.alwaysShowAvatars.value || !iOS)
                                      && !replyTo!.isFromMe!,
                                ),
                              ),
                            ),
                          Stack(
                            alignment: Alignment.bottomLeft,
                            children: [
                              // avatar, if needed
                              if (message.showTail(newerMessage)
                                  && e.part == controller.parts.length - 1
                                  && (showAvatar || ss.settings.alwaysShowAvatars.value)
                                  && !message.isFromMe! && !message.isGroupEvent)
                                Padding(
                                  padding: const EdgeInsets.only(left: 5.0),
                                  child: ContactAvatarWidget(
                                    handle: message.handle,
                                    size: iOS ? 30 : 35,
                                    fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                                    borderThickness: 0.1,
                                  ),
                                ),
                              Padding(
                                padding: showAvatar || ss.settings.alwaysShowAvatars.value
                                    ? const EdgeInsets.only(left: 35.0) : EdgeInsets.zero,
                                child: DecoratedBox(
                                  decoration: iOS && !widget.isReplyThread && ((index == 0 && message.threadOriginatorGuid != null && olderMessage != null)
                                      || (index == messageParts.length - 1 && service.struct.threads(message.guid!).isNotEmpty && newerMessage != null))
                                      ? ReplyLineDecoration(
                                    isFromMe: message.isFromMe!,
                                    color: context.theme.colorScheme.properSurface,
                                    connectUpper: message.connectToUpper(),
                                    connectLower: newerMessage != null && message.connectToLower(newerMessage!),
                                    context: context,
                                  ) : const BoxDecoration(),
                                  child: Obx(() => GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: widget.cvController.inSelectMode.value ? () {
                                      if (widget.cvController.isSelected(message.guid!)) {
                                        widget.cvController.selected.remove(message);
                                      } else {
                                        widget.cvController.selected.add(message);
                                      }
                                    } : kIsDesktop || kIsWeb || material ? () => tapped.value = !tapped.value : null,
                                    child: IgnorePointer(
                                      ignoring: widget.cvController.inSelectMode.value,
                                      child: Container(
                                        width: double.infinity,
                                        alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // show group event
                                            if (message.isGroupEvent || e.isUnsent)
                                              ChatEvent(
                                                part: e,
                                                message: message,
                                              ),
                                            if (samsung)
                                              Padding(
                                                padding: reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part).isNotEmpty
                                                    ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 20 : 0)
                                                    : const EdgeInsets.only(right: 10),
                                                child: MessageTimestamp(controller: controller, cvController: widget.cvController),
                                              ),
                                            // otherwise show content
                                            if (!message.isGroupEvent && !e.isUnsent)
                                              Stack(
                                                alignment: Alignment.center,
                                                fit: StackFit.loose,
                                                clipBehavior: Clip.none,
                                                children: [
                                                  // actual message content
                                                  BubbleEffects(
                                                    message: message,
                                                    part: index,
                                                    globalKey: keys.length > index ? keys[index] : null,
                                                    showTail: message.showTail(newerMessage) && e.part == controller.parts.length - 1,
                                                    child: MessagePopupHolder(
                                                      key: keys.length > index ? keys[index] : null,
                                                      controller: controller,
                                                      cvController: widget.cvController,
                                                      part: e,
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.deferToChild,
                                                        onHorizontalDragUpdate: !canSwipeToReply ? null : (details) {
                                                          final offset = replyOffsets[index];
                                                          offset.value += details.delta.dx * 0.5;
                                                          if (message.isFromMe!) {
                                                            offset.value = offset.value.clamp(-double.infinity, 0);
                                                          } else {
                                                            offset.value = offset.value.clamp(0, double.infinity);
                                                          }
                                                          if (!gaveHapticFeedback && offset.value.abs() >= SlideToReply.replyThreshold) {
                                                            HapticFeedback.lightImpact();
                                                            gaveHapticFeedback = true;
                                                          } else if (offset.value.abs() < SlideToReply.replyThreshold) {
                                                            gaveHapticFeedback = false;
                                                          }
                                                        },
                                                        onHorizontalDragEnd: !canSwipeToReply ? null : (details) {
                                                          final offset = replyOffsets[index];
                                                          if (offset.value.abs() >= SlideToReply.replyThreshold) {
                                                            widget.cvController.replyToMessage = Tuple2(message, index);
                                                          }
                                                          offset.value = 0;
                                                        },
                                                        onHorizontalDragCancel: !canSwipeToReply ? null : () {
                                                          replyOffsets[index].value = 0;
                                                        },
                                                        child: ClipPath(
                                                          clipper: TailClipper(
                                                            isFromMe: message.isFromMe!,
                                                            showTail: message.showTail(newerMessage) && e.part == controller.parts.length - 1,
                                                            connectLower: iOS ? false : (e.part != 0 && e.part != controller.parts.length - 1)
                                                                || (e.part == 0 && controller.parts.length > 1),
                                                            connectUpper: iOS ? false : e.part != 0,
                                                          ),
                                                          child: message.hasApplePayloadData
                                                              || message.isLegacyUrlPreview
                                                              || message.isInteractive ? InteractiveHolder(
                                                            parentController: controller,
                                                            message: e,
                                                          ) : e.attachments.isEmpty
                                                              && (e.text != null || e.subject != null) ? TextBubble(
                                                            parentController: controller,
                                                            message: e,
                                                          ) : e.attachments.isNotEmpty ? AttachmentHolder(
                                                            parentController: controller,
                                                            message: e,
                                                          ) : const SizedBox.shrink(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // show stickers on top
                                                  StickerHolder(stickerMessages: stickers.where((s) => (s.associatedMessagePart ?? 0) == e.part)),
                                                  // show reactions on top
                                                  if (message.isFromMe!)
                                                    Positioned(
                                                      top: -15,
                                                      left: -20,
                                                      child: ReactionHolder(
                                                        reactions: reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part),
                                                        message: message,
                                                      ),
                                                    ),
                                                  if (!message.isFromMe!)
                                                    Positioned(
                                                      top: -15,
                                                      right: -20,
                                                      child: ReactionHolder(
                                                        reactions: reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part),
                                                        message: message,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            // swipe to reply
                                            if (canSwipeToReply && !message.isGroupEvent && !e.isUnsent)
                                              Obx(() => SlideToReply(width: replyOffsets[index].value.abs(), isFromMe: message.isFromMe!)),
                                          ].conditionalReverse(message.isFromMe!),
                                        ),
                                      ),
                                    ),
                                  ),
                                )),
                              ),
                            ],
                          ),
                          // message properties (replies, edits, effect)
                          Padding(
                            padding: showAvatar || ss.settings.alwaysShowAvatars.value
                                ? const EdgeInsets.only(left: 35.0) : EdgeInsets.zero,
                            child: MessageProperties(
                              globalKey: keys.length > index ? keys[index] : null,
                              parentController: controller,
                              part: e
                            ),
                          ),
                        ],
                      ),
                    )),
                    // delivered / read receipt
                    Obx(() => DeliveredIndicator(parentController: controller, forceShow: tapped.value)),
                  ],
                ),
              ),
              if (message.isFromMe! && !message.isGroupEvent)
                SelectCheckbox(message: message, controller: widget.cvController),
              Obx(() {
                if (message.error > 0 || message.guid!.startsWith("error-")) {
                  int errorCode = message.error;
                  String errorText = "An unknown internal error occurred.";
                  if (errorCode == 22) {
                    errorText = "The recipient is not registered with iMessage!";
                  } else if (message.guid!.startsWith("error-")) {
                    errorText = message.guid!.split('-')[1];
                  }

                  return IconButton(
                    icon: Icon(
                      iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
                      color: context.theme.colorScheme.error,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: context.theme.colorScheme.properSurface,
                            title: Text("Message failed to send", style: context.theme.textTheme.titleLarge),
                            content: Text("Error ($errorCode): $errorText", style: context.theme.textTheme.bodyLarge),
                            actions: <Widget>[
                              TextButton(
                                child: Text(
                                  "Retry",
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)
                                ),
                                onPressed: () async {
                                  // Remove the original message and notification
                                  Navigator.of(context).pop();
                                  service.removeMessage(message);
                                  Message.delete(message.guid!);
                                  await notif.clearFailedToSend();
                                  // Re-send
                                  message.id = null;
                                  message.error = 0;
                                  message.dateCreated = DateTime.now();
                                  outq.queue(OutgoingItem(
                                    type: QueueType.sendMessage,
                                    chat: chat,
                                    message: message,
                                  ));
                                },
                              ),
                              TextButton(
                                child: Text(
                                  "Remove",
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  // Delete the message from the DB
                                  Message.delete(message.guid!);
                                  // Remove the message from the Bloc
                                  service.removeMessage(message);
                                  await notif.clearFailedToSend();
                                  // Get the "new" latest info
                                  List<Message> latest = Chat.getMessages(chat, limit: 1);
                                  chat.latestMessage = latest.first;
                                  chat.latestMessageDate = latest.first.dateCreated;
                                  chat.latestMessageText = MessageHelper.getNotificationText(latest.first);
                                  chat.save();
                                },
                              ),
                              TextButton(
                                child: Text(
                                  "Cancel",
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await notif.clearFailedToSend();
                                },
                              )
                            ],
                          );
                        },
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              }),
              // slide to view timestamp
              if (!samsung)
                MessageTimestamp(controller: controller, cvController: widget.cvController),
            ],
          ),
        ],
      ),
    );
  }
}
