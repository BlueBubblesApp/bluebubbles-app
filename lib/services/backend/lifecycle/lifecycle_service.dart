import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart';

LifecycleService ls = Get.isRegistered<LifecycleService>() ? Get.find<LifecycleService>() : Get.put(LifecycleService());

class LifecycleService extends GetxService with WidgetsBindingObserver {
  bool isBubble = false;
  bool isUiThread = true;
  bool get isAlive => kIsWeb ? !(window.document.hidden ?? false)
      : WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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
  void didChangeAppLifecycleState(AppLifecycleState state) async {
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
      await storeStartup.future;
      open();
    }
  }

  void open() {
    cm.setActiveToAlive();
    if (cm.activeChat != null) {
      cm.clearChatNotifications(cm.activeChat!.chat);
    }

    if (!kIsDesktop && !kIsWeb) {
      socket.reconnect();
    }
  }

  void close() {
    cm.setActiveToDead();
    if (!kIsDesktop && !kIsWeb) {
      socket.disconnect();
    }
  }

  void closeBubble() {
    cm.setAllInactive();
    socket.disconnect();
  }
}