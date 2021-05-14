import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intent/intent.dart' as android_intent;
import 'package:intent/action.dart' as android_action;
import 'package:permission_handler/permission_handler.dart';

class ContactTile extends StatefulWidget {
  final String address;
  final Handle handle;
  final Chat chat;
  final Function updateChat;
  final bool canBeRemoved;
  ContactTile({
    Key key,
    this.address,
    this.handle,
    this.chat,
    this.updateChat,
    this.canBeRemoved,
  }) : super(key: key);

  @override
  _ContactTileState createState() => _ContactTileState();
}

class _ContactTileState extends State<ContactTile> {
  MemoryImage contactImage;
  Contact contact;

  @override
  void initState() {
    super.initState();

    getContact();
    fetchAvatar();
    ContactManager().stream.listen((List<String> addresses) {
      // Check if any of the addresses are members of the chat
      List<Handle> participants = widget.chat.participants ?? [];
      dynamic handles = participants.map((Handle handle) => handle.address);
      for (String addr in addresses) {
        if (handles.contains(addr)) {
          fetchAvatar();
          break;
        }
      }
    });
  }

  void fetchAvatar() async {
    MemoryImage avatar = await loadAvatar(widget.chat, widget.handle.address);
    if (contactImage == null ||
        contactImage.bytes.length != avatar.bytes.length) {
      contactImage = avatar;
      if (this.mounted) setState(() {});
    }
  }

  void getContact() {
    ContactManager().getCachedContact(widget.address).then((Contact contact) {
      if (contact != null) {
        if (this.contact == null ||
            this.contact.identifier != contact.identifier) {
          this.contact = contact;
          if (this.mounted) setState(() {});
        }
      }
    });
  }

  Future<void> makeCall(String phoneNumber) async {
    if (await Permission.phone.request().isGranted) {
      android_intent.Intent()
        ..setAction(android_action.Action.ACTION_CALL)
        ..setData(Uri(scheme: "tel", path: phoneNumber))
        ..startActivity().catchError((e) => print(e));
    }
  }

  List<Item> getUniqueNumbers(Iterable<Item> numbers) {
    List<Item> phones = [];
    for (Item phone in numbers) {
      bool exists = false;
      for (Item current in phones) {
        if (cleansePhoneNumber(phone.value) ==
            cleansePhoneNumber(current.value)) {
          exists = true;
          break;
        }
      }

      if (!exists) {
        phones.add(phone);
      }
    }

    return phones;
  }

  Widget _buildContactTile() {
    return InkWell(
      onLongPress: () {
        Clipboard.setData(new ClipboardData(text: widget.handle.address));
        final snackBar = SnackBar(content: Text("Address copied to clipboard"));
        Scaffold.of(context).showSnackBar(snackBar);
      },
      onTap: () async {
        if (contact == null) {
          await ContactsService.openContactForm();
        } else {
          await ContactsService.openExistingContact(contact);
        }
      },
      child: ListTile(
        title: (contact?.displayName != null)
            ? Text(
                contact.displayName ?? "",
                style: Theme.of(context).textTheme.bodyText1,
              )
            : FutureBuilder(
                future: formatPhoneNumber(widget.handle?.address ?? ""),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      widget.handle?.address ?? "",
                      style: Theme.of(context).textTheme.bodyText1,
                    );
                  }

                  return Text(
                    snapshot.data,
                    style: Theme.of(context).textTheme.bodyText1,
                  );
                }),
        leading: ContactAvatarWidget(
          handle: widget.handle,
          borderThickness: 0.1,
        ),
        trailing: SizedBox(
          width: MediaQuery.of(context).size.width / 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              (contact != null && contact.phones.length > 0)
                  ? ButtonTheme(
                      minWidth: 1,
                      child: FlatButton(
                        shape: CircleBorder(),
                        color: Theme.of(context).accentColor,
                        onPressed: () {
                          List<Item> phones = getUniqueNumbers(contact.phones);
                          if (phones.length == 1) {
                            makeCall(contact.phones.elementAt(0).value);
                          } else {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor:
                                      Theme.of(context).accentColor,
                                  title: new Text("Select a Phone Number",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyText1
                                              .color)),
                                  content: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (int i = 0; i < phones.length; i++)
                                        FlatButton(
                                          child: Text(
                                              "${phones[i].value} (${phones[i].label})",
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyText1
                                                      .color),
                                              textAlign: TextAlign.start),
                                          onPressed: () async {
                                            makeCall(phones[i].value);
                                            Navigator.of(context).pop();
                                          },
                                        )
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        },
                        child: Icon(
                          Icons.call,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : Container()
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.canBeRemoved
        ? Slidable(
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
                    builder: (BuildContext context) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: SizedBox(
                          height: 40,
                          width: 40,
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                  );

                  Map<String, dynamic> params = new Map();
                  params["identifier"] = widget.chat.guid;
                  params["address"] = widget.handle.address;
                  SocketManager().sendMessage("remove-participant", params,
                      (response) async {
                    debugPrint("removed participant participant " +
                        response.toString());
                    if (response["status"] == 200) {
                      Chat updatedChat = Chat.fromMap(response["data"]);
                      await updatedChat.save();
                      await ChatBloc().updateChatPosition(updatedChat);
                      Chat chatWithParticipants =
                          await updatedChat.getParticipants();
                      debugPrint(
                          "updating chat with ${chatWithParticipants.participants.length} participants");
                      widget.updateChat(chatWithParticipants);
                      Navigator.of(context).pop();
                    }
                  });
                },
              ),
            ],
            child: _buildContactTile(),
          )
        : _buildContactTile();
  }
}
