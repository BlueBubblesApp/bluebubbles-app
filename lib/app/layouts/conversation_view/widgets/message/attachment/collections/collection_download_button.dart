import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Circular download control for incoming iOS media collections.
class CollectionDownloadButton extends StatelessWidget {
  const CollectionDownloadButton({
    super.key,
    required this.attachments,
  });

  static const double size = 34.0;
  static const double gap = 24.0;

  static bool get isSupported => CurrentSkin.iOS;

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

  /// Saves [attachments] to the device via [AttachmentsService.saveAllToDisk], confirming first when there's more
  /// than one, so a stray tap can't start a mass download.
  ///
  /// Skips the confirmation when the save itself asks for a destination folder
  /// ([AttachmentsService.batchSaveAsksForFolder]): that picker already lets the user back out, and asking twice
  /// is noise.
  static void download(BuildContext context, Iterable<Attachment> attachments) {
    final list = attachments.toList();
    void save() => AttachmentsSvc.saveAllToDisk(list);

    final count = list.length;
    if (count <= 1 || AttachmentsSvc.batchSaveAsksForFolder) return save();
    showAreYouSure(
      context,
      title: "Download $count items?",
      noText: "Cancel",
      yesText: "Download",
      onNo: () => Navigator.of(context, rootNavigator: true).pop(),
      onYes: () {
        Navigator.of(context, rootNavigator: true).pop();
        save();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.theme.colorScheme.primary;
    final outline = context.theme.colorScheme.outline.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: () => download(context, attachments),
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
