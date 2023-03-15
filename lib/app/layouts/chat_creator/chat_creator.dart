import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_creator_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/messages_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:slugify/slugify.dart';
import 'package:tuple/tuple.dart';

class SelectedContact {
  final String displayName;
  final String address;

  const SelectedContact({required this.displayName, required this.address});
}

class ChatCreator extends StatefulWidget {
  const ChatCreator({
    Key? key,
    this.initialText = "",
    this.initialAttachments = const [],
    this.initialSelected = const [],
  }) : super(key: key);

  final String? initialText;
  final List<PlatformFile> initialAttachments;
  final List<SelectedContact> initialSelected;

  @override
  ChatCreatorState createState() => ChatCreatorState();
}

class ChatCreatorState extends OptimizedState<ChatCreator> {
  final TextEditingController addressController = TextEditingController();
  late final TextEditingController textController = TextEditingController(text: widget.initialText);
  final FocusNode addressNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  List<Chat> existingChats = [];
  List<Chat> filteredChats = [];
  late final RxList<SelectedContact> selectedContacts = List<SelectedContact>.from(widget.initialSelected).obs;
  final Rxn<ConversationViewController> fakeController = Rxn(null);
  bool iMessage = true;
  bool sms = false;
  String? oldText;
  ConversationViewController? oldController;
  Timer? _debounce;
  Completer<void>? createCompleter;

  final messageNode = FocusNode();

  @override
  void initState() {
    super.initState();

    addressController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final tuple = await SchedulerBinding.instance.scheduleTask(() {
          if (addressController.text != oldText) {
            oldText = addressController.text;
            // if user has typed stuff, remove the message view and show filtered results
            if (addressController.text.isNotEmpty && fakeController.value != null) {
              cm.setAllInactive();
              oldController = fakeController.value;
              fakeController.value = null;
            }
          }
          final query = addressController.text.toLowerCase();
          final _contacts = contacts
              .where((e) =>
                  e.displayName.toLowerCase().contains(query) ||
                  e.phones.firstWhereOrNull((e) => e.toLowerCase().numericOnly().contains(query)) != null ||
                  e.emails.firstWhereOrNull((e) => e.toLowerCase().contains(query)) != null)
              .toList();
          final ids = _contacts.map((e) => e.id);
          final _chats = existingChats.where((e) =>
              ((iMessage && e.isIMessage) || (sms && !e.isIMessage)) &&
              ((e.title?.toLowerCase().contains(query) ?? false) ||
                  e.participants.firstWhereOrNull(
                          (e) => ids.contains(e.contact?.id) || e.address.contains(query) || e.displayName.toLowerCase().contains(query)) !=
                      null));
          return Tuple2(_contacts, _chats);
        }, Priority.animation);
        _debounce = null;
        setState(() {
          filteredContacts = List<Contact>.from(tuple.item1);
          filteredChats = List<Chat>.from(tuple.item2);
          if (addressController.text.isNotEmpty) {
            filteredChats.sort((a, b) => a.participants.length.compareTo(b.participants.length));
          }
        });
      });
    });

    updateObx(() {
      if (widget.initialAttachments.isEmpty && !kIsWeb) {
        final query = (contactBox.query()..order(Contact_.displayName)).build();
        contacts = query.find();
        filteredContacts = List<Contact>.from(contacts);
      }
      if (chats.loadedAllChats.isCompleted) {
        existingChats = chats.chats;
        filteredChats = List<Chat>.from(existingChats.where((e) => e.isIMessage));
      } else {
        chats.loadedAllChats.future.then((_) {
          existingChats = chats.chats;
          setState(() {
            filteredChats = List<Chat>.from(existingChats.where((e) => e.isIMessage));
          });
        });
      }
      setState(() {});
    });
  }

  void addSelected(SelectedContact c) {
    selectedContacts.add(c);
    addressController.text = "";
    findExistingChat();
  }

  void addSelectedList(Iterable<SelectedContact> c) {
    selectedContacts.addAll(c);
    addressController.text = "";
    findExistingChat();
  }

  void removeSelected(SelectedContact c) {
    selectedContacts.remove(c);
    findExistingChat();
  }

  Future<Chat?> findExistingChat({bool update = true}) async {
    // no selected items, remove message view
    if (selectedContacts.isEmpty) {
      cm.setAllInactive();
      fakeController.value = null;
      return null;
    }
    Chat? existingChat;
    // try and find the chat simply by identifier
    if (selectedContacts.length == 1) {
      final address = selectedContacts.first.address;
      try {
        if (kIsWeb) {
          existingChat = await Chat.findOneWeb(chatIdentifier: slugify(address, delimiter: ''));
        } else {
          existingChat = Chat.findOne(chatIdentifier: slugify(address, delimiter: ''));
        }
      } catch (_) {}
    }
    // match each selected contact to a participant in a chat
    if (existingChat == null) {
      for (Chat c in filteredChats) {
        if (c.participants.length != selectedContacts.length) continue;
        int matches = 0;
        for (SelectedContact contact in selectedContacts) {
          for (Handle participant in c.participants) {
            // If one is an email and the other isn't, skip
            if (contact.address.isEmail && !participant.address.isEmail) continue;
            if (contact.address == participant.address) {
              matches += 1;
              break;
            }
            // match last digits
            final matchLengths = [11, 10, 9, 8, 7];
            final numeric = contact.address.numericOnly();
            if (matchLengths.contains(numeric.length) && participant.address.numericOnly().endsWith(numeric)) {
              matches += 1;
              break;
            }
          }
        }
        if (matches == selectedContacts.length) {
          existingChat = c;
          break;
        }
      }
    }
    // if match, show message view, otherwise hide it
    if (update) {
      if (existingChat != null) {
        cm.setActiveChat(existingChat, clearNotifications: false);
        cm.activeChat!.controller = cvc(existingChat);
        fakeController.value = cm.activeChat!.controller;
      } else {
        cm.setAllInactive();
        fakeController.value = null;
      }
    }
    return existingChat;
  }

  void addressOnSubmitted() {
    final text = addressController.text;
    if (text.isEmail || text.isPhoneNumber) {
      addSelected(SelectedContact(
        displayName: text,
        address: text,
      ));
    } else if (filteredContacts.length == 1) {
      final possibleAddresses = [...filteredContacts.first.phones, ...filteredContacts.first.emails];
      if (possibleAddresses.length == 1) {
        addSelected(SelectedContact(
          displayName: filteredContacts.first.displayName,
          address: possibleAddresses.first,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: kIsDesktop ? Colors.transparent : context.theme.colorScheme.background,
        appBar: PreferredSize(
          preferredSize: Size(ns.width(context), kIsDesktop ? 90 : 50),
          child: AppBar(
            systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            toolbarHeight: kIsDesktop ? 90 : 50,
            elevation: 0,
            scrolledUnderElevation: 3,
            surfaceTintColor: context.theme.colorScheme.primary,
            leading: buildBackButton(context),
            backgroundColor: context.theme.colorScheme.background,
            centerTitle: ss.settings.skin.value == Skins.iOS,
            title: Text(
              "New Conversation",
              style: context.theme.textTheme.titleLarge,
            ),
            actions: [
              if (ss.isMinBigSurSync)
                IconButton(
                  icon: Icon(iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline, color: context.theme.colorScheme.error),
                  onPressed: () {
                    showDialog(
                        barrierDismissible: false,
                        context: Get.context!,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                              "Group Chat Creation",
                              style: context.theme.textTheme.titleLarge,
                            ),
                            content: Text(
                                "Creating group chats from BlueBubbles is not possible on macOS 11 (Big Sur) and later due to limitations from Apple.",
                                style: context.theme.textTheme.bodyLarge),
                            backgroundColor: context.theme.colorScheme.properSurface,
                            actions: <Widget>[
                              TextButton(
                                child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        });
                  },
                ),
            ],
          ),
        ),
        body: FocusScope(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                child: Row(
                  children: [
                    Text(
                      "To: ",
                      style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: ThemeSwitcher.getScrollPhysics(),
                        controller: addressScrollController,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeIn,
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: context.theme.textTheme.bodyMedium!.fontSize! + 20),
                                child: Obx(() => ListView.builder(
                                      itemCount: selectedContacts.length,
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        final e = selectedContacts[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                          child: Material(
                                            key: ValueKey(e.address),
                                            color: context.theme.colorScheme.properSurface,
                                            borderRadius: BorderRadius.circular(5),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () {
                                                removeSelected(e);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 7.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    Text(e.displayName,
                                                        style:
                                                            context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.primary)),
                                                    const SizedBox(width: 5.0),
                                                    Icon(
                                                      iOS ? CupertinoIcons.xmark : Icons.close,
                                                      size: 15.0,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: ns.width(context) - 50),
                              child: Focus(
                                onKey: (node, event) {
                                  if (event is RawKeyDownEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.backspace &&
                                        (addressController.selection.start == 0 || addressController.text.isEmpty)) {
                                      if (selectedContacts.isNotEmpty) {
                                        removeSelected(selectedContacts.last);
                                      }
                                      return KeyEventResult.handled;
                                    } else if (!event.data.isShiftPressed && event.logicalKey == LogicalKeyboardKey.tab) {
                                      messageNode.requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  textCapitalization: TextCapitalization.sentences,
                                  focusNode: addressNode,
                                  autocorrect: false,
                                  controller: addressController,
                                  style: context.theme.textTheme.bodyMedium,
                                  maxLines: 1,
                                  selectionControls: iOS ? cupertinoTextSelectionControls : materialTextSelectionControls,
                                  autofocus: kIsWeb || kIsDesktop,
                                  enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                                  textInputAction: TextInputAction.done,
                                  cursorColor: context.theme.colorScheme.primary,
                                  cursorHeight: context.theme.textTheme.bodyMedium!.fontSize! * 1.25,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    fillColor: Colors.transparent,
                                    hintText: "Enter a name...",
                                    hintStyle: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
                                  ),
                                  onSubmitted: (String value) {
                                    addressOnSubmitted();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0).add(const EdgeInsets.only(bottom: 5.0)),
                child: ToggleButtons(
                  constraints: BoxConstraints(minWidth: (ns.width(context) - 35) / 2),
                  fillColor: context.theme.colorScheme.bubble(context, iMessage).withOpacity(0.2),
                  splashColor: context.theme.colorScheme.bubble(context, iMessage).withOpacity(0.2),
                  children: [
                    Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("iMessage"),
                        ),
                        const Icon(CupertinoIcons.chat_bubble, size: 16),
                      ],
                    ),
                    Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("SMS Forwarding"),
                        ),
                        const Icon(Icons.messenger_outline, size: 16),
                      ],
                    ),
                  ],
                  borderRadius: BorderRadius.circular(20),
                  selectedBorderColor: context.theme.colorScheme.bubble(context, iMessage),
                  selectedColor: context.theme.colorScheme.bubble(context, iMessage),
                  isSelected: [iMessage, sms],
                  onPressed: (index) {
                    selectedContacts.clear();
                    addressController.text = "";
                    if (index == 0) {
                      setState(() {
                        iMessage = true;
                        sms = false;
                        filteredChats = List<Chat>.from(existingChats.where((e) => e.isIMessage));
                      });
                      cm.setAllInactive();
                      fakeController.value = null;
                    } else {
                      setState(() {
                        iMessage = false;
                        sms = true;
                        filteredChats = List<Chat>.from(existingChats.where((e) => !e.isIMessage));
                      });
                      cm.setAllInactive();
                      fakeController.value = null;
                    }
                  },
                ),
              ),
              Expanded(
                child: Theme(
                  data: context.theme.copyWith(
                    // in case some components still use legacy theming
                    primaryColor: context.theme.colorScheme.bubble(context, iMessage),
                    colorScheme: context.theme.colorScheme.copyWith(
                      primary: context.theme.colorScheme.bubble(context, iMessage),
                      onPrimary: context.theme.colorScheme.onBubble(context, iMessage),
                      surface: ss.settings.monetTheming.value == Monet.full
                          ? null
                          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                      onSurface: ss.settings.monetTheming.value == Monet.full
                          ? null
                          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                    ),
                  ),
                  child: Stack(
                    children: [
                      CustomScrollView(
                        shrinkWrap: true,
                        physics: (ss.settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                            ? const NeverScrollableScrollPhysics()
                            : ThemeSwitcher.getScrollPhysics(),
                        slivers: <Widget>[
                          SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) {
                              if (filteredChats.isEmpty) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "Loading existing chats...",
                                        style: context.theme.textTheme.labelLarge,
                                      ),
                                    ),
                                    buildProgressIndicator(context, size: 15),
                                  ],
                                );
                              }
                              final chat = filteredChats[index];
                              final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
                              String _title = chat.properTitle;
                              if (hideInfo) {
                                _title = chat.participants.length > 1 ? "Group Chat" : chat.participants[0].fakeName;
                              }
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    addSelectedList(chat.participants
                                        .where((e) => selectedContacts.firstWhereOrNull((c) => c.address == e.address) == null)
                                        .map((e) => SelectedContact(
                                              displayName: e.displayName,
                                              address: e.address,
                                            )));
                                  },
                                  child: ChatCreatorTile(
                                    key: ValueKey(chat.guid),
                                    title: _title,
                                    subtitle: hideInfo
                                        ? ""
                                        : !chat.isGroup
                                            ? (chat.participants.first.formattedAddress ?? chat.participants.first.address)
                                            : chat.getChatCreatorSubtitle(),
                                    chat: chat,
                                  ),
                                ),
                              );
                            }, childCount: filteredChats.length.clamp(chats.loadedAllChats.isCompleted ? 0 : 1, double.infinity).toInt()),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final contact = filteredContacts[index];
                                contact.phones = getUniqueNumbers(contact.phones);
                                contact.emails = getUniqueEmails(contact.emails);
                                final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
                                return Column(
                                  key: ValueKey(contact.id),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...contact.phones.map((e) => Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              if (selectedContacts.firstWhereOrNull((c) => c.address == e) != null) return;
                                              addSelected(SelectedContact(displayName: contact.displayName, address: e));
                                            },
                                            child: ChatCreatorTile(
                                              title: hideInfo ? "Contact" : contact.displayName,
                                              subtitle: hideInfo ? "" : e,
                                              contact: contact,
                                              format: true,
                                            ),
                                          ),
                                        )),
                                    ...contact.emails.map((e) => Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              if (selectedContacts.firstWhereOrNull((c) => c.address == e) != null) return;
                                              addSelected(SelectedContact(displayName: contact.displayName, address: e));
                                            },
                                            child: ChatCreatorTile(
                                              title: hideInfo ? "Contact" : contact.displayName,
                                              subtitle: hideInfo ? "" : e,
                                              contact: contact,
                                            ),
                                          ),
                                        )),
                                  ],
                                );
                              },
                              childCount: filteredContacts.length,
                            ),
                          ),
                        ],
                      ),
                      Obx(() {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: fakeController.value == null
                              ? const SizedBox.shrink()
                              : Container(
                                  color: context.theme.colorScheme.background,
                                  child: MessagesView(
                                    controller: fakeController.value!,
                                  ),
                                ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5.0, top: 10.0, bottom: 5.0),
                child: Theme(
                  data: context.theme.copyWith(
                    // in case some components still use legacy theming
                    primaryColor: context.theme.colorScheme.bubble(context, iMessage),
                    colorScheme: context.theme.colorScheme.copyWith(
                      primary: context.theme.colorScheme.bubble(context, iMessage),
                      onPrimary: context.theme.colorScheme.onBubble(context, iMessage),
                      surface: ss.settings.monetTheming.value == Monet.full
                          ? null
                          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                      onSurface: ss.settings.monetTheming.value == Monet.full
                          ? null
                          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                    ),
                  ),
                  child: Focus(
                    onKey: (node, event) {
                      if (event is RawKeyDownEvent && event.data.isShiftPressed && event.logicalKey == LogicalKeyboardKey.tab) {
                        addressNode.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextFieldComponent(
                        focusNode: messageNode,
                        subjectTextController: TextEditingController(),
                        textController: textController,
                        controller: null,
                        recorderController: RecorderController(),
                        initialAttachments: widget.initialAttachments,
                        sendMessage: ({String? effect}) async {
                          addressOnSubmitted();
                          if (fakeController.value?.chat != null || (await findExistingChat(update: false)) != null) {
                            final chat = (fakeController.value?.chat ?? await findExistingChat(update: false))!;
                            ns.pushAndRemoveUntil(
                              Get.context!,
                              ConversationView(chat: chat, fromChatCreator: true),
                              (route) => route.isFirst,
                              // don't force close the active chat in tablet mode
                              closeActiveChat: false,
                              // only used in non-tablet mode context
                              customRoute: PageRouteBuilder(
                                pageBuilder: (_, __, ___) => TitleBarWrapper(
                                  child: ConversationView(chat: chat, fromChatCreator: true,)
                                ),
                                transitionDuration: Duration.zero,
                              ),
                            );
                            await Future.delayed(const Duration(milliseconds: 500));
                            if (fakeController.value == null) {
                              cm.setActiveChat(chat, clearNotifications: false);
                              cm.activeChat!.controller = cvc(chat);
                              fakeController.value = cm.activeChat!.controller;
                            }
                            await fakeController.value!.send(
                              widget.initialAttachments,
                              textController.text,
                              "",
                              null,
                              null,
                              null,
                              false,
                            );
                          } else {
                            if (!(createCompleter?.isCompleted ?? true)) return;
                            createCompleter = Completer();
                            final participants = selectedContacts.map((e) => e.address.isEmail ? e.address : e.address.numericOnly()).toList();
                            showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: context.theme.colorScheme.properSurface,
                                    title: Text(
                                      "Creating a new iMessage chat...",
                                      style: context.theme.textTheme.titleLarge,
                                    ),
                                    content: Container(
                                      height: 70,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          backgroundColor: context.theme.colorScheme.properSurface,
                                          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                        ),
                                      ),
                                    ),
                                  );
                                });
                            http.createChat(participants, textController.text).then((response) async {
                              // Load the chat data and save it to the DB
                              Chat newChat = Chat.fromMap(response.data["data"]);
                              newChat = newChat.save();

                              // Fetch the newly saved chat data from the DB
                              // Throw an error if it wasn't saved correctly.
                              final saved = await cm.fetchChat(newChat.guid);
                              if (saved == null) {
                                return showSnackbar("Error", "Failed to save chat!");
                              }

                              // Update the chat in the chat list
                              newChat = saved;
                              chats.updateChat(newChat);

                              // Fetch the last message for the chat and save it.
                              final messageRes = await http.chatMessages(newChat.guid, limit: 1);
                              if (messageRes.data["data"].length > 0) {
                                final messages = (messageRes.data["data"] as List<dynamic>).map((e) => Message.fromMap(e)).toList();
                                await Chat.bulkSyncMessages(newChat, messages);
                              }

                              // Force close the message service for the chat so it can be reloaded.
                              // If this isn't done, new messages will not show.
                              ms(newChat.guid).close(force: true);
                              cvc(newChat).close();

                              // Let awaiters know we completed
                              createCompleter?.complete();

                              // Navigate to the new chat
                              Navigator.of(context).pop();
                              ns.pushAndRemoveUntil(
                                Get.context!,
                                ConversationView(chat: newChat),
                                (route) => route.isFirst,
                                customRoute: PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => TitleBarWrapper(
                                    child: ConversationView(
                                      chat: newChat,
                                      fromChatCreator: true,
                                    ),
                                  ),
                                  transitionDuration: Duration.zero,
                                ),
                              );
                            }).catchError((error) {
                              Navigator.of(context).pop();
                              showDialog(
                                  barrierDismissible: false,
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: context.theme.colorScheme.properSurface,
                                      title: Text(
                                        "Failed to create chat!",
                                        style: context.theme.textTheme.titleLarge,
                                      ),
                                      content: Text(
                                        error is Response
                                            ? "Reason: (${error.data["error"]["type"]}) -> ${error.data["error"]["message"]}"
                                            : error.toString(),
                                        style: context.theme.textTheme.bodyLarge,
                                      ),
                                      actions: [
                                        TextButton(
                                          child: Text("OK",
                                              style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                      ],
                                    );
                                  });
                              if (!createCompleter!.isCompleted) {
                                createCompleter?.completeError(error);
                              }
                            });
                          }
                        }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
