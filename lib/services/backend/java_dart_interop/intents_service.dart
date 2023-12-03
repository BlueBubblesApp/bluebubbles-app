import 'dart:async';

import 'package:bluebubbles/app/layouts/settings/pages/scheduling/scheduled_messages_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/ui/facetime_helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

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
        final id = intent.extra?["android.intent.extra.shortcut.ID"];
        final text = intent.extra?["android.intent.extra.TEXT"];
        final files = <PlatformFile>[];
        if (intent.extra?["android.intent.extra.STREAM"] != null) {
          final data = intent.extra!["android.intent.extra.STREAM"];
          if (data is List) {
            for (String? s in data) {
              if (s == null) continue;
              final path = await mcs.invokeMethod("get-content-path", {"uri": s});
              final bytes = await File(path).readAsBytes();
              files.add(PlatformFile(
                path: path,
                name: basename(path),
                bytes: bytes,
                size: bytes.length,
              ));
            }
          } else if (data != null) {
            final path = await mcs.invokeMethod("get-content-path", {"uri": data});
            final bytes = await File(path).readAsBytes();
            files.add(PlatformFile(
              path: path,
              name: basename(path),
              bytes: bytes,
              size: bytes.length,
            ));
          }
        }
        await openChat(id, text: text, attachments: files);
        return;
      default:
        if (intent.data?.startsWith("imessage://") ?? false) {
          final uri = Uri.tryParse(intent.data!.replaceFirst("imessage://", "imessage:").replaceFirst("&body=", "?body="));
          if (uri != null) {
            final address = uri.path;
            final handle = Handle.findOne(addressAndService: Tuple2(address, "iMessage"));
            ns.pushAndRemoveUntil(
              Get.context!,
              ChatCreator(
                initialSelected: [SelectedContact(displayName: handle?.displayName ?? address, address: address)],
                initialText: uri.queryParameters['body'],
              ),
              (route) => route.isFirst,
            );
          }
        } else if (intent.extra?["chatGuid"] != null) {
          final guid = intent.extra!["chatGuid"]!;
          final bubble = intent.extra!["bubble"] == "true";
          ls.isBubble = bubble;
          await openChat(guid);
        }
    }
  }

  Future<void> answerFaceTime(String callUuid) async {
    if (Get.context != null) {
      showDialog(
          context: Get.context!,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: context.theme.colorScheme.properSurface,
              title: Text(
                "Generating link for call...",
                style: context.theme.textTheme.titleLarge,
              ),
              content: Container(
                height: 70,
                child: Center(
                  child: CircularProgressIndicator(
                    backgroundColor: context.theme.colorScheme.properSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                  ),
                ),
              ),
            );
          }
      );
      hideFaceTimeOverlay(callUuid);
    }

    String? link;
    try {
      final call = await http.answerFaceTime(callUuid);
      link = call.data?["data"]?["link"];
    } catch (_) {}
    if (link == null) {
      if (Get.context != null) {
        Navigator.of(Get.context!).pop();
      }
      return showSnackbar("Failed to answer FaceTime", "Unable to generate FaceTime link!");
    }

    if (kIsDesktop) {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } else if (kIsWeb) {
      // TODO: Implement web FaceTime
    } else {
      mcs.invokeMethod("open-link", {"link": link, "forceBrowser": true});
    }
  }

  Future<void> openChat(String? guid, {String? text, List<PlatformFile> attachments = const []}) async {
    if (guid == null) {
      await uiStartup.future;
      ns.pushAndRemoveUntil(
        Get.context!,
        ChatCreator(
          initialAttachments: attachments,
          initialText: text,
        ),
        (route) => route.isFirst,
      );
    } else if (guid == "-1") {
      if (cm.activeChat != null) {
        Navigator.of(Get.context!).popUntil((route) => route.isFirst);
      }
    } else if (guid == "-2") {
      Navigator.of(Get.context!).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return ServerManagementPanel();
          },
        ),
      );
    } else if (guid.contains("scheduled")) {
      Navigator.of(Get.context!).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return ScheduledMessagesPanel();
          },
        ),
      );
    } else {
      final chat = Chat.findOne(guid: guid);
      if (chat == null) return;
      bool chatIsOpen = cm.activeChat?.chat.guid == guid;
      if (!chatIsOpen) {
        await uiStartup.future;
        ns.pushAndRemoveUntil(
          Get.context!,
          ConversationView(
            chat: chat,
          ),
          (route) => route.isFirst,
        );
        // wait for controller to be initialized
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (attachments.isNotEmpty) {
        cvc(chat).pickedAttachments.value = attachments;
      }
      if (text != null && text.isNotEmpty) {
        cvc(chat).textController.text = text;
      }
    }
  }
}
