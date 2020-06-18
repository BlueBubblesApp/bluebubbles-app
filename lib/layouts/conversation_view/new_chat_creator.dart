import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_sender.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/messages_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/text_field.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  TextEditingController _controller;
  List<Contact> contacts = <Contact>[];
  List participants = [];
  String previousText = "";
  Chat existingChat;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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

  Future<void> tryFindExistingChat() async {
    if (!widget.isCreator) return;
    List<Chat> possibleChats = <Chat>[];
    for (Chat _chat in ChatBloc().chats) {
      Chat chat = await _chat.getParticipants();

      List<String> addresses = <String>[];
      participants.forEach((element) {
        if (element is Contact) {
          element.phones.forEach((element) {
            addresses.add(cleansePhoneNumber(element.value));
          });
          element.emails.forEach((element) {
            addresses.add(cleansePhoneNumber(element.value));
          });
        } else {
          addresses.add(element);
        }
      });
      int foundContacts = 0;
      for (Handle handle in chat.participants) {
        for (String address in addresses) {
          if (address == cleansePhoneNumber(handle.address)) {
            foundContacts++;
            break;
          }
        }
      }
      if (foundContacts == participants.length) possibleChats.add(chat);
    }
    if (possibleChats.length > 1)
      possibleChats.sort((a, b) {
        return -ChatBloc()
            .tileVals[a.guid]["actualDate"]
            .compareTo(ChatBloc().tileVals[b.guid]["actualDate"]);
      });
    if (possibleChats.length > 0) {
      setState(() {
        existingChat = possibleChats.first;
      });
    } else {
      setState(() {
        existingChat = null;
      });
    }
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
              if (!widget.isCreator) {
                showDialog(
                  context: context,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: SizedBox(
                        height: 100,
                        width: 100,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                );
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
                for (int i = 0; i < _participants.length; i++) {
                  params["identifier"] = widget.currentChat.guid;
                  params["address"] = _participants[i];
                  SocketManager().socket.sendMessage(
                      "add-participant", jsonEncode(params), (_data) async {
                    Map<String, dynamic> response = jsonDecode(_data);
                    debugPrint("added participant " + response.toString());
                    if (i == _participants.length - 1 &&
                        response["status"] == 200) {
                      Chat updatedChat = Chat.fromMap(response["data"]);
                      updatedChat.save();
                      await ChatBloc().getChats();
                      NewMessageManager().updateWithMessage(null, null);
                      Navigator.of(context).pop();
                      Chat chatWithParticipants =
                          await updatedChat.getParticipants();
                      Navigator.of(context).pop(chatWithParticipants);
                    }
                  });
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              widget.isCreator ? "Cancel" : "Done",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          // MessageView(),
          widget.isCreator &&
                  _controller.text.length > 1 &&
                  _controller.text.substring(_controller.text.length - 2) ==
                      ", "
              ? existingChat != null
                  ? MessageView(
                      messageBloc: ChatBloc().tileVals[existingChat.guid]
                          ["bloc"],
                    )
                  : Container()
              : ListView.builder(
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
                          _controller.text = _controller.text.substring(
                                  0, _controller.text.lastIndexOf(",")) +
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
                        tryFindExistingChat();
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
                              _controller.text += " ";
                              _controller.selection = TextSelection(
                                baseOffset: _controller.text.length,
                                extentOffset: _controller.text.length,
                              );
                              tryFindExistingChat();
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
                              tryFindExistingChat();
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
                          setState(() {});
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
              widget.isCreator
                  ? BlueBubblesTextField(
                      existingAttachments: widget.attachments,
                      existingText: widget.existingText,
                      customSend: (pickedImages, text) async {
                        if (_controller.text.length == 0) return;
                        if (!_controller.text.endsWith(", ")) {
                          participants.add(_controller.text.split(",").last);
                        }
                        await tryFindExistingChat();
                        if (existingChat != null) {
                          if (pickedImages.length > 0) {
                            for (int i = 0; i < pickedImages.length; i++) {
                              new AttachmentSender(
                                pickedImages[i],
                                existingChat,
                                i == pickedImages.length - 1 ? text : "",
                              );
                            }
                          } else {
                            ActionHandler.sendMessage(existingChat, text);
                          }
                          String title = await getFullChatTitle(existingChat);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => ConversationView(
                                chat: existingChat,
                                title: title,
                                messageBloc: ChatBloc()
                                    .tileVals[existingChat.guid]["bloc"],
                              ),
                            ),
                          );
                          return;
                        }
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
                        showDialog(
                          context: context,
                          child: ClipRRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: SizedBox(
                                height: 100,
                                width: 100,
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        );
                        if (widget.isCreator) {
                          params["participants"] = _participants;
                          SocketManager().socket.sendMessage(
                            "start-chat",
                            jsonEncode(params),
                            (_data) async {
                              debugPrint(_data);
                              Map<String, dynamic> data = jsonDecode(_data);
                              Chat newChat = Chat.fromMap(data["data"]);
                              newChat = await newChat.save();
                              String title = await getFullChatTitle(newChat);
                              await ChatBloc().getChats();
                              await NewMessageManager()
                                  .updateWithMessage(null, null);
                              // await ChatBloc().getChats();
                              if (pickedImages.length > 0) {
                                for (int i = 0; i < pickedImages.length; i++) {
                                  new AttachmentSender(
                                    pickedImages[i],
                                    newChat,
                                    i == pickedImages.length - 1 ? text : "",
                                  );
                                }
                              } else {
                                ActionHandler.sendMessage(newChat, text);
                              }

                              Navigator.of(context, rootNavigator: true).pop();
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => ConversationView(
                                    chat: newChat,
                                    title: title,
                                    messageBloc: ChatBloc()
                                        .tileVals[newChat.guid]["bloc"],
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          for (int i = 0; i < _participants.length; i++) {
                            params["identifier"] = widget.currentChat.guid;
                            params["address"] = _participants[i];
                            SocketManager().socket.sendMessage(
                                "add-participant", jsonEncode(params), (_data) {
                              Map<String, dynamic> response = jsonDecode(_data);
                              debugPrint(
                                  "added participant " + response.toString());
                              if (i == _participants.length - 1) {
                                Navigator.of(context).pop();
                              }
                            });
                          }
                        }
                      },
                    )
                  : Container(),
            ],
          ),
        ],
      ),
    );
  }
}

//TODO update everything so that it is more organized
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
