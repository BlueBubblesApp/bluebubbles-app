import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/network/api/sticker_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Picks an image on this device and adds it to the Mac's sticker library, where it lands in Recents. A refusal shows
/// the server's reason.
Future<void> pickAndAddSticker() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return;
  try {
    await StickerLibrarySvc.add(await file.readAsBytes(), file.name);
  } catch (e, s) {
    Logger.warn("Failed to add a sticker to the library", error: e, trace: s, tag: "StickerLibrary");
    showSnackbar("Error", stickerRefusal(e).message ?? "Couldn't add the sticker", type: SnackbarType.error);
  }
}

/// Whether stickers can be removed from the Mac's library here: the server's Private API does it.
bool get canRemoveStickers => SettingsSvc.settings.enablePrivateAPI.value && !SubscriptionSvc.locked;

/// Asks, then removes [sticker] from the Mac's library. A refusal shows the server's reason.
Future<void> confirmRemoveSticker(BuildContext context, LibrarySticker sticker) async {
  final confirmed = Completer<bool>();
  await showAreYouSure(
    context,
    title: "Remove Sticker?",
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (StickerLibrarySvc.cachedThumbnails.contains(sticker.identifier)) ...[
          Image.file(StickerLibrarySvc.thumbnailFile(sticker.identifier), width: 88, height: 88),
          const SizedBox(height: 12),
        ],
        const Text("This sticker will be removed from your Mac's stickers.", textAlign: TextAlign.center),
      ],
    ),
    noText: "Cancel",
    yesText: "Remove",
    yesIsDestructive: true,
    yesColor: context.theme.colorScheme.error,
    onNo: () {
      Navigator.of(context, rootNavigator: true).pop();
      confirmed.complete(false);
    },
    onYes: () {
      Navigator.of(context, rootNavigator: true).pop();
      confirmed.complete(true);
    },
  );
  // Dismissed by tapping outside: neither button ran
  if (!confirmed.isCompleted || !await confirmed.future) return;
  try {
    await StickerLibrarySvc.delete(sticker);
  } catch (e, s) {
    Logger.warn("Failed to remove a sticker from the library", error: e, trace: s, tag: "StickerLibrary");
    showSnackbar("Couldn't Remove Sticker", stickerRefusal(e).message ?? "Couldn't reach your server to remove it.",
        type: SnackbarType.error);
  }
}

/// One sticker from the Mac's library, drawn from the on-disk thumbnail cache ([StickerLibrarySvc]), with a
/// placeholder until it's there. Long press, or right-click, offers to remove it ([confirmRemoveSticker]) where that's
/// possible.
class StickerLibraryTile extends StatelessWidget {
  const StickerLibraryTile({super.key, required this.sticker, this.onTap});

  final LibrarySticker sticker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final placeholder = Center(
      child: Icon(Icons.sticky_note_2_outlined, size: 28, color: scheme.outline.withValues(alpha: 0.4)),
    );
    return Semantics(
      button: onTap != null,
      label: sticker.label ?? "Sticker",
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: canRemoveStickers ? () => confirmRemoveSticker(context, sticker) : null,
          onSecondaryTap: canRemoveStickers ? () => confirmRemoveSticker(context, sticker) : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Obx(
              () => StickerLibrarySvc.cachedThumbnails.contains(sticker.identifier)
                  ? Image.file(
                      StickerLibrarySvc.thumbnailFile(sticker.identifier),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => placeholder,
                    )
                  : placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds an image from this device to the library ([pickAndAddSticker]), with a spinner while it uploads.
class StickerAddTile extends StatelessWidget {
  const StickerAddTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Semantics(
      button: true,
      label: "Add a sticker from this device",
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
          ),
          child: Obx(() {
            final adding = StickerLibrarySvc.adding.value;
            return InkWell(
              onTap: adding ? null : pickAndAddSticker,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  adding
                      ? CupertinoActivityIndicator(color: scheme.onPrimary)
                      : Icon(Icons.add_photo_alternate_rounded, color: scheme.onPrimary, size: 30),
                  const SizedBox(height: 6),
                  Text("Add", style: context.theme.textTheme.labelLarge!.copyWith(color: scheme.onPrimary)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
