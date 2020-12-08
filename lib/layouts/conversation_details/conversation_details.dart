import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/conversation_details/attachment_details_card.dart';
import 'package:bluebubbles/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/adding_participant_popup.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;
  final MessageBloc messageBloc;

  ConversationDetails({Key key, this.chat, this.messageBloc}) : super(key: key);

  @override
  _ConversationDetailsState createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<ConversationDetails> {
  TextEditingController controller;
  bool readOnly = true;
  Chat chat;
  List<Attachment> attachmentsForChat = <Attachment>[];
  bool isClearing = false;
  bool isCleared = false;

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    controller = new TextEditingController(text: chat.displayName);
    
    fetchAttachments();
    ChatBloc().chatStream.listen((event) async {
      if (this.mounted) {
        Chat _chat = await Chat.findOne({"guid": widget.chat.guid});
        await _chat.getParticipants();
        chat = _chat;
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    readOnly = !((await chat.getParticipants()).participants.length > 1);
    debugPrint("updated readonly $readOnly");
    if (this.mounted) setState(() {});
  }

  void fetchAttachments() {
    Chat.getAttachments(chat).then((value) {
      attachmentsForChat = value;
      if (this.mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).accentColor.withAlpha(125),
        actionsForegroundColor: Theme.of(context).primaryColor,
        middle: Text(
          "Details",
          style: Theme.of(context).textTheme.headline1,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Container(
              height: 100,
            ),
          ),
          SliverToBoxAdapter(
            child: readOnly
                ? Container()
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      cursorColor: Theme.of(context).primaryColor,
                      readOnly: true,
                      controller: controller,
                      style: Theme.of(context).textTheme.bodyText1,
                      autofocus: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: "NAME",
                        labelStyle:
                            TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return ContactTile(
                  key: Key(chat.participants[index].id.toString()),
                  address: chat.participants[index].address,
                  handle: chat.participants[index],
                  chat: chat,
                  updateChat: (Chat newChat) {
                    chat = newChat;
                    if (this.mounted) setState(() {});
                  },
                  canBeRemoved: chat.participants.length > 1,
                );
              },
              childCount: chat.participants.length,
            ),
          ),
          SliverToBoxAdapter(
            child: chat.participants.length > 1
                ? InkWell(
                    onTap: () async {
                      Chat result = await Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ConversationView(
                            isCreator: true,
                            type: ChatSelectorTypes.ONLY_CONTACTS,
                            onSelect: (List<UniqueContact> items) {
                              Navigator.of(context).pop();
                              if (items.length == 0) return;

                              for (UniqueContact contact in items) {
                                if (contact.isChat) return;
                              }
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AddingParticipantPopup(
                                  contacts: items,
                                  chat: chat,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                      if (result != null && this.mounted) {
                        chat = result;
                        setState(() {});
                      }
                    },
                    child: ListTile(
                      title: Text(
                        "Add Contact",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      leading: Icon(
                        Icons.add,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : Container(),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(vertical: 20),
          ),
          SliverToBoxAdapter(
            child: InkWell(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => SyncDialog(
                    chat: chat,
                    withOffset: true,
                    initialMessage: "Fetching messages...",
                    limit: 100
                  ),
                );

                fetchAttachments();
              },
              child: ListTile(
                leading: Text(
                  "Fetch more messages",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                trailing: Padding(
                  padding: EdgeInsets.only(right: 15),
                  child: Icon(
                    Icons.file_download,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: InkWell(
              onTap: () async {
                showDialog(
                  context: context,
                  builder: (context) => SyncDialog(
                    chat: chat,
                    initialMessage: "Syncing messages...",
                    limit: 25
                  ),
                );
              },
              child: ListTile(
                leading: Text(
                  "Sync last 25 messages",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                trailing: Padding(
                  padding: EdgeInsets.only(right: 15),
                  child: Icon(
                    Icons.replay,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: ListTile(
                  leading: Text("Pin Conversation",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                      )),
                  trailing: Switch(
                      value: widget.chat.isPinned,
                      activeColor: Theme.of(context).primaryColor,
                      activeTrackColor:
                          Theme.of(context).primaryColor.withAlpha(200),
                      inactiveTrackColor:
                          Theme.of(context).accentColor.withOpacity(0.6),
                      inactiveThumbColor: Theme.of(context).accentColor,
                      onChanged: (value) async {
                        if (value) {
                          await widget.chat.pin();
                        } else {
                          await widget.chat.unpin();
                        }
                        
                        EventDispatcher().emit("refresh", null);

                        if (this.mounted) setState(() {});
                      }))),
          SliverToBoxAdapter(
              child: ListTile(
                  leading: Text("Mute Conversation",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                      )),
                  trailing: Switch(
                      value: widget.chat.isMuted,
                      activeColor: Theme.of(context).primaryColor,
                      activeTrackColor:
                          Theme.of(context).primaryColor.withAlpha(200),
                      inactiveTrackColor:
                          Theme.of(context).accentColor.withOpacity(0.6),
                      inactiveThumbColor: Theme.of(context).accentColor,
                      onChanged: (value) async {
                        widget.chat.isMuted = value;
                        await widget.chat.save(updateLocalVals: true);
                        EventDispatcher().emit("refresh", null);

                        if (this.mounted) setState(() {});
                      }))),
          SliverToBoxAdapter(
              child: ListTile(
                  leading: Text("Archive Conversation",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                      )),
                  trailing: Switch(
                      value: widget.chat.isArchived,
                      activeColor: Theme.of(context).primaryColor,
                      activeTrackColor:
                          Theme.of(context).primaryColor.withAlpha(200),
                      inactiveTrackColor:
                          Theme.of(context).accentColor.withOpacity(0.6),
                      inactiveThumbColor: Theme.of(context).accentColor,
                      onChanged: (value) {
                        if (value) {
                          ChatBloc().archiveChat(widget.chat);
                        } else {
                          ChatBloc().unArchiveChat(widget.chat);
                        }

                        EventDispatcher().emit("refresh", null);
                        if (this.mounted) setState(() {});
                      }))),
          SliverToBoxAdapter(
            child: InkWell(
              onTap: () async {
                if (this.mounted) setState(() { isClearing = true; });

                try {
                  await widget.chat.clearTranscript();
                  if (this.mounted) setState(() { isClearing = false; isCleared = true; });
                } catch (ex) {
                  if (this.mounted) setState(() { isClearing = false; isCleared = false; });
                }
              },
              child: ListTile(
                leading: Text(
                  "Clear Transcript (Local Only)",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                trailing: Padding(
                  padding: EdgeInsets.only(right: 15),
                  child: (isClearing)
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor),
                    )
                  : (isCleared)
                    ? Icon(
                        Icons.done,
                        color: Theme.of(context).primaryColor,
                      )
                    : Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, int index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).accentColor, width: 3),
                  ),
                  child: AttachmentDetailsCard(
                    attachment: attachmentsForChat[index],
                    allAttachments: attachmentsForChat.reversed.toList(),
                  ),
                );
              },
              childCount: attachmentsForChat.length,
            ),
          )
        ],
      ),
      // ),
    );
  }
}

class SyncDialog extends StatefulWidget {
  SyncDialog(
      {Key key,
      this.chat,
      this.initialMessage,
      this.withOffset = false,
      this.limit = 100})
      : super(key: key);
  final Chat chat;
  final String initialMessage;
  final bool withOffset;
  final int limit;

  @override
  _SyncDialogState createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  String errorCode;
  bool finished = false;
  String message;
  double progress;

  @override
  void initState() {
    super.initState();
    message = widget.initialMessage;
    syncMessages();
  }

  void syncMessages() async {
    int offset = 0;
    if (widget.withOffset) {
      offset = await Message.countForChat(widget.chat);
    }

    SocketManager()
        .fetchMessages(widget.chat, offset: offset, limit: widget.limit)
        .then((List<dynamic> messages) {
      if (this.mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(
        widget.chat,
        messages,
        onProgress: (int progress, int length) {
          if (progress == 0 || length  == 0) {
            this.progress = null;
          } else {
            this.progress = progress / length;
          }

          if (this.mounted) setState(() {});
        })
          .then((List<Message> __) {
        onFinish(true);
      });
    }).catchError((_) => onFinish(false));
  }

  void onFinish([bool success = true]) {
    if (!this.mounted) return;
    if (success) Navigator.of(context).pop();
    if (!success) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(errorCode != null ? "Error!" : message),
      content: errorCode != null
          ? Text(errorCode)
          : Container(
              height: 5,
              child: Center(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor:
                      AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                ),
              ),
            ),
      actions: [
        FlatButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "Ok",
            style: Theme.of(context).textTheme.bodyText1.apply(
                  color: Theme.of(context).primaryColor,
                ),
          ),
        )
      ],
    );
  }
}
