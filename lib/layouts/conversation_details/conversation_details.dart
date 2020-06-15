import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
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

  @override
  void initState() {
    super.initState();
    controller = new TextEditingController(text: widget.chat.displayName);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    readOnly = !((await widget.chat.getParticipants()).participants.length > 1);
    debugPrint("updated readonly $readOnly");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.chat.displayName != controller.text &&
            (await widget.chat.getParticipants()).participants.length > 1) {
          Map<String, dynamic> params = new Map();
          params["identifier"] = widget.chat.guid;
          params["newName"] = controller.text;
          SocketManager().socket.sendMessage("rename-group", jsonEncode(params),
              (data) async {
            if (jsonDecode(data)["status"] == 200) {
              Chat updatedChat = Chat.fromMap(jsonDecode(data)["data"]);
              await updatedChat.save();
              await ChatBloc().getChats();
              NewMessageManager().updateWithMessage(null, null);
            }
            debugPrint("renamed group chat " + jsonDecode(data).toString());
          });
          // debugPrint("renaming");
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: CupertinoNavigationBar(
          backgroundColor: HexColor('26262a').withOpacity(0.5),
          middle: Text(
            "Details",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: ListView.builder(
          physics:
              AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: widget.chat.participants.length + 4,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return InkWell(
                onTap: () async {
                  if (await Permission.locationWhenInUse.request().isGranted) {
                    final result = await MethodChannelInterface()
                        .invokeMethod("get-last-location");
                    String vcfString = AttachmentHelper.createAppleLocation(
                        result["latitude"], result["longitude"]);

                    String _attachmentGuid = "temp-${randomString(8)}";

                    String fileName = "CL.loc.vcf";
                    String appDocPath = SettingsManager().appDocDir.path;
                    String pathName =
                        "$appDocPath/attachments/${_attachmentGuid}/$fileName";
                    await new File(pathName).create(recursive: true);

                    File attachmentFile =
                        await new File(pathName).writeAsString(vcfString);

                    List<int> bytes = await attachmentFile.readAsBytes();
                    Attachment messageAttachment = Attachment(
                      guid: _attachmentGuid,
                      totalBytes: bytes.length,
                      isOutgoing: true,
                      isSticker: false,
                      hideAttachment: false,
                      uti: "public.jpg",
                      transferName: fileName,
                      mimeType: "text/vcf",
                    );

                    Message sentMessage = Message(
                      guid: _attachmentGuid,
                      text: "",
                      dateCreated: DateTime.now(),
                      hasAttachments: true,
                    );
                    await sentMessage.save();

                    await messageAttachment.save(sentMessage);
                    await widget.chat.save();
                    await widget.chat.addMessage(sentMessage);

                    NewMessageManager()
                        .updateWithMessage(widget.chat, sentMessage);
                    Map<String, dynamic> params = new Map();
                    params["guid"] = widget.chat.guid;
                    // params["message"] = "current location";
                    params["attachmentGuid"] = _attachmentGuid;
                    params["attachmentName"] = fileName;
                    params["attachment"] = base64Encode(bytes);
                    SocketManager().socket.sendMessage(
                        "send-message", jsonEncode(params), (data) {
                      debugPrint("sent " + jsonDecode(data).toString());
                    });
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
              );
            } else if (index == widget.chat.participants.length + 1) {
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NewChatCreator(
                        currentChat: widget.chat,
                        isCreator: false,
                      ),
                    ),
                  );
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
              );
            } else if (index == widget.chat.participants.length + 2) {
              if (readOnly) {
                return Container();
              }
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  readOnly: readOnly,
                  controller: controller,
                  style: TextStyle(color: Colors.white),
                  autofocus: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: "NAME",
                    labelStyle: TextStyle(color: Colors.blue),
                  ),
                ),
              );
            } else if (index == widget.chat.participants.length + 3) {
              return InkWell(
                onTap: () async {
                  showDialog(
                    context: context,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: SizedBox(
                        height: 300,
                        width: 300,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                  SocketManager().resyncChat(widget.chat).then((value) {
                    Navigator.of(context).pop();
                  });
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
              );
            }
            return ContactTile(
              contact: getContact(ContactManager().contacts,
                  widget.chat.participants[index - 1].address),
              handle: widget.chat.participants[index - 1],
            );
          },
        ),
      ),
    );
  }
}
