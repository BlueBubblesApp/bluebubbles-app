import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
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
import 'package:bluebubbles/services/network/backend_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

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
  CustomState createState() => _MessageHolderState();
}

class _MessageHolderState extends CustomState<MessageHolder, void, MessageWidgetController> {
  Message get message => controller.message;
  Message? get olderMessage => controller.oldMessage;
  Message? get newerMessage => controller.newMessage;
  Message? get replyTo => message.threadOriginatorGuid == null
      ? null
      : ss.settings.repliesToPrevious.value
      ? (service.struct.getPreviousReply(message.threadOriginatorGuid!, message.normalizedThreadPart, message.guid!) ?? service.struct.getThreadOriginator(message.threadOriginatorGuid!))
      : service.struct.getThreadOriginator(message.threadOriginatorGuid!);
  Chat get chat => widget.cvController.chat;
  MessagesService get service => ms(widget.cvController.chat.guid);
  bool get canSwipeToReply => ss.settings.enablePrivateAPI.value
      && ss.isMinBigSurSync
      && chat.isIMessage
      && !widget.isReplyThread
      && !message.guid!.startsWith("temp")
      && !message.guid!.startsWith("error");
  bool get showSender => !message.isGroupEvent && (!message.sameSender(olderMessage) || (olderMessage?.isGroupEvent ?? false)
      || (olderMessage == null || !message.dateCreated!.isWithin(olderMessage!.dateCreated!, minutes: 30)));
  bool get showAvatar => chat.isGroup;
  bool isEditing(int part) => message.isFromMe! && widget.cvController.editing.firstWhereOrNull((e2) => e2.item1.guid == message.guid! && e2.item2.part == part) != null;

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
      messageParts = controller.parts;
      replyOffsets = List.generate(messageParts.length, (_) => 0.0.obs);
      keys = List.generate(messageParts.length, (_) => GlobalKey());
    }

    eventDispatcher.stream.listen((event) {
      if (event.item1 != 'refresh-avatar') return;
      if (event.item2[0] != message.handle?.address) return;
      message.handle?.color = event.item2[1];
      setState(() {});
    });
  }

  @override
  void updateWidget(void _) {
    messageParts = controller.parts;
    super.updateWidget(_);
  }

  List<Color> getBubbleColors() {
    List<Color> bubbleColors = [context.theme.colorScheme.properSurface, context.theme.colorScheme.properSurface];
    if (ss.settings.colorfulBubbles.value && !message.isFromMe!) {
      if (message.handle?.color == null) {
        bubbleColors = toColorGradient(message.handle?.address);
      } else {
        bubbleColors = [
          HexColor(message.handle!.color!),
          HexColor(message.handle!.color!).lightenAmount(0.075),
        ];
      }
    }
    return bubbleColors;
  }

  void completeEdit(String newEdit, int part) async {
    widget.cvController.editing.removeWhere((e2) => e2.item1.guid == message.guid! && e2.item2.part == part);
    if (newEdit.isNotEmpty && newEdit != messageParts.firstWhere((element) => element.part == part).text) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.properSurface,
            title: Text(
              "Editing message...",
              style: context.theme.textTheme.titleLarge,
            ),
            content: Container(
              height: 70,
              child: Center(
                child: CircularProgressIndicator(
                  backgroundColor: context.theme.colorScheme.properSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                ),
              ),
            ),
          );
        }
      );
      final response = await backend.edit(message.guid!, newEdit, part);
      if (response != null) {
        final updatedMessage = Message.fromMap(response);
        ah.handleUpdatedMessage(chat, updatedMessage, null);
      }
      if (kIsDesktop) {
        Get.close(1);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    controller.built = true;
    final stickers = message.associatedMessages.where((e) => e.associatedMessageType == "sticker");
    final reactions = message.associatedMessages.where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")));
    Iterable<Message> stickersForPart(int part) {
      return stickers.where((s) => (s.associatedMessagePart ?? 0) == part);
    }
    Iterable<Message> reactionsForPart(int part) {
      return reactions.where((s) => (s.associatedMessagePart ?? 0) == part);
    }
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
    // Item Type 5 indicates a kept audio message, we don't need to show this
    if (message.itemType == 5 && message.subject != null) {
      return const SizedBox.shrink();
    }
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
                                  ? EdgeInsets.only(left: 35.0 * ss.settings.avatarScale.value) : EdgeInsets.zero,
                              child: Obx(() => AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                alignment: Alignment.bottomCenter,
                                curve: controller.showEdits.value ? Curves.easeOutBack : Curves.easeOut,
                                child: controller.showEdits.value ? Opacity(
                                  opacity: 0.75,
                                  child: Column(
                                    crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                                    cvController: widget.cvController,
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
                                  ? EdgeInsets.only(left: 35.0 * ss.settings.avatarScale.value) : EdgeInsets.zero,
                              child: MessageSender(olderMessage: olderMessage, message: message),
                            ),
                          // add a box to account for height of reactions
                          if ((messageParts.length == 1 && reactions.isNotEmpty) || reactionsForPart(e.part).isNotEmpty)
                            const SizedBox(height: 12.5),
                          if (!iOS && index == 0 && !widget.isReplyThread
                              && olderMessage != null
                              && message.threadOriginatorGuid != null
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
                                  cvController: widget.cvController,
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
                                padding: (showAvatar || ss.settings.alwaysShowAvatars.value) && !(message.isGroupEvent || e.isUnsent)
                                    ? EdgeInsets.only(left: 35.0 * ss.settings.avatarScale.value) : EdgeInsets.zero,
                                child: DecoratedBox(
                                  decoration: iOS && !widget.isReplyThread && ((index == 0 && message.threadOriginatorGuid != null && olderMessage != null)
                                      || (index == messageParts.length - 1 && service.struct.threads(message.guid!, index).isNotEmpty && newerMessage != null))
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
                                    } : kIsDesktop || kIsWeb || iOS || material ? () => tapped.value = !tapped.value : null,
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
                                                padding: (messageParts.length == 1 && reactions.isNotEmpty) || reactionsForPart(e.part).isNotEmpty
                                                    ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 20 : 0)
                                                    : const EdgeInsets.only(right: 10),
                                                child: MessageTimestamp(controller: controller, cvController: widget.cvController),
                                              ),
                                            // otherwise show content
                                            if (!message.isGroupEvent && !e.isUnsent)
                                              Column(
                                                crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                children: [
                                                  // interactive messages may have subjects, so render them here
                                                  // also render the subject for attachments that may have not rendered already
                                                  if ((message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive
                                                      || (e.part == 0 && isNullOrEmpty(e.text)! && e.attachments.isNotEmpty))
                                                      && !isNullOrEmpty(message.subject)!)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 2.0),
                                                      child: ClipPath(
                                                        clipper: TailClipper(
                                                          isFromMe: message.isFromMe!,
                                                          showTail: false,
                                                          connectLower: iOS ? false : (e.part != 0 && e.part != controller.parts.length - 1)
                                                              || (e.part == 0 && controller.parts.length > 1),
                                                          connectUpper: iOS ? false : e.part != 0,
                                                        ),
                                                        child: TextBubble(
                                                          parentController: controller,
                                                          message: MessagePart(
                                                            subject: e.subject,
                                                            part: e.part,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
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
                                                            onHorizontalDragUpdate: !canSwipeToReply || isEditing(e.part) ? null : (details) {
                                                              if (ReplyScope.maybeOf(context) != null) return;
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
                                                            onHorizontalDragEnd: !canSwipeToReply || isEditing(e.part) ? null : (details) {
                                                              if (ReplyScope.maybeOf(context) != null) return;
                                                              final offset = replyOffsets[index];
                                                              if (offset.value.abs() >= SlideToReply.replyThreshold) {
                                                                widget.cvController.replyToMessage = Tuple2(message, index);
                                                              }
                                                              offset.value = 0;
                                                            },
                                                            onHorizontalDragCancel: !canSwipeToReply || isEditing(e.part) ? null : () {
                                                              if (ReplyScope.maybeOf(context) != null) return;
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
                                                              child: Stack(
                                                                alignment: Alignment.centerRight,
                                                                children: [
                                                                  message.hasApplePayloadData
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
                                                                  if (message.isFromMe!)
                                                                    Obx(() {
                                                                      final editStuff = widget.cvController.editing.firstWhereOrNull((e2) => e2.item1.guid == message.guid! && e2.item2.part == e.part);
                                                                      return AnimatedSize(
                                                                        duration: const Duration(milliseconds: 250),
                                                                        alignment: Alignment.centerRight,
                                                                        curve: Curves.easeOutBack,
                                                                        child: editStuff == null ? const SizedBox.shrink() : Material(
                                                                          color: Colors.transparent,
                                                                          child: Container(
                                                                            decoration: BoxDecoration(
                                                                              color: !message.isBigEmoji
                                                                                  ? context.theme.colorScheme.primary.darkenAmount(message.guid!.startsWith("temp") ? 0.2 : 0)
                                                                                  : context.theme.colorScheme.background,
                                                                            ),
                                                                            constraints: BoxConstraints(
                                                                              maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 40,
                                                                              minHeight: 40,
                                                                            ),
                                                                            padding: const EdgeInsets.only(right: 10).add(const EdgeInsets.all(5)),
                                                                            child: Focus(
                                                                              focusNode: FocusNode(),
                                                                              onKey: (_, ev) {
                                                                                if (ev is! RawKeyDownEvent) return KeyEventResult.ignored;
                                                                                RawKeyEventDataWindows? windowsData;
                                                                                RawKeyEventDataLinux? linuxData;
                                                                                RawKeyEventDataWeb? webData;
                                                                                RawKeyEventDataAndroid? androidData;
                                                                                if (ev.data is RawKeyEventDataWindows) {
                                                                                  windowsData = ev.data as RawKeyEventDataWindows;
                                                                                } else if (ev.data is RawKeyEventDataLinux) {
                                                                                  linuxData = ev.data as RawKeyEventDataLinux;
                                                                                } else if (ev.data is RawKeyEventDataWeb) {
                                                                                  webData = ev.data as RawKeyEventDataWeb;
                                                                                } else if (ev.data is RawKeyEventDataAndroid) {
                                                                                  androidData = ev.data as RawKeyEventDataAndroid;
                                                                                }
                                                                                if ((windowsData?.keyCode == 13 || linuxData?.keyCode == 65293 || webData?.code == "Enter") && !ev.isShiftPressed) {
                                                                                  completeEdit(editStuff.item3.text, e.part);
                                                                                  return KeyEventResult.handled;
                                                                                }
                                                                                if (windowsData?.keyCode == 27 || linuxData?.keyCode == 65307 || webData?.code == "Escape" || androidData?.physicalKey == PhysicalKeyboardKey.escape) {
                                                                                  widget.cvController.editing.removeWhere((e2) => e2.item1.guid == message.guid! && e2.item2.part == e.part);
                                                                                  return KeyEventResult.handled;
                                                                                }
                                                                                return KeyEventResult.ignored;
                                                                              },
                                                                              child: TextField(
                                                                                textCapitalization: TextCapitalization.sentences,
                                                                                autocorrect: true,
                                                                                focusNode: editStuff.item4,
                                                                                controller: editStuff.item3,
                                                                                scrollPhysics: const CustomBouncingScrollPhysics(),
                                                                                style: context.theme.extension<BubbleText>()!.bubbleText.apply(
                                                                                  fontSizeFactor: message.isBigEmoji ? 3 : 1,
                                                                                ),
                                                                                keyboardType: TextInputType.multiline,
                                                                                maxLines: 14,
                                                                                minLines: 1,
                                                                                selectionControls: ss.settings.skin.value == Skins.iOS ? cupertinoTextSelectionControls : materialTextSelectionControls,
                                                                                autofocus: kIsDesktop || kIsWeb,
                                                                                enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                                                                                textInputAction: ss.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                                                                                    ? TextInputAction.send
                                                                                    : TextInputAction.newline,
                                                                                cursorColor: context.theme.extension<BubbleText>()!.bubbleText.color,
                                                                                cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25 * (message.isBigEmoji ? 3 : 1),
                                                                                decoration: InputDecoration(
                                                                                  contentPadding: EdgeInsets.all(iOS ? 10 : 12.5),
                                                                                  isDense: true,
                                                                                  isCollapsed: true,
                                                                                  hintText: "Edited Message",
                                                                                  enabledBorder: OutlineInputBorder(
                                                                                    borderSide: BorderSide(
                                                                                        color: context.theme.colorScheme.outline,
                                                                                        width: 1.5
                                                                                    ),
                                                                                    borderRadius: BorderRadius.circular(20),
                                                                                  ),
                                                                                  border: OutlineInputBorder(
                                                                                    borderSide: BorderSide(
                                                                                      color: context.theme.colorScheme.outline,
                                                                                      width: 1.5
                                                                                    ),
                                                                                    borderRadius: BorderRadius.circular(20),
                                                                                  ),
                                                                                  focusedBorder: OutlineInputBorder(
                                                                                    borderSide: BorderSide(
                                                                                        color: context.theme.colorScheme.outline,
                                                                                        width: 1.5
                                                                                    ),
                                                                                    borderRadius: BorderRadius.circular(20),
                                                                                  ),
                                                                                  fillColor: Colors.transparent,
                                                                                  hintStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                                                                                  prefixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 40),
                                                                                  prefixIcon: IconButton(
                                                                                    constraints: const BoxConstraints(maxWidth: 27),
                                                                                    padding: const EdgeInsets.only(left: 5),
                                                                                    visualDensity: VisualDensity.compact,
                                                                                    icon: Icon(
                                                                                      CupertinoIcons.xmark_circle_fill,
                                                                                      color: context.theme.colorScheme.outline,
                                                                                      size: 22,
                                                                                    ),
                                                                                    onPressed: () {
                                                                                      widget.cvController.editing.removeWhere((e2) => e2.item1.guid == message.guid! && e2.item2.part == e.part);
                                                                                    },
                                                                                    iconSize: 22,
                                                                                    style: const ButtonStyle(
                                                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                      visualDensity: VisualDensity.compact,
                                                                                    ),
                                                                                  ),
                                                                                  suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 40),
                                                                                  suffixIcon: ValueListenableBuilder(
                                                                                    valueListenable: editStuff.item3,
                                                                                    builder: (context, value, _) {
                                                                                      return Padding(
                                                                                        padding: const EdgeInsets.all(3.0),
                                                                                        child: TextButton(
                                                                                          style: TextButton.styleFrom(
                                                                                            backgroundColor: Colors.transparent,
                                                                                            shape: const CircleBorder(),
                                                                                            padding: const EdgeInsets.all(0),
                                                                                            maximumSize: const Size(27, 27),
                                                                                            minimumSize: const Size(27, 27),
                                                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                          ),
                                                                                          child: AnimatedContainer(
                                                                                            duration: const Duration(milliseconds: 150),
                                                                                            constraints: const BoxConstraints(minHeight: 27, minWidth: 27),
                                                                                            decoration: BoxDecoration(
                                                                                              shape: iOS ? BoxShape.circle : BoxShape.rectangle,
                                                                                              color: !iOS ? null : editStuff.item3.text.isNotEmpty ? Colors.white : context.theme.colorScheme.outline,
                                                                                            ),
                                                                                            alignment: Alignment.center,
                                                                                            child: Icon(
                                                                                              iOS ? CupertinoIcons.arrow_up : Icons.send_outlined,
                                                                                              color: !iOS ? context.theme.extension<BubbleText>()!.bubbleText.color : context.theme.colorScheme.bubble(context, chat.isIMessage),
                                                                                              size: iOS ? 18 : 26,
                                                                                            ),
                                                                                          ),
                                                                                          onPressed: () {
                                                                                            completeEdit(editStuff.item3.text, e.part);
                                                                                          },
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                  ),
                                                                                ),
                                                                                onTap: () {
                                                                                  HapticFeedback.selectionClick();
                                                                                },
                                                                                onSubmitted: (String value) {
                                                                                  completeEdit(value, e.part);
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        )
                                                                      );
                                                                    }),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      // show stickers on top
                                                      if ((messageParts.length == 1 ? stickers : stickersForPart(e.part)).isNotEmpty)
                                                        StickerHolder(
                                                          stickerMessages: messageParts.length == 1 ? stickers : stickersForPart(e.part),
                                                          controller: widget.cvController,
                                                        ),
                                                      // show reactions on top
                                                      if (message.isFromMe!)
                                                        Positioned(
                                                          top: -14,
                                                          left: -20,
                                                          child: ReactionHolder(
                                                            reactions: messageParts.length == 1 ? reactions : reactionsForPart(e.part),
                                                            message: message,
                                                          ),
                                                        ),
                                                      if (!message.isFromMe!)
                                                        Positioned(
                                                          top: -14,
                                                          right: -20,
                                                          child: ReactionHolder(
                                                            reactions: messageParts.length == 1 ? reactions : reactionsForPart(e.part),
                                                            message: message,
                                                          ),
                                                        ),
                                                    ],
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
                                ? EdgeInsets.only(left: 35.0 * ss.settings.avatarScale.value) : EdgeInsets.zero,
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
                                  for (Attachment? a in message.attachments) {
                                    if (a == null) continue;
                                    Attachment.delete(a.guid!);
                                    a.bytes = await File(a.path).readAsBytes();
                                  }
                                  await notif.clearFailedToSend(chat.id!);
                                  // Re-send
                                  message.id = null;
                                  message.error = 0;
                                  message.dateCreated = DateTime.now();
                                  if (message.attachments.isNotEmpty) {
                                    outq.queue(OutgoingItem(
                                      type: QueueType.sendAttachment,
                                      chat: chat,
                                      message: message,
                                    ));
                                  } else {
                                    outq.queue(OutgoingItem(
                                      type: QueueType.sendMessage,
                                      chat: chat,
                                      message: message,
                                    ));
                                  }
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
                                  await notif.clearFailedToSend(chat.id!);
                                  // Get the "new" latest info
                                  List<Message> latest = Chat.getMessages(chat, limit: 1);
                                  chat.latestMessage = latest.first;
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
                                  await notif.clearFailedToSend(chat.id!);
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
              if (iOS)
                MessageTimestamp(controller: controller, cvController: widget.cvController),
            ],
          ),
        ],
      ),
    );
  }
}
