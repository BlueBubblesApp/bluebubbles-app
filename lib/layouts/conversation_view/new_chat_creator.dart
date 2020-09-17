import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator_text_field.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../socket_manager.dart';

class NewChatCreator extends StatefulWidget {
  final bool isCreator;
  final Chat currentChat;
  final List<File> attachments;
  final String existingText;
  NewChatCreator({
    Key key,
    this.isCreator,
    this.currentChat,
    this.attachments,
    this.existingText,
  }) : super(key: key);

  @override
  _NewChatCreatorState createState() => _NewChatCreatorState();
}

class _NewChatCreatorState extends State<NewChatCreator> {
  String filter = "";
  List<Chat> conversations = [];
  List contacts = <Contact>[];

  TextEditingController controller = new TextEditingController();

  @override
  void initState() {
    super.initState();
    if (ChatBloc().chats != null) {
      conversations = ChatBloc().chats;
      conversations.forEach((element) {
        element.getParticipants();
      });
    }
    ChatBloc().chatStream.listen((event) {
      if (conversations.length == 0 && this.mounted && event != null) {
        conversations = event;
        conversations.forEach((element) {
          element.getParticipants();
        });
        setState(() {});
      }
    });
  }

  void filterContacts(String searchQuery) {
    List<dynamic> _contacts = [];
    Function addContactEntries = (Contact contact, {conditionally = false}) {
      for (Item phone in contact.phones) {
        if (conditionally && !cleansePhoneNumber(phone.value).contains(searchQuery.toLowerCase()))
          continue;

        _contacts.add({"data": contact, "type": "contact", "text": phone.value});
      }

      for (Item email in contact.emails) {
        if (conditionally && !cleansePhoneNumber(email.value).contains(searchQuery.toLowerCase()))
          continue;

        _contacts.add({"data": contact, "type": "contact", "text": email.value});
      }
    };

    for (Contact contact in ContactManager().contacts) {
      if (contact.displayName.toLowerCase().contains(searchQuery.toLowerCase())) {
        addContactEntries(contact);
      } else {
        addContactEntries(contact, conditionally: true);
      }
    }



    List<dynamic> _conversations = [];
    for (Chat chat in conversations) {
      if (chat.title.toLowerCase().contains(searchQuery.toLowerCase())) {
        _conversations.add({"data": chat, "type": "chat", "text": chat.title});
      }
    }

    _conversations.addAll(_contacts);
    contacts = _conversations;

    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
        middle: Container(
          child: Text(
            "New Message",
            style: Theme.of(context).textTheme.headline2,
          ),
        ),
        leading: Container(),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: filter.length > 0
                ? ListView.builder(
                  cacheExtent: 0.0,
                    physics: AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: contacts.length,
                    itemBuilder: (BuildContext context, int index) {
                      return contacts[index]["type"] == "contact"
                          ? ListTile(
                              onTap: () {
                                Contact contact = contacts[index]["data"];
                                controller.text =
                                    controller.text.replaceAll(filter, "");

                                if (contact.phones.length > 0) {
                                  controller.text += contact.phones.first.value;
                                } else if (contact.emails.length > 0) {
                                  controller.text += contact.emails.first.value;
                                } else if (contact.displayName != null &&
                                    contact.displayName != "") {
                                  controller.text += contact.displayName;
                                } else {
                                  return;
                                }
                                controller.text += ",";
                                controller.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                    offset: controller.text.length,
                                  ),
                                );
                                setState(() {});
                              },
                              title: Text(
                                contacts[index]["data"].displayName,
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                              subtitle: Text(contacts[index]["text"],
                                style: Theme.of(context).textTheme.subtitle1,
                              ),
                            )
                          : ConversationTile(
                              existingAttachments: widget.attachments,
                              existingText: widget.existingText,
                              chat: contacts[index]["data"],
                              replaceOnTap: true,
                            );
                    },
                  )
                : ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemBuilder: (context, index) {
                      return ConversationTile(
                        existingAttachments: widget.attachments,
                        existingText: widget.existingText,
                        chat: conversations[index],
                        replaceOnTap: true,
                      );
                    },
                    itemCount: conversations.length,
                  ),
          ),
          NewChatCreatorTextField(
            createText: widget.isCreator ? "Create" : "Done",
            onCreate: (List<Contact> _vals) {
              List<String> participants = _convertContactsToString(_vals);

              if (widget.isCreator) {
                Map<String, dynamic> params = {};
                showDialog(
                  context: context,
                  child: AlertDialog(
                    backgroundColor: Theme.of(context).backgroundColor,
                    title: Text(
                      "Creating a new chat...",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          // height: 70,
                          // color: Colors.black,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                params["participants"] = participants;
                SocketManager().sendMessage(
                  "start-chat",
                  params,
                  (data) async {
                    if (data['status'] != 200) {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        child: AlertDialog(
                          backgroundColor: Theme.of(context).backgroundColor,
                          title: Text(
                            "Could not create",
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                          content: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                // height: 70,
                                // color: Colors.black,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      return;
                    }
                    Chat newChat = Chat.fromMap(data["data"]);
                    await newChat.save();
                    await ChatBloc().updateChatPosition(newChat);


                    String title = await getFullChatTitle(newChat);
                    Navigator.of(context, rootNavigator: true).pop();
                    Navigator.of(context).pushReplacement(
                      CupertinoPageRoute(
                        builder: (context) => ConversationView(
                          chat: newChat,
                          title: title,
                          messageBloc: MessageBloc(newChat),
                          existingAttachments: widget.attachments,
                          existingText: widget.existingText,
                        ),
                      ),
                    );
                  },
                );
              } else {
                showDialog(
                  context: context,
                  child: AlertDialog(
                    backgroundColor: Theme.of(context).backgroundColor,
                    title: Text(
                      "Not Implemented Lol",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                  ),
                );
              }
            },
            filter: (String val) async {
              filterContacts(val);
              setState(() {
                filter = val;
              });
            },
            controller: controller,
          ),
        ],
      ),
    );
  }

  List<String> _convertContactsToString(List<Contact> _contacts) {
    List<String> vals = [];
    for (Contact contact in _contacts) {
      if (contact.phones.length > 0) {
        vals.add(contact.phones.first.value);
      } else if (contact.emails.length > 0) {
        vals.add(contact.emails.first.value);
      } else {
        //If for whatever reason the contact does not have a phone number or email, we want to throw an error
        return null;
      }
    }
    return vals;
  }
}
