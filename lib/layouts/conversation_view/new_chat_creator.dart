import 'dart:convert';
import 'dart:ui';

import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/layouts/conversation_view/messages_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/text_field.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewChatCreator extends StatefulWidget {
  NewChatCreator({Key key}) : super(key: key);

  @override
  _NewChatCreatorState createState() => _NewChatCreatorState();
}

class _NewChatCreatorState extends State<NewChatCreator> {
  TextEditingController _controller;
  List<Contact> contacts = <Contact>[];
  List participants = [];
  String previousText = "";

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // _controller.addListener();
  }

  void filterContacts(String searchQuery) {
    List<Contact> _contacts = <Contact>[];
    _contacts.addAll(ContactManager().contacts);
    if (_controller.text.isNotEmpty) {
      _contacts.retainWhere((contact) {
        String searchTerm = searchQuery.toLowerCase();
        searchTerm = cleansePhoneNumber(searchTerm);

        String contactName = contact.displayName.toLowerCase();
        String contactAddress = "";
        String contactEmail = "";
        if (contact.phones.length > 0) {
          contactAddress =
              cleansePhoneNumber(contact.phones.first.value.toLowerCase());
        }
        if (contact.emails.length > 0) {
          contactEmail =
              cleansePhoneNumber(contact.emails.first.value.toLowerCase());
        }
        return (contactName != "" && contactName.contains(searchTerm)) ||
            (contactAddress != "" && contactAddress.contains(searchTerm) ||
                (contactEmail != "" && contactEmail.contains(searchTerm)));
        // return true;
      });
    }
    contacts = _contacts;
    contacts.insert(0, null);
    contacts.add(null);
    setState(() {});
  }

  String cleansePhoneNumber(String input) {
    String output = input.replaceAll("-", "");
    output = output.replaceAll("(", "");
    output = output.replaceAll(")", "");
    output = output.replaceAll("+", "");
    output = output.replaceAll(" ", "");
    output = output.replaceAll(".", "");
    output = output.replaceAll("@", "");
    return output;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CupertinoNavigationBar(
        backgroundColor: HexColor('26262a').withOpacity(0.5),
        middle: Container(
          child: Text(
            "New Message",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
          ),
        ),
        leading: Container(),
        trailing: Container(
          child: RaisedButton(
            color: Colors.transparent,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          // MessageView(),
          ListView.builder(
            physics: AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: contacts.length,
            itemBuilder: (BuildContext context, int index) {
              if (contacts[index] == null) {
                return Container(
                  height: 60,
                );
              }
              return ListTile(
                onTap: () {
                  if (_controller.text.contains(",")) {
                    _controller.text = _controller.text
                            .substring(0, _controller.text.lastIndexOf(",")) +
                        ", " +
                        contacts[index].displayName +
                        ", ";
                  } else {
                    _controller.text = contacts[index].displayName + ", ";
                  }
                  _controller.selection = TextSelection(
                    baseOffset: _controller.text.length,
                    extentOffset: _controller.text.length,
                  );
                  previousText = _controller.text;
                  participants.add(contacts[index]);
                  contacts = [];
                  setState(() {});
                },
                title: Text(
                  contacts[index].displayName,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  contacts[index].phones.length > 0
                      ? contacts[index].phones.first.value
                      : contacts[index].emails.length > 0
                          ? contacts[index].emails.first.value
                          : "",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          Column(
            children: <Widget>[
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Stack(
                    children: <Widget>[
                      CupertinoTextField(
                        onChanged: (String text) {
                          if (text.length > 0) {
                            if (text.substring(text.length - 1) == "," &&
                                text.length > previousText.length) {
                              participants.add(
                                  text.split(",")[text.split(",").length - 2]);
                              debugPrint("updated participants: " +
                                  participants.toString());
                            } else if (previousText.length > 0 &&
                                previousText
                                        .substring(previousText.length - 1) ==
                                    "," &&
                                text.substring(text.length - 1) != "," &&
                                text.length < previousText.length) {
                              participants.removeLast();
                              String newParticipantsText = "";
                              for (int i = 0;
                                  i < previousText.split(",").length - 2;
                                  i++) {
                                newParticipantsText +=
                                    previousText.split(",")[i] + ", ";
                              }
                              _controller.text = newParticipantsText;
                              _controller.selection = TextSelection(
                                baseOffset: _controller.text.length,
                                extentOffset: _controller.text.length,
                              );
                              debugPrint(
                                  "removed participant " + newParticipantsText);
                              debugPrint("updated participants: " +
                                  participants.toString());
                            } else {
                              if (text.contains(",")) {
                                debugPrint("searching " + text.split(",").last);
                                filterContacts(
                                    text.split(",").last.replaceFirst(" ", ""));
                              } else {
                                filterContacts(text);
                              }
                            }
                          }
                          previousText = text;
                        },
                        controller: _controller,
                        scrollPhysics: BouncingScrollPhysics(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        padding: EdgeInsets.only(
                            left: 50, right: 40, top: 20, bottom: 20),
                        placeholderStyle: TextStyle(),
                        autofocus: true,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          top: 18,
                        ),
                        child: Text(
                          "To: ",
                          style: TextStyle(
                            color: Color.fromARGB(255, 100, 100, 100),
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(
                flex: 1,
              ),
              // BlueBubblesTextField(),
              RaisedButton(
                onPressed: () {
                  Map<String, dynamic> params = new Map();
                  List<String> _participants = <String>[];
                  participants.forEach((e) {
                    if (e is Contact) {
                      if (e.phones.length > 0) {
                        _participants.add(e.phones.first.value);
                      } else if (e.emails.length > 0) {
                        _participants.add(e.emails.first.value);
                      }
                    } else {
                      _participants.add(e);
                    }
                  });
                  params["participants"] = _participants;
                  SocketManager()
                      .socket
                      .sendMessage("start-chat", jsonEncode(params), (data) {
                    debugPrint(data.toString());
                  });
                },
                color: Colors.white,
                child: Text("Create"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Participant {
  String _displayName = "";
  Contact _contact;
  String _address = "";

  String get displayName => _displayName;
  String get address => _address;

  Participant(contact) {
    if (contact is String) {
      _displayName = contact;
      _address = contact;
    } else if (contact is Contact) {
      if (contact.phones.length > 0) {
        _address = contact.phones.first.value;
      } else if (contact.emails.length > 0) {
        _address = contact.emails.first.value;
      }

      _displayName = contact.displayName;
      _contact = contact;
    }
  }
}
