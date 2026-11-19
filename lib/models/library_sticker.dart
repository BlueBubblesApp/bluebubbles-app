import 'dart:math';

import 'package:flutter/foundation.dart';

/// One sticker in the server Mac's sticker library (`GET /api/v2/sticker`), metadata only.
@immutable
class LibrarySticker {
  final String identifier;

  /// `saved` (the user's sticker drawer) or `recent`
  final String shelf;
  final String? name;
  final String? accessibilityName;

  /// MIME type of the full-size image, which is what gets sent
  final String mimeType;

  /// Longest side of the full-size image in pixels, from the server's metadata: measuring the image itself fails for
  /// formats this platform can't decode, like HEIC on desktop
  final double longestSide;

  const LibrarySticker({
    required this.identifier,
    required this.shelf,
    this.name,
    this.accessibilityName,
    this.mimeType = 'image/png',
    required this.longestSide,
  });

  bool get isSaved => shelf == 'saved';

  String? get label => accessibilityName ?? name;

  /// For the upload's filename: the server reads the file type from the extension
  String get fileExtension => switch (mimeType) {
    'image/jpeg' => 'jpg',
    final m when m.startsWith('image/') => m.substring(6),
    _ => 'png',
  };

  /// Size assumed for a sticker image whose dimensions the server didn't send
  static const double fallbackPixels = 300;

  /// Throws only without an identifier; see [tryFromMap]
  factory LibrarySticker.fromMap(Map<String, dynamic> json) {
    final reps = ((json['representations'] as List?) ?? const []).whereType<Map>();
    final preferred = reps.where((r) => r['is_preferred'] == true).firstOrNull ?? reps.firstOrNull ?? const {};
    final width = preferred['width'] is num ? preferred['width'] as num : null;
    final height = preferred['height'] is num ? preferred['height'] as num : null;
    final longest = width == null || height == null ? width ?? height : max(width, height);
    return LibrarySticker(
      identifier: json['identifier'] as String,
      shelf: json['shelf'] as String? ?? 'recent',
      name: json['name'] as String?,
      accessibilityName: json['accessibility_name'] as String?,
      mimeType: preferred['mime_type'] as String? ?? 'image/png',
      longestSide: longest == null || longest <= 0 ? fallbackPixels : longest.toDouble(),
    );
  }

  /// [fromMap], or null for an entry it can't read, so one bad sticker doesn't fail a whole listing
  static LibrarySticker? tryFromMap(Object? json) {
    if (json is! Map || json['identifier'] is! String) return null;
    try {
      return LibrarySticker.fromMap(json.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// The server's shape, trimmed to what [fromMap] reads, for the on-disk cache
  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'shelf': shelf,
    'name': name,
    'accessibility_name': accessibilityName,
    'representations': [
      {'mime_type': mimeType, 'is_preferred': true, 'width': longestSide, 'height': longestSide},
    ],
  };
}
