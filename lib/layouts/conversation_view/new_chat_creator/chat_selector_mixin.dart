import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_option.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class UniqueContact {
  final String displayName;
  final String label;
  final String address;
  final Chat chat;

  bool get isChat => chat != null;

  UniqueContact({this.displayName, this.label, this.address, this.chat});
}

mixin ChatSelectorMixin<ConvrsationViewState extends StatefulWidget>
    on State<ConversationView> {
  List<Chat> conversations = [];
  List<UniqueContact> contacts = [];
  List<UniqueContact> selected = [];
  List<UniqueContact> prevSelected = [];
  String searchQuery = "";
  bool currentlyProcessingDeleteKey = false;

  TextEditingController chatSelectorController =
      new TextEditingController(text: " ");

  void initChatSelector() {
    if (!widget.localIsCreator) return;

    loadEntries();

    // Add listener to filter the contacts on text change
    chatSelectorController.addListener(() {
      if (chatSelectorController.text.length == 0) {
        if (selected.length > 0 && !currentlyProcessingDeleteKey) {
          currentlyProcessingDeleteKey = true;
          selected.removeLast();
          resetCursor();
          fetchCurrentChat();
          setState(() {});
          // Prevent deletes from occuring multiple times
          Future.delayed(Duration(milliseconds: 100), () {
            currentlyProcessingDeleteKey = false;
          });
        } else {
          resetCursor();
        }
      } else if (chatSelectorController.text[0] != " ") {
        chatSelectorController.text = " " +
            chatSelectorController.text
                .substring(0, chatSelectorController.text.length - 1);
        chatSelectorController.selection = TextSelection.fromPosition(
          TextPosition(offset: chatSelectorController.text.length),
        );
        setState(() {});
      }
      searchQuery = chatSelectorController.text.substring(1);
      filterContacts();
    });

    ChatBloc().chatStream.listen((List<Chat> chats) {
      if (this.mounted) loadEntries();
    });
  }

  void resetCursor() {
    if (!widget.localIsCreator) return;
    chatSelectorController.text = " ";
    chatSelectorController.selection = TextSelection.fromPosition(
      TextPosition(offset: 1),
    );
  }

  void fetchCurrentChat() {
    if (!widget.localIsCreator) return;
    if (selected.length == 1 && selected.first.isChat) {
      widget.localChat = selected.first.chat;
    }
    debugPrint(selected.toString());
    if (selected.length == 0) {
      widget.localChat = null;
      if (this.mounted) setState(() {});
      return;
    }
    List<Chat> cache = ChatBloc().chats.sublist(0);

    cache.retainWhere((element) {
      if (element.participants.length != selected.length) return false;
      for (UniqueContact contact in selected) {
        if (!contact.isChat &&
            element.participants
                .where((participant) =>
                    sameAddress(participant.address, contact.address))
                .isEmpty) {
          return false;
        }
      }
      return true;
    });
    if (cache.length == 0) {
      widget.localChat = null;
      widget.messageBloc = null;
      if (this.mounted) setState(() {});
      return;
    }

    cache
        .sort((a, b) => a.participants.length.compareTo(b.participants.length));
    widget.localChat = cache.first;
    NotificationManager().switchChat(widget.localChat);
    widget.messageBloc = null;
    if (this.mounted) setState(() {});
  }

  Future<void> loadEntries() async {
    if (!widget.localIsCreator) return;
    if (isNullOrEmpty(ChatBloc().chats)) {
      await ChatBloc().refreshChats();
    }

    conversations = ChatBloc().chats.sublist(0);
    for (Chat element in conversations) {
      await element.getParticipants();
    }

    if (widget.type != ChatSelectorTypes.ONLY_EXISTING) {
      conversations.retainWhere((element) => element.participants.length > 1);
    }

    filterContacts();
    if (this.mounted) setState(() {});
  }

  void filterContacts() {
    if (!widget.localIsCreator) return;
    if (selected.length == 1 && selected.first.isChat) {
      if (this.mounted)
        setState(() {
          contacts = [];
        });
    }
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
              address: email.value,
              displayName: contact.displayName,
              label: email.label,
            ),
          );
        }
      }
    };

    if (widget.type != ChatSelectorTypes.ONLY_EXISTING) {
      for (Contact contact in ContactManager().contacts) {
        String name = (contact.displayName ?? "").toLowerCase();
        if (name.contains(searchQuery.toLowerCase())) {
          addContactEntries(contact);
        } else {
          addContactEntries(contact, conditionally: true);
        }
      }
    }

    List<UniqueContact> _conversations = [];
    if (selected.length == 0 &&
        widget.type != ChatSelectorTypes.ONLY_CONTACTS) {
      for (Chat chat in conversations) {
        String title = (chat?.title ?? "").toLowerCase();
        if (title.contains(searchQuery.toLowerCase())) {
          if (!cache.contains(chat.guid)) {
            cache.add(chat.guid);
            _conversations.add(
              new UniqueContact(
                chat: chat,
                displayName: chat.title,
              ),
            );
          }
        }
      }
    }

    _conversations.addAll(_contacts);
    if (searchQuery.length > 0)
      _conversations.sort((a, b) {
        if (a.isChat && !b.isChat) return 1;
        if (b.isChat && !a.isChat) return -1;
        if (!b.isChat && !a.isChat) return 0;
        return a.chat.participants.length.compareTo(b.chat.participants.length);
      });

    if (this.mounted)
      setState(() {
        contacts = _conversations;
      });
  }

  Future<Chat> createChat() async {
    if (widget.localChat != null) return widget.localChat;
    Completer<Chat> completer = Completer();
    if (searchQuery.length > 0) {
      selected.add(
          new UniqueContact(address: searchQuery, displayName: searchQuery));
    }
    List<String> participants =
        selected.map((e) => cleansePhoneNumber(e.address)).toList();
    Map<String, dynamic> params = {};
    showDialog(
      context: context,
      child: AlertDialog(
        backgroundColor: Theme.of(context).accentColor,
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
              title: Text(
                "Could not create",
              ),
              content: Text(
                "Reason: (${data["error"]["type"]}) -> ${data["error"]["message"]}",
              ),
              actions: [
                FlatButton(
                  child: Text(
                    "Ok",
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
          );
          completer.complete(null);
          return;
        }

        // If everything went well, let's add the chat to the bloc
        Chat newChat = Chat.fromMap(data["data"]);
        await newChat.save();
        await ChatBloc().updateChatPosition(newChat);
        completer.complete(newChat);
        Navigator.of(context).pop();
      },
    );

    return completer.future;
  }

  void onSelected(UniqueContact item) {
    if (item.isChat) {
      if (widget.type == ChatSelectorTypes.ONLY_EXISTING) {
        selected.add(item);
        widget.localChat = item.chat;
        contacts = [];
      } else {
        item.chat.participants.forEach((e) {
          UniqueContact contact = new UniqueContact(
              address: e.address,
              displayName: ContactManager()
                      .getCachedContactSync(e.address)
                      ?.displayName ??
                  formatPhoneNumber(e.address));
          selected.add(contact);
        });
        fetchCurrentChat();
      }
      resetCursor();
      if (this.mounted) setState(() {});
      return;
    }
    // Add the selected item
    selected.add(item);
    fetchCurrentChat();

    // Reset the controller text
    resetCursor();
    if (this.mounted) setState(() {});
  }

  Widget buildChatSelectorBody() => ListView.builder(
        physics: AlwaysScrollableScrollPhysics(
            parent: CustomBouncingScrollPhysics()),
        itemBuilder: (BuildContext context, int index) => ContactSelectorOption(
          item: contacts[index],
          onSelected: onSelected,
        ),
        itemCount: contacts.length,
      );

  Widget buildChatSelectorHeader() => PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: CupertinoNavigationBar(
          backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
          middle: Container(
            child: Text(
              widget.customHeading ?? "New Message",
              style: Theme.of(context).textTheme.headline2,
            ),
          ),
          leading: Container(),
        ),
      );
}
