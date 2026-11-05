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
  late final Future<Map<String, dynamic>?> _payload = OpenPigeon.payloadFor(widget.message);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _payload,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        if (payload == null) return widget.fallback;
        // The size OpenPigeon composes its live views at
        final width = (MediaQuery.sizeOf(context).width * 0.6).roundToDouble() - 10;
        return _OpenPigeonView(
          viewType: 'openpigeon/live',
          creationParams: {
            ...payload,
            'chatGuid': widget.chat.guid,
            'userCount': OpenPigeon.userCount(widget.chat),
          },
          gestureRecognizers: {Factory<TapGestureRecognizer>(() => TapGestureRecognizer())},
          fallback: widget.fallback,
          child: (view) => SizedBox(width: width, height: 250, child: view),
        );
      },
    );
  }
}

/// An OpenPigeon platform view, replaced by [fallback] if OpenPigeon fails to fill it.
class _OpenPigeonView extends StatefulWidget {
  const _OpenPigeonView({
    required this.viewType,
    required this.creationParams,
    required this.gestureRecognizers,
    required this.fallback,
    required this.child,
  });

  final String viewType;
  final Map<String, dynamic> creationParams;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final Widget fallback;
  final Widget Function(Widget view) child;

  @override
  State<_OpenPigeonView> createState() => _OpenPigeonViewState();
}

class _OpenPigeonViewState extends State<_OpenPigeonView> {
  int? _viewId;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (OpenPigeon.failedViews.contains(_viewId)) return widget.fallback;
      return widget.child(AndroidView(
        viewType: widget.viewType,
        creationParams: widget.creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: widget.gestureRecognizers,
        onPlatformViewCreated: (id) {
          if (mounted) setState(() => _viewId = id);
        },
      ));
    });
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
      child: _OpenPigeonView(
        viewType: 'openpigeon/keyboard',
        creationParams: {'chatGuid': chat.guid, 'userCount': OpenPigeon.userCount(chat)},
        gestureRecognizers: {Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())},
        fallback: const Center(child: Text("Couldn't load games")),
        child: (view) => view,
      ),
    ),
  );
  OpenPigeon.onKeyboardMessage(null);
}

Uint8List? _decode(Object? base64) {
  if (base64 is! String) return null;
  try {
    return base64Decode(base64);
  } on FormatException {
    return null;
  }
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
      final image = _decode(game['imageBase64']);
      final title = game['ldText'] is String ? game['ldText'] as String : "Game";
      final caption = game['caption'] is String ? game['caption'] as String : null;
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: context.theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (image != null)
                Image.memory(
                  image,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(width: 72, height: 72),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.theme.textTheme.titleSmall),
                    if (caption != null) Text(caption, style: context.theme.textTheme.bodySmall),
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
