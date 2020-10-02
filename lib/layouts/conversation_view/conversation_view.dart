import 'dart:io';
import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBackButton.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
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
  Map<String, dynamic> avatarStack = {};
  List<String> newMessages = [];

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    chatTitle = "...";
    NotificationManager().switchChat(chat);

    getChatTitle();
    fetchAvatars();
    ContactManager().stream.listen((List<String> addresses) async {
      fetchAvatars();
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
    fetchAvatars();
    getChatTitle();
  }

  void getChatTitle() {
    getShortChatTitle(widget.chat).then((String title) {
      if (title != chatTitle) {
        chatTitle = title;
        if (this.mounted) setState(() {});
      }
    });
  }

  Future<void> fetchAvatars() async {
    Function cb = () {
      if (this.mounted) setState(() {});
    };

    // If we don't have participants, get them
    if (widget.chat.participants.length == 0) {
      await widget.chat.getParticipants();
    }

    // Loop over the participants
    for (Handle handle in widget.chat.participants) {
      // Since we only want to update if we've made changes, check a flag
      bool existed = avatarStack.containsKey(handle.address);

      // If the avatar doesnt exist yet, add it as null
      dynamic currentVal = avatarStack.putIfAbsent(handle.address,
          () => {"avatar": null, "initials": getInitials(null, "")});

      // Update the UI with the placeholders
      if (!existed) cb();

      // Get the latest avatar
      if (currentVal["avatar"] == null) {
        MemoryImage avatar = await loadAvatar(widget.chat, handle.address);
        String tile = await ContactManager().getContactTitle(handle.address);
        dynamic initials = getInitials(tile, " ");

        // Only update if there is a change
        if (avatarStack[handle.address]["initials"] != initials) {
          avatarStack[handle.address]["initials"] = initials;
        }

        if (avatar != null) {
          avatarStack[handle.address]["avatar"] = avatar;
        }

        // Update the UI with the actual avatars
        cb();
      }
    }
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
    avatarStack.forEach((address, info) {
      avatars.add(
        Container(
          height: 42.0, // 1 px larger than the diameter
          width: 42.0, // 1 px larger than the diameter
          decoration:
              new BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).accentColor,
            child: ContactAvatarWidget(
              contactImage: info["avatar"],
              initials: info["initials"],
            ),
          ),
        ),
      );
    });

    // Calculate separation factor
    // Anything below -60 won't work due to the alignment
    double distance = avatars.length * -4.0;
    if (distance <= -60.0) distance = -60.0;

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
          children: <Widget>[
            Container(height: 10.0),
            GestureDetector(
              onTap: openDetails,
              child: Container(
                // padding: EdgeInsets.only(right: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.only(left: distance <= -40.0 ? 60 : 0),
                      child: RowSuper(
                        children: avatars,
                        innerDistance: distance,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                    RichText(
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: MessageView(
                messageBloc: widget.messageBloc,
                showHandle: chat.participants.length > 1,
              ),
            ),
          ),
          BlueBubblesTextField(
            chat: chat,
            existingAttachments: widget.existingAttachments,
            existingText: widget.existingText,
            onSend: (String text) async {},
          )
        ],
      ),
    );
  }
}
