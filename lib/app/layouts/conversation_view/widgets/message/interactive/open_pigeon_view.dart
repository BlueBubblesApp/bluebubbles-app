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

/// A game bubble: [card], drawn from the image the sender attached, or the compact form once a later turn of the same
/// game has arrived, as Messages shows earlier turns. GamePigeon only attaches an image to a game's opening message,
/// so the latest turn without one shows OpenPigeon's drawing of the game where it can, and is compact otherwise.
class OpenPigeonGameBubble extends StatefulWidget {
  const OpenPigeonGameBubble({super.key, required this.message, required this.data, required this.card});

  final Message message;
  final iMessageAppData data;
  final Widget card;

  @override
  State<OpenPigeonGameBubble> createState() => _OpenPigeonGameBubbleState();
}

class _OpenPigeonGameBubbleState extends State<OpenPigeonGameBubble> {
  Future<Uint8List?>? _snapshot;

  @override
  Widget build(BuildContext context) {
    final compact = OpenPigeonCollapsedGame(
      icon: decodeBase64(widget.data.appIcon),
      title: widget.data.ldText,
      caption: widget.data.userInfo?.caption,
    );
    if (OpenPigeon.isEarlierTurn(widget.message)) return compact;
    if (widget.message.dbAttachments.isNotEmpty) return widget.card;
    final chat = widget.message.chat.target;
    if (chat == null) return compact;
    return Obx(() {
      // Both read, unlike canDraw on its own, which stops at the platform check and leaves this Obx observing nothing
      final drawable = OpenPigeon.licensed.value & OpenPigeon.installed.value & OpenPigeon.canDraw;
      return drawable ? _drawnCard(context, chat, compact) : compact;
    });
  }

  Widget _drawnCard(BuildContext context, Chat chat, Widget compact) {
    // A bubble's width; OpenPigeon's layout decides the height
    final width = (MediaQuery.sizeOf(context).width * 0.6).roundToDouble() - 10;
    _snapshot ??= OpenPigeon.snapshot(widget.message, chat, width, width * 1.5);
    // A live view is the whole bubble, caption included
    return FutureBuilder<Uint8List?>(
      future: _snapshot,
      builder: (context, snapshot) {
        final png = snapshot.data;
        return png == null ? compact : Image.memory(png, width: width, gaplessPlayback: true);
      },
    );
  }
}

/// A game message in compact form, as Messages shows earlier turns: the app's icon, the game and its caption.
/// Also stands in for a game whose payload hasn't arrived yet.
class OpenPigeonCollapsedGame extends StatelessWidget {
  const OpenPigeonCollapsedGame({super.key, this.icon, this.title, this.caption});

  final Uint8List? icon;
  final String? title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = Icon(
      Icons.sports_esports_rounded,
      size: 28,
      color: context.theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // iMessage app icons are 4:3 JPEGs of a pill (radius half the height) on white, the shape Messages draws.
          // Scaled up slightly so the edge where the JPEG fades into white falls outside the clip
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: icon == null
                ? SizedBox(width: 40, height: 30, child: fallbackIcon)
                : Transform.scale(
                    scale: 1.08,
                    child: Image.memory(
                      icon!,
                      width: 40,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => SizedBox(width: 40, height: 30, child: fallbackIcon),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? "GamePigeon",
                  style: context.theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: context.theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An earlier turn the other player sent, as Messages shows it: the app's icon and the game on one quiet line.
class OpenPigeonEarlierTurn extends StatelessWidget {
  const OpenPigeonEarlierTurn({super.key, required this.data, this.onTap});

  /// Null until the turn's payload arrives
  final iMessageAppData? data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = decodeBase64(data?.appIcon);
    const fallback = SizedBox(width: 24, height: 18);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: icon == null
                  ? fallback
                  : Transform.scale(
                      scale: 1.08,
                      child: Image.memory(
                        icon,
                        width: 24,
                        height: 18,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              data?.ldText ?? "GamePigeon",
              style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// What tapping a game does when OpenPigeon isn't drawing it: explain the subscription, offer the install, or open
/// the game.
Future<void> openOpenPigeonGame(BuildContext context, Message message, Chat chat) async {
  if (!OpenPigeon.licensed.value) return _showSubscriptionRequired(context);
  if (!OpenPigeon.installed.value) return OpenPigeon.openStore();
  final payload = await OpenPigeon.payloadFor(message);
  if (payload == null || !await OpenPigeon.open(payload, chat)) {
    showSnackbar("Error", "Couldn't open the game", type: SnackbarType.error);
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
      return widget.child(
        AndroidView(
          viewType: widget.viewType,
          creationParams: widget.creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: widget.gestureRecognizers,
          onPlatformViewCreated: (id) {
            if (mounted) setState(() => _viewId = id);
          },
        ),
      );
    });
  }
}

/// Opens OpenPigeon's game picker in the keyboard's place. A picked game waits in the composer until the user sends it.
Future<void> showOpenPigeonPicker(BuildContext context, ConversationViewController controller) async {
  if (!OpenPigeon.licensed.value) return _showSubscriptionRequired(context);
  if (!OpenPigeon.installed.value) return OpenPigeon.openStore();
  controller.focusNode.unfocus();
  controller.subjectFocusNode.unfocus();
  controller.showAttachmentPicker.value = false;
  controller.showGamePicker.value = true;
}

/// OpenPigeon's game picker, below the text field. It stays open after a pick: a game with variants stages its
/// default and shows its options, and each option picked stages the game again.
class OpenPigeonKeyboard extends StatefulWidget {
  const OpenPigeonKeyboard({super.key, required this.controller});

  final ConversationViewController controller;

  @override
  State<OpenPigeonKeyboard> createState() => _OpenPigeonKeyboardState();
}

class _OpenPigeonKeyboardState extends State<OpenPigeonKeyboard> {
  @override
  void initState() {
    super.initState();
    OpenPigeon.onKeyboardMessage((game) => widget.controller.pendingGame.value = game);
  }

  @override
  void dispose() {
    OpenPigeon.onKeyboardMessage(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.controller.chat;
    return SizedBox(
      // The attachment picker's height, so switching between them doesn't move the field
      height: 340,
      child: _OpenPigeonView(
        viewType: 'openpigeon/keyboard',
        creationParams: {'chatGuid': chat.guid, 'userCount': OpenPigeon.userCount(chat)},
        gestureRecognizers: {Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())},
        fallback: const Center(child: Text("Couldn't load games")),
        child: (view) => view,
      ),
    );
  }
}

Uint8List? decodeBase64(Object? base64) {
  if (base64 is! String) return null;
  try {
    return base64Decode(base64);
  } on FormatException {
    return null;
  }
}

/// The picked game, above the composer's text field: its picture, capped at [_maxHeight], beside its name and caption.
class OpenPigeonPendingGame extends StatelessWidget {
  const OpenPigeonPendingGame({super.key, required this.controller});

  final ConversationViewController controller;

  static const double _maxHeight = 64;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final game = controller.pendingGame.value;
      if (game == null) return const SizedBox.shrink();
      final data = OpenPigeon.gameMessage(game).payloadData!.appData!.first;
      final image = OpenPigeon.gameImage(game);
      final fallback = SizedBox(
        width: _maxHeight,
        height: _maxHeight,
        child: Icon(Icons.sports_esports_rounded, size: 32, color: context.theme.colorScheme.onSurfaceVariant),
      );
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: image == null
                    ? fallback
                    : Image.memory(
                        image,
                        width: _maxHeight * 3 / 2,
                        height: _maxHeight,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.ldText ?? "GamePigeon",
                      style: context.theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data.userInfo?.caption != null)
                      Text(
                        data.userInfo!.caption!,
                        style: context.theme.textTheme.bodySmall!
                            .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => controller.pendingGame.value = null),
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
