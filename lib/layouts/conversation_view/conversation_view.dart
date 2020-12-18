import 'dart:io';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
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
    this.type = ChatSelectorTypes.ALL,
  }) : super(key: key);

  final Chat chat;
  final Function(List<UniqueContact> items) onSelect;
  final Widget selectIcon;
  final String customHeading;
  final String type;
  final bool isCreator;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends State<ConversationView>
    with ConversationViewMixin {
  @override
  void initState() {
    super.initState();

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
    if (isCreator && chat == null) {
      chat = await createChat();

      if (chat == null) return false;
      initCurrentChat(chat);
      initConversationViewState();
      initChatSelector();

      // Fetch messages
      messageBloc = initMessageBloc();
      messageBloc.getMessages();
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
      ActionHandler.sendMessage(chat, text);
    }
    if (isCreator) {
      isCreator = false;
      setState(() {});
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    currentChat?.isAlive = true;

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      extendBodyBehindAppBar: !isCreator,
      appBar: !isCreator
          ? buildConversationViewHeader()
          : buildChatSelectorHeader(),
      resizeToAvoidBottomInset: false,
      body: FooterLayout(
        footer: KeyboardAttachable(
          child: widget.onSelect == null
              ? BlueBubblesTextField(
                  onSend: send,
                  isCreator: isCreator,
                  existingAttachments:
                      isCreator ? widget.existingAttachments : null,
                  existingText: isCreator ? widget.existingText : null,
                )
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
                      messageBloc: messageBloc ?? initMessageBloc(),
                      showHandle: chat.participants.length > 1,
                      chat: chat,
                    )
                  : buildChatSelectorBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.onSelect != null
          ? FloatingActionButton(
              onPressed: () => widget.onSelect(selected),
              child: widget.selectIcon ??
                  Icon(
                    Icons.check,
                    color: Theme.of(context).textTheme.bodyText1.color,
                  ),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
    );
  }
}
