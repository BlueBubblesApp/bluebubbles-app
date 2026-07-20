import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/bubble_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/models/models.dart' show MessageReplyContext;

/// Extracted child widget to reduce MessageHolder rebuild scope
class MessagePartWrapper extends StatelessWidget {
  const MessagePartWrapper({
    super.key,
    required this.part,
    required this.controller,
    required this.cvController,
    required this.message,
    required this.newerMessage,
    required this.chat,
    required this.canSwipeToReply,
    required this.globalKey,
    required this.replyOffset,
    required this.stickers,
    required this.reactions,
    required this.onHapticFeedback,
  });

  final MessagePart part;
  final MessageState controller;
  final ConversationViewController cvController;
  final Message message;
  final Message? newerMessage;
  final Chat chat;
  final bool canSwipeToReply;
  final GlobalKey globalKey;
  final RxDouble replyOffset;
  final Iterable<Message> stickers;
  final Iterable<Message> reactions;
  final VoidCallback onHapticFeedback;

  bool get isEditing =>
      message.isFromMe! &&
      cvController.editing.firstWhereOrNull((e2) => e2.message.guid == message.guid! && e2.part.part == part.part) !=
          null;

  void completeEdit(String newEdit) async {
    cvController.editing.removeWhere((e2) => e2.message.guid == message.guid! && e2.part.part == part.part);
    if (newEdit.isNotEmpty && newEdit != part.text) {
      await MessagesSvc(chat.guid).editMessage(message, part.part, newEdit);
    }
    cvController.lastFocusedNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.loose,
      clipBehavior: Clip.none,
      children: [
        // actual message content
        BubbleEffects(
          part: part.part,
          globalKey: globalKey,
          showTail: !part.isPkPass && message.showTail(newerMessage) && part.part == controller.parts.length - 1,
          child: MessagePopupHolder(
            key: globalKey,
            controller: controller,
            cvController: cvController,
            part: part,
            isEditing: isEditing,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onHorizontalDragUpdate: !canSwipeToReply || isEditing
                  ? null
                  : (details) {
                      if (ReplyScope.maybeOf(context) != null) return;
                      replyOffset.value += details.delta.dx * 0.5;
                      if (message.isFromMe!) {
                        replyOffset.value = replyOffset.value.clamp(-double.infinity, 0);
                      } else {
                        replyOffset.value = replyOffset.value.clamp(0, double.infinity);
                      }
                      if (replyOffset.value.abs() >= SlideToReply.replyThreshold) {
                        onHapticFeedback();
                      }
                    },
              onHorizontalDragEnd: !canSwipeToReply || isEditing
                  ? null
                  : (details) {
                      if (ReplyScope.maybeOf(context) != null) return;
                      if (replyOffset.value.abs() >= SlideToReply.replyThreshold) {
                        cvController.replyToMessage = MessageReplyContext(message, part.part);
                      }
                      replyOffset.value = 0;
                    },
              onHorizontalDragCancel: !canSwipeToReply || isEditing
                  ? null
                  : () {
                      if (ReplyScope.maybeOf(context) != null) return;
                      replyOffset.value = 0;
                    },
              child: _MessageContentBubble(
                part: part,
                controller: controller,
                cvController: cvController,
                message: message,
                newerMessage: newerMessage,
                chat: chat,
                isEditing: isEditing,
                onCompleteEdit: completeEdit,
              ),
            ),
          ),
        ),
        // show stickers on top
        if (stickers.isNotEmpty)
          Positioned(
            top: 0,
            left: message.isFromMe! ? null : 0,
            right: message.isFromMe! ? 0 : null,
            child: StickerHolder(
              stickerMessages: stickers,
              controller: cvController,
            ),
          ),
        // show reactions on top
        if (message.isFromMe!)
          Positioned(
            top: -14,
            left: -20,
            child: ReactionHolder(
              reactions: reactions,
            ),
          ),
        if (!message.isFromMe!)
          Positioned(
            top: -14,
            right: -20,
            child: ReactionHolder(
              reactions: reactions,
            ),
          ),
      ],
    );
  }
}

/// Separate widget for message content bubble to isolate edit mode rebuilds
class _MessageContentBubble extends StatelessWidget {
  const _MessageContentBubble({
    required this.part,
    required this.controller,
    required this.cvController,
    required this.message,
    required this.newerMessage,
    required this.chat,
    required this.isEditing,
    required this.onCompleteEdit,
  });

  final MessagePart part;
  final MessageState controller;
  final ConversationViewController cvController;
  final Message message;
  final Message? newerMessage;
  final Chat chat;
  final bool isEditing;
  final Function(String) onCompleteEdit;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TailClipper(
        isFromMe: message.isFromMe!,
        showTail: !part.isPkPass && message.showTail(newerMessage) && part.part == controller.parts.length - 1,
        connectLower: SettingsSvc.settings.skin.value == Skins.iOS
            ? false
            : (part.part != 0 && part.part != controller.parts.length - 1) ||
                (part.part == 0 && controller.parts.length > 1),
        connectUpper: SettingsSvc.settings.skin.value == Skins.iOS ? false : part.part != 0,
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive
              ? InteractiveHolder(
                  message: part,
                )
              : part.attachments.isEmpty && (part.text != null || part.subject != null)
                  ? TextBubble(
                      message: part,
                    )
                  : part.attachments.isNotEmpty
                      ? AttachmentHolder(
                          message: part,
                        )
                      : const SizedBox.shrink(),
          if (message.isFromMe!)
            Obx(() {
              final editStuff = cvController.editing
                  .firstWhereOrNull((e2) => e2.message.guid == message.guid! && e2.part.part == part.part);
              return AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.centerRight,
                curve: Curves.easeOutBack,
                child: editStuff == null
                    ? const SizedBox.shrink()
                    : _EditModeTextField(
                        editStuff: editStuff,
                        message: message,
                        chat: chat,
                        cvController: cvController,
                        part: part,
                        onComplete: onCompleteEdit,
                      ),
              );
            }),
        ],
      ),
    );
  }
}

/// Separate stateless widget for edit mode to reduce rebuild scope
class _EditModeTextField extends StatelessWidget {
  const _EditModeTextField({
    required this.editStuff,
    required this.message,
    required this.chat,
    required this.cvController,
    required this.part,
    required this.onComplete,
  });

  final MessageEditEntry editStuff;
  final Message message;
  final Chat chat;
  final ConversationViewController cvController;
  final MessagePart part;
  final Function(String) onComplete;

  MessageState get controller => MessagesSvc(chat.guid).getOrCreateState(message);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isTempMessage = controller.isSending.value;
      return Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: !message.isBigEmoji
                ? context.theme.colorScheme.primary.darkenAmount(isTempMessage ? 0.2 : 0)
                : context.theme.colorScheme.surface,
          ),
          constraints: BoxConstraints(
            maxWidth: NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 40,
            minHeight: 40,
          ),
          padding: const EdgeInsets.only(right: 10).add(const EdgeInsets.all(5)),
          child: Focus(
            focusNode: FocusNode(),
            onKeyEvent: (_, ev) {
              if (ev is! KeyDownEvent) {
                if (ev.logicalKey == LogicalKeyboardKey.tab) {
                  return KeyEventResult.skipRemainingHandlers;
                }
                return KeyEventResult.ignored;
              }
              if (ev.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                onComplete(editStuff.controller.text);
                return KeyEventResult.handled;
              }
              if (ev.logicalKey == LogicalKeyboardKey.escape) {
                cvController.editing.removeWhere((e2) => e2.message.guid == message.guid! && e2.part.part == part.part);
                if (cvController.editing.isEmpty) {
                  cvController.lastFocusedNode.requestFocus();
                } else {
                  cvController.editing.last.controller.focusNode?.requestFocus();
                }
                return KeyEventResult.handled;
              }
              if (ev.logicalKey == LogicalKeyboardKey.tab) {
                return KeyEventResult.skipRemainingHandlers;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              autocorrect: true,
              controller: editStuff.controller,
              scrollPhysics: const CustomBouncingScrollPhysics(),
              style: context.theme.extension<BubbleText>()!.bubbleText.apply(
                    fontSizeFactor: message.isBigEmoji ? 3 : 1,
                  ),
              keyboardType: TextInputType.multiline,
              maxLines: 14,
              minLines: 1,
              autofocus: !(kIsDesktop || kIsWeb),
              enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
              textInputAction: SettingsSvc.settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                  ? TextInputAction.send
                  : TextInputAction.newline,
              cursorColor: context.theme.extension<BubbleText>()!.bubbleText.color,
              cursorHeight:
                  context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25 * (message.isBigEmoji ? 3 : 1),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.all(SettingsSvc.settings.skin.value == Skins.iOS ? 10 : 12.5),
                isDense: true,
                isCollapsed: true,
                hintText: "Edited Message",
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.theme.colorScheme.outline, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: context.theme.colorScheme.outline, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.theme.colorScheme.outline, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                fillColor: Colors.transparent,
                hintStyle: context.theme
                    .extension<BubbleText>()!
                    .bubbleText
                    .copyWith(color: context.theme.colorScheme.outline),
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
                    cvController.editing
                        .removeWhere((e2) => e2.message.guid == message.guid! && e2.part.part == part.part);
                    cvController.lastFocusedNode.requestFocus();
                  },
                  iconSize: 22,
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 40),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: editStuff.controller,
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
                            shape: SettingsSvc.settings.skin.value == Skins.iOS ? BoxShape.circle : BoxShape.rectangle,
                            color: SettingsSvc.settings.skin.value != Skins.iOS
                                ? null
                                : editStuff.controller.text.isNotEmpty
                                    ? Colors.white
                                    : context.theme.colorScheme.outline,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            SettingsSvc.settings.skin.value == Skins.iOS
                                ? CupertinoIcons.arrow_up
                                : Icons.send_outlined,
                            color: SettingsSvc.settings.skin.value != Skins.iOS
                                ? context.theme.extension<BubbleText>()!.bubbleText.color
                                : context.theme.colorScheme.bubble(context, chat.isIMessage),
                            size: SettingsSvc.settings.skin.value == Skins.iOS ? 18 : 26,
                          ),
                        ),
                        onPressed: () {
                          onComplete(editStuff.controller.text);
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
                onComplete(value);
              },
            ),
          ),
        ), // Container closes
      ); // Material closes
    }); // Obx closes
  }
}
