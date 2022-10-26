import 'dart:async';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

MessagesService messages(String chatGuid, {Chat? chat}) => Get.isRegistered<MessagesService>(tag: chatGuid)
    ? Get.find<MessagesService>(tag: chatGuid) : Get.put(MessagesService(), tag: chatGuid);

class MessagesService extends GetxController {
  static final Map<String, Size> cachedBubbleSizes = {};
  late final Chat chat;
  late final StreamSubscription countSub;
  final RxList<Message> messages = <Message>[].obs;

  int currentCount = 0;

  void init(Chat c) {
    chat = c;
    // watch for new messages
    final countQuery = (messageBox.query(Message_.dateDeleted.isNull())
      ..link(Message_.chat, Chat_.id.equals(chat.id!))
      ..order(Message_.id, flags: Order.descending)).watch(triggerImmediately: true);
    countSub = countQuery.listen((event) {
      final newCount = event.count();
      if (newCount > currentCount) {
        messages.add(event.findFirst()!);
      }
      currentCount = newCount;
    });
  }

  @override
  void onClose() {
    countSub.cancel();
    super.onClose();
  }
}