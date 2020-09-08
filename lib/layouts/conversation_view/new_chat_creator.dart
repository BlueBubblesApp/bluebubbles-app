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
    List _contacts = [];
    _contacts.addAll(ContactManager().contacts);
    if (filter.isNotEmpty) {
      _contacts.retainWhere((contact) {
        String searchTerm = searchQuery.toLowerCase();
        searchTerm = cleansePhoneNumber(searchTerm);

        String contactName =
            cleansePhoneNumber(contact.displayName.toLowerCase());
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

    List _conversations = [];
    _conversations.addAll(conversations);
    _conversations.retainWhere((element) {
      if (element.participants.length == 1) return false;
      if ((element as Chat).title.contains(searchQuery.toLowerCase()))
        return true;
      return false;
    });
    _conversations.addAll(_contacts);
    contacts = _conversations;

    setState(() {});
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
                    physics: AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: contacts.length,
                    itemBuilder: (BuildContext context, int index) {
                      return contacts[index] is Contact
                          ? ListTile(
                              onTap: () {
                                Contact contact = contacts[index];
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
                            )
                          : Builder(
                              builder: (context) {
                                // Map<String, dynamic> _data = ChatBloc()
                                //     .tileVals[contacts[index].guid];
                                return ConversationTile(
                                  chat: contacts[index],
                                  // title: _data["title"],
                                  // subtitle: _data["subtitle"],
                                  // date: _data["date"],
                                  // hasNewMessage: false,
                                  replaceOnTap: true,
                                );
                              },
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

// class _NewChatCreatorState extends State<NewChatCreator> {
//   TextEditingController _controller;
//   List contacts = <Contact>[];
//   List participants = [];
//   String previousText = "";
//   Chat existingChat;
//   MessageBloc existingMessageBloc;
//   List<Chat> conversations = [];

//   @override
//   void initState() {
//     super.initState();
//     if (ChatBloc().chats != null) {
//       conversations = ChatBloc().chats;
//       conversations.forEach((element) {
//         element.getParticipants();
//       });
//     }
//     ChatBloc().chatStream.listen((event) {
//       if (conversations.length == 0 && this.mounted && event != null) {
//         conversations = event;
//         conversations.forEach((element) {
//           element.getParticipants();
//         });
//         setState(() {});
//       }
//     });
//     _controller = TextEditingController();
//   }

//   void filterContacts(String searchQuery) {
//     List _contacts = [];
//     _contacts.addAll(ContactManager().contacts);
//     if (_controller.text.isNotEmpty) {
//       _contacts.retainWhere((contact) {
//         String searchTerm = searchQuery.toLowerCase();
//         searchTerm = cleansePhoneNumber(searchTerm);

//         String contactName = contact.displayName.toLowerCase();
//         String contactAddress = "";
//         String contactEmail = "";
//         if (contact.phones.length > 0) {
//           contactAddress =
//               cleansePhoneNumber(contact.phones.first.value.toLowerCase());
//         }
//         if (contact.emails.length > 0) {
//           contactEmail =
//               cleansePhoneNumber(contact.emails.first.value.toLowerCase());
//         }
//         return (contactName != "" && contactName.contains(searchTerm)) ||
//             (contactAddress != "" && contactAddress.contains(searchTerm) ||
//                 (contactEmail != "" && contactEmail.contains(searchTerm)));
//         // return true;
//       });
//     }
//     // contacts = _contacts;
//     List _conversations = [];
//     _conversations.addAll(conversations);
//     _conversations.retainWhere((element) {
//       // Map<String, dynamic> data = ChatBloc().tileVals[element.guid];
//       if (element.participants.length == 1) return false;
//       if ((element as Chat).title.contains(searchQuery.toLowerCase()))
//         return true;
//       return false;
//     });
//     _conversations.addAll(_contacts);
//     contacts = _conversations;

//     setState(() {});
//   }

//   Future<void> tryFindExistingChat() async {
//     if (!widget.isCreator) return;
//     List<Chat> possibleChats = <Chat>[];
//     for (Chat _chat in ChatBloc().chats) {
//       Chat chat = await _chat.getParticipants();

//       List<String> addresses = <String>[];
//       participants.forEach((element) {
//         if (element is Contact) {
//           element.phones.forEach((element) {
//             if (!addresses.contains(cleansePhoneNumber(element.value)))
//               addresses.add(cleansePhoneNumber(element.value));
//           });
//           element.emails.forEach((element) {
//             if (!addresses.contains(cleansePhoneNumber(element.value)))
//               addresses.add(cleansePhoneNumber(element.value));
//           });
//         } else {
//           addresses.add(element);
//         }
//       });
//       debugPrint(addresses.toString());
//       int foundContacts = 0;
//       for (Handle handle in chat.participants) {
//         for (String address in addresses) {
//           if (cleansePhoneNumber(handle.address).contains(address)) {
//             foundContacts++;
//             break;
//           }
//         }
//       }
//       if (foundContacts == participants.length &&
//           chat.participants.length == participants.length)
//         possibleChats.add(chat);
//     }
//     if (possibleChats.length > 1) {
//       possibleChats.sort((a, b) {
//         return -a.latestMessageDate.compareTo(b.latestMessageDate);
//       });
//       possibleChats.forEach((element) {
//         String toPrint = "Chat: ";
//         element.participants.forEach((element) {
//           toPrint += element.address + ", ";
//         });
//         debugPrint(toPrint);
//       });
//     }
//     if (possibleChats.length > 0) {
//       existingChat = possibleChats.first;
//       if (existingMessageBloc != null) {
//         existingMessageBloc.dispose();
//       }
//       existingMessageBloc = new MessageBloc(existingChat);
//       await existingMessageBloc.getMessages();
//       setState(() {});
//     } else {
//       setState(() {
//         existingChat = null;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).backgroundColor,
//       appBar: CupertinoNavigationBar(
//         backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
//         middle: Container(
//           child: Text(
//             "New Message",
//             style: Theme.of(context).textTheme.headline2,
//           ),
//         ),
//         leading: Container(),
//         trailing: Container(
//           child: FlatButton(
//             color: Colors.transparent,
//             onPressed: () {
//               if (!widget.isCreator) {
//                 showDialog(
//                   context: context,
//                   child: ClipRRect(
//                     child: BackdropFilter(
//                       filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//                       child: SizedBox(
//                         height: 100,
//                         width: 100,
//                         child: CircularProgressIndicator(),
//                       ),
//                     ),
//                   ),
//                 );
//                 Map<String, dynamic> params = new Map();
//                 List<String> _participants = <String>[];
//                 participants.forEach((e) {
//                   if (e is Contact) {
//                     if (e.phones.length > 0) {
//                       _participants.add(e.phones.first.value);
//                     } else if (e.emails.length > 0) {
//                       _participants.add(e.emails.first.value);
//                     }
//                   } else {
//                     _participants.add(e);
//                   }
//                 });
//                 for (int i = 0; i < _participants.length; i++) {
//                   params["identifier"] = widget.currentChat.guid;
//                   params["address"] = cleansePhoneNumber(_participants[i]);
//                   SocketManager().sendMessage("add-participant", params,
//                       (_data) async {
//                     Map<String, dynamic> response = _data;
//                     debugPrint("added participant " + response.toString());
//                     if (i == _participants.length - 1 &&
//                         response["status"] == 200) {
//                       Chat updatedChat = Chat.fromMap(response["data"]);
//                       updatedChat.save();
//                       // await ChatBloc().getChats();
//                       // NewMessageManager().updateWithMessage(null, null);
//                       await ChatBloc().moveChatToTop(updatedChat);
//                       Navigator.of(context).pop();
//                       Chat chatWithParticipants =
//                           await updatedChat.getParticipants();
//                       Navigator.of(context).pop(chatWithParticipants);
//                     }
//                   });
//                 }
//               } else {
//                 Navigator.of(context).pop();
//               }
//             },
//             child: Text(
//               widget.isCreator ? "Cancel" : "Done",
//               style: TextStyle(color: Colors.blue),
//             ),
//           ),
//         ),
//       ),
//       body: Column(
//         children: <Widget>[
//           Stack(
//             children: <Widget>[
//               RichInput(
//                 onChanged: (String text) {
//                   if (text.length > 0) {
//                     if (text.substring(text.length - 1) == "," &&
//                         text.length > previousText.length) {
//                       participants
//                           .add(text.split(",")[text.split(",").length - 2]);
//                       debugPrint(
//                           "updated participants: " + participants.toString());
//                       _controller.text += " ";
//                       _controller.selection = TextSelection(
//                         baseOffset: _controller.text.length,
//                         extentOffset: _controller.text.length,
//                       );
//                       tryFindExistingChat();
//                     } else if (previousText.length > 0 &&
//                         previousText.substring(previousText.length - 1) ==
//                             "," &&
//                         text.substring(text.length - 1) != "," &&
//                         text.length < previousText.length) {
//                       participants.removeLast();
//                       String newParticipantsText = "";
//                       for (int i = 0;
//                           i < previousText.split(",").length - 2;
//                           i++) {
//                         newParticipantsText +=
//                             previousText.split(",")[i] + ", ";
//                       }
//                       _controller.text = newParticipantsText;
//                       _controller.selection = TextSelection(
//                         baseOffset: _controller.text.length,
//                         extentOffset: _controller.text.length,
//                       );
//                       tryFindExistingChat();
//                     } else {
//                       if (text.contains(",")) {
//                         debugPrint("searching " + text.split(",").last);
//                         filterContacts(
//                             text.split(",").last.replaceFirst(" ", ""));
//                       } else {
//                         filterContacts(text);
//                       }
//                     }
//                   } else {
//                     conversations = ChatBloc().chats;
//                   }
//                   previousText = text;
//                   setState(() {});
//                 },
//                 controller: _controller,
//                 scrollPhysics: BouncingScrollPhysics(),
//                 style: Theme.of(context).textTheme.bodyText1,
//                 keyboardType: TextInputType.multiline,
//                 maxLines: null,
//                 // padding:
//                 //     EdgeInsets.only(left: 50, right: 40, top: 20, bottom: 20),
//                 // placeholderStyle: TextStyle(),
//                 autofocus: true,
//                 // decoration: BoxDecoration(
//                 //   color: Colors.transparent,
//                 // ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.only(
//                   left: 10,
//                   top: 18,
//                 ),
//                 child:
//                     Text("To: ", style: Theme.of(context).textTheme.subtitle1),
//               ),
//             ],
//           ),
//           Expanded(
//             child: widget.isCreator &&
//                     _controller.text.length > 1 &&
//                     _controller.text.substring(_controller.text.length - 2) ==
//                         ", "
//                 ? existingChat != null
//                     ? MessageView(
//                         key: Key(existingChat.guid),
//                         messageBloc: existingMessageBloc,
//                         showHandle: existingChat.participants.length > 1,
//                       )
//                     : Container()
//                 : _controller.text.length > 0
//                     ? ListView.builder(
//                         physics: AlwaysScrollableScrollPhysics(
//                           parent: BouncingScrollPhysics(),
//                         ),
//                         itemCount: contacts.length,
//                         itemBuilder: (BuildContext context, int index) {
//                           return contacts[index] is Contact
//                               ? ListTile(
//                                   onTap: () {
//                                     if (_controller.text.contains(",")) {
//                                       _controller.text = _controller.text
//                                               .substring(
//                                                   0,
//                                                   _controller.text
//                                                       .lastIndexOf(",")) +
//                                           ", " +
//                                           contacts[index].displayName +
//                                           ", ";
//                                     } else {
//                                       _controller.text =
//                                           contacts[index].displayName + ", ";
//                                     }
//                                     _controller.selection = TextSelection(
//                                       baseOffset: _controller.text.length,
//                                       extentOffset: _controller.text.length,
//                                     );
//                                     previousText = _controller.text;
//                                     participants.add(contacts[index]);
//                                     contacts = [];
//                                     setState(() {});
//                                     tryFindExistingChat();
//                                   },
//                                   title: Text(
//                                     contacts[index].displayName,
//                                     style:
//                                         Theme.of(context).textTheme.bodyText1,
//                                   ),
//                                   subtitle: Text(
//                                     contacts[index].phones.length > 0
//                                         ? contacts[index].phones.first.value
//                                         : contacts[index].emails.length > 0
//                                             ? contacts[index].emails.first.value
//                                             : "",
//                                     style:
//                                         Theme.of(context).textTheme.subtitle1,
//                                   ),
//                                 )
//                               : Builder(
//                                   builder: (context) {
//                                     // Map<String, dynamic> _data = ChatBloc()
//                                     //     .tileVals[contacts[index].guid];
//                                     return ConversationTile(
//                                       chat: contacts[index],
//                                       // title: _data["title"],
//                                       // subtitle: _data["subtitle"],
//                                       // date: _data["date"],
//                                       // hasNewMessage: false,
//                                       replaceOnTap: true,
//                                     );
//                                   },
//                                 );
//                         },
//                       )
//                     : ListView.builder(
//                         physics: AlwaysScrollableScrollPhysics(
//                             parent: BouncingScrollPhysics()),
//                         itemBuilder: (context, index) {
//                           // Map<String, dynamic> _data =
//                           //     ChatBloc().tileVals[conversations[index].guid];

//                           return ConversationTile(
//                             existingAttachments: widget.attachments,
//                             existingText: widget.existingText,
//                             chat: conversations[index],
//                             // title: _data["title"],
//                             // subtitle: _data["subtitle"],
//                             // date: _data["date"],
//                             // hasNewMessage: false,
//                             replaceOnTap: true,
//                           );
//                         },
//                         itemCount: conversations.length,
//                       ),
//           ),
//           //   ],
//           // ),
//           // Spacer(
//           //   flex: 1,
//           // ),
//           widget.isCreator
//               ? BlueBubblesTextField(
//                   existingAttachments: widget.attachments,
//                   existingText: widget.existingText,
//                   customSend: (pickedImages, text) async {
//                     if (_controller.text.length == 0) return;
//                     if (!_controller.text.endsWith(", ")) {
//                       participants.add(_controller.text.split(",").last);
//                     }
//                     await tryFindExistingChat();
//                     if (existingChat != null) {
//                       if (pickedImages.length > 0) {
//                         for (int i = 0; i < pickedImages.length; i++) {
//                           OutgoingQueue().add(new QueueItem(
//                               event: "send-attachment",
//                               item: new AttachmentSender(
//                                 pickedImages[i],
//                                 existingChat,
//                                 i == pickedImages.length - 1 ? text : "",
//                               )));
//                         }
//                       } else {
//                         await ActionHandler.sendMessage(existingChat, text);
//                       }
//                       String title = await getFullChatTitle(existingChat);
//                       Navigator.of(context).pushReplacement(
//                         MaterialPageRoute(
//                           builder: (context) => ConversationView(
//                             chat: existingChat,
//                             title: title,
//                             messageBloc: existingMessageBloc,
//                           ),
//                         ),
//                       );
//                       return;
//                     }
//                     Map<String, dynamic> params = new Map();
//                     List<String> _participants = <String>[];
//                     participants.forEach((e) {
//                       if (e is Contact) {
//                         if (e.phones.length > 0) {
//                           _participants.add(e.phones.first.value);
//                         } else if (e.emails.length > 0) {
//                           _participants.add(e.emails.first.value);
//                         }
//                       } else {
//                         _participants.add(e);
//                       }
//                     });
//                     showDialog(
//                       context: context,
//                       child: AlertDialog(
//                         backgroundColor: Theme.of(context).backgroundColor,
//                         title: Text(
//                           "Creating a new chat...",
//                           style: Theme.of(context).textTheme.bodyText1,
//                         ),
//                         content: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: <Widget>[
//                             Container(
//                               // height: 70,
//                               // color: Colors.black,
//                               child: CircularProgressIndicator(
//                                 valueColor:
//                                     AlwaysStoppedAnimation<Color>(Colors.blue),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                     params["participants"] = _participants;
//                     SocketManager().sendMessage(
//                       "start-chat",
//                       params,
//                       (data) async {
//                         if (data['status'] != 200) {
//                           Navigator.of(context).pop();
//                           showDialog(
//                             context: context,
//                             child: AlertDialog(
//                               backgroundColor:
//                                   Theme.of(context).backgroundColor,
//                               title: Text(
//                                 "Could not create",
//                                 style: Theme.of(context).textTheme.bodyText1,
//                               ),
//                               content: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: <Widget>[
//                                   Container(
//                                     // height: 70,
//                                     // color: Colors.black,
//                                     child: CircularProgressIndicator(
//                                       valueColor: AlwaysStoppedAnimation<Color>(
//                                           Colors.blue),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                           return;
//                         }
//                         Chat newChat = Chat.fromMap(data["data"]);
//                         await newChat.save();

//                         NewMessageManager().updateWithMessage(null, null);

//                         String title = await getFullChatTitle(newChat);
//                         await ChatBloc().moveChatToTop(newChat);

//                         if (pickedImages.length > 0) {
//                           for (int i = 0; i < pickedImages.length; i++) {
//                             OutgoingQueue().add(new QueueItem(
//                                 event: "send-attachment",
//                                 item: new AttachmentSender(
//                                   pickedImages[i],
//                                   newChat,
//                                   i == pickedImages.length - 1 ? text : "",
//                                 )));
//                           }
//                         } else {
//                           await ActionHandler.sendMessage(newChat, text);
//                         }
//                         Navigator.of(context, rootNavigator: true).pop();
//                         Navigator.of(context).pushReplacement(
//                           MaterialPageRoute(
//                             builder: (context) => ConversationView(
//                               chat: newChat,
//                               title: title,
//                               messageBloc: MessageBloc(newChat),
//                             ),
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 )
//               : Container(),
//         ],
//       ),
//     );
//   }
// }

// class Participant {
//   String _displayName = "";
//   Contact _contact;
//   String _address = "";

//   String get displayName => _displayName;
//   String get address => _address;

//   Participant(contact) {
//     if (contact is String) {
//       _displayName = contact;
//       _address = contact;
//     } else if (contact is Contact) {
//       if (contact.phones.length > 0) {
//         _address = contact.phones.first.value;
//       } else if (contact.emails.length > 0) {
//         _address = contact.emails.first.value;
//       }

//       _displayName = contact.displayName;
//       _contact = contact;
//     }
//   }
// }
