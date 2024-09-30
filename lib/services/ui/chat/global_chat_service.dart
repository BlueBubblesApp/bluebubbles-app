import 'dart:async';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/network/metadata_helper.dart';
import 'package:bluebubbles/helpers/types/classes/aliases.dart';
import 'package:bluebubbles/helpers/types/extensions/extensions.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:bluebubbles/services/ui/message/messages_service.dart';
import 'package:bluebubbles/services/ui/navigator/navigator_service.dart';
import 'package:bluebubbles/services/ui/reactivity/reactive_handle.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

// ignore: library_private_types_in_public_api, non_constant_identifier_names
IGlobalChatService GlobalChatService = Get.isRegistered<IGlobalChatService>() ? Get.find<IGlobalChatService>() : Get.put(IGlobalChatService());

/// Global Chat Service
/// 
/// This service is responsible for managing all chats in the app.
/// It listens for changes to the database and updates the reactive chat objects accordingly.
/// It also provides a way to get the reactive chat object for a given chat GUID.
/// 
/// Anytime you need to interact with a chat, you should use this service.
/// If you do not, the UI may not update properly.
class IGlobalChatService extends GetxService {
  Timer? _syncAllDebounce;

  final Completer<void> _chatsLoaded = Completer<void>();
  bool get chatsLoaded => _chatsLoaded.isCompleted;
  Completer<void> get chatsLoadedFuture => _chatsLoaded;

  /// A master list of all chats
  final RxList<Chat> chats = <Chat>[].obs;

  /// A map of all reactive chats
  /// You can access the original Chat within the ReactiveChat object
  final Map<String, Chat> _chatMap = <String, Chat>{}.obs;

  /// A map of chat GUIDs to their participants
  final Map<String, RxList<String>> _chatParticipants = <String, RxList<String>>{}.obs;

  /// A map of handle addresses to their reactive handle objects
  final Map<String, ReactiveHandle> _reactiveHandles = <String, ReactiveHandle>{}.obs;

  final Rxn<ConversationViewController> _activeController = Rxn<ConversationViewController>();

  /// A counter to track the number of unread chats
  final RxInt _unreadCount = 0.obs;

  final RxnString _activeGuid = RxnString();

  bool get hasActiveChat => _activeGuid.value != null;

  Rxn<ConversationViewController> get activeController => _activeController;

  RxnString get activeGuid => _activeGuid;

  Chat? get activeChat => _activeGuid.value == null ? null : _chatMap[_activeGuid.value!];

  /// Getter for the unread count.
  /// Calculates the unread count and upates the reactive variable if the count has changed.
  RxInt get unreadCount {
    int count = 0;
    for (Chat chat in _chatMap.values) {
      if (chat.hasUnreadMessage) {
        count++;
      }
    }

    if (count != _unreadCount.value) {
      _unreadCount.value = count;
    }

    return _unreadCount;
  }

  List<Handle> get allHandles {
    return _reactiveHandles.values.map((handle) => handle.handle).toList();
  }

  /// Get a reactive chat object by the [chatGuid].
  /// Returns null if the chat does not exist.
  /// 
  /// You will be able to access the original Chat object within the ReactiveChat object.
  Chat? getChat(ChatGuid chatGuid) {
    return _chatMap[chatGuid];
  }

  List<Handle> getChatParticipants(ChatGuid chatGuid) {
    final addresses = _chatParticipants[chatGuid];
    if (addresses == null) return [];
    return _chatParticipants[chatGuid]!.map((address) => _reactiveHandles[address]!.handle).toList();
  }

  /// Our own init function so we can control when chats are loaded
  void init() {
    reloadChats();
    watchForChatUpdates();
    _chatsLoaded.complete();
  }

  /// Resyncs all of the chats directly from the database.
  Future<void> reloadChats() async {
    final chats = await Database.chats.getAllAsync();
    _syncChats(chats);
  }

  /// Syncs a list of [chats] with the global chat service.
  /// Updates the reactive chat objects accordingly, and therefore
  /// updates the UI as well.
  void _syncChats(List<Chat> chats) {
    Logger.info("Syncing ${chats.length} chats with Global Chat Service");
    final stopwatch = Stopwatch()..start();

    for (Chat chat in chats) {
      // Save the chat globally
      if (!_chatMap.containsKey(chat.guid)) {
        _chatMap[chat.guid] = chat;

        // Load the chat's last message
        chat.latestMessage;

        sortChat(chat.guid);
      }

      // Ensure the chat participants observable is created
      if (_chatParticipants[chat.guid] == null) {
        _chatParticipants[chat.guid] = <String>[].obs;
      }

      // Save the participants to the chat participants list
      // and create the reactive handles
      for (Handle participant in chat.participants) {
        if (!_chatParticipants[chat.guid]!.contains(participant.address)) {
          _chatParticipants[chat.guid]!.add(participant.address);
          _reactiveHandles[participant.address] = ReactiveHandle.fromHandle(participant);
        }
      }

      // Detect changes and make updates
      Chat existing = _chatMap[chat.guid]!;
      _evaluateTitleInfo(chat, existing);
      _evaluateUnreadInfo(chat, existing);
      _evaluateMuteInfo(chat, existing);
      _evaluateDeletedInfo(chat, existing);
    }

    int newUnread = this.chats.where((chat) => chat.hasUnreadMessage).length;
    if (newUnread != unreadCount.value) {
      unreadCount.value = newUnread;
    }
    
    stopwatch.stop();
    Logger.info("Finished initializing chats in ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Watches for changes to the Chat database.
  /// Whenever a change is detected, the chat list will be evaluated and updated accordingly.
  void watchForChatUpdates() {
    final query = Database.chats.query().watch(triggerImmediately: false);
    query.listen((event) async {
      final chats = await event.findAsync();
      _syncAllChats(chats);
    });
  }

  // The same as syncChats but with a debounce of 500ms
  void _syncAllChats(List<Chat> chats) {
    if (_syncAllDebounce?.isActive ?? false) _syncAllDebounce?.cancel();
    _syncAllDebounce = Timer(const Duration(milliseconds: 500), () {
      _syncChats(chats);
    });
  }

  /// Syncs a single [chat] with the global chat service.
  void syncChat(Chat chat) {
    _syncChats([chat]);
  }

  /// Syncs a single chat by the [guid] with the global chat service.
  /// Since you are passing a GUID, it will fetch the chat from the database.
  void syncChatByGuid(String guid) {
    final chat = Database.chats.query(Chat_.guid.equals(guid)).build().findFirst();
    if (chat != null) {
      syncChat(chat);
    }
  }

  /// Adds a [message] to a chat by the [chatGuid].
  /// This will also fetch any metadata for the message if it has a URL.
  /// This method is essentially a wrapper for the Chat.addMessage method
  /// so that we can also update the latest message in the reactive chat object.
  /// 
  /// So long as the chat GUID exists, this method will always return the chat.
  /// If the chat does not exist, this method will return null.
  /// 
  /// If [changeUnreadStatus] is true, the unread status of the chat will be updated
  /// based on the message.
  /// 
  /// If [checkForMessageText] is true, the message will be evaluated to be updated as
  /// the chat's latestMessage. It will also un-delete a message that's been deleted.
  /// 
  /// If [clearNotificationsIfFromMe] is true, the chat's notifications will be cleared
  /// if the message is from the yourself
  Future<Chat?> addMessage(ChatGuid chatGuid, Message message, {bool changeUnreadStatus = true, bool checkForMessageText = true, bool clearNotificationsIfFromMe = true}) async {
    final chat = _chatMap[chatGuid];
    if (chat == null) return null;
  
    // If this is a message preview and we don't already have metadata for this, get it
    if (message.fullText.replaceAll("\n", " ").hasUrl && !MetadataHelper.mapIsNotEmpty(message.metadata) && !message.hasApplePayloadData) {
      MetadataHelper.fetchMetadata(message).then((Metadata? meta) async {
        // If the metadata is empty, don't do anything
        if (!MetadataHelper.isNotEmpty(meta)) return;

        // Save the metadata to the object
        message.metadata = meta!.toJson();
      });
    }

    if (chat.latestMessage == null) {
      chat.setLatestMessage(message);
    } else if (message.dateCreated.isAfter(chat.latestMessage!.dateCreated)) {
      chat.setLatestMessage(message);
    }

    return await chat.addMessage(message, changeUnreadStatus: changeUnreadStatus, checkForMessageText: checkForMessageText, clearNotificationsIfFromMe: clearNotificationsIfFromMe);
  }

  /// Toggles the unread status of a chat by the [chatGuid].
  /// Passing [isUnread] as true will mark the chat as unread,
  /// and the UI will show that the chat is unread. Passing false
  /// will mark the chat as read, and the UI will show that the chat is read.
  void toggleReadStatus(ChatGuid chatGuid, {bool? isUnread, bool force = false, bool clearLocalNotifications = true, bool privateMark = true}) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      chat.toggleUnreadStatus(isUnread, force: force, clearLocalNotifications: clearLocalNotifications, privateMark: privateMark);
    }
  }

  bool isChatUnread(ChatGuid chatGuid) {
    final chat = _chatMap[chatGuid];
    if (chat == null) return false;
    return chat.hasUnreadMessage;
  }

  void toggleMuteStatus(ChatGuid chatGuid, {String? muteType, String? muteArgs}) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      chat.toggleMuteType(muteType, muteArgs: muteArgs,);
    }
  }

  void togglePinStatus(ChatGuid chatGuid, {bool? isPinned, int? pinIndex}) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      chat.toggleIsPinned(isPinned, pinIndex: pinIndex);
    }
  }

  void toggleArchivedStatus(ChatGuid chatGuid, {bool? isArchived}) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      chat.toggleIsArchived(isArchived);
    }
  }

  bool isChatMuted(ChatGuid chatGuid) {
    final chat = _chatMap[chatGuid];
    if (chat == null) return false;
    return chat.muteType == "mute";
  }

  void markAllAsRead() {
    for (Chat chat in _chatMap.values) {
      if (chat.hasUnreadMessage) {
        toggleReadStatus(chat.guid, isUnread: false);
      }
    }
  }

  removeChat(ChatGuid chatGuid, {bool softDelete = true, bool hardDelete = false}) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      _chatMap.remove(chatGuid);
      _chatParticipants.remove(chatGuid);
      chats.removeWhere((element) => element.guid == chatGuid);

      if (hardDelete) {
        Chat.deleteChat(chat);
      } else if (softDelete) {
        Chat.softDelete(chat); 
      }
    }
  }

  /// Sorts the chat by the Chat.sort static method,
  /// which compares two chats, returning 1, 0, or -1.
  sortChat(ChatGuid chatGuid) {
    final chat = _chatMap[chatGuid];
    if (chat == null) return;

    final index = chats.indexWhere((element) => [0, 1].contains(Chat.sort(element, chat)));
    if (index != -1) {
      chats.remove(chat);
      chats.insert(index, chat);
    } else {
      chats.add(chat);
    }
  }

  sortAll() {
    chats.sort(Chat.sort);
  }

  isGroupChat(String? chatGuid) {
    if (chatGuid == null) return false;
    final chat = _chatMap[chatGuid];
    if (chat == null) return false;
    return chat.isGroup;
  }

  isChatPinned(ChatGuid chatGuid) {
    final chat = _chatMap[chatGuid];
    if (chat == null) return false;
    return chat.isPinned;
  }

  updateLatestMessage(ChatGuid chatGuid) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      Message? latestMessage = Chat.getMessages(chat, limit: 1, getDetails: true).firstOrNull;
      if (latestMessage != null) {
        chat.setLatestMessage(latestMessage);
      }
    }
  }

  updateChatPinIndex(int oldIndex, int newIndex) {
    final items = chats.bigPinHelper(true);
    final item = items[oldIndex];

    // Remove the item at the old index, and re-add it at the newIndex
    // We dynamically subtract 1 from the new index depending on if the newIndex is > the oldIndex
    items.removeAt(oldIndex);
    items.insert(newIndex + (oldIndex < newIndex ? -1 : 0), item);

    // Move the pinIndex for each of the chats, and save the pinIndex in the DB
    List<String> toSort = [];
    items.forEachIndexed((i, e) {
      e.pinIndex = i;
      e.save(updatePinIndex: true);
      toSort.add(e.guid);
    });
  
    for (String guid in toSort) {
      sortChat(guid);
    }
  }

  removePinIndices() {
    List<String> toSort = [];
    chats.bigPinHelper(true).where((e) => e.pinIndex != null).forEach((element) {
      element.pinIndex = null;
      element.save(updatePinIndex: true);
      toSort.add(element.guid);
    });

    for (String guid in toSort) {
      sortChat(guid);
    }
  }

  moveChat(ChatGuid chatGuid, int newIndex) {
    final chat = _chatMap[chatGuid];
    if (chat != null) {
      final index = chats.indexWhere((element) => element.guid == chatGuid);
      if (index != -1) {
        chats.removeAt(index);
        chats.insert(newIndex, chat);
      }
    }
  }

  Future<void> openChat(ChatGuid chatGuid, {
    BuildContext? context,
    MessagesService? customService,
    bool fromChatCreator = false,
    Function()? onInit,
    bool closeActiveChat = true,
    PageRoute? customRoute
  }) async {
    BuildContext? ctx = context ?? Get.context;
    if (ctx == null) throw Exception("No context provided to open chat");

    // Code won't run after this call until the route is popped.
    await ns.pushAndRemoveUntil(
      context ?? Get.context!,
      ConversationView(
        chatGuid: chatGuid,
        customService: customService,
        fromChatCreator: fromChatCreator,
        onInit: onInit
      ),
      (route) => route.isFirst,
      closeActiveChat: closeActiveChat && _activeGuid.value != chatGuid,
      customRoute: customRoute
    );
  }

  Future<void> openNextChat(ChatGuid chatGuid, {BuildContext? context}) async {
    final index = GlobalChatService.chats.indexWhere((e) => e.guid == chatGuid);
    if (index > -1 && index < chats.length - 1) {
      final _chat = chats[index + 1];
      openChat(_chat.guid, context: context);
    }
  }

  Future<void> openPreviousChat(ChatGuid chatGuid, {BuildContext? context}) async {
    final index = GlobalChatService.chats.indexWhere((e) => e.guid == chatGuid);
    if (index > 0 && index < chats.length) {
      final _chat = chats[index - 1];
      openChat(_chat.guid, context: context);
    }
  }

  Future<void> closeChat(ChatGuid chatGuid, {bool clearNotifications = true}) async {
    if (_activeGuid.value != chatGuid) return;

    unsetActiveChat();
    await ss.prefs.remove('lastOpenedChat');
    toggleHighlightChat(chatGuid, false);
  }

  setActiveChat(ChatGuid chatGuid) {
    _activeGuid.value = chatGuid;
    _activeController.value = cvc(chatGuid);
  }

  unsetActiveChat() {
    _activeGuid.value = null;

    if (_activeController.value != null) {
      print("Closing active controller");
      _activeController.value!.close();
    }

    _activeController.value = null;
  }

  Future<void> closeActiveChat() async {
    if (_activeGuid.value == null) return;
    await closeChat(_activeGuid.value!);
  }

  openChatDetails(ChatGuid chatGuid, {BuildContext? context}) async {
    final ctx = context ?? Get.context;
    if (context == null) throw Exception("No context provided to open chat details");
    ns.push(ctx!, ConversationDetails(chatGuid: chatGuid));
  }

  clearHighlightedChats() {
    for (Chat chat in _chatMap.values) {
      chat.observables.isHighlighted.value = false;
    }
  }

  bool isChatActive(ChatGuid chatGuid) {
    return _activeGuid.value == chatGuid;
  }

  toggleHighlightChat(ChatGuid chatGuid, bool highlight) {
    final chat = _chatMap[chatGuid];
    if (chat != null && chat.observables.isHighlighted.value != highlight) {
      chat.observables.isHighlighted.value = highlight;
    }
  }

  /// Gets the mentionables (handles) for a chat by the [chatGuid].
  List<Mentionable> getMentionablesForChat(ChatGuid chatGuid) {
    final addresses = _chatParticipants[chatGuid] ?? [];
    return addresses.map((address) {
      final handle = _reactiveHandles[address]!;
      return Mentionable(handle: handle.handle);
    }).toList();
  }

  /// Evaluates to see if a reactive [existingChat] needs to be updated with the [newChat] unread status.
  void _evaluateUnreadInfo(Chat newChat, Chat existingChat) {    
    // Set the default value
    if (existingChat.hasUnreadMessage != newChat.hasUnreadMessage && newChat.hasUnreadMessage) {
      Logger.debug("Updating Chat (${existingChat.guid}) Unread Status from ${existingChat.hasUnreadMessage} to ${newChat.hasUnreadMessage}");
      existingChat.toggleUnreadStatus(newChat.hasUnreadMessage);
    }
  }

  /// Evaluates to see if a reactive [existingChat] needs to be updated with the [newChat] mute type.
  void _evaluateMuteInfo(Chat newChat, Chat existingChat) {
    if (existingChat.muteType != newChat.muteType && newChat.muteType != null) {
      Logger.debug("Updating Chat (${newChat.guid}) Mute Type from ${existingChat.muteType} to ${newChat.muteType}");
      existingChat.toggleMuteType(newChat.muteType);
    }
  }

  /// Evaluates to see if a reactive [existingChat] needs to be updated with the [newChat] title.
  void _evaluateTitleInfo(Chat newChat, Chat existingChat) {
    final newTitle = newChat.getTitle();
    if (existingChat.title != newTitle) {
      Logger.debug("Updating Chat (${newChat.guid}) Title from ${existingChat.title} to ${newChat.getTitle()}");
      existingChat.title = newTitle;
    }
  }

  void _evaluateDeletedInfo(Chat newChat, Chat existingChat) {
    final isDeleted = (newChat.dateDeleted != null);
    if ((existingChat.dateDeleted != null) != isDeleted) {
      Logger.debug("Updating Chat (${newChat.guid}) Deleted Status from ${existingChat.dateDeleted != null} to $isDeleted");
      existingChat.toggleIsDeleted(newChat.dateDeleted != null);
    }
  }

  void dispose() {
    _syncAllDebounce?.cancel();
    _chatMap.clear();
    _chatParticipants.clear();
    _reactiveHandles.clear();
    _unreadCount.value = 0;
    _activeGuid.value = null;
    _activeController.value = null;
  }
}