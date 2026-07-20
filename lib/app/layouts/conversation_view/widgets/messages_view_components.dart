import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_indicator.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Helper to check if iOS skin is active
bool get iOS => SettingsSvc.settings.skin.value == Skins.iOS;

/// Extracted widget for typing indicator row with avatar
class TypingIndicatorRow extends StatelessWidget {
  const TypingIndicatorRow({
    super.key,
    required this.controller,
  });

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    final chat = ChatStateScope.chatOf(context);
    return Obx(() => Row(
          key: controller.typingInfoKey,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (controller.showTypingIndicator.value && SettingsSvc.settings.alwaysShowAvatars.value && iOS)
              Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: ContactAvatarWidget(
                  key: Key("${chat.handles.first.address}-typing-indicator"),
                  handle: chat.handles.first,
                  size: 30,
                  fontSize: 14,
                  borderThickness: 0.1,
                ),
              ),
            TypingIndicator(
              controller: controller,
            )
          ],
        ));
  }
}

/// Extracted widget for notifications silenced banner
class NotificationsSilencedBanner extends StatelessWidget {
  const NotificationsSilencedBanner({
    super.key,
    required this.controller,
    required this.latestMessage,
  });

  final ConversationViewController controller;
  final Message? latestMessage;

  @override
  Widget build(BuildContext context) {
    final chat = ChatStateScope.chatOf(context);
    const moonIcon = CupertinoIcons.moon_fill;

    return AnimatedSize(
      key: controller.focusInfoKey,
      duration: const Duration(milliseconds: 250),
      child: Obx(() => controller.recipientNotifsSilenced.value
          ? Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        String.fromCharCode(moonIcon.codePoint),
                        style: TextStyle(
                          fontFamily: moonIcon.fontFamily,
                          package: moonIcon.fontPackage,
                          fontSize: context.theme.textTheme.bodyMedium!.fontSize,
                          color: context.theme.colorScheme.tertiaryContainer,
                        ),
                      ),
                      Text(
                        " ${chat.getTitle()} has notifications silenced",
                        style: context.theme.textTheme.bodyMedium!
                            .copyWith(color: context.theme.colorScheme.tertiaryContainer),
                      ),
                    ],
                  ),
                  _NotifyAnywayButton(latestMessage: latestMessage),
                ],
              ),
            )
          : const SizedBox.shrink()),
    );
  }
}

/// Nested widget for "Notify Anyway" button to further isolate rebuilds
class _NotifyAnywayButton extends StatelessWidget {
  const _NotifyAnywayButton({required this.latestMessage});

  final Message? latestMessage;

  @override
  Widget build(BuildContext context) {
    // Check conditions for showing the button
    if (latestMessage?.isFromMe == true &&
        latestMessage?.dateRead == null &&
        latestMessage?.wasDeliveredQuietly == true &&
        latestMessage?.didNotifyRecipient == false) {
      return TextButton(
        child: Text(
          "Notify Anyway",
          style: context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.tertiaryContainer),
        ),
        onPressed: () async {
          await HttpSvc.message.notify(latestMessage!.guid!);
        },
      );
    }
    return const SizedBox.shrink();
  }
}

/// Extracted widget for smart replies row
class SmartRepliesRow extends StatelessWidget {
  const SmartRepliesRow({
    super.key,
    required this.controller,
    required this.smartReplies,
    required this.internalSmartReplies,
  });

  final ConversationViewController controller;
  final RxList<String> smartReplies;
  final RxMap<String, Widget> internalSmartReplies;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool visible = smartReplies.isNotEmpty || internalSmartReplies.isNotEmpty;
      final double rowHeight = context.theme.extension<BubbleText>()!.bubbleText.fontSize! + 35;
      final double topPadding = iOS ? 8.0 : 0.0;
      final double totalHeight = visible ? rowHeight + topPadding : 0.0;

      controller.updateSmartReplyLayout(visible: visible, height: totalHeight);

      return AnimatedSize(
        duration: const Duration(milliseconds: 400),
        child: visible
            ? Padding(
                padding: EdgeInsets.only(top: topPadding, right: 5),
                child: SizedBox(
                  height: rowHeight,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    children: smartReplies.map((suggestion) => _buildReplyWidget(context, suggestion)).toList()
                      ..addAll(internalSmartReplies.values),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
    });
  }

  Widget _buildReplyWidget(BuildContext context, String suggestion) {
    final hasBackground = ChatsSvc.getChatState(controller.chat.guid)?.customBackgroundPath.value?.isNotEmpty == true;
    return Container(
      margin: const EdgeInsets.all(5),
      decoration: hasBackground
          ? BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(19),
            )
          : BoxDecoration(
              border: Border.all(
                width: 2,
                style: BorderStyle.solid,
                color: context.theme.colorScheme.surfaceContainerHighest,
              ),
              borderRadius: BorderRadius.circular(19),
            ),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () {
          OutgoingMsgHandler.queue(OutgoingMessage(
            chat: controller.chat,
            message: Message(
              text: suggestion,
              dateCreated: DateTime.now(),
              hasAttachments: false,
              isFromMe: true,
              handleId: 0,
            ),
          ));
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 1.5, left: 13.0, right: 13.0),
            child: RichText(
              text: TextSpan(
                children: MessageHelper.buildEmojiText(
                  suggestion,
                  context.theme.extension<BubbleText>()!.bubbleText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extracted widget for scroll down button
class ScrollDownButton extends StatelessWidget {
  const ScrollDownButton({
    super.key,
    required this.controller,
  });

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: iOS ? Alignment.bottomRight : Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
        child: Obx(
          () => IgnorePointer(
            ignoring: !controller.showScrollDown.value,
            child: AnimatedOpacity(
              opacity: controller.showScrollDown.value ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: iOS
                  ? TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: context.theme.colorScheme.secondary,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(0),
                        maximumSize: const Size(32, 32),
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: controller.scrollToBottom,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.only(top: 3, left: 1),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          color: context.theme.colorScheme.onSecondary,
                          size: 20,
                        ),
                      ),
                    )
                  : FloatingActionButton.small(
                      heroTag: null,
                      onPressed: controller.scrollToBottom,
                      backgroundColor: context.theme.colorScheme.secondary,
                      child: Icon(
                        Icons.arrow_downward,
                        color: context.theme.colorScheme.onSecondary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extracted widget for drag and drop overlay
class DragDropOverlay extends StatelessWidget {
  const DragDropOverlay({
    super.key,
    required this.dragging,
    required this.numFiles,
  });

  final RxBool dragging;
  final RxInt numFiles;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: context.theme.colorScheme.surface.withValues(alpha: dragging.value ? 0.4 : 0),
        child: dragging.value
            ? Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iOS ? CupertinoIcons.paperclip : Icons.attach_file,
                      color: context.theme.colorScheme.primary,
                      size: 50,
                    ),
                    Text(
                      "Attach ${numFiles.value} File${numFiles.value > 1 ? 's' : ''}",
                      style: context.theme.textTheme.headlineLarge!.copyWith(color: context.theme.colorScheme.primary),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
