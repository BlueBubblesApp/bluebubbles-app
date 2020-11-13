import 'dart:io';
import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBackButton.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart' as Cupertino;
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
  })  : localIsCreator = isCreator ?? false,
        localChat = chat,
        super(key: key);

  final Chat chat;
  final Function(List<UniqueContact> items) onSelect;
  final Widget selectIcon;
  final String customHeading;
  final String type;
  final bool isCreator;

  bool localIsCreator;
  Chat localChat;
  MessageBloc messageBloc;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends State<ConversationView>
    with ChatSelectorMixin, ConversationViewMixin {
  @override
  void initState() {
    super.initState();
    initChatSelector();
    initConversationViewState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    didChangeDependenciesConversationView();
  }

  Future<bool> send(List<File> attachments, String text) async {
    if (widget.localIsCreator && widget.localChat == null) {
      widget.localChat = await createChat();
      if (widget.localChat == null) return false;
    }
    if (attachments.length > 0) {
      for (int i = 0; i < attachments.length; i++) {
        OutgoingQueue().add(
          new QueueItem(
            event: "send-attachment",
            item: new AttachmentSender(
              attachments[i],
              widget.localChat,
              i == attachments.length - 1 ? text : "",
            ),
          ),
        );
      }
    } else {
      ActionHandler.sendMessage(widget.localChat, text);
    }
    if (widget.localIsCreator) {
      widget.localIsCreator = false;
      setState(() {});
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      extendBodyBehindAppBar: !widget.localIsCreator,
      appBar: !widget.localIsCreator
          ? buildConversationViewHeader()
          : buildChatSelectorHeader(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (widget.localIsCreator)
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
            child: widget.localChat != null &&
                    (searchQuery.length == 0 || !widget.localIsCreator)
                ? MessagesView(
                    messageBloc: widget.messageBloc ?? initMessageBloc(),
                    showHandle: widget.localChat.participants.length > 1,
                    chat: widget.localChat,
                  )
                : buildChatSelectorBody(),
          ),
          if (widget.onSelect == null)
            BlueBubblesTextField(
              chat: widget.localChat,
              onSend: send,
              isCreator: widget.localIsCreator,
              existingAttachments:
                  widget.localIsCreator ? widget.existingAttachments : null,
              existingText: widget.localIsCreator ? widget.existingText : null,
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
