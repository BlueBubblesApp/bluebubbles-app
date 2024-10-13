import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

void showReplyThread(BuildContext context, Message message, MessagePart part, MessagesService service, ConversationViewController cvController) {
  final originatorPart = message.threadOriginatorGuid != null ? message.normalizedThreadPart : part.part;
  final _messages = service.struct.threads(message.threadOriginatorGuid ?? message.guid!, originatorPart);
  _messages.sort((a, b) => Message.sort(a, b, descending: false));
  _buildThreadView(_messages, originatorPart, cvController, context);
}

void showBookmarksThread(ConversationViewController cvController, BuildContext context) async {
  final _messages = (Database.messages.query(Message_.isBookmarked.equals(true))
    ..link(Message_.chat, Chat_.guid.equals(cvController.chat.guid))
    ..order(Message_.dateCreated, flags: Order.descending)).build().find();
  if (_messages.isEmpty) {
    return showSnackbar("Error", "There are no bookmarked messages in this chat!");
  }
  for (Message m in _messages) {
    m.realAttachments;
    m.fetchAssociatedMessages();
    m.handle = m.getHandle();
  }
  _messages.sort((a, b) => Message.sort(a, b, descending: false));
  _buildThreadView(_messages, null, cvController, context);
}

void _buildThreadView(List<Message> _messages, int? originatorPart, ConversationViewController cvController, BuildContext context) {
  final controller = ScrollController();
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        // Future.delayed(Duration.zero, () => controller.jumpTo(controller.position.maxScrollExtent));
        return FadeTransition(
            opacity: animation,
            child: Theme(
              data: context.theme.copyWith(
                // in case some components still use legacy theming
                primaryColor: context.theme.colorScheme.bubble(context, true),
                colorScheme: context.theme.colorScheme.copyWith(
                  primary: context.theme.colorScheme.bubble(context, true),
                  onPrimary: context.theme.colorScheme.onBubble(context, true),
                  surface: ss.settings.monetTheming.value == Monet.full
                      ? null
                      : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                  onSurface: ss.settings.monetTheming.value == Monet.full
                      ? null
                      : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                ),
              ),
              child: DeferredPointerHandler(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background,
                      // navigation bar color
                      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
                      statusBarColor: Colors.transparent,
                      // status bar color
                      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
                    ),
                    child: Scaffold(
                      backgroundColor: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled
                          ? context.theme.colorScheme.properSurface.withOpacity(0.9)
                          : Colors.transparent,
                      body: Stack(
                        fit: StackFit.expand,
                        children: [
                          BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled ? 0 : 30,
                                sigmaY: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled ? 0 : 30),
                            child: Container(
                              color: context.theme.colorScheme.properSurface.withOpacity(0.3),
                            ),
                          ),
                          Container(
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(
                                  child: SingleChildScrollView(
                                    controller: controller,
                                    child: Column(
                                      children: _messages.mapIndexed((index, e) => GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          if (originatorPart == null && ss.settings.skin.value == Skins.iOS) {
                                            // pop twice to remove convo details page
                                            Navigator.of(context).pop();
                                          }
                                          ms(cvController.chat.guid).jumpToMessage.call(e.guid!);
                                        },
                                        child: AbsorbPointer(
                                          absorbing: true,
                                          child: Padding(
                                              padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                                              child: MessageHolder(
                                                cvController: cvController,
                                                message: _messages[index],
                                                oldMessageGuid: index > 0 ? _messages[index - 1].guid : null,
                                                newMessageGuid: index < _messages.length - 1 ? _messages[index + 1].guid : null,
                                                isReplyThread: true,
                                                replyPart: index == 0 ? originatorPart : null,
                                              ),
                                          ),
                                        ),
                                      )).toList(),
                                    ),
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
              ),
            ));
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
