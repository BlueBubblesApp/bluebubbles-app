import 'dart:async';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

ChatsService chats = Get.isRegistered<ChatsService>() ? Get.find<ChatsService>() : Get.put(ChatsService());

class ChatsService extends GetxService {
  static const batchSize = 15;
  int currentCount = 0;
  late final StreamSubscription countSub;

  final RxBool hasChats = false.obs;
  final RxBool loadedChatBatch = false.obs;
  final RxList<Chat> chats = <Chat>[].obs;

  final List<Handle> webCachedHandles = [];

  @override
  void onInit() {
    super.onInit();
    // watch for new chats
    final countQuery = (chatBox.query()
      ..order(Chat_.id, flags: Order.descending)).watch(triggerImmediately: true);
    countSub = countQuery.listen((event) {
      final newCount = event.count();
      if (newCount > currentCount) {
        addChat(event.findFirst()!);
      }
      currentCount = newCount;
    });
  }

  Future<void> init() async {
    Logger.info("Fetching chats...", tag: "ChatBloc");
    currentCount = Chat.count() ?? (await http.chatCount().catchError((err) {
      Logger.info("Error when fetching chat count!", tag: "ChatBloc");
    })).data['data']['total'];

    if (currentCount != 0) {
      hasChats.value = true;
    } else {
      loadedChatBatch.value = true;
      return;
    }

    final newChats = <Chat>[];
    final batches = (currentCount < batchSize) ? batchSize : (currentCount / batchSize).ceil();

    for (int i = 0; i < batches; i++) {
      List<Chat> temp;
      if (kIsWeb) {
        temp = await cm.getChats(withLastMessage: true, limit: batchSize, offset: i * batchSize);
      } else {
        temp = await Chat.getChats(limit: batchSize, offset: i * batchSize);
      }

      for (Chat c in temp) {
        cm.createChatController(c);
      }
      newChats.addAll(temp);

      if (kIsWeb) {
        webCachedHandles.addAll(chats.map((e) => e.participants).flattened.toList());
        final ids = webCachedHandles.map((e) => e.address).toSet();
        webCachedHandles.retainWhere((element) => ids.remove(element.address));
      }

      newChats.sort(Chat.sort);
      chats.value = newChats;
      loadedChatBatch.value = true;
    }

    Logger.info("Finished fetching chats (${chats.length}).", tag: "ChatBloc");
    // update share targets
    for (Chat c in chats.where((e) => !isNullOrEmpty(e.title)!).take(4)) {
      await mcs.invokeMethod("push-share-targets", {
        "title": c.title,
        "guid": c.guid,
        "icon": await avatarAsBytes(
          isGroup: c.isGroup,
          participants: c.participants,
          chatGuid: c.guid,
          quality: 256
        ),
      });
    }
  }

  @override
  void onClose() {
    countSub.cancel();
    super.onClose();
  }

  void sort() {
    chats.sort(Chat.sort);
  }

  void updateChat(Chat updated, {bool shouldSort = false}) {
    final index = chats.indexWhere((e) => updated.guid == e.guid);
    final toUpdate = chats[index];
    // this is so the list doesn't re-render
    // ignore: invalid_use_of_protected_member
    chats.value[index] = updated.merge(toUpdate);
    if (shouldSort) sort();
  }

  void addChat(Chat toAdd) {
    chats.add(toAdd);
    cm.createChatController(toAdd);
    sort();
  }

  void removeChat(Chat toRemove) {
    final index = chats.indexWhere((e) => toRemove.guid == e.guid);
    chats.removeAt(index);
  }

  void markAllAsRead() {
    chats.where((element) => element.hasUnreadMessage!).forEach((element) {
      element.toggleHasUnread(false);
      mcs.invokeMethod("clear-chat-notifs", {"chatGuid": element.guid});
    });
  }

  void updateChatPinIndex(int oldIndex, int newIndex) {
    final items = chats.bigPinHelper(true);
    final item = items[oldIndex];

    // Remove the item at the old index, and re-add it at the newIndex
    // We dynamically subtract 1 from the new index depending on if the newIndex is > the oldIndex
    items.removeAt(oldIndex);
    items.insert(newIndex + (oldIndex < newIndex ? -1 : 0), item);

    // Move the pinIndex for each of the chats, and save the pinIndex in the DB
    items.forEachIndexed((i, e) {
      e.pinIndex = i;
      e.save(updatePinIndex: true);
    });
    chats.sort();
  }

  void removePinIndices() {
    chats.bigPinHelper(true).where((e) => e.pinIndex != null).forEach((element) {
      element.pinIndex = null;
      element.save(updatePinIndex: true);
    });
    chats.sort();
  }
}