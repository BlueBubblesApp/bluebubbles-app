import 'dart:async';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_dialogs.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_utils.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_list_section.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/message_type_toggle.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/selected_contact_chip.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/text_field_component.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/messages_view.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/sync_interface.dart';
import 'package:bluebubbles/services/ui/chat/send_data.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart' show Response;
import 'package:get/get.dart' hide Response;
import 'package:slugify/slugify.dart';
import 'package:bluebubbles/models/models.dart' show ContactSearchResult;

class SelectedContact {
  final String displayName;
  final String address;
  late final Rxn<ChatServiceType> serviceType;

  SelectedContact({required this.displayName, required this.address, ChatServiceType? serviceType}) {
    this.serviceType = Rxn(serviceType);
  }
}

@Deprecated("Use NewChatCreator instead")
class ChatCreator extends StatefulWidget {
  const ChatCreator({
    super.key,
    this.initialText = "",
    this.initialAttachments = const [],
    this.initialSelected = const [],
  });

  final String? initialText;
  final List<PlatformFile> initialAttachments;
  final List<SelectedContact> initialSelected;

  @override
  ChatCreatorState createState() => ChatCreatorState();
}

class ChatCreatorState extends State<ChatCreator> with ThemeHelpers {
  final TextEditingController addressController = TextEditingController();
  final messageNode = FocusNode();
  late final MentionTextEditingController textController =
      MentionTextEditingController(text: widget.initialText, focusNode: messageNode);
  final FocusNode addressNode = FocusNode();
  final ScrollController addressScrollController = ScrollController();

  List<ContactV2> contacts = [];
  final filteredContacts = <ContactV2>[].obs;
  List<Chat> existingChats = [];
  final filteredChats = <Chat>[].obs;
  late final RxList<SelectedContact> selectedContacts = List<SelectedContact>.from(widget.initialSelected).obs;
  final Rxn<ConversationViewController> fakeController = Rxn(null);
  final Rx<ChatServiceType> selectedService = ChatServiceType.iMessage.obs;
  String? oldText;
  ConversationViewController? oldController;
  Timer? _debounce;
  Completer<void>? createCompleter;
  MessagesService? messagesService;

  bool canCreateGroupChats = SettingsSvc.canCreateGroupChatSync();

  @override
  void initState() {
    super.initState();

    addressController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () async {
        final tuple = await SchedulerBinding.instance.scheduleTask(() async {
          // If you type and then delete everything, show selected chat view
          if (addressController.text.isEmpty && selectedContacts.isNotEmpty) {
            await findExistingChat();
            return ContactSearchResult(contacts, existingChats);
          }

          if (addressController.text != oldText) {
            oldText = addressController.text;
            // if user has typed stuff, remove the message view and show filtered results
            if (addressController.text.isNotEmpty && fakeController.value != null) {
              await ChatsSvc.setAllInactive();
              oldController = fakeController.value;
              fakeController.value = null;
            }
          }
          final query = addressController.text.toLowerCase();
          final _contacts = ChatCreatorUtils.filterContacts(contacts, query);
          final _chats = ChatCreatorUtils.filterChats(existingChats, query, selectedService.value);
          return ContactSearchResult(_contacts, _chats);
        }, Priority.animation);
        _debounce = null;
        filteredContacts.value = tuple.contacts;
        filteredChats.value = List<Chat>.from(tuple.chats);
        if (addressController.text.isNotEmpty) {
          filteredChats.sort((a, b) => a.handles.length.compareTo(b.handles.length));
        }
      });
    });

    // Load contacts and chats asynchronously
    () async {
      if (widget.initialAttachments.isEmpty) {
        contacts = await ContactsSvcV2.getAllContacts();
        if (mounted) {
          filteredContacts.value = contacts;
        }
      }
      if (ChatsSvc.loadedAllChats.isCompleted) {
        existingChats = ChatsSvc.allChats;
        filteredChats.value = existingChats.where((e) => e.isIMessage).toList();
      } else {
        ChatsSvc.loadedAllChats.future.then((_) {
          existingChats = ChatsSvc.allChats;
          filteredChats.value = existingChats.where((e) => e.isIMessage).toList();
        });
      }
      if (widget.initialSelected.isNotEmpty) {
        findExistingChat();
      }
    }();

    if (widget.initialSelected.isNotEmpty) messageNode.requestFocus();
  }

  void addSelected(SelectedContact c) async {
    selectedContacts.add(c);
    try {
      final response = await HttpSvc.handle.handleiMessageState(c.address);
      c.serviceType.value = response.data["data"]["available"] == true ? ChatServiceType.iMessage : ChatServiceType.sms;
    } catch (e, s) {
      Logger.warn("Failed to check iMessage availability for contact", error: e, trace: s, tag: 'ChatCreator');
    }
    addressController.text = "";
    findExistingChat();
  }

  void addSelectedList(Iterable<SelectedContact> c) {
    selectedContacts.addAll(c);
    addressController.text = "";
    unawaited(findExistingChat());
  }

  void removeSelected(SelectedContact c) {
    selectedContacts.remove(c);
    unawaited(findExistingChat());
  }

  Future<Chat?> findExistingChat({bool checkDeleted = false, bool update = true}) async {
    // no selected items, remove message view
    if (selectedContacts.isEmpty) {
      await ChatsSvc.setAllInactive();
      fakeController.value = null;
      return null;
    }
    if (selectedContacts.firstWhereOrNull((element) => element.serviceType.value == ChatServiceType.sms) != null) {
      selectedService.value = ChatServiceType.sms;
      filteredChats.value = List<Chat>.from(existingChats.where((e) => !e.isIMessage));
    } else {
      selectedService.value = ChatServiceType.iMessage;
      filteredChats.value = List<Chat>.from(existingChats.where((e) => e.isIMessage));
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
      } catch (e, s) {
        Logger.warn("Failed to find existing chat by identifier", error: e, trace: s, tag: 'ChatCreator');
      }
    }
    // match each selected contact to a participant in a chat
    if (existingChat == null) {
      for (Chat c in (checkDeleted ? Database.chats.getAll() : filteredChats)) {
        if (ChatCreatorUtils.chatMatchesSelectedContacts(c, selectedContacts.map((e) => e.address).toList())) {
          existingChat = c;
          break;
        }
      }
    }
    // if match, show message view, otherwise hide it
    if (update) {
      if (existingChat != null) {
        await ChatsSvc.setActiveChat(existingChat, clearNotifications: false);
        ChatsSvc.activeChat!.controller = cvc(existingChat);

        // Get or create the MessagesService for this chat
        // Only create a new one if we don't already have one for this chat
        // DON'T initialize it here - let MessagesView initialize it with proper handlers
        if (messagesService == null || messagesService!.tag != existingChat.guid) {
          messagesService = maybeFindMessagesSvc(existingChat.guid) ?? MessagesService(existingChat.guid);
        }

        if (widget.initialAttachments.isNotEmpty) {
          ChatsSvc.activeChat!.controller!.pickedAttachments.value = widget.initialAttachments;
        } else if (fakeController.value != null && fakeController.value!.pickedAttachments.isNotEmpty) {
          ChatsSvc.activeChat!.controller!.pickedAttachments.value = fakeController.value!.pickedAttachments;
        }

        if (widget.initialText != null && widget.initialText!.isNotEmpty) {
          ChatsSvc.activeChat!.controller!.textController.text = widget.initialText!;
        } else if (fakeController.value?.textController.text != null &&
            fakeController.value!.textController.text.isNotEmpty) {
          ChatsSvc.activeChat!.controller!.textController.text = fakeController.value!.textController.text;
        } else if (textController.text.isNotEmpty) {
          ChatsSvc.activeChat!.controller!.textController.text = textController.text;
        }

        fakeController.value = ChatsSvc.activeChat!.controller;
      } else {
        await ChatsSvc.setAllInactive();
        fakeController.value = null;
        messagesService = null;
      }
    }
    if (checkDeleted && existingChat?.dateDeleted != null) {
      ChatsSvc.unDeleteChat(existingChat!);
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      await ChatsSvc.addChat(existingChat);
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
      final possibleAddresses = [
        ...filteredContacts.first.phoneNumbers.map((p) => p.number),
        ...filteredContacts.first.emailAddresses.map((e) => e.address),
      ];
      if (possibleAddresses.length == 1) {
        addSelected(SelectedContact(
          displayName: filteredContacts.first.computedDisplayName,
          address: possibleAddresses.first,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      appBar: BBAppBar(
        titleText: "New Conversation",
        leading: buildBackButton(context),
        backgroundColor: Colors.transparent,
        toolbarHeight: kIsDesktop ? 90 : 50,
        actions: [
          if (!canCreateGroupChats)
            IconButton(
              icon: Icon(iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
                  color: context.theme.colorScheme.error),
              onPressed: () {
                ChatCreatorDialogs.showGroupChatCreationDialog(Get.context!);
              },
            ),
        ],
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
                              constraints:
                                  BoxConstraints(maxHeight: context.theme.textTheme.bodyMedium!.fontSize! + 20),
                              child: Obx(() => ListView.builder(
                                    itemCount: selectedContacts.length,
                                    shrinkWrap: true,
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(),
                                    findChildIndexCallback: (key) =>
                                        findChildIndexByKey(selectedContacts, key, (item) => item.address),
                                    itemBuilder: (context, index) {
                                      final e = selectedContacts[index];
                                      return SelectedContactChip(
                                        key: ValueKey(e.address),
                                        contact: e,
                                        onRemove: () => removeSelected(e),
                                      );
                                    },
                                  )),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: NavigationSvc.width(context) - 50),
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent) {
                                  if (event.logicalKey == LogicalKeyboardKey.backspace &&
                                      (addressController.selection.start == 0 || addressController.text.isEmpty)) {
                                    if (selectedContacts.isNotEmpty) {
                                      removeSelected(selectedContacts.last);
                                    }
                                    return KeyEventResult.handled;
                                  } else if (!HardwareKeyboard.instance.isShiftPressed &&
                                      event.logicalKey == LogicalKeyboardKey.tab) {
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
                                enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
                                textInputAction: TextInputAction.done,
                                cursorColor: context.theme.colorScheme.primary,
                                cursorHeight: context.theme.textTheme.bodyMedium!.fontSize! * 1.25,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  hintText: "Enter a name...",
                                  hintStyle: context.theme.textTheme.bodyMedium!
                                      .copyWith(color: context.theme.colorScheme.outline),
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
            Obx(() => MessageTypeToggle(
                  selectedService: selectedService.value,
                  onToggle: (index) async {
                    selectedContacts.clear();
                    addressController.text = "";
                    if (index == 0) {
                      selectedService.value = ChatServiceType.iMessage;
                      filteredChats.value = List<Chat>.from(existingChats.where((e) => e.isIMessage));
                    } else {
                      selectedService.value = ChatServiceType.sms;
                      filteredChats.value = List<Chat>.from(existingChats.where((e) => !e.isIMessage));
                    }
                    await ChatsSvc.setAllInactive();
                    fakeController.value = null;
                  },
                )),
            Expanded(
              child: Obx(() => Theme(
                    data: context.theme.copyWith(
                      // in case some components still use legacy theming
                      primaryColor: context.theme.colorScheme.bubble(context, selectedService.value.isIMessageService),
                      colorScheme: context.theme.colorScheme.copyWith(
                        primary: context.theme.colorScheme.bubble(context, selectedService.value.isIMessageService),
                        onPrimary: context.theme.colorScheme.onBubble(context, selectedService.value.isIMessageService),
                        surface: ThemeSvc.isMaterialYouActive(context)
                            ? null
                            : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                        onSurface: ThemeSvc.isMaterialYouActive(context)
                            ? null
                            : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                      ),
                    ),
                    child: Obx(() {
                      // Access the lists to ensure Obx tracks changes
                      final chats = filteredChats.toList();
                      final contacts = filteredContacts.toList();
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: fakeController.value == null
                            ? ChatListSection(
                                filteredChats: chats,
                                filteredContacts: contacts,
                                selectedContacts: selectedContacts,
                                onChatTap: addSelectedList,
                                onContactTap: addSelected,
                              )
                            : ChatStateScope(
                                chatState: ChatsSvc.getOrCreateChatState(fakeController.value!.chat),
                                child: Container(
                                  color: Colors.transparent,
                                  child: MessagesView(
                                    customService: messagesService,
                                    controller: fakeController.value!,
                                  ),
                                ),
                              ),
                      );
                    }),
                  )),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 5.0,
                top: 10.0,
                bottom: 5.0 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Obx(
                () => Theme(
                    data: context.theme.copyWith(
                      // in case some components still use legacy theming
                      primaryColor: context.theme.colorScheme.bubble(context, selectedService.value.isIMessageService),
                      colorScheme: context.theme.colorScheme.copyWith(
                        primary: context.theme.colorScheme.bubble(context, selectedService.value.isIMessageService),
                        onPrimary: context.theme.colorScheme.onBubble(context, selectedService.value.isIMessageService),
                        surface: ThemeSvc.isMaterialYouActive(context)
                            ? null
                            : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                        onSurface: ThemeSvc.isMaterialYouActive(context)
                            ? null
                            : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                      ),
                    ),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            HardwareKeyboard.instance.isShiftPressed &&
                            event.logicalKey == LogicalKeyboardKey.tab) {
                          addressNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Obx(() => TextFieldComponent(
                          focusNode: messageNode,
                          textController: textController,
                          controller: fakeController.value,
                          recorderController: null,
                          initialAttachments: widget.initialAttachments,
                          hideMediaPicker: fakeController.value == null,
                          sendMessage: ({String? effect}) async {
                            addressOnSubmitted();
                            Chat? chat =
                                fakeController.value?.chat ?? await findExistingChat(checkDeleted: true, update: false);

                            // If no local chat and we have a single contact, try fetching from the
                            // server using the guessed GUID pattern before falling back to creation.
                            if (chat == null && selectedContacts.length == 1) {
                              final address = selectedContacts.first.address;
                              final service = selectedService.value.method;
                              chat = await ChatsSvc.fetchChat('$service;-;$address');
                            }

                            if (chat != null) {
                              final existingChat = chat;
                              // Ensure fakeController is set up for this chat
                              if (fakeController.value == null) {
                                await ChatsSvc.setActiveChat(existingChat, clearNotifications: false);
                                ChatsSvc.activeChat!.controller = cvc(existingChat);
                                fakeController.value = ChatsSvc.activeChat!.controller;
                              }
                              if (messagesService == null || messagesService!.tag != existingChat.guid) {
                                messagesService =
                                    maybeFindMessagesSvc(existingChat.guid) ?? MessagesService(existingChat.guid);
                              }

                              final ctrl = fakeController.value!;
                              ctrl.textController.text = textController.text;
                              ctrl.pickedAttachments.value = List<PlatformFile>.from(widget.initialAttachments);
                              ctrl.replyToMessage = null;

                              // Pre-queue the send so _SendAnimationState fires it as soon as
                              // it wires up sendFunc — after the ConversationView frame builds.
                              ctrl.pendingSend = SendData(
                                attachments: widget.initialAttachments,
                                text: ctrl.textController.text,
                                subject: "",
                                replyGuid: ctrl.replyToMessage?.message.threadOriginatorGuid ??
                                    ctrl.replyToMessage?.message.guid,
                                replyPart: ctrl.replyToMessage?.partIndex,
                                effectId: effect,
                              );

                              NavigationSvc.pushAndRemoveUntil(
                                Get.context!,
                                ConversationView(
                                  chat: existingChat,
                                  customService: messagesService,
                                  fromChatCreator: true,
                                ),
                                (route) => route.isFirst,
                                // don't force close the active chat in tablet mode
                                closeActiveChat: false,
                                // only used in non-tablet mode context
                                customRoute: PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => TitleBarWrapper(
                                      child: ConversationView(
                                    chat: existingChat,
                                    customService: messagesService,
                                    fromChatCreator: true,
                                  )),
                                  transitionDuration: Duration.zero,
                                ),
                              );
                            } else {
                              if (!(createCompleter?.isCompleted ?? true)) return;

                              // Attachments cannot be sent when creating a brand-new chat because
                              // the server's createChat API only accepts a text body. Show an error
                              // and let the user pick an existing contact instead.
                              if (widget.initialAttachments.isNotEmpty) {
                                ChatCreatorDialogs.showCannotForwardAttachmentDialog(context);
                                return;
                              }

                              // hard delete a chat that exists on BB but not on the server to make way for the proper server data
                              if (chat != null) {
                                ChatsSvc.removeChat(chat);
                                ChatsSvc.deleteChat(chat);
                              }
                              createCompleter = Completer();
                              final participants = selectedContacts
                                  .map((e) => e.address.isEmail ? e.address : cleansePhoneNumber(e.address))
                                  .toList();
                              final method = selectedService.value.method;
                              BuildContext? createDialogCtx;
                              showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    createDialogCtx = dialogContext;
                                    return ChatCreatorDialogs.buildCreatingChatDialog(dialogContext, method);
                                  });
                              HttpSvc.chat.create(participants, textController.text, method).then((response) async {
                                // Load the chat data and save it to the DB
                                Chat newChat = Chat.fromMap(response.data["data"]);
                                newChat = await newChat.saveAsync();

                                // Fetch the newly saved chat data from the DB
                                // Throw an error if it wasn't saved correctly.
                                final saved = await ChatsSvc.fetchChat(newChat.guid);
                                if (saved == null) {
                                  return showSnackbar("Error", "Failed to save chat!");
                                }

                                // Update the chat in the chat list.
                                // If it wasn't existing, add it.
                                newChat = saved;
                                bool updated = ChatsSvc.updateChat(newChat);
                                if (!updated) {
                                  await ChatsSvc.addChat(newChat);
                                }

                                // Fetch the last message for the chat and save it.
                                final messageRes = await HttpSvc.chat.getMessages(newChat.guid, limit: 1);
                                if (messageRes.data["data"].length > 0) {
                                  final rawMessages =
                                      (messageRes.data["data"] as List<dynamic>).cast<Map<String, dynamic>>();
                                  await SyncInterface.bulkSyncData(
                                    chatData: newChat.toMap(),
                                    messagesData: rawMessages,
                                  );
                                }

                                // Force close the message service for the chat so it can be reloaded.
                                // If this isn't done, new messages will not show.
                                maybeFindMessagesSvc(newChat.guid)?.close(force: true);
                                cvc(newChat).close();

                                // Let awaiters know we completed
                                createCompleter?.complete();

                                if (createDialogCtx != null) Navigator.of(createDialogCtx!).pop();
                                if (!mounted) return;
                                NavigationSvc.pushAndRemoveUntil(
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
                                if (createDialogCtx != null) Navigator.of(createDialogCtx!).pop();
                                if (!mounted) {
                                  if (!createCompleter!.isCompleted) createCompleter?.completeError(error);
                                  return;
                                }
                                showBBDialog(
                                  barrierDismissible: false,
                                  context: context,
                                  title: 'Failed to create chat!',
                                  body: error is Response
                                      ? 'Reason: (${error.data["error"]["type"]}) -> ${error.data["error"]["message"]}'
                                      : error.toString(),
                                  actions: [
                                    BBDialogAction(
                                      text: 'OK',
                                      isDefault: true,
                                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                                    ),
                                  ],
                                );
                                if (!createCompleter!.isCompleted) {
                                  createCompleter?.completeError(error);
                                }
                              });
                            }
                          })),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
