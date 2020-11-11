import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/adding_participant_popup.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../socket_manager.dart';

class UniqueContact {
  final bool isChat;
  final String displayName;
  final String label;
  final String address;
  final Chat chat;

  UniqueContact(
      {this.isChat, this.displayName, this.label, this.address, this.chat});
}

class ChatSelector extends StatefulWidget {
  final bool isCreator;
  final Chat currentChat;
  final List<File> attachments;
  final String existingText;
  final String heading;
  final bool onlyExistingChats;
  final Function onSelection;
  ChatSelector({
    Key key,
    this.isCreator,
    this.currentChat,
    this.attachments,
    this.existingText,
    this.heading,
    this.onlyExistingChats = false,
    this.onSelection,
  }) : super(key: key);

  @override
  _ChatSelectorState createState() => _ChatSelectorState();
}

class _ChatSelectorState extends State<ChatSelector> {
  List<Chat> conversations = [];
  List<UniqueContact> contacts = [];
  List<UniqueContact> selected = [];
  bool hadInvisibleSpace = false;
  String searchQuery = "";

  TextEditingController controller = new TextEditingController();

  @override
  void initState() {
    super.initState();
    loadEntries();

    // Add listener to filter the contacts on text change
    controller.addListener(() {
      searchQuery = controller.text;
      filterContacts();
    });

    ChatBloc().chatStream.listen((List<Chat> chats) {
      loadEntries();
    });
  }

  Future<void> loadEntries() async {
    if (!widget.isCreator) return;
    if (isNullOrEmpty(ChatBloc().chats)) {
      await ChatBloc().refreshChats();
    }

    conversations = ChatBloc().chats;
    conversations.forEach((element) {
      element.getParticipants();
    });

    filterContacts();
  }

  String getTypeStr(String type) {
    if (isNullOrEmpty(type)) return "";
    return " ($type)";
  }

  void filterContacts() {
    searchQuery = (searchQuery ?? "");

    List<UniqueContact> _contacts = [];
    List<String> cache = [];
    Function addContactEntries = (Contact contact, {conditionally = false}) {
      for (Item phone in contact.phones) {
        String cleansed = cleansePhoneNumber(phone.value);
        if (conditionally && !cleansed.contains(searchQuery.toLowerCase()))
          continue;

        if (!cache.contains(cleansed)) {
          cache.add(cleansed);
          _contacts.add(
            new UniqueContact(
              isChat: false,
              address: phone.value,
              displayName: contact.displayName,
              label: phone.label,
            ),
          );
        }
      }

      for (Item email in contact.emails) {
        if (conditionally && !email.value.contains(searchQuery.toLowerCase()))
          continue;

        if (!cache.contains(email.value)) {
          cache.add(email.value);
          _contacts.add(
            new UniqueContact(
              isChat: false,
              address: email.value,
              displayName: contact.displayName,
              label: email.label,
            ),
          );
        }
      }
    };

    for (Contact contact in ContactManager().contacts) {
      String name = (contact.displayName ?? "").toLowerCase();
      if (name.contains(searchQuery.toLowerCase())) {
        addContactEntries(contact);
      } else {
        addContactEntries(contact, conditionally: true);
      }
    }

    List<UniqueContact> _conversations = [];
    if (selected.length == 0 || widget.onlyExistingChats) {
      for (Chat chat in conversations) {
        String title = (chat?.title ?? "").toLowerCase();
        if (title.contains(searchQuery.toLowerCase())) {
          if (!cache.contains(chat.guid)) {
            cache.add(chat.guid);
            _conversations.add(
              new UniqueContact(
                isChat: true,
                chat: chat,
                displayName: chat.title,
              ),
            );
          }
        }
      }
    }

    if (!widget.onlyExistingChats) {
      _conversations.addAll(_contacts);
    }

    if (this.mounted)
      setState(() {
        contacts = _conversations;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
        middle: Container(
          child: Text(
            widget.heading ?? "New Message",
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
              child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(
              parent: CustomBouncingScrollPhysics(),
            ),
            itemCount: contacts.length,
            itemBuilder: (BuildContext context, int index) {
              UniqueContact item = contacts[index];
              return !item.isChat
                  ? ListTile(
                      key: new Key(item.address),
                      onTap: () {
                        // Add the selected item
                        selected.add(item);

                        if (widget.onSelection != null) {
                          return widget.onSelection(selected);
                        }

                        // Reset the controller text
                        controller.clear();
                        if (this.mounted) setState(() {});
                      },
                      title: Text(
                        "${item.displayName}${getTypeStr(item.label)}",
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      subtitle: Text(
                        item.address,
                        style: Theme.of(context).textTheme.subtitle1,
                      ),
                    )
                  : ConversationTile(
                      key: new Key(item.chat.chatIdentifier),
                      existingAttachments: widget.attachments,
                      existingText: widget.existingText,
                      chat: item.chat,
                      onTapCallback: () {
                        // Add the selected item
                        selected.add(item);

                        if (widget.onSelection != null) {
                          return widget.onSelection(selected);
                        }
                      },
                    );
            },
          )),
          ChatSelectorTextField(
              allContacts:
                  this.contacts.where((element) => !element.isChat).toList(),
              isCreator: widget.isCreator,
              controller: controller,
              onCreate: () {
                if (widget.isCreator) {
                  List<String> participants = selected
                      .map((e) => cleansePhoneNumber(e.address))
                      .toList();
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor),
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
                          barrierDismissible: false,
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
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        return;
                      }

                      // If everything went well, let's add the chat to the bloc
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
                  if (selected.length > 0)
                    showDialog(
                      barrierDismissible: false,
                      context: context,
                      child: AddingParticipantPopup(
                        contacts: selected,
                        chat: widget.currentChat,
                      ),
                    );
                }
              },
              onRemove: (UniqueContact contact) {
                selected.remove(contact);
                filterContacts();
                if (this.mounted) setState(() {});
              },
              selectedContacts: selected)
        ],
      ),
    );
  }
}
