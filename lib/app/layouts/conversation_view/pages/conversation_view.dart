import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart';
import 'package:bluebubbles/app/wrappers/gradient_background_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/messages_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/effects/screen_effects_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart';

class ConversationView extends StatefulWidget {
  ConversationView({
    super.key,
    required this.chatGuid,
    this.customService,
    this.fromChatCreator = false,
    this.onInit,
  });

  final String chatGuid;
  final MessagesService? customService;
  final bool fromChatCreator;
  final void Function()? onInit;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends OptimizedState<ConversationView> {
  late final ConversationViewController controller = cvc(widget.chatGuid, tag: widget.customService?.tag);

  Chat get chat => GlobalChatService.getChat(widget.chatGuid)!.chat;

  @override
  void initState() {
    super.initState();

    Logger.debug("Initializing Conversation View for ${widget.chatGuid}");
    controller.fromChatCreator = widget.fromChatCreator;
    GlobalChatService.closeChat(widget.chatGuid);
    Logger.debug("Conversation View initialized for ${widget.chatGuid}");

    if (widget.onInit != null) {
      Future.delayed(Duration.zero, widget.onInit!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background,
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
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
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            if (controller.inSelectMode.value) {
              controller.inSelectMode.value = false;
              controller.selected.clear();
              return;
            }
            if (controller.showAttachmentPicker) {
              controller.showAttachmentPicker = false;
              controller.updateWidgets<ConversationTextField>(null);
              return;
            }
            if (ls.isBubble) {
              SystemNavigator.pop();
            }
            controller.close();
            if (ls.isBubble) return;
            return Navigator.of(context).pop();
          },
          child: SafeArea(
            top: false,
            bottom: false,
            child: Scaffold(
              backgroundColor: ss.settings.windowEffect.value != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background,
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                  preferredSize: Size(ns.width(context), (kIsDesktop ? (!iOS ? 25 : 5) : 0) + 90 * (iOS ? ss.settings.avatarScale.value : 0) + (!iOS ? kToolbarHeight : 0)),
                  child: iOS
                  ? CupertinoHeader(controller: controller)
                  : MaterialHeader(controller: controller) as PreferredSizeWidget),
              body: Actions(
                actions: {
                  if (ss.settings.enablePrivateAPI.value)
                    ReplyRecentIntent: ReplyRecentAction(widget.chatGuid),
                  if (ss.settings.enablePrivateAPI.value)
                    HeartRecentIntent: HeartRecentAction(widget.chatGuid),
                  if (ss.settings.enablePrivateAPI.value)
                    LikeRecentIntent: LikeRecentAction(widget.chatGuid),
                  if (ss.settings.enablePrivateAPI.value)
                    DislikeRecentIntent: DislikeRecentAction(widget.chatGuid),
                  if (ss.settings.enablePrivateAPI.value)
                    LaughRecentIntent: LaughRecentAction(widget.chatGuid),
                  if (ss.settings.enablePrivateAPI.value)
                    EmphasizeRecentIntent: EmphasizeRecentAction(widget.chatGuid),
                  if (ss.settings.enablePrivateAPI.value)
                    QuestionRecentIntent: QuestionRecentAction(widget.chatGuid),
                  OpenChatDetailsIntent: OpenChatDetailsAction(context, widget.chatGuid),
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
                                      child: Obx(() => IgnorePointer(
                                        ignoring: controller.showScrollDown.value ? false : true,
                                        child: AnimatedOpacity(
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
                                              padding: const EdgeInsets.only(top: 3, left: 1),
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
                                      if (!mounted) return;
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
                                      parentController: controller,
                                    ),
                                  ),
                                )
                              ]
                            ),
                          ],
                        ),
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
