import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/adding_participant_popup.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_option.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';

import '../../../socket_manager.dart';

class UniqueContact {
  final String displayName;
  final String label;
  final String address;
  final Chat chat;

  bool get isChat => chat != null;

  UniqueContact({this.displayName, this.label, this.address, this.chat});
}

class ChatSelector extends StatefulWidget {
  final bool isCreator;
  final Chat currentChat;
  final List<File> attachments;
  final String existingText;
  final String heading;
  final bool onlyExistingChats;
  final Function onSelection;
  final bool onTapGoToChat;
  ChatSelector({
    Key key,
    this.isCreator,
    this.currentChat,
    this.attachments,
    this.existingText,
    this.heading,
    this.onlyExistingChats = false,
    this.onSelection,
    this.onTapGoToChat = false,
  }) : super(key: key);

  static ChatSelectorState of(BuildContext context) {
    assert(context != null);
    return context.findAncestorStateOfType<ChatSelectorState>();
  }

  @override
  ChatSelectorState createState() => ChatSelectorState();
}

class ChatSelectorState extends State<ChatSelector> {
  List<Chat> conversations = [];
  List<UniqueContact> contacts = [];
  List<UniqueContact> selected = [];
  List<UniqueContact> prevSelected = [];
  String searchQuery = "";
  bool currentlyProcessingDeleteKey = false;

  TextEditingController controller = new TextEditingController(text: " ");
  Chat currentChat;
  MessageBloc currentChatMessageBloc;

  void resetCursor() {
    controller.text = " ";
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  @override
  void initState() {
    super.initState();
    loadEntries();

    // Add listener to filter the contacts on text change
    controller.addListener(() {
      if (controller.text.length == 0) {
        if (selected.length > 0 && !currentlyProcessingDeleteKey) {
          currentlyProcessingDeleteKey = true;
          selected.removeLast();
          resetCursor();
          fetchCurrentChat();
          setState(() {
            currentlyProcessingDeleteKey = false;
          });
        } else {
          resetCursor();
        }
      } else if (controller.text[0] != " ") {
        controller.text =
            " " + controller.text.substring(0, controller.text.length - 1);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        setState(() {});
      }
      searchQuery = controller.text.substring(1);
      filterContacts();
    });

    ChatBloc().chatStream.listen((List<Chat> chats) {
      if (this.mounted) loadEntries();
    });
  }

  Future<void> loadEntries() async {
    if (!widget.isCreator) return;
    if (isNullOrEmpty(ChatBloc().chats)) {
      await ChatBloc().refreshChats();
    }

    conversations = ChatBloc().chats.sublist(0);
    for (Chat element in conversations) {
      await element.getParticipants();
    }

    conversations.retainWhere((element) => element.participants.length > 1);

    filterContacts();
    if (this.mounted) setState(() {});
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

  void fetchCurrentChat() {
    debugPrint(selected.toString());
    if (selected.length == 0) {
      currentChat = null;
      currentChatMessageBloc = null;
      if (this.mounted) setState(() {});
      return;
    }
    List<Chat> cache = ChatBloc().chats.sublist(0);

    cache.retainWhere((element) {
      if (element.participants.length != selected.length) return false;
      for (UniqueContact contact in selected) {
        if (element.participants
            .where((participant) =>
                sameAddress(participant.address, contact.address))
            .isEmpty) {
          return false;
        }
      }
      return true;
    });
    if (cache.length == 0) {
      currentChat = null;
      currentChatMessageBloc = null;
      if (this.mounted) setState(() {});
      return;
    }

    cache
        .sort((a, b) => a.participants.length.compareTo(b.participants.length));
    currentChat = cache.first;
    currentChatMessageBloc = null;
    if (this.mounted) setState(() {});
  }

  void onSend(BlueBubblesTextFieldState state) async {
    if (searchQuery.length > 0) {
      selected.add(
          new UniqueContact(address: searchQuery, displayName: searchQuery));
    }
    if (currentChat != null) {
      state.send();
      await currentChat.getTitle();
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => ConversationView(
            chat: currentChat,
            title: currentChat.title,
            messageBloc: currentChatMessageBloc,
            existingAttachments: widget.attachments,
            existingText: widget.existingText,
          ),
        ),
      );
      await Future.delayed(Duration(milliseconds: 500));
      NotificationManager().switchChat(currentChat);
    } else {
      List<String> participants =
          selected.map((e) => cleansePhoneNumber(e.address)).toList();
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
            return;
          }

          // If everything went well, let's add the chat to the bloc
          Chat newChat = Chat.fromMap(data["data"]);
          await newChat.save();
          await ChatBloc().updateChatPosition(newChat);

          String title = await getFullChatTitle(newChat);
          state.send(chat: newChat);
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
          await Future.delayed(Duration(milliseconds: 500));
          NotificationManager().switchChat(currentChat);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // if (prevSelected != selected) prevSelected = selected;
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
        children: [
          ChatSelectorTextField(
            controller: controller,
            onRemove: (UniqueContact item) {
              selected.remove(item);
              fetchCurrentChat();
              filterContacts();
              resetCursor();
              if (this.mounted) setState(() {});
            },
            isCreator: widget.isCreator,
            allContacts: contacts,
            selectedContacts: selected,
          ),
          _buildBody(),
          if (widget.isCreator)
            BlueBubblesTextField(
              chat: currentChat,
              existingAttachments: widget.attachments,
              existingText: widget.existingText,
              customSend: onSend,
            )
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (currentChat != null && controller.text.length == 1) {
      if (currentChatMessageBloc == null)
        currentChatMessageBloc = MessageBloc(currentChat);
      return Expanded(
        child: MessagesView(
          chat: currentChat,
          messageBloc: currentChatMessageBloc,
          showHandle: currentChat.isGroup(),
        ),
      );
    } else {
      return Expanded(
        child: ListView.builder(
          physics: AlwaysScrollableScrollPhysics(
              parent: CustomBouncingScrollPhysics()),
          itemBuilder: (BuildContext context, int index) =>
              ContactSelectorOption(
            item: contacts[index],
            onSelected: (item) {
              if (item.isChat) {
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
                resetCursor();
                if (this.mounted) setState(() {});
                return;
              }
              // Add the selected item
              selected.add(item);
              fetchCurrentChat();

              if (widget.onSelection != null) {
                return widget.onSelection(selected);
              }

              // Reset the controller text
              resetCursor();
              if (this.mounted) setState(() {});
            },
          ),
          itemCount: contacts.length,
        ),
      );
    }
  }
}
