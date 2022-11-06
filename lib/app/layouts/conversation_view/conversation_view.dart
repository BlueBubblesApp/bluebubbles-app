import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/gradient_background_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/app/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/app/widgets/components/screen_effects_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:url_launcher/url_launcher.dart';

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
  // message animation
  Message? message;
  Tween<double> tween = Tween<double>(begin: 1, end: 0);
  double offset = 0;
  Control control = Control.stop;

  bool markingAsRead = false;
  bool markedAsRead = false;

  late final ConversationViewController controller = cvc(chat, tag: widget.customService?.tag);
  final GlobalKey key = GlobalKey();

  Chat get chat => widget.chat;

  @override
  void initState() {
    super.initState();

    cm.setActiveChat(chat);
    cm.activeChat!.controller = controller;

    KeyboardVisibilityController().onChange.listen((bool visible) async {
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        final textFieldSize = (key.currentContext?.findRenderObject() as RenderBox?)?.size.height;
        setState(() {
          offset = (textFieldSize ?? 0) > 300 ? 300 : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    cm.setAllInactive();
    controller.close();
    super.dispose();
  }

  Future<bool> send(List<PlatformFile> attachments, String text, String subject, String? replyGuid, String? effectId) async {
    await controller.scrollToBottom();

    for (PlatformFile file in attachments) {
      final message = Message(
        text: "",
        dateCreated: DateTime.now(),
        hasAttachments: true,
        attachments: [
          Attachment(
            isOutgoing: true,
            uti: "public.jpg",
            bytes: file.bytes,
            transferName: file.name,
          ),
        ],
        isFromMe: true,
        handleId: 0,
      );
      message.generateTempGuid();
      message.attachments.first!.guid = message.guid;
      final completer = Completer<void>();
      outq.queue(OutgoingItem(
        type: QueueType.sendAttachment,
        chat: chat,
        message: message,
        completer: completer,
      ));
      await completer.future;
    }

    if (text.isNotEmpty || subject.isNotEmpty) {
      final _message = Message(
        text: text,
        subject: subject,
        threadOriginatorGuid: replyGuid,
        expressiveSendStyleId: effectId,
        dateCreated: DateTime.now(),
        hasAttachments: true,
        isFromMe: true,
        handleId: 0,
      );
      outq.queue(OutgoingItem(
        type: QueueType.sendMessage,
        chat: chat,
        message: _message,
      ));
      final constraints = BoxConstraints(
        maxWidth: ns.width(context) * MessageWidgetMixin.MAX_SIZE,
        minHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize!,
        maxHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize!,
      );
      final renderParagraph = RichText(
        text: TextSpan(
          text: _message.text,
          style: context.theme.extension<BubbleText>()!.bubbleText,
        ),
        maxLines: 1,
      ).createRenderObject(context);
      final renderParagraph2 = RichText(
        text: TextSpan(
          text: _message.subject ?? "",
          style: context.theme.extension<BubbleText>()!.bubbleText,
        ),
        maxLines: 1,
      ).createRenderObject(context);
      final size = renderParagraph.getDryLayout(constraints);
      final size2 = renderParagraph2.getDryLayout(constraints);
      setState(() {
        tween = Tween<double>(
            begin: ns.width(context) - 30,
            end: min(max(size.width, size2.width) + 68,
                ns.width(context) * MessageWidgetMixin.MAX_SIZE + 40));
        control = Control.play;
        message = _message;
      });
    }

    return true;
  }

  Widget buildScrollToBottomFAB(BuildContext context) {
    if (!controller.showScrollDown.value) return const SizedBox.shrink();
    if (ss.settings.skin.value != Skins.iOS) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: FloatingActionButton(
          onPressed: controller.scrollToBottom,
          child: Icon(
            Icons.arrow_downward,
            color: context.theme.colorScheme.onSecondary,
          ),
          backgroundColor: context.theme.colorScheme.secondary,
        ),
      );
    } else {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: EdgeInsets.only(left: 25.0, bottom: 15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.secondary.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: GestureDetector(
                      onTap: controller.scrollToBottom,
                      child: Text(
                        "\u{2193} Scroll to bottom \u{2193}",
                        textAlign: TextAlign.center,
                        style:
                            context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    }
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
                  child: Stack(

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
                            key: key,
                            onSend: send,
                            parentController: controller,
                          ),
                        ),
                      )
                    ]
                  ),
                ),
              ),
            ),
          ),
        )
      ),
    );
  }

  /*@override
  Widget build(BuildContext context) {
    final textField = BlueBubblesTextField(
      key: key,
      onSend: send,
      controller: controller,
    );

    final Widget child = Actions(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Flexible(
              fit: FlexFit.loose,
              child: DeferredPointerHandler(
                child: Stack(children: <Widget>[
                  Positioned.fill(child: ScreenEffectsWidget()),
                  Column(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          MessagesView(
                            key: Key(chat.guid),
                            customService: widget.customService,
                            chat: chat,
                          ),
                           Obx(() => AnimatedOpacity(
                            duration: Duration(milliseconds: 250),
                            opacity: controller.showScrollDown.value ? 1 : 0,
                            curve: Curves.easeInOut,
                            child: buildScrollToBottomFAB(context),
                          )),
                        ],
                      ),
                    ),
                    Obx(() {
                      if (ss.settings.swipeToCloseKeyboard.value ||
                          ss.settings.swipeToOpenKeyboard.value) {
                        return GestureDetector(
                            onPanUpdate: (details) {
                              if (ss.settings.swipeToCloseKeyboard.value &&
                                  details.delta.dy > 0 &&
                                  controller.keyboardOpen) {
                                eventDispatcher.emit("unfocus-keyboard", null);
                              } else if (ss.settings.swipeToOpenKeyboard.value &&
                                  details.delta.dy < 0 &&
                                  !controller.keyboardOpen) {
                                eventDispatcher.emit("focus-keyboard", null);
                              }
                            },
                            child: textField);
                      }
                      return textField;
                    }),
                  ]),
                  AnimatedPositioned(
                    duration: Duration(milliseconds: 300),
                    bottom: message != null ? 62 + offset : 10 + offset,
                    right: 5,
                    curve: Curves.linear,
                    onEnd: () {
                      if (message != null) {
                        setState(() {
                          tween = Tween<double>(begin: 1, end: 0);
                          control = Control.stop;
                          message = null;
                        });
                      }
                    },
                    child: Visibility(
                      visible: message != null,
                      child: CustomAnimationBuilder<double>(
                          control: control,
                          tween: tween,
                          duration: Duration(milliseconds: 250),
                          builder: (context, value, child) {
                            return SentMessageHelper.buildMessageWithTail(
                              context,
                              message,
                              true,
                              false,
                              message?.isBigEmoji ?? false,
                              MessageWidgetMixin.buildMessageSpansAsync(context, message),
                              customWidth: (message?.hasAttachments ?? false) &&
                                      (message?.text?.isEmpty ?? true) &&
                                      (message?.subject?.isEmpty ?? true)
                                  ? null
                                  : value,
                              customColor: (message?.hasAttachments ?? false) &&
                                      (message?.text?.isEmpty ?? true) &&
                                      (message?.subject?.isEmpty ?? true)
                                  ? Colors.transparent
                                  : null,
                              customContent: child,
                            );
                          },
                          child: (message?.hasAttachments ?? false) &&
                                  (message?.text?.isEmpty ?? true) &&
                                  (message?.subject?.isEmpty ?? true)
                              ? MessageAttachments(
                                  message: message,
                                  showTail: true,
                                  showHandle: false,
                                )
                              : null),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
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
            child: Obx(
              () {
                final Rx<Color> _backgroundColor =
                    (ss.settings.windowEffect.value == WindowEffect.disabled
                            ? context.theme.colorScheme.background
                            : Colors.transparent)
                        .obs;

                if (kIsDesktop) {
                  ss.settings.windowEffect.listen((WindowEffect effect) {
                    if (mounted) {
                      _backgroundColor.value =
                          effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background;
                    }
                  });
                }

                return Scaffold(
                  backgroundColor: _backgroundColor.value,
                  appBar: buildConversationViewHeader(context),
                  body: Obx(() => adjustBackground.value
                      ? MirrorAnimationBuilder<Movie>(
                          tween: gradientTween.value,
                          curve: Curves.fastOutSlowIn,
                          duration: Duration(seconds: 3),
                          builder: (context, anim, child) {
                            return Container(
                              decoration: adjustBackground.value
                                  ? BoxDecoration(
                                      gradient:
                                          LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, stops: [
                                      anim.get("color1"),
                                      anim.get("color2")
                                    ], colors: [
                                      context.theme.colorScheme
                                          .bubble(context, chat.isIMessage)
                                          .withOpacity(0.5),
                                      context.theme.colorScheme.background,
                                    ]))
                                  : null,
                              child: child,
                            );
                          },
                          child: child,
                        )
                      : child
                  ),
                );
              },
            ),
          )),
    );
  }*/

  void openDetails() {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          hideInSplitView: true,
          child: ConversationDetails(
            chat: chat,
          ),
        ),
      ),
    );
  }

  void markChatAsRead() {
    void setProgress(bool val) {
      if (mounted) {
        setState(() {
          markingAsRead = val;

          if (!val) {
            markedAsRead = true;
          }
        });
      }

      // Unset the marked icon
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            markedAsRead = false;
          });
        }
      });
    }

    // Set that we are
    setProgress(true);

    http.markChatRead(chat.guid).then((_) {
      setProgress(false);
    }).catchError((_) {
      setProgress(false);
    });
  }

  PreferredSizeWidget buildConversationViewHeader(BuildContext context) {
    Color? fontColor = context.theme.colorScheme.onBackground;
    Color? fontColor2 = context.theme.colorScheme.outline;
    String? title = chat.title;

    final hideTitle = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
    final generateTitle =
        ss.settings.redactedMode.value && ss.settings.generateFakeContactNames.value;

    if (generateTitle) {
      title = chat.participants.length > 1 ? "Group Chat" : chat.participants[0].fakeName;
    } else if (hideTitle) {
      fontColor = Colors.transparent;
      fontColor2 = Colors.transparent;
    }

    if (ss.settings.skin.value == Skins.Material ||
        ss.settings.skin.value == Skins.Samsung) {
      return AppBar(
        toolbarHeight: kIsDesktop ? 70 : null,
        systemOverlayStyle:
        context.theme.colorScheme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: GestureDetector(
            onTap: () async {
              if (!chat.isGroup) {
                final handle = chat.handles.first;
                final contact = handle.contact;
                if (contact == null) {
                  await mcs.invokeMethod("open-contact-form",
                      {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
                } else {
                  await mcs.invokeMethod("view-contact-form", {'id': contact.id});
                }
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: context.theme.textTheme.titleLarge!.apply(color: fontColor),
                ),
                if (ss.settings.skin.value == Skins.Samsung &&
                    (chat.isGroup || (!title.isPhoneNumber && !title.isEmail)))
                  Text(
                    generateTitle
                        ? ""
                        : chat.isGroup
                        ? "${chat.participants.length} recipients"
                        : chat.participants[0].address,
                    style: context.theme.textTheme.labelLarge!.apply(color: fontColor2),
                  ),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          child: Container(
            color: context.theme.colorScheme.properSurface,
            height: 0.5,
          ),
          preferredSize: Size.fromHeight(0.5),
        ),
        leading: Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: buildBackButton(context, callback: () {
            if (ls.isBubble) {
              SystemNavigator.pop();
              return false;
            }
            eventDispatcher.emit("update-highlight", null);
            return true;
          }),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: context.theme.colorScheme.background,
        actionsIconTheme: IconThemeData(color: context.theme.colorScheme.primary),
        iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
        actions: [
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Obx(() {
              if (ss.settings.showConnectionIndicator.value) {
                return Obx(() => getIndicatorIcon(socket.state.value, size: 12));
              } else {
                return SizedBox.shrink();
              }
            }),
          ),
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Obx(() {
              if (ss.settings.privateManualMarkAsRead.value && markingAsRead) {
                return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              backgroundColor: context.theme.colorScheme.properSurface,
                              valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary)),
                        )));
              } else {
                return SizedBox.shrink();
              }
            }),
          ),
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Obx(() {
              if (ss.settings.enablePrivateAPI.value &&
                  ss.settings.privateManualMarkAsRead.value &&
                  !markingAsRead) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    child: Icon(
                      (markedAsRead)
                          ? ss.settings.skin.value == Skins.iOS
                          ? CupertinoIcons.check_mark_circled_solid
                          : Icons.check_circle
                          : ss.settings.skin.value == Skins.iOS
                          ? CupertinoIcons.check_mark_circled
                          : Icons.check_circle_outline,
                      color: (markedAsRead) ? HexColor('43CC47').withAlpha(200) : fontColor,
                    ),
                    onTap: markChatAsRead,
                  ),
                );
              } else {
                return SizedBox.shrink();
              }
            }),
          ),
          if ((!chat.isGroup &&
              (chat.participants[0].address.isPhoneNumber || chat.participants[0].address.isEmail)) &&
              !kIsDesktop &&
              !kIsWeb)
            Padding(
              padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  child: Icon(
                    chat.participants[0].address.isPhoneNumber ? Icons.call : Icons.email,
                    color: fontColor,
                  ),
                  onTap: () {
                    if (chat.participants[0].address.isPhoneNumber) {
                      launchUrl(Uri(scheme: "tel", path: chat.participants[0].address));
                    } else {
                      launchUrl(Uri(scheme: "mailto", path: chat.participants[0].address));
                    }
                  },
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                child: Icon(
                  ss.settings.skin.value == Skins.iOS
                      ? CupertinoIcons.ellipsis
                      : Icons.more_vert,
                  color: fontColor,
                ),
                onTap: openDetails,
              ),
            ),
          ),
        ],
      );
    }

    return PreferredSize(preferredSize: Size.zero,child: Container(),);
  }
}
