import 'dart:async';

import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_creator_tile.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
  }) : super(key: key);

  final String initialText;
  final List<PlatformFile> initialAttachments;

  @override
  ChatCreatorState createState() => ChatCreatorState();
}

class ChatCreatorState extends OptimizedState<ChatCreator> {
  late final TextEditingController addressController = TextEditingController(text: widget.initialText);
  final FocusNode addressNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  ConversationViewController? fakeController;
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  List<Chat> existingChats = [];
  List<Chat> filteredChats = [];
  RxList<SelectedContact> selectedContacts = <SelectedContact>[].obs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    addressController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final tuple = await SchedulerBinding.instance.scheduleTask(() {
          final query = addressController.text.toLowerCase();
          final _contacts = contacts.where((e) => e.displayName.toLowerCase().contains(query)
              || e.phones.firstWhereOrNull((e) => e.toLowerCase().numericOnly().contains(query)) != null
              || e.emails.firstWhereOrNull((e) => e.toLowerCase().contains(query)) != null).toList();
          final ids = _contacts.map((e) => e.id);
          final _chats = existingChats.where((e) => (e.title?.toLowerCase().contains(query) ?? false)
              || e.participants.firstWhereOrNull((e) => ids.contains(e.contact?.id)
                  || e.address.contains(query)
                  || e.displayName.toLowerCase().contains(query)) != null);
          return Tuple2(_contacts, _chats);
        }, Priority.animation);
        _debounce = null;
        setState(() {
          filteredContacts = List<Contact>.from(tuple.item1);
          filteredChats = List<Chat>.from(tuple.item2);
        });
      });
    });

    updateObx(() {
      final query = (contactBox.query()..order(Contact_.displayName)).build();
      contacts = query.find();
      filteredContacts = List<Contact>.from(contacts);
      if (chats.loadedAllChats.isCompleted) {
        existingChats = chats.chats;
        filteredChats = List<Chat>.from(existingChats);
      } else {
        chats.loadedAllChats.future.then((_) {
          existingChats = chats.chats;
          setState(() {
            filteredChats = List<Chat>.from(existingChats);
          });
        });
      }
      setState(() {});
    });
  }

  void addSelected(SelectedContact c) {
    selectedContacts.add(c);
    addressController.text = "";
  }

  void addSelectedList(Iterable<SelectedContact> c) {
    selectedContacts.addAll(c);
    addressController.text = "";
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "New Conversation",
      initialHeader: null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
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
                      style: context.theme.textTheme.bodyLarge
                    ),
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
                }
              );
            },
          ),
      ],
      stickyPrefix: Padding(
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
                                    selectedContacts.remove(e);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 7.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          e.displayName,
                                          style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.primary)
                                        ),
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
                      constraints: BoxConstraints(maxWidth: context.width - 50),
                      child: FocusScope(
                        child: Focus(
                          onKey: (_, ev) {
                            if (ev is RawKeyDownEvent) {
                              if (ev.logicalKey == LogicalKeyboardKey.backspace
                                  && (addressController.selection.start == 0 || addressController.text.isEmpty)) {
                                selectedContacts.removeLast();
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
                            },
                          ),
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
      bodySlivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
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
                    title: chat.properTitle,
                    subtitle: chat.getChatCreatorSubtitle(),
                    chat: chat,
                  ),
                ),
              );
            },
            childCount: filteredChats.length.clamp(chats.loadedAllChats.isCompleted ? 0 : 1, double.infinity).toInt()
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final contact = filteredContacts[index];
              contact.phones = getUniqueNumbers(contact.phones);
              contact.emails = getUniqueEmails(contact.emails);
              return Column(
                key: ValueKey(contact.id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...contact.phones.map((e) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (selectedContacts.firstWhereOrNull((c) => c.address == e) != null) return;
                        addSelected(SelectedContact(
                          displayName: contact.displayName,
                          address: e
                        ));
                      },
                      child: ChatCreatorTile(
                        title: contact.displayName,
                        subtitle: e,
                        contact: contact,
                      ),
                    ),
                  )),
                  ...contact.emails.map((e) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (selectedContacts.firstWhereOrNull((c) => c.address == e) != null) return;
                        addSelected(SelectedContact(
                          displayName: contact.displayName,
                          address: e
                        ));
                      },
                      child: ChatCreatorTile(
                        title: contact.displayName,
                        subtitle: e,
                        contact: contact,
                      ),
                    ),
                  )),
                ]
              );
            },
            childCount: filteredContacts.length,
          ),
        )
      ],
    );
  }
}
