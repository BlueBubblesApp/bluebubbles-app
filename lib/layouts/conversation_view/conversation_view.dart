import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/layouts/widgets/screen_effects_widget.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:slugify/slugify.dart';

abstract class ChatSelectorTypes {
  static const String ALL = "ALL";
  static const String ONLY_EXISTING = "ONLY_EXISTING";
  static const String ONLY_CONTACTS = "ONLY_CONTACTS";
}

class ConversationView extends StatefulWidget {
  final List<PlatformFile> existingAttachments;
  final String? existingText;
  final List<UniqueContact> selected;

  ConversationView({
    Key? key,
    this.chat,
    this.previousChat,
    this.existingAttachments = const [],
    this.existingText,
    this.isCreator = false,
    this.onSelect,
    this.selectIcon,
    this.customHeading,
    this.customMessageBloc,
    this.onMessagesViewComplete,
    this.selected = const [],
    this.type = ChatSelectorTypes.ALL,
  }) : super(key: key);

  final Chat? chat;
  final Chat? previousChat;
  final Function(List<UniqueContact> items)? onSelect;
  final Widget? selectIcon;
  final String? customHeading;
  final String type;
  final bool isCreator;
  final MessageBloc? customMessageBloc;
  final Function? onMessagesViewComplete;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends State<ConversationView> with ConversationViewMixin, WidgetsBindingObserver {
  List<PlatformFile> existingAttachments = [];
  String? existingText;
  Brightness? brightness;
  Color? previousBackgroundColor;
  bool gotBrightness = false;
  Message? message;
  Tween<double> tween = Tween<double>(begin: 1, end: 0);
  double offset = 0;
  CustomAnimationControl controller = CustomAnimationControl.stop;
  bool wasCreator = false;
  GlobalKey key = GlobalKey();
  Worker? worker;
  bool widgetsBuilt = false;
  final RxBool adjustBackground = RxBool(false);

  @override
  void initState() {
    super.initState();

    getAdjustBackground();

    selected = widget.selected.isEmpty ? [] : widget.selected;
    existingAttachments = widget.existingAttachments.isEmpty ? [] : widget.existingAttachments;
    existingText = widget.existingText;

    // Initialize the current chat state
    if (widget.chat != null) {
      initChatController(widget.chat!);
    }

    isCreator = widget.isCreator;
    chat = widget.chat;
    previousChat = widget.previousChat;

    if (chat != null) {
      prefs.setString('lastOpenedChat', chat!.guid);
    }

    if (widget.selected.isEmpty) {
      initChatSelector();
    }
    initConversationViewState();

    LifeCycleManager().stream.listen((event) {
      if (!mounted) return;
      currentChat?.isActive = true;
    });

    ever(ChatBloc().chats, (List<Chat> chats) {
      currentChat = ChatManager().activeChat;

      if (currentChat != null) {
        Chat? _chat = chats.firstWhereOrNull((e) => e.guid == widget.chat?.guid);
        if (_chat != null) {
          _chat.getParticipants();
          currentChat!.chat = _chat;
          if (mounted) setState(() {});
        }
      }
    });

    KeyboardVisibilityController().onChange.listen((bool visible) async {
      await Future.delayed(Duration(milliseconds: 500));
      final textFieldSize = (key.currentContext?.findRenderObject() as RenderBox?)?.size.height;
      if (mounted) {
        setState(() {
          offset = (textFieldSize ?? 0) > 300 ? 300 : 0;
        });
      }
    });

    // Set the custom message bloc if provided (and there is not already an existing one)
    if (widget.customMessageBloc != null && messageBloc == null) {
      messageBloc = widget.customMessageBloc;
    } else if (widget.chat != null && messageBloc == null) {
      messageBloc = MessageBloc(widget.chat);
    }

    initListener();

    // Bind the lifecycle events
    WidgetsBinding.instance!.addObserver(this);

    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      ChatManager().setActiveChat(chat);
      if (widget.isCreator) {
        setState(() {
          getShowAlert();
        });
      }
    });
  }

  void getAdjustBackground() async {
    var lightTheme = ThemeObject.getLightTheme(fetchData: false);
    var darkTheme = ThemeObject.getDarkTheme(fetchData: false);
    if ((lightTheme.gradientBg && !ThemeObject.inDarkMode(Get.context!)) ||
        (darkTheme.gradientBg && ThemeObject.inDarkMode(Get.context!))) {
      if (adjustBackground.value != true) adjustBackground.value = true;
    } else {
      if (adjustBackground.value != false) adjustBackground.value = false;
    }
  }

  void getShowAlert() async {
    shouldShowAlert = widget.isCreator && (await SettingsManager().getMacOSVersion())! >= 11;
  }

  void initListener() {
    if (messageBloc != null) {
      worker = ever<MessageBlocEvent?>(messageBloc!.event, (event) async {
        // Get outta here if we don't have a chat "open"
        if (currentChat == null) return;
        if (event == null) return;

        // Skip deleted messages
        if (event.message != null && event.message!.dateDeleted != null) return;

        if (event.type == MessageBlocEventType.insert && mounted && event.outGoing) {
          final constraints = BoxConstraints(
            maxWidth: CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE,
            minHeight: Theme.of(context).textTheme.bodyText2!.fontSize!,
            maxHeight: Theme.of(context).textTheme.bodyText2!.fontSize!,
          );
          final renderParagraph = RichText(
            text: TextSpan(
              text: event.message!.text,
              style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
            ),
            maxLines: 1,
          ).createRenderObject(context);
          final renderParagraph2 = RichText(
            text: TextSpan(
              text: event.message!.subject ?? "",
              style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
            ),
            maxLines: 1,
          ).createRenderObject(context);
          final size = renderParagraph.getDryLayout(constraints);
          final size2 = renderParagraph2.getDryLayout(constraints);
          if (!(event.message?.hasAttachments ?? false) &&
              (!(event.message?.text?.isEmpty ?? true) || !(event.message?.subject?.isEmpty ?? true))) {
            setState(() {
              tween = Tween<double>(
                  begin: CustomNavigator.width(context) - 30,
                  end: min(max(size.width, size2.width) + 68,
                      CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE + 40));
              controller = CustomAnimationControl.play;
              message = event.message;
            });
          } else {
            setState(() {
              isCreator = false;
              wasCreator = true;
              existingText = "";
              existingAttachments = [];
            });
          }
        }
      });
    }
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (ChatManager().hasActiveChat) didChangeDependenciesConversationView();
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      Logger.info("Removing ChatController imageData");
      ChatManager().activeChat?.imageData.clear();
    }
    if (widgetsBuilt && ChatManager().hasActiveChat) didChangeDependenciesConversationView();
  }

  @override
  void dispose() {
    if (currentChat != null) {
      currentChat!.disposeControllers();
      currentChat!.dispose();
    }
    super.dispose();
  }

  Future<bool> send(
      List<PlatformFile> attachments, String text, String subject, String? replyGuid, String? effectId) async {
    bool isDifferentChat = currentChat == null || currentChat?.chat.guid != chat?.guid;
    bool alreadySent = false;
    if (isCreator!) {
      if (chat == null && selected.length == 1) {
        try {
          if (kIsWeb) {
            chat = await Chat.findOneWeb(chatIdentifier: slugify(selected[0].address!, delimiter: ''));
          } else {
            chat = Chat.findOne(chatIdentifier: slugify(selected[0].address!, delimiter: ''));
          }
        } catch (_) {}
      }

      if (chat == null &&
          (await SettingsManager().getMacOSVersion() ?? 10) >
              10 /*&& SettingsManager().settings.enablePrivateAPI.value == false*/) {
        if (searchQuery.isNotEmpty) {
          selected.add(UniqueContact(address: searchQuery, displayName: searchQuery));
          resetCursor();
        }
        if (selected.length > 1) {
          showSnackbar("Error", "Creating group chats is currently unsupported on Big Sur!");
          return false;
        } else if (isNullOrEmpty(text, trimString: true)!) {
          showSnackbar("Error",
              "Starting new chats with an attachment is currently unsupported on Big Sur! Please start the chat with a text instead.");
          return false;
        } else if (!isNullOrEmpty(cleansePhoneNumber(selected.firstOrNull?.address ?? ""))!) {
          chat = await ActionHandler.createChatBigSur(
              context, cleansePhoneNumber(selected.firstOrNull?.address ?? ""), text);
          if (chat == null) {
            Navigator.of(context).pop();
            showSnackbar("Error", "Failed to create chat.");
            return false;
          } else {
            alreadySent = true;
          }
        }
      } else {
        chat ??= await createChat();
      }

      // If the chat is still null, return false
      if (chat == null) return false;

      prefs.setString('lastOpenedChat', chat!.guid);

      // If the current chat is null, set it
      if (isDifferentChat) {
        initChatController(chat!);
      }

      bool isDifferentBloc = messageBloc == null || messageBloc?.currentChat?.guid != chat!.guid;

      // Fetch messages
      if (isDifferentBloc) {
        // Init the states
        messageBloc = initMessageBloc();
        messageBloc!.getMessages();
      }
      if (worker == null) {
        initListener();
      }
    } else {
      if (isDifferentChat) {
        initChatController(chat!);
      }
    }

    if (attachments.isNotEmpty && chat != null) {
      for (int i = 0; i < attachments.length; i++) {
        OutgoingQueue().add(
          QueueItem(
            event: "send-attachment",
            item: AttachmentSender(
              attachments[i],
              chat!,
              // This means to send the text when the last attachment is sent
              // If we switched this to i == 0, then it will be send with the first attachment
              i == attachments.length - 1 && !alreadySent ? text : "",
            ),
          ),
        );
      }
    } else if (chat != null && !alreadySent) {
      // We include messageBloc here because the bloc listener may not be instantiated yet
      ActionHandler.sendMessage(chat!, text,
          messageBloc: messageBloc, subject: subject, replyGuid: replyGuid, effectId: effectId);
    }

    if (alreadySent) {
      setState(() {
        tween = Tween<double>(begin: 1, end: 0);
        controller = CustomAnimationControl.stop;
        message = null;
        existingText = "";
        existingAttachments = [];
        isCreator = false;
        wasCreator = true;
      });
    }

    return true;
  }

  Widget buildFAB() {
    if (widget.onSelect != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: () => widget.onSelect!(selected),
          child: widget.selectIcon ??
              Icon(
                Icons.check,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }

    return Container();
  }

  Widget buildScrollToBottomFAB(BuildContext context) {
    if (currentChat != null &&
        currentChat!.showScrollDown.value &&
        (SettingsManager().settings.skin.value == Skins.Material ||
            SettingsManager().settings.skin.value == Skins.Samsung)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: FloatingActionButton(
          onPressed: currentChat!.scrollToBottom,
          child: Icon(
            Icons.arrow_downward,
            color: Theme.of(context).textTheme.bodyText1!.color,
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    } else if (currentChat != null &&
        currentChat!.showScrollDown.value &&
        SettingsManager().settings.skin.value == Skins.iOS) {
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
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: GestureDetector(
                      onTap: currentChat!.scrollToBottom,
                      child: Text(
                        "\u{2193} Scroll to bottom \u{2193}",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyText1,
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
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration.zero, () {
      widgetsBuilt = true;
    });
    currentChat?.isActive = true;

    if (messageBloc == null && !isCreator!) {
      messageBloc = initMessageBloc();
    }

    Widget textField = BlueBubblesTextField(
      key: key,
      onSend: send,
      wasCreator: wasCreator,
      isCreator: isCreator,
      existingAttachments: existingAttachments,
      existingText: existingText,
      chatGuid: widget.chat?.guid,
    );

    final Widget child = Actions(
        actions: isCreator! || !SettingsManager().settings.enablePrivateAPI.value || widget.chat == null
            ? {}
            : {
                ReplyRecentIntent: ReplyRecentAction(messageBloc!),
                HeartRecentIntent: HeartRecentAction(messageBloc!, widget.chat!),
                LikeRecentIntent: LikeRecentAction(messageBloc!, widget.chat!),
                DislikeRecentIntent: DislikeRecentAction(messageBloc!, widget.chat!),
                LaughRecentIntent: LaughRecentAction(messageBloc!, widget.chat!),
                EmphasizeRecentIntent: EmphasizeRecentAction(messageBloc!, widget.chat!),
                QuestionRecentIntent: QuestionRecentAction(messageBloc!, widget.chat!),
                OpenChatDetailsIntent: OpenChatDetailsAction(context, messageBloc!, widget.chat!),
              },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (isCreator!)
              ChatSelectorTextField(
                controller: chatSelectorController,
                onRemove: (UniqueContact item) {
                  if (item.isChat) {
                    selected.removeWhere((e) => (e.chat?.guid) == item.chat!.guid);
                  } else {
                    selected.removeWhere((e) => e.address == item.address);
                  }
                  fetchChatController();
                  filterContacts();
                  resetCursor();
                  if (mounted) setState(() {});
                },
                onSelected: onSelected,
                isCreator: widget.isCreator,
                allContacts: contacts,
                selectedContacts: selected,
              ),
            if (isCreator!)
              Obx(() {
                if (!ChatBloc().hasChats.value) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Loading existing chats...",
                              style: Theme.of(context).textTheme.subtitle1,
                            ),
                          ),
                          buildProgressIndicator(context, size: 15),
                        ],
                      ),
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              }),
            Flexible(
              fit: FlexFit.loose,
              child: DeferredPointerHandler(
                child: Stack(children: <Widget>[
                  Positioned.fill(child: ScreenEffectsWidget()),
                  Column(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Expanded(
                      child: Obx(
                        () => fetchingChatController.value
                            ? Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Loading chat...",
                                          style: Theme.of(context).textTheme.subtitle1,
                                        ),
                                      ),
                                      buildProgressIndicator(context, size: 15),
                                    ],
                                  ),
                                ),
                              )
                            : (searchQuery.isEmpty || !isCreator!) && chat != null
                                ? Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      MessagesView(
                                        key: Key(chat?.guid ?? "unknown-chat"),
                                        messageBloc: messageBloc,
                                        showHandle: chat!.participants.length > 1,
                                        chat: chat,
                                        initComplete: widget.onMessagesViewComplete,
                                      ),
                                      currentChat != null
                                          ? Obx(() => AnimatedOpacity(
                                                duration: Duration(milliseconds: 250),
                                                opacity: currentChat!.showScrollDown.value ? 1 : 0,
                                                curve: Curves.easeInOut,
                                                child: buildScrollToBottomFAB(context),
                                              ))
                                          : Container(),
                                    ],
                                  )
                                : buildChatSelectorBody(),
                      ),
                    ),
                    if (widget.onSelect == null)
                      Obx(() {
                        if (SettingsManager().settings.swipeToCloseKeyboard.value ||
                            SettingsManager().settings.swipeToOpenKeyboard.value) {
                          return GestureDetector(
                              onPanUpdate: (details) {
                                if (SettingsManager().settings.swipeToCloseKeyboard.value &&
                                    details.delta.dy > 0 &&
                                    (currentChat?.keyboardOpen ?? false)) {
                                  EventDispatcher().emit("unfocus-keyboard", null);
                                } else if (SettingsManager().settings.swipeToOpenKeyboard.value &&
                                    details.delta.dy < 0 &&
                                    !(currentChat?.keyboardOpen ?? false)) {
                                  EventDispatcher().emit("focus-keyboard", null);
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
                          controller = CustomAnimationControl.stop;
                          message = null;
                          existingText = "";
                          existingAttachments = [];
                          isCreator = false;
                          wasCreator = true;
                        });
                      }
                    },
                    child: Visibility(
                      visible: message != null,
                      child: CustomAnimation<double>(
                          control: controller,
                          tween: tween,
                          duration: Duration(milliseconds: 250),
                          builder: (context, child, value) {
                            return SentMessageHelper.buildMessageWithTail(
                              context,
                              message,
                              true,
                              false,
                              message?.isBigEmoji() ?? false,
                              MessageWidgetMixin.buildMessageSpansAsync(context, message),
                              currentChat: currentChat,
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
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
            ? Colors.transparent
            : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(primaryColor: chat?.isTextForwarding ?? false ? Colors.green : Theme.of(context).primaryColor),
        child: Builder(
          builder: (context) {
            return WillPopScope(
              onWillPop: () async {
                if (LifeCycleManager().isBubble) {
                  ChatManager().setActiveChat(null);
                  SystemNavigator.pop();
                }
                return !LifeCycleManager().isBubble;
              },
              child: Obx(
                () {
                  chat?.getTitle();
                  return Scaffold(
                    backgroundColor: Theme.of(context).backgroundColor,
                    extendBodyBehindAppBar: !isCreator!,
                    appBar: (!isCreator! || false.obs.value) // Necessary
                        ? buildConversationViewHeader(context) as PreferredSizeWidget?
                        : buildChatSelectorHeader() as PreferredSizeWidget?,
                    body: Obx(() => adjustBackground.value
                        ? MirrorAnimation<MultiTweenValues<String>>(
                            tween: ConversationViewMixin.gradientTween.value,
                            curve: Curves.fastOutSlowIn,
                            duration: Duration(seconds: 3),
                            builder: (context, child, anim) {
                              return Container(
                                decoration:
                                    (searchQuery.isEmpty || !isCreator!) && chat != null && adjustBackground.value
                                        ? BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment.topRight,
                                                end: Alignment.bottomLeft,
                                                stops: [
                                                anim.get("color1"),
                                                anim.get("color2")
                                              ],
                                                colors: [
                                                AdaptiveTheme.of(context).mode == AdaptiveThemeMode.light
                                                    ? Theme.of(context).primaryColor.lightenPercent(20)
                                                    : Theme.of(context).primaryColor.darkenPercent(20),
                                                Theme.of(context).backgroundColor
                                              ]))
                                        : null,
                                child: child,
                              );
                            },
                            child: child,
                          )
                        : child),
                    floatingActionButton: AnimatedOpacity(
                        duration: Duration(milliseconds: 250), opacity: 1, curve: Curves.easeInOut, child: buildFAB()),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
