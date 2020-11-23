import 'dart:io';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:flutter/material.dart';

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
    with ConversationViewMixin, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    if (widget.chat != null) {
      currentChat = CurrentChat.getCurrentChat(widget.chat);
      currentChat.init();
      currentChat.updateChatAttachments().then((value) {
        if (this.mounted) setState(() {});
      });
      currentChat.stream.listen((event) {
        if (this.mounted) setState(() {});
      });
    }

    isCreator = widget.isCreator ?? false;
    chat = widget.chat;
    initChatSelector();
    initConversationViewState();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    didChangeDependenciesConversationView();
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!this.mounted) return;
    currentChat?.isAlive = true;
  }

  @override
  void dispose() {
    if (currentChat != null) {
      currentChat.disposeAudioControllers();
      currentChat.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);

    // Switching chat to null will clear the currently active chat
    NotificationManager().switchChat(null);
    super.dispose();
  }

  Future<bool> send(List<File> attachments, String text) async {
    if (isCreator && chat == null) {
      chat = await createChat();
      if (chat == null) return false;
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
      body: Column(
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
                    messageBloc: messageBloc ?? initMessageBloc(),
                    showHandle: chat.participants.length > 1,
                    chat: chat,
                  )
                : buildChatSelectorBody(),
          ),
          if (widget.onSelect == null)
            BlueBubblesTextField(
              onSend: send,
              isCreator: isCreator,
              existingAttachments:
                  isCreator ? widget.existingAttachments : null,
              existingText: isCreator ? widget.existingText : null,
            ),
        ],
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
