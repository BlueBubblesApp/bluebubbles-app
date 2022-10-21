import 'package:bluebubbles/core/events/event_dispatcher.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

LifecycleService ls = Get.isRegistered<LifecycleService>() ? Get.find<LifecycleService>() : Get.put(LifecycleService());

class LifecycleService extends GetxService with WidgetsBindingObserver {
  bool isBubble = false;
  bool get isAlive => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
        Logger.error("Error caught while hiding keyboard: ${e.toString()}");
      });
      if (isBubble) {
        closeBubble();
      } else {
        close();
      }
    } else if (state == AppLifecycleState.resumed) {
      open();
    }
  }

  void open() {
    final currentChat = ChatManager().getActiveDeadController();
    if (currentChat != null) {
      ChatManager().clearChatNotifications(ChatManager().activeChat!.chat);
      ChatManager().setActiveToAlive();
    }

    if (!kIsDesktop && !kIsWeb) {
      socket.reconnect();
    } else {
      EventDispatcher().emit('focus-keyboard', null);
    }
  }

  void close() {
    ChatManager().setActiveToDead();
    if (!kIsDesktop && !kIsWeb) {
      socket.disconnect();
    }
  }

  void closeBubble() {
    ChatManager().setAllInactive();
    socket.disconnect();
  }
}