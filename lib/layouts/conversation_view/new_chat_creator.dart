import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_sender.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/messages_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/text_field.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
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
  MessageBloc existingMessageBloc;

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
    setState(() {});
  }

  String cleansePhoneNumber(String input) {
    String output = input.replaceAll("-", "");
    output = output.replaceAll("(", "");
    output = output.replaceAll(")", "");
    // output = output.replaceAll("+", "");
    output = output.replaceAll(" ", "");
    // output = output.replaceAll(".", "");
    // output = output.replaceAll("@", "");
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
            if (!addresses.contains(cleansePhoneNumber(element.value)))
              addresses.add(cleansePhoneNumber(element.value));
          });
          element.emails.forEach((element) {
            if (!addresses.contains(cleansePhoneNumber(element.value)))
              addresses.add(cleansePhoneNumber(element.value));
          });
        } else {
          addresses.add(element);
        }
      });
      debugPrint(addresses.toString());
      int foundContacts = 0;
      for (Handle handle in chat.participants) {
        for (String address in addresses) {
          if (cleansePhoneNumber(handle.address).contains(address)) {
            foundContacts++;
            break;
          }
        }
      }
      if (foundContacts == participants.length &&
          chat.participants.length == participants.length)
        possibleChats.add(chat);
    }
    if (possibleChats.length > 1) {
      possibleChats.sort((a, b) {
        return -ChatBloc()
            .tileVals[a.guid]["actualDate"]
            .compareTo(ChatBloc().tileVals[b.guid]["actualDate"]);
      });
      possibleChats.forEach((element) {
        String toPrint = "Chat: ";
        element.participants.forEach((element) {
          toPrint += element.address + ", ";
        });
        debugPrint(toPrint);
      });
    }
    if (possibleChats.length > 0) {
      existingChat = possibleChats.first;
      if (existingMessageBloc != null) {
        existingMessageBloc.dispose();
      }
      existingMessageBloc = new MessageBloc(existingChat);
      await existingMessageBloc.getMessages();
      // debugPrint(existingMessageBloc.messages.values.first.text);
      setState(() {});
      // existingMessageBloc.getMessages();
    } else {
      setState(() {
        existingChat = null;
      });
    }
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
        trailing: Container(
          child: FlatButton(
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
                  params["address"] = cleansePhoneNumber(_participants[i]);
                  SocketManager().sendMessage("add-participant", params,
                      (_data) async {
                    Map<String, dynamic> response = _data;
                    debugPrint("added participant " + response.toString());
                    if (i == _participants.length - 1 &&
                        response["status"] == 200) {
                      Chat updatedChat = Chat.fromMap(response["data"]);
                      updatedChat.save();
                      // await ChatBloc().getChats();
                      // NewMessageManager().updateWithMessage(null, null);
                      await ChatBloc().moveChatToTop(updatedChat);
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
      body: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              CupertinoTextField(
                onChanged: (String text) {
                  if (text.length > 0) {
                    if (text.substring(text.length - 1) == "," &&
                        text.length > previousText.length) {
                      participants
                          .add(text.split(",")[text.split(",").length - 2]);
                      debugPrint(
                          "updated participants: " + participants.toString());
                      _controller.text += " ";
                      _controller.selection = TextSelection(
                        baseOffset: _controller.text.length,
                        extentOffset: _controller.text.length,
                      );
                      tryFindExistingChat();
                    } else if (previousText.length > 0 &&
                        previousText.substring(previousText.length - 1) ==
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
                style: Theme.of(context).textTheme.bodyText1,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                padding:
                    EdgeInsets.only(left: 50, right: 40, top: 20, bottom: 20),
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
                child:
                    Text("To: ", style: Theme.of(context).textTheme.subtitle1),
              ),
            ],
          ),
          Expanded(
            child: widget.isCreator &&
                    _controller.text.length > 1 &&
                    _controller.text.substring(_controller.text.length - 2) ==
                        ", "
                ? existingChat != null
                    ? MessageView(
                        key: Key(existingChat.guid),
                        messageBloc: existingMessageBloc,
                        showHandle: existingChat.participants.length > 1,
                      )
                    : Container()
                : ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: contacts.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        onTap: () {
                          if (_controller.text.contains(",")) {
                            _controller.text = _controller.text.substring(
                                    0, _controller.text.lastIndexOf(",")) +
                                ", " +
                                contacts[index].displayName +
                                ", ";
                          } else {
                            _controller.text =
                                contacts[index].displayName + ", ";
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
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                        subtitle: Text(
                          contacts[index].phones.length > 0
                              ? contacts[index].phones.first.value
                              : contacts[index].emails.length > 0
                                  ? contacts[index].emails.first.value
                                  : "",
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                      );
                    },
                  ),
          ),
          //   ],
          // ),
          // Spacer(
          //   flex: 1,
          // ),
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
                        await ActionHandler.sendMessage(existingChat, text);
                      }
                      String title = await getFullChatTitle(existingChat);
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute(
                          builder: (context) => ConversationView(
                            chat: existingChat,
                            title: title,
                            messageBloc: existingMessageBloc,
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
                    params["participants"] = _participants;
                    SocketManager().sendMessage(
                      "start-chat",
                      params,
                      (data) async {
                        Chat newChat = Chat.fromMap(data["data"]);
                        newChat = await newChat.save();
                        newChat = await newChat.getParticipants();
                        String title = await getFullChatTitle(newChat);
                        // await ChatBloc().getChats();
                        // await NewMessageManager()
                        //     .updateWithMessage(null, null);
                        await ChatBloc().moveChatToTop(newChat);
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
                          CupertinoPageRoute(
                            builder: (context) => ConversationView(
                              chat: newChat,
                              title: title,
                              messageBloc: MessageBloc(newChat),
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              : Container(),
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
