import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Circular outlined download control for incoming iOS media collections.
///
/// Saves all [attachments] that are already available on disk via [AttachmentsSvc.saveToDisk].
class CollectionDownloadButton extends StatelessWidget {
  const CollectionDownloadButton({
    super.key,
    required this.attachments,
  });

  static const double size = 34.0;
  static const double gap = 30.0;

  /// Available whenever collage/stack is shown; keep skin-gated for iOS styling.
  static bool get isSupported => SettingsSvc.settings.skin.value == Skins.iOS;

  final List<Attachment> attachments;

  void _downloadAttachments() {
    for (final a in attachments) {
      final file = AttachmentsSvc.getContent(a, autoDownload: false);
      if (file is PlatformFile) {
        AttachmentsSvc.saveToDisk(file);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final outline = Theme.of(context).colorScheme.outline.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: _downloadAttachments,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: outline),
        ),
        alignment: Alignment.center,
        child: Padding(
          // Optical center: the glyph sits low in its box; shift up slightly.
          padding: const EdgeInsets.only(bottom: 1.5),
          child: Icon(
            CupertinoIcons.square_arrow_down,
            size: 17,
            color: primary,
          ),
        ),
      ),
    );
  }
}
