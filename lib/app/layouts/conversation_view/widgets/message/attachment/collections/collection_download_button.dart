import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Circular download control for incoming iOS media collections.
class CollectionDownloadButton extends StatelessWidget {
  const CollectionDownloadButton({
    super.key,
    required this.attachments,
  });

  static const double size = 34.0;
  static const double gap = 24.0;

  static bool get isSupported => SettingsSvc.settings.skin.value == Skins.iOS;

  /// Places [child] beside the download control for incoming iOS collections.
  /// Returns [child] unchanged when from-me or skin unsupported.
  static Widget wrap({
    required bool isFromMe,
    required double contentWidth,
    required List<Attachment> attachments,
    required Widget child,
    double? contentHeight,
  }) {
    if (isFromMe || !isSupported) return child;
    return SizedBox(
      width: contentWidth + gap + size,
      height: contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: contentWidth + gap,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.center,
              child: CollectionDownloadButton(attachments: attachments),
            ),
          ),
          child,
        ],
      ),
    );
  }

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
