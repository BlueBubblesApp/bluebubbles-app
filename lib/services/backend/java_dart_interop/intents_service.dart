import 'dart:async';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:universal_io/io.dart';

IntentsService intents = Get.isRegistered<IntentsService>() ? Get.find<IntentsService>() : Get.put(IntentsService());

class IntentsService extends GetxService {
  late final StreamSubscription sub;

  Future<void> init() async {
    if (kIsWeb || kIsDesktop) return;

    final intent = await ReceiveIntent.getInitialIntent();
    handleIntent(intent);

    sub = ReceiveIntent.receivedIntentStream.listen((Intent? intent) {
      handleIntent(intent);
    }, onError: (err) {
      Logger.error("Failed to get intent! Error: ${err.toString()}");
    });
  }

  @override
  void onClose() async {
    await sub.cancel();
    super.onClose();
  }

  void handleIntent(Intent? intent) async {
    if (intent == null) return;

    switch (intent.action) {
      case "android.intent.action.SEND":
      case "android.intent.action.SEND_MULTIPLE":
        if (intent.extra?["android.intent.extra.TEXT"] != null) {
          await openChat(intent.extra?["android.intent.extra.shortcut.ID"], text: intent.extra?["android.intent.extra.TEXT"]);
        } else if (intent.extra?["android.intent.extra.STREAM"] != null) {
          final data = intent.extra!["android.intent.extra.STREAM"];
          final files = <PlatformFile>[];
          if (data is List) {
            for (String? s in data) {
              if (s == null) continue;
              final path = await mcs.invokeMethod("get-content-path", {"uri": s});
              final bytes = await File(path).readAsBytes();
              files.add(PlatformFile(
                path: path,
                name: path.split("/").last,
                bytes: bytes,
                size: bytes.length,
              ));
            }
          } else if (data != null) {
            final path = await mcs.invokeMethod("get-content-path", {"uri": data});
            final bytes = await File(path).readAsBytes();
            files.add(PlatformFile(
              path: path,
              name: path.split("/").last,
              bytes: bytes,
              size: bytes.length,
            ));
          }
          await openChat(intent.extra?["android.intent.extra.shortcut.ID"], attachments: files);
        }
        return;
      default:
        if (intent.extra?["chatGuid"] != null) {
          final guid = intent.extra!["chatGuid"]!;
          final bubble = intent.extra!["bubble"] == "true";
          ls.isBubble = bubble;
          await openChat(guid);
        }
    }
  }

  Future<void> openChat(String? guid, {String? text, List<PlatformFile> attachments = const []}) async {
    if (guid == null) {
      /*ns.pushAndRemoveUntil(
        Get.context!,
        ConversationView(
          existingAttachments: attachments,
          existingText: text,
          isCreator: true,
        ),
        (route) => route.isFirst,
      );*/
    } else if (guid == "-1") {
      ns.key.currentState!.popUntil((route) => route.isFirst);
    } else if (guid == "-2") {
      Get.toNamed("/settings/server-management-panel");
    } else {
      final chat = Chat.findOne(guid: guid);
      if (chat == null) return;

      // Add the attachments/text to the chat's draft state variables
      bool updateAttachments = false;
      bool updateText = false;
      if (attachments.isNotEmpty) {
        chat.textFieldAttachments = attachments.map((e) => e.path!).toList();
        updateAttachments = true;
      }
      if (text != null && text.isNotEmpty) {
        chat.textFieldText = text;
        updateText = true;
      }

      // Save the draft state variables
      if (updateAttachments || updateText) {
        chat.save(updateTextFieldAttachments: updateAttachments, updateTextFieldText: updateText);
      }

      if (cm.activeChat?.chat.guid != guid) {
        ns.pushAndRemoveUntil(
          Get.context!,
          ConversationView(
            chat: chat,
          ),
          (route) => route.isFirst,
        );
      }
    }
  }
}