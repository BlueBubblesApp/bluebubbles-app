import 'dart:async';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart' show SelectedContact;
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/sync_interface.dart';
import 'package:bluebubbles/services/ui/chat/send_data.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart' hide Response;
import 'package:slugify/slugify.dart';

class ChatCreatorController extends StatefulController {
  ChatCreatorController({
    this.initialText = "",
    this.initialAttachments = const [],
    this.initialSelected = const [],
  });

  final String? initialText;
  final List<PlatformFile> initialAttachments;
  final List<SelectedContact> initialSelected;

  // ---- State ----
  final RxList<SelectedContact> selectedContacts = <SelectedContact>[].obs;
  final RxList<Chat> filteredChats = <Chat>[].obs;
  final RxList<ContactV2> filteredContacts = <ContactV2>[].obs;
  final Rxn<ConversationViewController> activeController = Rxn(null);
  final Rx<ChatServiceType> selectedService = ChatServiceType.iMessage.obs;
  final RxBool isHeaderVisible = true.obs;

  // ---- Text / Focus ----
  late final MentionTextEditingController textController;
  final messageNode = FocusNode();
  final addressNode = FocusNode();
  final TextEditingController addressController = TextEditingController();

  // ---- Cached full lists ----
  List<Chat> _allChats = [];
  List<ContactV2> _allContacts = [];

  // ---- Internal ----
  Timer? _debounce;
  MessagesService? messagesService;
  Completer<void>? _createCompleter;
  final RxString currentQuery = ''.obs;
  final RxBool isSending = false.obs;

  bool get canCreateGroupChats => SettingsSvc.canCreateGroupChatSync();

  @override
  void onInit() {
    super.onInit();

    textController = MentionTextEditingController(text: initialText, focusNode: messageNode);

    selectedContacts.addAll(initialSelected);

    // Auto-select service based on pre-selected contacts' known iMessage status.
    // If any initial contact is explicitly non-iMessage, start on SMS.
    if (initialSelected.any((c) => c.serviceType.value == ChatServiceType.sms)) {
      selectedService.value = ChatServiceType.sms;
    }

    _loadData();

    addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final text = addressController.text;

      // If the user has typed something while a chat is displayed, hide the
      // message view so the filtered search results are shown instead.
      if (text.isNotEmpty && activeController.value != null) {
        await deactivateExistingChat();
      }

      // If the user cleared the field and contacts are still selected,
      // re-resolve the matching chat and restore the message view.
      if (text.isEmpty && selectedContacts.isNotEmpty) {
        await findExistingChat();
        return;
      }

      final result = await SchedulerBinding.instance.scheduleTask(() async {
        return _computeSearchResults(text);
      }, Priority.animation);
      _debounce = null;
      currentQuery.value = text;
      filteredChats.value = result.chats;
      filteredContacts.value = result.contacts;
      if (text.isNotEmpty) {
        filteredChats.sort((a, b) => a.handles.length.compareTo(b.handles.length));
      }
    });
  }

  _SearchResult _computeSearchResults(String query) {
    final selectedAddresses = selectedContacts.map((c) => c.address.toLowerCase()).toSet();

    bool contactNotFullySelected(ContactV2 e) {
      // "Fully selected" means every address valid for the current service is
      // already in selectedContacts. Keep the contact visible if at least one
      // valid address remains un-selected.
      final validAddresses = [
        if (selectedService.value == ChatServiceType.iMessage) ...e.emailAddresses.map((a) => a.address.toLowerCase()),
        ...e.phoneNumbers.map((p) => p.number.toLowerCase()),
      ];
      if (validAddresses.isEmpty) return false;
      return validAddresses.any((a) => !selectedAddresses.contains(a));
    }

    if (query.isEmpty && selectedContacts.isNotEmpty) {
      // Show all chats for current service type while contacts are selected;
      // actual matching is done in findExistingChat.
      final chats = _allChats.where(_chatMatchesService).toList();
      return _SearchResult(chats: chats, contacts: []);
    }

    if (query.isEmpty) {
      return _SearchResult(
        chats: _allChats.where(_chatMatchesService).toList(),
        contacts: _allContacts.where((e) => _contactHasAddressForService(e) && contactNotFullySelected(e)).toList(),
      );
    }

    final q = query.toLowerCase();
    final contacts = _allContacts
        .where((e) =>
            _contactHasAddressForService(e) &&
            contactNotFullySelected(e) &&
            (e.computedDisplayName.toLowerCase().contains(q) ||
                (e.nickname?.toLowerCase().contains(q) ?? false) ||
                e.phoneNumbers.firstWhereOrNull((p) => cleansePhoneNumber(p.number.toLowerCase()).contains(q)) !=
                    null ||
                e.emailAddresses.firstWhereOrNull((e) => e.address.toLowerCase().contains(q)) != null))
        .toList();

    final chats = _allChats.where((e) {
      if (!_chatMatchesService(e)) return false;
      return e.getTitle().toLowerCase().contains(q) ||
          e.handles.firstWhereOrNull((h) => h.address.contains(q) || h.displayName.toLowerCase().contains(q)) != null;
    }).toList();

    return _SearchResult(chats: chats, contacts: contacts);
  }

  bool _chatMatchesService(Chat c) {
    switch (selectedService.value) {
      case ChatServiceType.iMessage:
        return c.isIMessage;
      case ChatServiceType.sms:
        return !c.isIMessage;
      case ChatServiceType.rcs:
        return false;
    }
  }

  /// Returns true if [c] has at least one address type valid for the selected service.
  /// SMS/RCS only support phone numbers; iMessage supports both phone and email.
  bool _contactHasAddressForService(ContactV2 c) {
    switch (selectedService.value) {
      case ChatServiceType.iMessage:
        return c.phoneNumbers.isNotEmpty || c.emailAddresses.isNotEmpty;
      case ChatServiceType.sms:
      case ChatServiceType.rcs:
        return c.phoneNumbers.isNotEmpty;
    }
  }

  Future<void> _loadData() async {
    // Load contacts first (won't block chat loading)
    if (initialAttachments.isEmpty) {
      _allContacts = await ContactsSvcV2.getAllContacts();
    }

    // Load chats
    if (ChatsSvc.loadedAllChats.isCompleted) {
      _allChats = ChatsSvc.allChats;
    } else {
      await ChatsSvc.loadedAllChats.future;
      _allChats = ChatsSvc.allChats;
    }

    // Populate initial filtered state
    filteredChats.value = _allChats.where(_chatMatchesService).toList();
    filteredContacts.value = _allContacts.where(_contactHasAddressForService).toList();

    // If we already have pre-selected contacts, try to find a matching chat
    if (selectedContacts.isNotEmpty) {
      await findExistingChat();
    }
  }

  // ---------------------------------------------------------------------------
  // Contact selection
  // ---------------------------------------------------------------------------

  Future<void> addSelected(SelectedContact contact) async {
    // Guard: server doesn't support group chats
    if (selectedContacts.length > 1 && !canCreateGroupChats) {
      showSnackbar('Not Supported', 'Your server does not support creating group chats');
      return;
    }

    selectedContacts.add(contact);
    addressController.text = '';
    currentQuery.value = '';

    // Refresh search results so the newly-selected contact is excluded
    final result = _computeSearchResults('');
    filteredChats.value = result.chats;
    filteredContacts.value = result.contacts;

    // Async iMessage status check for chip color
    unawaited(_fetchIMessageState(contact));

    await findExistingChat();

    // Keep focus on the address field so the user can keep adding recipients.
    addressNode.requestFocus();
  }

  Future<void> _fetchIMessageState(SelectedContact contact) async {
    try {
      final response = await HttpSvc.handle.handleiMessageState(contact.address);
      final available = response.data['data']['available'] as bool?;
      contact.serviceType.value = available == true
          ? ChatServiceType.iMessage
          : available == false
              ? ChatServiceType.sms
              : null;
    } catch (e, s) {
      Logger.warn("Failed to check iMessage availability for contact",
          error: e, trace: s, tag: 'ChatCreatorController');
    }
  }

  Future<void> addSelectedFromChat(List<SelectedContact> contacts) async {
    for (final c in contacts) {
      if (selectedContacts.firstWhereOrNull((s) => s.address == c.address) == null) {
        selectedContacts.add(c);
        unawaited(_fetchIMessageState(c));
      }
    }
    addressController.text = '';
    currentQuery.value = '';
    // Refresh search results so newly-selected contacts are excluded
    final result = _computeSearchResults('');
    filteredChats.value = result.chats;
    filteredContacts.value = result.contacts;
    await findExistingChat();

    // A chat was selected — move focus to the message compose field.
    // Defer to the next frame so the TextFieldComponent has time to build
    // and attach the CVC's focusNode before we request focus.
    final cvcFocusNode = activeController.value?.focusNode;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      cvcFocusNode?.requestFocus();
    });
  }

  Future<void> removeSelected(SelectedContact contact) async {
    selectedContacts.remove(contact);

    // Refresh results immediately so the removed contact is selectable again
    // and the contact exclusion logic reflects the updated selection set.
    final result = _computeSearchResults(addressController.text);
    filteredChats.value = result.chats;
    filteredContacts.value = result.contacts;
    if (selectedContacts.isEmpty) {
      await deactivateExistingChat();
    } else {
      await findExistingChat();
    }
  }

  // ---------------------------------------------------------------------------
  // Service type toggle
  // ---------------------------------------------------------------------------

  Future<void> onServiceChanged(ChatServiceType service) async {
    if (selectedService.value == service) return;
    selectedService.value = service;
    selectedContacts.clear();
    addressController.text = '';
    currentQuery.value = '';
    await deactivateExistingChat();
    filteredChats.value = _allChats.where(_chatMatchesService).toList();
    filteredContacts.value = _allContacts.where(_contactHasAddressForService).toList();
  }

  // ---------------------------------------------------------------------------
  // Chat resolution
  // ---------------------------------------------------------------------------

  Future<Chat?> findExistingChat({bool checkDeleted = false, bool update = true}) async {
    if (selectedContacts.isEmpty) {
      await deactivateExistingChat();
      return null;
    }

    // Auto-update service type based on selected contact iMessage status
    final hasSmsContact = selectedContacts.firstWhereOrNull((c) => c.serviceType.value == ChatServiceType.sms) != null;
    if (hasSmsContact) {
      selectedService.value = ChatServiceType.sms;
    } else {
      selectedService.value = ChatServiceType.iMessage;
    }
    filteredChats.value = _allChats.where(_chatMatchesService).toList();

    Chat? existingChat;

    // Single contact: try by chatIdentifier
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

    // Multi-contact: match by participant handles.
    // Always use the complete service-filtered list here — filteredChats is
    // narrowed by the current search query and would miss valid chats.
    if (existingChat == null) {
      final searchList = checkDeleted ? ChatsSvc.allChats : _allChats.where(_chatMatchesService).toList();
      for (final c in searchList) {
        if (c.handles.length != selectedContacts.length) continue;
        int matches = 0;
        for (final contact in selectedContacts) {
          for (final participant in c.handles) {
            if (contact.address.isEmail && !participant.address.isEmail) continue;
            if (contact.address == participant.address) {
              matches++;
              break;
            }
            final matchLengths = [15, 14, 13, 12, 11, 10, 9, 8, 7];
            final numeric = contact.address.numericOnly();
            if (matchLengths.contains(numeric.length) && cleansePhoneNumber(participant.address).endsWith(numeric)) {
              matches++;
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

    if (update) {
      if (existingChat != null) {
        await _activateExistingChat(existingChat);
      } else {
        await deactivateExistingChat();
      }
    }

    if (checkDeleted && existingChat?.dateDeleted != null) {
      ChatsSvc.unDeleteChat(existingChat!);
      await ChatsSvc.addChat(existingChat);
    }

    return existingChat;
  }

  Future<void> _activateExistingChat(Chat chat, {bool transferText = true}) async {
    await ChatsSvc.setActiveChat(chat, clearNotifications: false);
    ChatsSvc.activeChat!.controller = cvc(chat);

    // Only create a new MessagesService if necessary.
    // Do NOT initialize here — MessagesView initializes it with proper handlers.
    if (messagesService == null || messagesService!.tag != chat.guid) {
      messagesService = maybeFindMessagesSvc(chat.guid) ?? MessagesService(chat.guid);
    }

    final newCVC = ChatsSvc.activeChat!.controller!;

    // Transfer text/attachments from the "new chat" text field to the resolved CVC.
    // Skip this when transferText is false (send path) — the caller captures content
    // directly into pendingSend so there is no need to populate the text controller,
    // and doing so forces an extra clear that can race with Flutter rendering.
    if (transferText) {
      if (initialAttachments.isNotEmpty) {
        newCVC.pickedAttachments.value = initialAttachments;
      } else if (activeController.value != null && activeController.value!.pickedAttachments.isNotEmpty) {
        newCVC.pickedAttachments.value = activeController.value!.pickedAttachments;
      }

      if (initialText != null && initialText!.isNotEmpty) {
        newCVC.textController.text = initialText!;
      } else if (activeController.value != null && activeController.value!.textController.text.isNotEmpty) {
        newCVC.textController.text = activeController.value!.textController.text;
      } else if (textController.text.isNotEmpty) {
        newCVC.textController.text = textController.text;
      }
    }

    activeController.value = newCVC;
  }

  Future<void> deactivateExistingChat() async {
    await ChatsSvc.setAllInactive();
    activeController.value = null;
    messagesService = null;
  }

  // ---------------------------------------------------------------------------
  // Address field on-submit (auto-select if valid address)
  // ---------------------------------------------------------------------------

  /// Converts a user-typed phone number to E.164 format (+15106405652) if it
  /// doesn't already include a country code. Falls back to the raw input if the
  /// library can't parse it (e.g. for short-codes or unconventional numbers).
  ///
  /// Uses [isPossibleNumber] rather than [isValidNumber] so that structurally-
  /// correct numbers (right length for the region) are normalised even if they
  /// aren't in an active subscriber range (e.g. 555 numbers in the US).
  String normalizeToE164(String phone) {
    if (phone.startsWith('+')) return phone; // already has country code
    final cc = Get.deviceLocale?.countryCode ?? 'US';
    try {
      final parsed = PhoneNumberUtil.instance.parse(phone, cc);
      if (PhoneNumberUtil.instance.isValidNumber(parsed)) {
        return PhoneNumberUtil.instance.format(parsed, PhoneNumberFormat.e164);
      }
    } catch (_) {}
    return phone;
  }

  void addressOnSubmitted() {
    final text = addressController.text.trim();
    if (text.isEmail || text.isPhoneNumber) {
      final address = text.isEmail ? text : normalizeToE164(text);
      addSelected(SelectedContact(displayName: address, address: address));
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

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

  /// Called from the text field's sendMessage callback.
  /// [context] is needed for showing dialogs and navigating.
  Future<void> sendMessage(BuildContext context, {String? effectId}) async {
    // Auto-submit any typed address before proceeding.
    addressOnSubmitted();

    // Guard: if nothing is selected and no chat is resolved there is no
    // recipient — do nothing instead of crashing trying to create a chat
    // with an empty participants list.
    if (selectedContacts.isEmpty && activeController.value == null) return;

    // Re-check for an existing chat in case the debounce hasn't fired yet.
    Chat? resolvedChat = activeController.value?.chat ?? await findExistingChat(checkDeleted: true, update: false);
    bool messageSentWithChat = false;
    // Messages already synced to the DB during the new-chat creation flow.
    // Pre-seeded into messagesService.struct before navigation so MessagesView's
    // fast path fires and avoids an HTTP round-trip for the very first message.
    List<Message> syncedMessages = [];

    // ------------------------------------------------------------------
    // Step 1: If we have a local chat, use it directly — no server check.
    // ------------------------------------------------------------------
    if (resolvedChat == null) {
      // ----------------------------------------------------------------
      // Step 2: No local chat. A message is required to create a new one
      // (the server rejects POST /chat/new without one when the Private
      // API is enabled). Validate before making any network call so the
      // user gets immediate feedback.
      // ----------------------------------------------------------------
      final messageText = textController.text.trim();
      if (messageText.isEmpty) {
        showSnackbar('Error', 'A message is required to start a new conversation');
        return;
      }

      if (!(_createCompleter?.isCompleted ?? true)) return;
      _createCompleter = Completer();
      isSending.value = true;

      final participants =
          selectedContacts.map((c) => c.address.isEmail ? c.address : cleansePhoneNumber(c.address)).toList();
      final method = selectedService.value.method;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.theme.colorScheme.surfaceContainerHighest,
          title: Text(
            'Finding or creating chat...',
            style: ctx.theme.textTheme.titleLarge,
          ),
          content: const SizedBox(
            height: 70,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      try {
        // For single-contact chats, try to find an existing chat on the server via a
        // GET request before creating one. Using createChat with no message as a lookup
        // is incorrect — the server rejects it when the Private API is enabled.
        Chat? serverChat;
        if (selectedContacts.length == 1) {
          final address = selectedContacts.first.address;
          serverChat = await ChatsSvc.fetchChat('$method;-;$address');
        }

        if (serverChat == null) {
          // No existing chat found on the server — create one.
          // Message has already been validated above; it is delivered as part of
          // creation, so pendingSend must be skipped for this path.
          final response = await HttpSvc.chat.create(participants, messageText, method);
          serverChat = Chat.fromMap(response.data['data'] as Map<String, dynamic>);
          messageSentWithChat = true;
        }

        // Sync the chat + its participants into the local DB.
        final synced = await Chat.bulkSyncChats([serverChat]);
        resolvedChat = synced.isNotEmpty ? synced.first : serverChat;

        // Add to ChatsService so the rest of the app knows about it.
        final updated = ChatsSvc.updateChat(resolvedChat);
        if (!updated) await ChatsSvc.addChat(resolvedChat);

        // When the message was bundled in createChat, proactively sync it from
        // the server so MessagesView can display it immediately rather than
        // waiting for the socket echo (which has a built-in 500 ms delay for
        // isFromMe / no-tempGuid messages).
        if (messageSentWithChat) {
          try {
            final msgResponse = await HttpSvc.chat.getMessages(resolvedChat.guid, limit: 1);
            final msgData = msgResponse.data['data'];
            if (msgData is List && msgData.isNotEmpty) {
              final rawMessages = msgData.cast<Map<String, dynamic>>();
              syncedMessages = (await SyncInterface.bulkSyncData(
                chatData: resolvedChat.toMap(),
                messagesData: rawMessages,
              ))
                  .messages;
            }
          } catch (_) {
            // Non-fatal: the socket echo will still arrive and display the message
          }
        }

        _createCompleter?.complete();
        isSending.value = false;
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      } catch (error) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

        _createCompleter?.completeError(error);
        isSending.value = false;

        showBBDialog(
          barrierDismissible: false,
          context: context,
          title: 'Failed to create chat!',
          body: error is Response
              ? 'Reason: (${(error as dynamic).data["error"]["type"]}) -> ${(error as dynamic).data["error"]["message"]}'
              : error.toString(),
          actions: [
            BBDialogAction(
              text: 'OK',
              isDefault: true,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ],
        );
        return;
      }
    }

    // ------------------------------------------------------------------
    // Step 3: We have a chat (local or freshly synced). Set up its CVC
    // and navigate to the ConversationView, sending the message on init.
    // ------------------------------------------------------------------

    // Capture content now, before _activateExistingChat runs.
    // For existing chats the CVC already has the live text; for new chats the
    // text is still only in the chat creator's own textController.
    final capturedText = activeController.value?.textController.text.isNotEmpty == true
        ? activeController.value!.textController.text
        : textController.text;
    final capturedAttachments = activeController.value?.pickedAttachments.isNotEmpty == true
        ? activeController.value!.pickedAttachments.toList()
        : List<PlatformFile>.from(initialAttachments);

    if (activeController.value == null || activeController.value!.chat.guid != resolvedChat.guid) {
      // transferText: false — content is captured above and will go into pendingSend;
      // writing it into the CVC's textController would leave stale text visible in
      // the destination ConversationView if the clear races with Flutter rendering.
      await _activateExistingChat(resolvedChat, transferText: false);
    }

    // Pre-seed the messagesService struct with any messages already synced to the
    // DB (only applies to the messageSentWithChat path). This means MessagesView's
    // fast path (customService.struct.isNotEmpty) will trigger and skip the HTTP
    // fallback that would otherwise show "Loading..." while fetching the very first
    // message from the server.
    if (syncedMessages.isNotEmpty && messagesService != null) {
      messagesService!.struct.addMessages(syncedMessages);
    }

    // Ensure attachments are transferred to the active CVC (text is captured above).
    if (activeController.value != null) {
      if (activeController.value!.pickedAttachments.isEmpty && capturedAttachments.isNotEmpty) {
        activeController.value!.pickedAttachments.value = capturedAttachments;
      }
    }

    final activeCVC = activeController.value!;
    final chat = resolvedChat;

    // Only send a message when there is actual content to send. When the user
    // taps the send button from the chat creator with an existing chat but no
    // text/attachments (i.e. "open conversation" intent), skip the send step.
    final hasContent = capturedText.isNotEmpty || capturedAttachments.isNotEmpty;

    // Pre-queue the send so _SendAnimationState fires it as soon as it wires up
    // sendFunc — after the ConversationView frame builds and MessagesView has
    // initialized its handlers. Only set when there is actual content to send,
    // and when the message was not already sent as part of new chat creation.
    if (hasContent && !messageSentWithChat) {
      activeCVC.pendingSend = SendData(
        attachments: capturedAttachments,
        text: capturedText,
        subject: '',
        replyGuid: activeCVC.replyToMessage?.message.threadOriginatorGuid ?? activeCVC.replyToMessage?.message.guid,
        replyPart: activeCVC.replyToMessage?.partIndex,
        effectId: effectId,
      );
      activeCVC.replyToMessage = null;
    }

    // Always clear text/attachments from the CVC and the persisted draft before navigating.
    // - pendingSend path: data already captured above; dispose() must not re-save it as a draft.
    // - messageSentWithChat path: message sent via createChat; nothing left to draft.
    // Awaiting the DB clear ensures ConversationTextFieldState.getTextDraft() finds '' when
    // the new ConversationView initialises, so the text field starts empty.
    // Also clear activeCVC.chat.textFieldText directly: cvc() may return an already-registered
    // CVC whose .chat is an older object instance than resolvedChat, so setChatTextFieldText
    // would update state.chat but not the CVC's own .chat — getTextDraft() reads the latter.
    activeCVC.chat.textFieldText = '';
    activeCVC.textController.clear();
    activeCVC.pickedAttachments.clear();
    await ChatsSvc.setChatTextFieldText(chat, '');
    await ChatsSvc.setChatTextFieldAttachments(chat, []);

    FocusManager.instance.primaryFocus?.unfocus();

    isHeaderVisible.value = false;
    // Null the active controller so the inline MessagesView is removed from the
    // tree before the new ConversationView mounts — prevents GlobalKey conflicts
    // (the shared focusInfoKey on the CVC would otherwise appear in both trees).
    activeController.value = null;

    NavigationSvc.pushAndRemoveUntil(
      Get.context!,
      ConversationView(chat: chat, customService: messagesService, fromChatCreator: true),
      (route) => route.isFirst,
      closeActiveChat: false,
      customRoute: PageRouteBuilder(
        pageBuilder: (_, __, ___) => TitleBarWrapper(
          child: ConversationView(
            chat: chat,
            customService: messagesService,
            fromChatCreator: true,
          ),
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void onClose() {
    _debounce?.cancel();
    addressController.removeListener(_onAddressChanged);
    addressController.dispose();
    messageNode.dispose();
    addressNode.dispose();
    textController.dispose();
    super.onClose();
  }
}

class _SearchResult {
  final List<Chat> chats;
  final List<ContactV2> contacts;
  const _SearchResult({required this.chats, required this.contacts});
}
