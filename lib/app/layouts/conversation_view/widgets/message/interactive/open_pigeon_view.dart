import 'dart:convert';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// A game bubble drawn by OpenPigeon, falling back to [fallback] until (or unless) the server's payload loads.
class OpenPigeonLiveView extends StatefulWidget {
  const OpenPigeonLiveView({super.key, required this.message, required this.chat, required this.fallback});

  final Message message;
  final Chat chat;
  final Widget fallback;

  @override
  State<OpenPigeonLiveView> createState() => _OpenPigeonLiveViewState();
}

class _OpenPigeonLiveViewState extends State<OpenPigeonLiveView> {
  late final Future<Map<String, dynamic>?> _payload = OpenPigeon.payloadFor(widget.message.guid!);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _payload,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        if (payload == null) return widget.fallback;
        // The size OpenPigeon composes its live views at
        final width = (MediaQuery.sizeOf(context).width * 0.6).roundToDouble() - 10;
        return SizedBox(
          width: width,
          height: 250,
          child: AndroidView(
            viewType: 'openpigeon/live',
            creationParams: {
              ...payload,
              'chatGuid': widget.chat.guid,
              'userCount': OpenPigeon.userCount(widget.chat),
            },
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: {Factory<TapGestureRecognizer>(() => TapGestureRecognizer())},
          ),
        );
      },
    );
  }
}

/// OpenPigeon's game picker. A picked game waits in the composer until the user sends it.
Future<void> showOpenPigeonPicker(BuildContext context, ConversationViewController controller) async {
  if (!OpenPigeon.licensed.value) return _showSubscriptionRequired(context);
  if (!OpenPigeon.installed.value) return OpenPigeon.openStore();
  final chat = controller.chat;
  OpenPigeon.onKeyboardMessage((game) {
    controller.pendingGame.value = game;
    controller.showAttachmentPicker.value = false;
    Navigator.of(context).maybePop();
  });
  await showModalBottomSheet(
    context: context,
    builder: (context) => SizedBox(
      // OpenPigeon's keyboard height for BlueBubbles hosts
      height: 380,
      child: AndroidView(
        viewType: 'openpigeon/keyboard',
        creationParams: {'chatGuid': chat.guid, 'userCount': OpenPigeon.userCount(chat)},
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: {Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())},
      ),
    ),
  );
  OpenPigeon.onKeyboardMessage(null);
}

/// The picked game, above the composer's text field.
class OpenPigeonPendingGame extends StatelessWidget {
  const OpenPigeonPendingGame({super.key, required this.controller});

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final game = controller.pendingGame.value;
      if (game == null) return const SizedBox.shrink();
      final image = game['imageBase64'] as String?;
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: context.theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (image != null) Image.memory(base64Decode(image), width: 72, height: 72, fit: BoxFit.cover),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game['ldText'] as String? ?? "Game", style: context.theme.textTheme.titleSmall),
                    if (game['caption'] != null) Text(game['caption'] as String, style: context.theme.textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => controller.pendingGame.value = null,
              ),
            ],
          ),
        ),
      );
    });
  }
}

Future<void> _showSubscriptionRequired(BuildContext context) async {
  final url = OpenPigeon.purchaseUrl;
  await showBBDialog(
    context: context,
    title: "Subscription Required",
    body: "Playing games needs a BlueBubbles subscription on your server.",
    actions: [
      BBDialogAction(text: "Close", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
      if (url != null)
        BBDialogAction(
          text: "Learn More",
          isDefault: true,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
        ),
    ],
  );
}
