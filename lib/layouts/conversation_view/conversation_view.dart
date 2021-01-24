import 'dart:io';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/utils.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_attachable/keyboard_attachable.dart';

import '../../repository/models/chat.dart';

abstract class ChatSelectorTypes {
  static const String ALL = "ALL";
  static const String ONLY_EXISTING = "ONLY_EXISTING";
  static const String ONLY_CONTACTS = "ONLY_CONTACTS";
}

class ConversationView extends StatefulWidget {
  final List<File> existingAttachments;
  final String existingText;
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
    this.type = ChatSelectorTypes.ALL,
  }) : super(key: key);

  final Chat chat;
  final Function(List<UniqueContact> items) onSelect;
  final Widget selectIcon;
  final String customHeading;
  final String type;
  final bool isCreator;
  final MessageBloc customMessageBloc;
  final Function onMessagesViewComplete;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends State<ConversationView>
    with ConversationViewMixin {
  List<File> existingAttachments;
  String existingText;
  bool keyboardOpen = false;
  bool keyboardClosed = false;

  @override
  void initState() {
    super.initState();

    this.existingAttachments = widget.existingAttachments;
    this.existingText = widget.existingText;

    // Initialize the current chat state
    if (widget.chat != null) {
      initCurrentChat(widget.chat);
    }

    isCreator = widget.isCreator ?? false;
    chat = widget.chat;

    initChatSelector();
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
    EventDispatcher().stream.listen((event) {
      if (!event.containsKey("type")) return;
      if (event["type"] == "keyboard-is-open") {
        keyboardOpen = event.containsKey("data") ? event["data"] : false;
      }
      if (event["type"] == "keyboard-is-closed") {
        keyboardClosed = event.containsKey("data") ? event["data"] : false;
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
    if (isCreator) {
      if (chat == null && selected.length == 1) {
        try {
          chat = await Chat.findOne(
              {"chatIdentifier": sanitizeAddress(selected[0].address)});
        } catch (ex) {}
      }

      // If the chat is null, create it
      if (chat == null) chat = await createChat();

      // If the chat is still null, return false
      if (chat == null) return false;

      // If the current chat is null, set it
      bool isDifferentChat =
          currentChat == null || currentChat?.chat?.guid != chat.guid;
      if (isDifferentChat) {
        initCurrentChat(chat);
      }

      // Fetch messages
      if (isDifferentChat || messageBloc == null) {
        // Init the states
        initCurrentChat(chat);
        initConversationViewState();

        messageBloc = initMessageBloc();
        messageBloc.getMessages();
      }
    }

    // If the current chat is null, set it
    bool isDifferentChat =
        currentChat == null || currentChat?.chat?.guid != chat.guid;
    if (isDifferentChat) {
      initCurrentChat(chat);
    }

    if (attachments.length > 0) {
      for (int i = 0; i < attachments.length; i++) {
        OutgoingQueue().add(
          new QueueItem(
            event: "send-attachment",
            item: new AttachmentSender(
              attachments[i],
              chat,
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
        SettingsManager().settings.skin == Skins.Material) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: () {
            currentChat.scrollToBottom();
            if (SettingsManager().settings.openKeyboardOnSTB) {
              SystemChannels.textInput
                                .invokeMethod('TextInput.show');
            }
          },
          child: Icon(
            Icons.arrow_downward,
            color: Theme.of(context).textTheme.bodyText1.color,
          ),
          backgroundColor: Theme.of(context).accentColor,
        ),
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: !isCreator
            ? buildConversationViewHeader()
            : buildChatSelectorHeader(),
        resizeToAvoidBottomInset: false,
        body: FooterLayout(
          footer: KeyboardAttachable(
            child: widget.onSelect == null
                ? (SettingsManager().settings.swipeToCloseKeyboard)
                    ? GestureDetector(
                        onPanUpdate: (details) {
                          if (details.delta.dy > 0 && keyboardOpen) {
                            SystemChannels.textInput
                                .invokeMethod('TextInput.hide');
                          }
                          else if (details.delta.dy < 0) {
                            SystemChannels.textInput
                                .invokeMethod('TextInput.show');
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
                      selected.removeWhere(
                          (e) => (e.chat?.guid ?? null) == item.chat.guid);
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
                  return buildFAB();
                },
              )
            : buildFAB(),
      ),
    );
  }
}
