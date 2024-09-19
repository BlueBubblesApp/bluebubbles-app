import 'dart:async';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/ui/reactivity/reactive_chat.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:get/get.dart';

// ignore: library_private_types_in_public_api, non_constant_identifier_names
_GlobalChatService GlobalChatService = Get.isRegistered<_GlobalChatService>() ? Get.find<_GlobalChatService>() : Get.put(_GlobalChatService());

class _GlobalChatService extends GetxService {
  Timer? _chatDebounceTimer;

  final RxList<Chat> chats = <Chat>[].obs;
  final Map<String, ReactiveChat> _reactiveChats = <String, ReactiveChat>{}.obs;

  final RxInt _unreadCount = 0.obs;
  RxInt get unreadCount {
    int count = 0;
    for (ReactiveChat chat in _reactiveChats.values) {
      if (chat.isUnread.value) {
        count++;
      }
    }

    if (count != _unreadCount.value) {
      _unreadCount.value = count;
    }

    return _unreadCount;
  }

  int initCount = 0;

  ReactiveChat? getReactiveChat(String chatGuid) {
    return _reactiveChats[chatGuid];
  }

  @override
  void onInit() {
    super.onInit();
    reloadChats();
    watchForChatUpdates();
  }

  void reloadChats() {
    final chats = Database.chats.getAll();
    initializeChats(chats);
  }

  void initializeChats(List<Chat> chats) {
    // If we have't had a timer yet, initialize the chats immediately
    if (_chatDebounceTimer == null) {
      _initializeChats(chats);
      
      // Give it a value of 1 so we don't initialize again
      _chatDebounceTimer = Timer(Duration.zero, () {});
      return;
    }

    if (_chatDebounceTimer!.isActive) _chatDebounceTimer?.cancel();
      _chatDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _initializeChats(chats);
      });
  }

  void _initializeChats(List<Chat> chats) {
    initCount += 1;
    Logger.info("Initializing Chats #$initCount");

    final stopwatch = Stopwatch()..start();
    for (Chat chat in chats) {
      if (!_reactiveChats.containsKey(chat.guid)) {
        _reactiveChats[chat.guid] = ReactiveChat.fromChat(chat);
        this.chats.add(chat);
      }
    }

    // Detect changes and make updates
    _evaluateTitleInfo(chats);
    _evaluateUnreadInfo(chats);
    _evaluateMuteInfo(chats);
    
    stopwatch.stop();
    Logger.info("Finished initializing chats in ${stopwatch.elapsedMilliseconds}ms");
  }

  void watchForChatUpdates() {
    final query = Database.chats.query().watch(triggerImmediately: false);
    query.listen((event) {
      final chats = event.find();
      initializeChats(chats);
    });
  }

  void _evaluateUnreadInfo(List<Chat> chats) {
    unreadCount.value = chats.where((element) => element.hasUnreadMessage ?? false).length;

    for (Chat chat in chats) {
      final ReactiveChat? rChat = _reactiveChats[chat.guid];
      if (rChat == null) continue;
      
      // Set the default value
      if (rChat.isUnread.value != chat.hasUnreadMessage && chat.hasUnreadMessage != null) {
        Logger.debug("Updating Chat (${chat.guid}) Unread Status from ${rChat.isUnread} to ${chat.hasUnreadMessage}");
        rChat.isUnread.value = chat.hasUnreadMessage ?? false;
      }
    }
  }

  void _evaluateMuteInfo(List<Chat> chats) {
    for (Chat chat in chats) {
      final ReactiveChat? rChat = _reactiveChats[chat.guid];
      if (rChat == null) continue;
      if (rChat.muteType.value != chat.muteType && chat.muteType != null) {
        Logger.debug("Updating Chat (${chat.guid}) Mute Type from ${rChat.muteType.value} to ${chat.muteType}");
        rChat.muteType.value = chat.muteType;
      }
    }
  }

  void _evaluateTitleInfo(List<Chat> chats) {
    Logger.info("Evaluating Title Info");
    final stopwatch = Stopwatch()..start();
    for (Chat chat in chats) {
      ReactiveChat? rChat = _reactiveChats[chat.guid];
      if (rChat == null) continue;
      
      final newTitle = chat.getTitle();
      if (rChat.title.value != newTitle) {
        Logger.debug("Updating Chat (${chat.guid}) Title from ${rChat.title.value} to ${chat.getTitle()}");
        rChat.title.value = newTitle;
      }
    }

    stopwatch.stop();
    Logger.info("Finished evaluating title info in ${stopwatch.elapsedMilliseconds}ms");
  }

  void dispose() {
    _chatDebounceTimer?.cancel();
  }
}