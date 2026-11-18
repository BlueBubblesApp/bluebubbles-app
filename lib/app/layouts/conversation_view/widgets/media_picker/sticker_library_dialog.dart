import 'dart:async';

import 'package:bluebubbles/app/components/subscription_required.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/composer_popover.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/sticker_library_tile.dart';
import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The desktop composer's Stickers button: the Mac's sticker library as a popover above [anchorContext]. Drag a sticker
/// out onto a message to place it there; the popover hides once the drag leaves it and closes when it ends. Only open
/// this when `ServerDetails.supportsStickers`.
Future<void> showStickerLibraryPopover(BuildContext anchorContext, ConversationViewController controller) async {
  if (SubscriptionSvc.locked) {
    return showSubscriptionRequired(
      anchorContext,
      feature: ProFeature.stickers,
      onUnlocked: () => anchorContext.mounted ? showStickerLibraryPopover(anchorContext, controller) : null,
    );
  }
  // The cached library draws at once; this brings it up to date behind it
  unawaited(StickerLibrarySvc.sync());
  await showComposerPopover(
    anchorContext,
    controller,
    builder: (context) => ComposerPopoverCard(
      child: StickerLibraryView(
        onClose: () => Navigator.of(context).pop(),
        draggable: true,
        // Hidden rather than closed while the drag is out: closing would cancel it
        onDragUpdate: (details) {
          final hidden = ComposerPopoverScope.of(context);
          // `context` is the popover's own box
          final box = context.findRenderObject() as RenderBox?;
          if (hidden == null || hidden.value || box == null || !box.attached) return;
          if (!(box.localToGlobal(Offset.zero) & box.size).contains(details.globalPosition)) hidden.value = true;
        },
        // Escape closes the popover mid-drag, which cancels the drag (navigating cancels pointers): then it's no
        // longer the current route, and popping again would close the conversation
        onDragEnd: () {
          if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
          if (ComposerPopoverScope.of(context)?.value ?? false) Navigator.of(context).pop();
        },
      ),
    ),
  );
}

/// The library itself: saved stickers then recents, with an add button. [onPicked], when set, makes stickers tappable.
/// Without [title] it leaves the heading to its container (the emoji tapback picker's Stickers tab). [onClose] adds a
/// close button. [draggable] lets stickers be dragged onto messages ([StickerDropTarget]), calling [onDragUpdate] and
/// [onDragEnd].
class StickerLibraryView extends StatefulWidget {
  const StickerLibraryView({
    super.key,
    this.onPicked,
    this.title = true,
    this.onClose,
    this.draggable = false,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final ValueChanged<LibrarySticker>? onPicked;
  final bool title;
  final VoidCallback? onClose;
  final bool draggable;
  final DragUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  State<StickerLibraryView> createState() => _StickerLibraryViewState();
}

class _StickerLibraryViewState extends State<StickerLibraryView> {
  @override
  Widget build(BuildContext context) {
    final svc = StickerLibrarySvc;
    return Column(
      children: [
        Obx(
          () => widget.title || widget.onClose != null || !SubscriptionSvc.locked ? _header() : const SizedBox.shrink(),
        ),
        Expanded(
          child: Obx(() {
            // The cached library stays on disk for when the subscription comes back
            if (SubscriptionSvc.locked) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SubscriptionRequiredCard(feature: ProFeature.stickers),
                      if (SubscriptionSvc.offline)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton(onPressed: retrySubscriptionCheck, child: const Text("Retry")),
                        )
                      else if (SubscriptionSvc.purchaseUrl.value != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton(onPressed: openSubscriptionPage, child: const Text("Learn More")),
                        ),
                    ],
                  ),
                ),
              );
            }
            final stickers = svc.entries.toList();
            if (stickers.isEmpty) {
              if (!svc.loaded.value || svc.syncing.value) return const Center(child: CircularProgressIndicator());
              final error = svc.syncError.value;
              if (error != null) return _message(error);
              return _message(svc.unavailableReason.value ?? "No stickers yet");
            }
            final saved = stickers.where((s) => s.isSaved).toList();
            final recent = stickers.where((s) => !s.isSaved).toList();
            return CustomScrollView(
              slivers: [
                if (saved.isNotEmpty) ..._section("Stickers", saved),
                if (recent.isNotEmpty) ..._section("Recents", recent),
                const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
    child: Row(
      children: [
        Expanded(child: widget.title ? Text("Stickers", style: context.textTheme.titleMedium) : const SizedBox()),
        if (!SubscriptionSvc.locked)
          Obx(
            () => StickerLibrarySvc.syncing.value
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(icon: const Icon(Icons.refresh), tooltip: "Refresh", onPressed: StickerLibrarySvc.sync),
          ),
        // Adding goes through the server's Private API helper
        if (SettingsSvc.settings.enablePrivateAPI.value && !SubscriptionSvc.locked)
          Obx(
            () => StickerLibrarySvc.adding.value
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: "Add from this device",
                    color: context.theme.colorScheme.primary,
                    onPressed: pickAndAddSticker,
                  ),
          ),
        if (widget.onClose != null)
          IconButton(icon: const Icon(Icons.close), tooltip: "Close", onPressed: widget.onClose),
      ],
    ),
  );

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.outline),
          ),
        ],
      ),
    ),
  );

  List<Widget> _section(String title, List<LibrarySticker> stickers) => [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(title, style: context.textTheme.titleSmall!.copyWith(color: context.theme.colorScheme.outline)),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 76,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: stickers.length,
        itemBuilder: (context, i) => Tooltip(
          message: stickers[i].label ?? "",
          child: StickerLibraryTile(
            sticker: stickers[i],
            onTap: widget.onPicked == null ? null : () => widget.onPicked!(stickers[i]),
            draggable: widget.draggable,
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: widget.onDragEnd,
          ),
        ),
      ),
    ),
  ];
}
