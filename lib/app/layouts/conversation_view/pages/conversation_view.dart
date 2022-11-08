import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/send_animation.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart';
import 'package:bluebubbles/app/wrappers/gradient_background_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/messages_view.dart';
import 'package:bluebubbles/app/widgets/components/screen_effects_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConversationView extends StatefulWidget {
  ConversationView({
    Key? key,
    required this.chat,
    this.customService,
  }) : super(key: key);

  final Chat chat;
  final MessagesService? customService;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends OptimizedState<ConversationView> {
  late final ConversationViewController controller = cvc(chat, tag: widget.customService?.tag);

  Chat get chat => widget.chat;

  @override
  void initState() {
    super.initState();

    cm.setActiveChat(chat);
    cm.activeChat!.controller = controller;
  }

  @override
  void dispose() {
    cm.setAllInactive();
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background,
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, chat.isIMessage),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, chat.isIMessage),
            onPrimary: context.theme.colorScheme.onBubble(context, chat.isIMessage),
            surface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: WillPopScope(
          onWillPop: () async {
            if (ls.isBubble) {
              SystemNavigator.pop();
            }
            return !ls.isBubble;
          },
          child: SafeArea(
            top: false,
            bottom: false,
            child: Scaffold(
              backgroundColor: context.theme.colorScheme.background,
              extendBodyBehindAppBar: true,
              appBar: iOS
                  ? CupertinoHeader(controller: controller)
                  : MaterialHeader(controller: controller) as PreferredSizeWidget,
              body: Actions(
                actions: {
                  if (ss.settings.enablePrivateAPI.value)
                    ReplyRecentIntent: ReplyRecentAction(widget.chat),
                  if (ss.settings.enablePrivateAPI.value)
                    HeartRecentIntent: HeartRecentAction(widget.chat),
                  if (ss.settings.enablePrivateAPI.value)
                    LikeRecentIntent: LikeRecentAction(widget.chat),
                  if (ss.settings.enablePrivateAPI.value)
                    DislikeRecentIntent: DislikeRecentAction(widget.chat),
                  if (ss.settings.enablePrivateAPI.value)
                    LaughRecentIntent: LaughRecentAction(widget.chat),
                  if (ss.settings.enablePrivateAPI.value)
                    EmphasizeRecentIntent: EmphasizeRecentAction(widget.chat),
                  if (ss.settings.enablePrivateAPI.value)
                    QuestionRecentIntent: QuestionRecentAction(widget.chat),
                  OpenChatDetailsIntent: OpenChatDetailsAction(context, widget.chat),
                },
                child: GradientBackground(
                  controller: controller,
                  child: SizedBox(
                    height: context.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(child: ScreenEffectsWidget()),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  MessagesView(
                                    key: Key(chat.guid),
                                    customService: widget.customService,
                                    controller: controller,
                                  ),
                                  Align(
                                    alignment: iOS ? Alignment.bottomRight : Alignment.bottomCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
                                      child: Obx(() => AnimatedOpacity(
                                        opacity: controller.showScrollDown.value ? 1 : 0,
                                        duration: const Duration(milliseconds: 300),
                                        child: iOS ? TextButton(
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
                                            alignment: Alignment.center,
                                            child: Icon(
                                              CupertinoIcons.chevron_down,
                                              color: context.theme.colorScheme.onSecondary,
                                              size: 20,
                                            ),
                                          ),
                                        ) : FloatingActionButton.small(
                                          heroTag: null,
                                          onPressed: controller.scrollToBottom,
                                          child: Icon(
                                            Icons.arrow_downward,
                                            color: context.theme.colorScheme.onSecondary,
                                          ),
                                          backgroundColor: context.theme.colorScheme.secondary,
                                        ),
                                      )),
                                    )
                                  )
                                ],
                              ),
                            ),
                            Stack(
                              children: [
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      if (ss.settings.swipeToCloseKeyboard.value &&
                                          details.delta.dy > 0 &&
                                          controller.keyboardOpen) {
                                        controller.focusNode.unfocus();
                                        controller.subjectFocusNode.unfocus();
                                      } else if (ss.settings.swipeToOpenKeyboard.value &&
                                          details.delta.dy < 0 &&
                                          !controller.keyboardOpen) {
                                        controller.focusNode.requestFocus();
                                      }
                                    },
                                    child: ConversationTextField(
                                      key: controller.textFieldKey,
                                      parentController: controller,
                                    ),
                                  ),
                                )
                              ]
                            ),
                          ],
                        ),
                        SendAnimation(parentController: controller),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      ),
    );
  }
}
