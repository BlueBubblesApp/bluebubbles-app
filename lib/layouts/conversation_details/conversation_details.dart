import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/conversation_details/attachment_details_card.dart';
import 'package:bluebubbles/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;
  final MessageBloc messageBloc;

  ConversationDetails({
    Key key,
    this.chat,
    this.messageBloc
  }) : super(key: key);

  @override
  _ConversationDetailsState createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<ConversationDetails> {
  TextEditingController controller;
  bool readOnly = true;
  Chat chat;
  List<Attachment> attachmentsForChat = <Attachment>[];

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    controller = new TextEditingController(text: chat.displayName);
    Chat.getAttachments(chat).then((value) {
      attachmentsForChat = value;
     if (this.mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    readOnly = !((await chat.getParticipants()).participants.length > 1);
    debugPrint("updated readonly $readOnly");
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (chat.displayName != controller.text &&
            (await chat.getParticipants()).participants.length > 1) {
          Map<String, dynamic> params = new Map();
          params["identifier"] = chat.guid;
          params["newName"] = controller.text;
          SocketManager().sendMessage("rename-group", params, (data) async {
            if (data["status"] == 200) {
              Chat updatedChat = Chat.fromMap(data["data"]);
              await updatedChat.save();
              await ChatBloc().updateChatPosition(updatedChat);
            }
            debugPrint("renamed group chat " + data.toString());
          });
          // debugPrint("renaming");
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: CupertinoNavigationBar(
          backgroundColor: HexColor('26262a').withOpacity(0.5),
          middle: Text(
            "Details",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
          physics:
              AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                        readOnly: readOnly,
                        controller: controller,
                        style: Theme.of(context).textTheme.bodyText1,
                        autofocus: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: "NAME",
                          labelStyle: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return ContactTile(
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
                            builder: (context) => NewChatCreator(
                              currentChat: chat,
                              isCreator: false,
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
                            color: Colors.blue,
                          ),
                        ),
                        leading: Icon(
                          Icons.add,
                          color: Colors.blue,
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
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: new Text("Resync Chat"),
                        content: new Text("Are you sure you want to resync this chat? All messages/attachments will be removed and the last 25 messages will be pre-loaded."),
                        actions: <Widget> [
                          new FlatButton(
                            child: new Text("Yes, I'm sure!"),
                            onPressed: () {
                              // Remove the OG alert dialog
                              Navigator.of(context).pop();

                              // Show the next dialog
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  // Resync the chat, then return to the first page
                                  ActionHandler.resyncChat(chat, widget.messageBloc).then((value) {
                                    Navigator.of(context).popUntil((Route<dynamic> route) {
                                      return route.isFirst;
                                    });
                                  });

                                  // Show a loading dialog
                                  return AlertDialog(
                                    title: new Text("Resyncing Chat..."),
                                    content: Container(
                                      alignment: Alignment.center,
                                      height: 100,
                                      width: 100,
                                      child: new Container(
                                        child: CircularProgressIndicator()
                                      )
                                    )
                                  );
                                }
                              );
                            }
                          ),
                          new FlatButton(
                            child: new Text("Cancel"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            }
                          )
                        ]
                      );
                    }
                  );
                },
                child: ListTile(
                  title: Text(
                    "Resync chat",
                    style: TextStyle(
                      color: Colors.blue,
                    ),
                  ),
                  leading: Icon(
                    Icons.replay,
                    color: Colors.blue,
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
                    ),
                  );
                },
                childCount: attachmentsForChat.length,
              ),
            )
          ],
        ),
      ),
    );
  }
}
