import 'package:flutter/material.dart';
import 'package:get/get.dart';

MessagesService messages(String chatGuid) => Get.isRegistered<MessagesService>(tag: chatGuid)
    ? Get.find<MessagesService>(tag: chatGuid) : Get.put(MessagesService(), tag: chatGuid);

class MessagesService extends GetxController {
  static final Map<String, Size> cachedBubbleSizes = {};
}