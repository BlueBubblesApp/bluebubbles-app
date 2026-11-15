import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/sticker_library_tile.dart';
import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the server Mac's sticker library ([StickerLibrarySvc]), with a button to add an image from this device to it.
///
/// Browse-only: the desktop composer's Stickers button. Only open this when `ServerDetails.supportsStickers`.
Future<void> showStickerLibrary(BuildContext context) {
  // The cached library draws at once; this brings it up to date behind it
  unawaited(StickerLibrarySvc.sync());
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

/// The library itself: saved stickers then recents, with an add button. [onPicked], when set, makes stickers tappable.
/// Without [title] it leaves the heading to its container (the emoji tapback picker's Stickers tab).
class StickerLibraryView extends StatefulWidget {
  const StickerLibraryView({super.key, this.onPicked, this.title = true});

  final ValueChanged<LibrarySticker>? onPicked;
  final bool title;

  @override
  State<StickerLibraryView> createState() => _StickerLibraryViewState();
}

class _StickerLibraryViewState extends State<StickerLibraryView> {
  @override
  Widget build(BuildContext context) {
    final svc = StickerLibrarySvc;
    return Column(
      children: [
        if (widget.title || SettingsSvc.settings.enablePrivateAPI.value) _header(),
        Expanded(
          child: Obx(() {
            final stickers = svc.entries.toList();
            if (stickers.isEmpty) {
              if (!svc.loaded.value || svc.syncing.value) return const Center(child: CircularProgressIndicator());
              final error = svc.syncError.value;
              if (error != null) return _message(error, learnMoreUrl: svc.syncErrorUrl.value);
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
        if (SettingsSvc.settings.enablePrivateAPI.value)
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
      ],
    ),
  );

  Widget _message(String text, {String? learnMoreUrl}) => Center(
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
          if (learnMoreUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse(learnMoreUrl), mode: LaunchMode.externalApplication),
                child: const Text("Learn More"),
              ),
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
