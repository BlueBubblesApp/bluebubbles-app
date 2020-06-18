import 'dart:convert';
import 'dart:ui';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intent/intent.dart' as android_intent;
import 'package:intent/action.dart' as android_action;
import 'package:permission_handler/permission_handler.dart';

class ContactTile extends StatefulWidget {
  final Contact contact;
  final Handle handle;
  final Chat chat;
  final Function updateChat;
  ContactTile({Key key, this.contact, this.handle, this.chat, this.updateChat})
      : super(key: key);

  @override
  _ContactTileState createState() => _ContactTileState();
}

class _ContactTileState extends State<ContactTile> {
  @override
  Widget build(BuildContext context) {
    return Slidable(
      actionExtentRatio: 0.25,
      actionPane: SlidableStrechActionPane(),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'Remove',
          color: Colors.red,
          icon: Icons.delete,
          onTap: () async {
            showDialog(
              context: context,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(),
                ),
              ),
            );

            Map<String, dynamic> params = new Map();
            params["identifier"] = widget.chat.guid;
            params["address"] = widget.handle.address;
            SocketManager().socket.sendMessage(
                "remove-participant", jsonEncode(params), (_data) async {
              Map<String, dynamic> response = jsonDecode(_data);
              debugPrint(
                  "removed participant participant " + response.toString());
              if (response["status"] == 200) {
                Chat updatedChat = Chat.fromMap(response["data"]);
                await updatedChat.save(true);
                await ChatBloc().getChats();
                NewMessageManager().updateWithMessage(null, null);
                Chat chatWithParticipants = await updatedChat.getParticipants();
                debugPrint(
                    "updating chat with ${chatWithParticipants.participants.length} participants");
                widget.updateChat(chatWithParticipants);
                Navigator.of(context).pop();
              }
            });
          },
        ),
      ],
      child: InkWell(
        onTap: () async {
          if (widget.contact == null) {
            await ContactsService.openContactForm();
          } else {
            await ContactsService.openExistingContact(widget.contact);
          }
        },
        child: ListTile(
          title: Text(
            widget.contact != null
                ? widget.contact.displayName
                : widget.handle.address,
            style: TextStyle(color: Colors.white),
          ),
          trailing: SizedBox(
            width: MediaQuery.of(context).size.width / 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                ButtonTheme(
                  minWidth: 1,
                  child: RaisedButton(
                    shape: CircleBorder(),
                    color: HexColor('26262a'),
                    onPressed: () async {
                      if (widget.contact != null &&
                          widget.contact.phones.length > 0) {
                        if (await Permission.phone.request().isGranted) {
                          android_intent.Intent()
                            ..setAction(android_action.Action.ACTION_CALL)
                            ..setData(Uri(
                                scheme: "tel",
                                path: widget.contact.phones.first.value))
                            ..startActivity().catchError((e) => print(e));
                        }
                      }
                    },
                    child: Icon(
                      Icons.call,
                      color: Colors.blue,
                    ),
                  ),
                ),
                ButtonTheme(
                  minWidth: 1,
                  child: RaisedButton(
                    shape: CircleBorder(),
                    color: HexColor('26262a'),
                    onPressed: () {},
                    child: Icon(
                      Icons.videocam,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
