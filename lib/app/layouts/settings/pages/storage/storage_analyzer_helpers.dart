import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared segment presentation config (label/icon) and byte formatting, mixed
/// into every skin's storage analyzer widgets so presentation stays in one
/// place. Same split as `IMessageStatsHelpersMixin`.
mixin StorageAnalyzerHelpersMixin {
  static const Map<StorageSegmentType, ({String label, IconData iosIcon, IconData materialIcon})> segmentConfig = {
    StorageSegmentType.photos: (label: 'Photos', iosIcon: CupertinoIcons.photo, materialIcon: Icons.image_outlined),
    StorageSegmentType.videos: (
      label: 'Videos',
      iosIcon: CupertinoIcons.videocam,
      materialIcon: Icons.videocam_outlined,
    ),
    StorageSegmentType.audio: (
      label: 'Audio',
      iosIcon: CupertinoIcons.waveform,
      materialIcon: Icons.audiotrack_outlined,
    ),
    StorageSegmentType.documents: (
      label: 'Documents',
      iosIcon: CupertinoIcons.doc,
      materialIcon: Icons.description_outlined,
    ),
    StorageSegmentType.other: (
      label: 'Other',
      iosIcon: CupertinoIcons.doc_on_doc,
      materialIcon: Icons.insert_drive_file_outlined,
    ),
    StorageSegmentType.thumbnailsAndConversions: (
      label: 'Thumbnails & Cache',
      iosIcon: CupertinoIcons.timer,
      materialIcon: Icons.cached_outlined,
    ),
    StorageSegmentType.orphaned: (
      label: 'Orphaned Files',
      iosIcon: CupertinoIcons.trash,
      materialIcon: Icons.delete_sweep_outlined,
    ),
  };

  /// Segment color, derived from the *currently selected* theme's
  /// `ColorScheme` rather than fixed named colors — so a custom accent/theme
  /// picked in Theme Studio is reflected in the chart and progress bars too.
  /// `thumbnailsAndConversions` reuses a lightened/darkened `primary` (via
  /// `themeLightenOrDarken`) rather than a sixth container color, since
  /// container tones read as too washed-out for a chart swatch.
  Color colorFor(BuildContext context, StorageSegmentType type) {
    final cs = context.theme.colorScheme;
    return switch (type) {
      StorageSegmentType.photos => cs.primary,
      StorageSegmentType.videos => cs.secondary,
      StorageSegmentType.audio => cs.tertiary,
      StorageSegmentType.documents => cs.outline,
      StorageSegmentType.other => cs.outlineVariant,
      StorageSegmentType.thumbnailsAndConversions => cs.primary.themeLightenOrDarken(context, 20),
      StorageSegmentType.orphaned => cs.error,
    };
  }

  /// Binary (1024-based), correct bytes→TB tiers. Deliberately not reusing
  /// `double.getFriendlySize()` (extensions.dart:171) — that helper divides
  /// by a mixed 1024000 base and has no B or TB tier. Fixing it in place
  /// would shift numbers on every other screen that calls it.
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    var i = -1;
    do {
      size /= 1024;
      i++;
    } while (size >= 1024 && i < units.length - 1);
    return '${size.toStringAsFixed(size < 10 ? 2 : 1)} ${units[i]}';
  }
}
