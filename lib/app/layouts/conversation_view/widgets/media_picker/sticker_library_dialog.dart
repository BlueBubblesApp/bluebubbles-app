import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/components/subscription_required.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/sticker_library_tile.dart';
import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows the server Mac's sticker library ([StickerLibrarySvc]), with a button to add an image from this device to it.
///
/// The desktop composer's Stickers button. In tablet mode it's a panel over the chat list rather than a dialog, so the
/// conversation stays in view and usable; pressing the button again closes it. Only open this when
/// `ServerDetails.supportsStickers`.
Future<void> showStickerLibrary(BuildContext context) async {
  if (SubscriptionSvc.locked) {
    return showSubscriptionRequired(
      context,
      feature: ProFeature.stickers,
      onUnlocked: () => context.mounted ? showStickerLibrary(context) : null,
    );
  }
  if (_sidePanel != null) return _closeSidePanel();
  // The cached library draws at once; this brings it up to date behind it
  unawaited(StickerLibrarySvc.sync());
  if (kIsDesktop && NavigationSvc.widthChatListLeft(context) >= _sidePanelMinPane) return _openSidePanel(context);
  final colors = context.theme.colorScheme;
  final height = min(460.0, MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical - 48);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: colors.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        height: height,
        child: const StickerLibraryView(),
      ),
    ),
  );
}

OverlayEntry? _sidePanel;

/// The narrowest chat list pane the panel goes over; a narrower one (avatars only) gets the dialog.
const double _sidePanelMinPane = 240;
const double _sidePanelMargin = 12;

void _openSidePanel(BuildContext context) {
  final overlay = Overlay.of(context, rootOverlay: true);
  // The root overlay doesn't carry the conversation's theme
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  final paneWidth = NavigationSvc.widthChatListLeft(context);
  final colors = context.theme.colorScheme;
  _sidePanel = OverlayEntry(
    builder: (overlayContext) => Positioned(
      left: _sidePanelMargin,
      bottom: _sidePanelMargin,
      width: min(420.0, paneWidth - _sidePanelMargin * 2),
      height: min(520.0, MediaQuery.sizeOf(overlayContext).height - 80),
      child: themes.wrap(
        Material(
          color: colors.surfaceContainerHighest,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: const StickerLibraryView(onClose: _closeSidePanel),
        ),
      ),
    ),
  );
  overlay.insert(_sidePanel!);
}

void _closeSidePanel() {
  _sidePanel?.remove();
  _sidePanel = null;
}

/// The library itself: saved stickers then recents, with an add button. [onPicked], when set, makes stickers tappable.
/// Without [title] it leaves the heading to its container (the emoji tapback picker's Stickers tab). [onClose] adds a
/// close button, for the desktop panel.
class StickerLibraryView extends StatefulWidget {
  const StickerLibraryView({super.key, this.onPicked, this.title = true, this.onClose});

  final ValueChanged<LibrarySticker>? onPicked;
  final bool title;
  final VoidCallback? onClose;

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
          () =>
              widget.title ||
                  widget.onClose != null ||
                  (SettingsSvc.settings.enablePrivateAPI.value && !SubscriptionSvc.locked)
              ? _header()
              : const SizedBox.shrink(),
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
          ),
        ),
      ),
    ),
  ];
}
