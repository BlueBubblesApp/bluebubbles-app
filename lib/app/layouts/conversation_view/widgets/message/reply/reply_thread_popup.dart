import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

void showReplyThread(BuildContext context, Message message, MessagePart part, MessagesService service,
    ConversationViewController cvController) {
  final originatorPart = message.threadOriginatorGuid != null ? message.normalizedThreadPart : part.part;
  final originatorGuid = message.threadOriginatorGuid ?? message.guid!;
  final _messages = message.threadOriginatorGuid != null
      ? service.struct.threads(originatorGuid, originatorPart)
      : service.struct.threadsForParts(
          originatorGuid,
          part.attachmentPartIndices ?? [part.part],
        );
  _messages.sort((a, b) => Message.sort(a, b, descending: false));
  _buildThreadView(_messages, originatorPart, cvController, context);
}

void showBookmarksThread(ConversationViewController cvController, BuildContext context) async {
  final _messages = (Database.messages.query(Message_.isBookmarked.equals(true))
        ..link(Message_.chat, Chat_.guid.equals(cvController.chat.guid))
        ..order(Message_.dateCreated, flags: Order.descending))
      .build()
      .find();
  if (_messages.isEmpty) {
    return showSnackbar("Error", "There are no bookmarked messages in this chat!");
  }
  for (Message m in _messages) {
    m.realAttachments;
    m.fetchAssociatedMessages();
  }
  _messages.sort((a, b) => Message.sort(a, b, descending: false));
  _buildThreadView(_messages, null, cvController, context);
}

void _buildThreadView(
    List<Message> _messages, int? originatorPart, ConversationViewController cvController, BuildContext context) {
  final controller = ScrollController();
  // Capture the conversation's theme before pushing the route — if adaptive
  // theming is active, context.theme is already the per-chat theme.
  final capturedTheme = context.theme;
  final capturedIsM3 = ThemeSvc.isMaterialYouActive(context);
  final capturedBubbleExt = capturedTheme.extensions[BubbleColors] as BubbleColors?;
  // Capture the ChatState so it can be re-provided inside the new route,
  // which has its own widget tree without a ChatStateScope.
  final capturedChatState = ChatsSvc.getOrCreateChatState(cvController.chat);
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (routeCtx, animation, secondaryAnimation) {
        // Future.delayed(Duration.zero, () => controller.jumpTo(controller.position.maxScrollExtent));
        return FadeTransition(
            opacity: animation,
            child: ChatStateScope(
                chatState: capturedChatState,
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
                  child: DeferredPointerHandler(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: BBScaffold(
                        backgroundColor: kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                            ? capturedTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
                            : Colors.transparent,
                        safeAreaLeft: false,
                        safeAreaRight: false,
                        body: Stack(
                          fit: StackFit.expand,
                          children: [
                            BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                                      ? 0
                                      : 30,
                                  sigmaY: kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                                      ? 0
                                      : 30),
                              child: Container(
                                color: capturedTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              ),
                            ),
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(
                                  child: SingleChildScrollView(
                                    controller: controller,
                                    child: Column(
                                      children: _messages
                                          .mapIndexed((index, e) => GestureDetector(
                                                onTap: () {
                                                  Navigator.of(context).pop();
                                                  if (originatorPart == null &&
                                                      SettingsSvc.settings.skin.value == Skins.iOS) {
                                                    // pop twice to remove convo details page
                                                    Navigator.of(context).pop();
                                                  }
                                                  MessagesSvc(cvController.chat.guid).jumpToMessage.call(e.guid!);
                                                },
                                                child: AbsorbPointer(
                                                  absorbing: true,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                                                    child: MessageHolder(
                                                      cvController: cvController,
                                                      message: _messages[index],
                                                      oldMessage: index > 0 ? _messages[index - 1] : null,
                                                      newMessage:
                                                          index < _messages.length - 1 ? _messages[index + 1] : null,
                                                      isReplyThread: true,
                                                      replyPart: index == 0 ? originatorPart : null,
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )));
      },
      fullscreenDialog: true,
      opaque: false,
    ),
  ).then((_) {
    if (kIsDesktop || kIsWeb) {
      cvController.focusNode.requestFocus();
    }
  });
}
