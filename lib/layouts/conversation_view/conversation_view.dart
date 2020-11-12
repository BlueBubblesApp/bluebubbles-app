import 'dart:io';
import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBackButton.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart' as Cupertino;
import 'package:flutter/material.dart';

import '../../repository/models/chat.dart';

class ConversationView extends StatefulWidget {
  final List<File> existingAttachments;
  final String existingText;
  ConversationView({
    Key key,
    @required this.chat,
    @required this.title,
    @required this.messageBloc,
    this.existingAttachments,
    this.existingText,
  }) : super(key: key);

  // final data;
  final Chat chat;
  final String title;
  final MessageBloc messageBloc;

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  Chat chat;
  OverlayEntry entry;
  LayerLink layerLink = LayerLink();
  String chatTitle;
  List<String> newMessages = [];
  bool processingParticipants = false;

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    chatTitle = "...";
    NotificationManager().switchChat(chat);

    getChatTitle();
    fetchParticipants();
    ContactManager().stream.listen((List<String> addresses) async {
      fetchParticipants();
    });

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!["add-unread-chat", "remove-unread-chat"].contains(event["type"]))
        return;
      if (!event["data"].containsKey("chatGuid")) return;

      // Ignore any events having to do with this chat
      String chatGuid = event["data"]["chatGuid"];
      if (chat.guid == chatGuid) return;

      int preLength = newMessages.length;
      if (event["type"] == "add-unread-chat" &&
          !newMessages.contains(chatGuid)) {
        newMessages.add(chatGuid);
      } else if (event["type"] == "remove-unread-chat" &&
          newMessages.contains(chatGuid)) {
        newMessages.remove(chatGuid);
      }

      // Only re-render if the newMessages count changes
      if (preLength != newMessages.length && this.mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    SocketManager().removeChatNotification(chat);
    fetchParticipants();
    getChatTitle();
  }

  void getChatTitle() async {
    getShortChatTitle(widget.chat).then((String title) {
      if (title != chatTitle) {
        chatTitle = title;
        if (this.mounted) setState(() {});
      }
    });
  }

  Future<void> fetchParticipants() async {
    // Prevent multiple calls to fetch participants
    if (processingParticipants) return;
    processingParticipants = true;

    // If we don't have participants, get them
    if (widget.chat.participants.isEmpty) {
      await widget.chat.getParticipants();

      // If we have participants, refresh the state
      if (widget.chat.participants.isNotEmpty) {
        if (this.mounted) setState(() {});
        return;
      }

      debugPrint("(Convo View) No participants found for chat, fetching...");

      try {
        // If we don't have participants, we should fetch them from the server
        Chat data = await SocketManager().fetchChat(widget.chat.guid);
        // If we got data back, fetch the participants and update the state
        if (data != null) {
          await widget.chat.getParticipants();
          if (widget.chat.participants.isNotEmpty) {
            debugPrint("(Convo View) Got new chat participants. Updating state.");
            if (this.mounted) setState(() {});
          } else {
            debugPrint("(Convo View) Participants list is still empty, please contact support!");
          }
        }
      } catch (ex) {
        debugPrint("There was an error fetching the chat");
        debugPrint(ex.toString());
      }
    }

    processingParticipants = false;
  }

  @override
  void dispose() {
    widget.messageBloc.dispose();
    NotificationManager().leaveChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Function openDetails = () async {
      Chat _chat = await chat.getParticipants();
      Navigator.of(context).push(
        Cupertino.CupertinoPageRoute(
          builder: (context) =>
              ConversationDetails(chat: _chat, messageBloc: widget.messageBloc),
        ),
      );
    };

    // Build the stack
    List<Widget> avatars = [];
    widget.chat.participants.forEach((Handle participant) {
      avatars.add(
        Container(
          height: 42.0, // 2 px larger than the diameter
          width: 42.0, // 2 px larger than the diameter
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).accentColor,
            child: ContactAvatarWidget(
              handle: participant,
              borderThickness: 0.5,
            ),
          ),
        ),
      );
    });

    // Calculate separation factor
    // Anything below -60 won't work due to the alignment
    double distance = avatars.length * -4.0;
    if (distance <= -30.0 && distance > -60) distance = -30.0;
    if (distance <= -60.0) distance = -35.0;

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).accentColor.withAlpha(125),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.2),
        ),
        leading: CustomCupertinoNavigationBarBackButton(
          color: Theme.of(context).primaryColor,
          notifications: newMessages.length,
        ),
        middle: ListView(
          physics: Cupertino.NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(right: 30),
          children: <Widget>[
            Container(height: 10.0),
            GestureDetector(
              onTap: openDetails,
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RowSuper(
                      children: avatars,
                      innerDistance: distance,
                      alignment: Alignment.center,
                    ),
                    Container(height: 5.0),
                    RichText(
                      maxLines: 1,
                      overflow: Cupertino.TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.headline2,
                        children: [
                          TextSpan(
                            text: chatTitle,
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                          TextSpan(
                            text: " >",
                            style: Theme.of(context).textTheme.subtitle1,
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        trailing: Container(width: 20),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: MessagesView(
              messageBloc: widget.messageBloc,
              showHandle: chat.participants.length > 1,
              chat: chat,
            ),
          ),
          BlueBubblesTextField(
            chat: chat,
            existingAttachments: widget.existingAttachments,
            existingText: widget.existingText,
          ),
        ],
      ),
    );
  }
}
