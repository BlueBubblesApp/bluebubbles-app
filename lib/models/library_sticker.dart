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

  const LibrarySticker({
    required this.identifier,
    required this.shelf,
    this.name,
    this.accessibilityName,
    this.mimeType = 'image/png',
  });

  bool get isSaved => shelf == 'saved';

  String? get label => accessibilityName ?? name;

  /// For the upload's filename: the server reads the file type from the extension
  String get fileExtension => switch (mimeType) {
    'image/jpeg' => 'jpg',
    final m when m.startsWith('image/') => m.substring(6),
    _ => 'png',
  };

  factory LibrarySticker.fromMap(Map<String, dynamic> json) {
    final reps = ((json['representations'] as List?) ?? const []).whereType<Map>();
    final preferred = reps.where((r) => r['is_preferred'] == true).firstOrNull ?? reps.firstOrNull;
    return LibrarySticker(
      identifier: json['identifier'] as String,
      shelf: json['shelf'] as String? ?? 'recent',
      name: json['name'] as String?,
      accessibilityName: json['accessibility_name'] as String?,
      mimeType: preferred?['mime_type'] as String? ?? 'image/png',
    );
  }

  /// The server's shape, trimmed to what [fromMap] reads, for the on-disk cache
  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'shelf': shelf,
    'name': name,
    'accessibility_name': accessibilityName,
    'representations': [
      {'mime_type': mimeType, 'is_preferred': true},
    ],
  };
}
