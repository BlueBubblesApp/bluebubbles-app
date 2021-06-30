import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:keyboard_attachable/keyboard_attachable.dart';
import 'package:slugify/slugify.dart';

abstract class ChatSelectorTypes {
  static const String ALL = "ALL";
  static const String ONLY_EXISTING = "ONLY_EXISTING";
  static const String ONLY_CONTACTS = "ONLY_CONTACTS";
}

class ConversationView extends StatefulWidget {
  final List<File> existingAttachments;
  final String existingText;
  final List<UniqueContact> selected;

  ConversationView({
    Key key,
    this.chat,
    this.existingAttachments,
    this.existingText,
    this.isCreator,
    this.onSelect,
    this.selectIcon,
    this.customHeading,
    this.customMessageBloc,
    this.onMessagesViewComplete,
    this.selected,
    this.type = ChatSelectorTypes.ALL,
    this.showSnackbar = false,
  }) : super(key: key);

  final Chat chat;
  final Function(List<UniqueContact> items) onSelect;
  final Widget selectIcon;
  final String customHeading;
  final String type;
  final bool isCreator;
  final MessageBloc customMessageBloc;
  final Function onMessagesViewComplete;
  final bool showSnackbar;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends State<ConversationView> with ConversationViewMixin {
  List<File> existingAttachments;
  String existingText;
  List<DisplayMode> modes;
  DisplayMode currentMode;
  Brightness brightness;
  Color previousBackgroundColor;
  bool gotBrightness = false;

  bool wasCreator = false;

  @override
  void initState() {
    super.initState();

    this.selected = widget.selected ?? [];
    this.existingAttachments = widget.existingAttachments;
    this.existingText = widget.existingText;

    // Initialize the current chat state
    if (widget.chat != null) {
      initCurrentChat(widget.chat);
    }

    isCreator = widget.isCreator ?? false;
    chat = widget.chat;

    if (widget.selected == null) {
      initChatSelector();
    }
    initConversationViewState();

    LifeCycleManager().stream.listen((event) {
      if (!this.mounted) return;
      currentChat?.isAlive = true;
    });

    ChatBloc().chatStream.listen((event) async {
      if (currentChat == null) {
        currentChat = CurrentChat.getCurrentChat(widget.chat);
      }

      if (currentChat != null) {
        Chat _chat = await Chat.findOne({"guid": currentChat.chat.guid});
        await _chat.getParticipants();
        currentChat.chat = _chat;
        if (this.mounted) setState(() {});
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (widget.showSnackbar) {
        showSnackbar('Warning', 'Support for creating chats is currently limited on MacOS 11 (Big Sur) and up due to limitations imposed by Apple');
      }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    didChangeDependenciesConversationView();
  }

  @override
  void dispose() {
    if (currentChat != null) {
      currentChat.disposeControllers();
      currentChat.dispose();
    }

    // Switching chat to null will clear the currently active chat
    NotificationManager().switchChat(null);
    super.dispose();
  }

  Future<bool> send(List<File> attachments, String text) async {
    bool isDifferentChat = currentChat == null || currentChat?.chat?.guid != chat?.guid;

    if (isCreator) {
      if (chat == null && selected.length == 1) {
        try {
          chat = await Chat.findOne({"chatIdentifier": Slugify(selected[0].address, delimiter: '')});
        } catch (ex) {}
      }

      // If the chat is null, create it
      if (chat == null) chat = await createChat();

      // If the chat is still null, return false
      if (chat == null) return false;

      // If the current chat is null, set it
      if (isDifferentChat) {
        initCurrentChat(chat);
      }

      bool isDifferentBloc = messageBloc == null || messageBloc?.currentChat?.guid != chat.guid;

      // Fetch messages
      if (isDifferentBloc) {
        // Init the states
        messageBloc = initMessageBloc();
        messageBloc.getMessages();
      }
    } else {
      if (isDifferentChat) {
        initCurrentChat(chat);
      }
    }

    if (attachments.length > 0) {
      for (int i = 0; i < attachments.length; i++) {
        OutgoingQueue().add(
          new QueueItem(
            event: "send-attachment",
            item: new AttachmentSender(
              attachments[i],
              chat,
              // This means to send the text when the last attachment is sent
              // If we switched this to i == 0, then it will be send with the first attachment
              i == attachments.length - 1 ? text : "",
            ),
          ),
        );
      }
    } else {
      // We include messageBloc here because the bloc listener may not be instantiated yet
      ActionHandler.sendMessage(chat, text, messageBloc: messageBloc);
    }

    if (isCreator) {
      isCreator = false;
      wasCreator = true;
      this.existingText = "";
      this.existingAttachments = [];
      setState(() {});
    }

    return true;
  }

  Widget buildFAB() {
    if (widget.onSelect != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: () => widget.onSelect(selected),
          child: widget.selectIcon ??
              Icon(
                Icons.check,
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } else if (currentChat != null &&
        currentChat.showScrollDown &&
        (SettingsManager().settings.skin == Skins.Material || SettingsManager().settings.skin == Skins.Samsung)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: currentChat.scrollToBottom,
          child: Icon(
            Icons.arrow_downward,
            color: Theme.of(context).textTheme.bodyText1.color,
          ),
          backgroundColor: Theme.of(context).accentColor,
        ),
      );
    } else if (currentChat != null && currentChat.showScrollDown && SettingsManager().settings.skin == Skins.IOS) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: EdgeInsets.only(left: 25.0, bottom: 45),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                    color: Theme.of(context).accentColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: GestureDetector(
                      onTap: currentChat.scrollToBottom,
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

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;
    if (this.context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();
    currentChat?.isAlive = true;

    if (widget.customMessageBloc != null && messageBloc == null) {
      messageBloc = widget.customMessageBloc;
    }

    if (messageBloc == null) {
      messageBloc = initMessageBloc();
      messageBloc.getMessages();
    }

    Widget textField = BlueBubblesTextField(
      onSend: send,
      wasCreator: wasCreator,
      isCreator: isCreator,
      existingAttachments: this.existingAttachments,
      existingText: this.existingText,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        extendBodyBehindAppBar: !isCreator,
        appBar: !isCreator ? buildConversationViewHeader() : buildChatSelectorHeader(),
        resizeToAvoidBottomInset: wasCreator,
        body: FooterLayout(
          footer: KeyboardAttachable(
            child: widget.onSelect == null
                ? (SettingsManager().settings.swipeToCloseKeyboard.value)
                    ? GestureDetector(
                        onPanUpdate: (details) {
                          if (details.delta.dy > 0 && (currentChat?.keyboardOpen ?? false)) {
                            EventDispatcher().emit("unfocus-keyboard", null);
                          } else if (details.delta.dy < 0 && !(currentChat?.keyboardOpen ?? false)) {
                            EventDispatcher().emit("focus-keyboard", null);
                          }
                        },
                        child: textField)
                    : textField
                : Container(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (isCreator)
                ChatSelectorTextField(
                  controller: chatSelectorController,
                  onRemove: (UniqueContact item) {
                    if (item.isChat) {
                      selected.removeWhere((e) => (e.chat?.guid ?? null) == item.chat.guid);
                    } else {
                      selected.removeWhere((e) => e.address == item.address);
                    }
                    fetchCurrentChat();
                    filterContacts();
                    resetCursor();
                    if (this.mounted) setState(() {});
                  },
                  onSelected: onSelected,
                  isCreator: widget.isCreator,
                  allContacts: contacts,
                  selectedContacts: selected,
                ),
              Expanded(
                child: (searchQuery.length == 0 || !isCreator) && chat != null
                    ? MessagesView(
                        key: new Key(chat?.guid ?? "unknown-chat"),
                        messageBloc: messageBloc,
                        showHandle: chat.participants.length > 1,
                        chat: chat,
                        initComplete: widget.onMessagesViewComplete,
                      )
                    : buildChatSelectorBody(),
              ),
            ],
          ),
        ),
        floatingActionButton: currentChat != null
            ? StreamBuilder<bool>(
                stream: currentChat.showScrollDownStream.stream,
                builder: (context, snapshot) {
                  return AnimatedOpacity(
                      duration: Duration(milliseconds: 250),
                      opacity: (snapshot?.data ?? false) ? 1 : 0,
                      curve: Curves.easeInOut,
                      child: buildFAB());
                },
              )
            : null,
      ),
    );
  }
}
