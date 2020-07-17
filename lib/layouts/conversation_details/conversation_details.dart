import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/conversation_details/attachment_details_card.dart';
import 'package:bluebubble_messages/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:permission_handler/permission_handler.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;

  ConversationDetails({
    Key key,
    this.chat,
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
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    readOnly = !((await chat.getParticipants()).participants.length > 1);
    debugPrint("updated readonly $readOnly");
    setState(() {});
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
              // await ChatBloc().getChats();
              // NewMessageManager().updateWithMessage(null, null);
              await ChatBloc().moveChatToTop(updatedChat);
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
                    contact: getContact(ContactManager().contacts,
                        chat.participants[index].address),
                    handle: chat.participants[index],
                    chat: chat,
                    updateChat: (Chat newChat) {
                      chat = newChat;
                      setState(() {});
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
                        if (result != null) {
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
                  if (await Permission.locationWhenInUse.request().isGranted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).accentColor,
                        title: Text(
                          "Send Current Location?",
                          style: Theme.of(context).textTheme.headline1,
                        ),
                        actions: <Widget>[
                          FlatButton(
                            color: Colors.blue[600],
                            child: Text(
                              "Send",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                            onPressed: () async {
                              final result = await MethodChannelInterface()
                                  .invokeMethod("get-last-location");
                              String vcfString =
                                  AttachmentHelper.createAppleLocation(
                                      result["latitude"], result["longitude"]);

                              String _attachmentGuid =
                                  "temp-${randomString(8)}";

                              String fileName = "CL.loc.vcf";
                              String appDocPath =
                                  SettingsManager().appDocDir.path;
                              String pathName =
                                  "$appDocPath/attachments/${_attachmentGuid}/$fileName";
                              await new File(pathName).create(recursive: true);

                              File attachmentFile = await new File(pathName)
                                  .writeAsString(vcfString);

                              List<int> bytes =
                                  await attachmentFile.readAsBytes();
                              Attachment messageAttachment = Attachment(
                                guid: _attachmentGuid,
                                totalBytes: bytes.length,
                                isOutgoing: true,
                                isSticker: false,
                                hideAttachment: false,
                                uti: "public.jpg",
                                transferName: fileName,
                                mimeType: "text/x-vlocation",
                              );

                              Message sentMessage = Message(
                                guid: _attachmentGuid,
                                text: "",
                                dateCreated: DateTime.now(),
                                hasAttachments: true,
                              );
                              await sentMessage.save();

                              await messageAttachment.save(sentMessage);
                              await chat.save();
                              await chat.addMessage(sentMessage);

                              NewMessageManager()
                                  .updateWithMessage(chat, sentMessage);
                              Map<String, dynamic> params = new Map();
                              params["guid"] = chat.guid;
                              params["attachmentGuid"] = _attachmentGuid;
                              params["attachmentName"] = fileName;
                              params["attachment"] = base64Encode(bytes);
                              SocketManager()
                                  .sendMessage("send-message", params, (data) {
                                debugPrint("sent " + data.toString());
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                          FlatButton(
                            child: Text(
                              "Cancel",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                            color: Colors.red,
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: ListTile(
                  title: Text(
                    "Send Current Location",
                    style: TextStyle(
                      color: Colors.blue,
                    ),
                  ),
                  leading: Icon(
                    Icons.my_location,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () async {
                  ActionHandler.resyncChat(chat).then((value) {});
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
