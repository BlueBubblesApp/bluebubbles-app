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

/// One sticker from the Mac's library, drawn from the on-disk thumbnail cache ([StickerLibrarySvc]), with a
/// placeholder until it's there.
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
