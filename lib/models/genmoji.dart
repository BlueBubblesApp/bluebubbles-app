import 'dart:convert';

import 'package:flutter/foundation.dart';

/// `GET /api/v2/genmoji/status`: whether this server's Mac can generate a Genmoji right now.
///
/// [reason] is a stable word to branch on (`available`, `release_too_old`, `needs_app`,
/// `withdrawn`, `apple_intelligence_unavailable`, `device_not_eligible`,
/// `unsupported_language`, `undetermined`); [detail] is the sentence to show the user, null
/// when [available].
@immutable
class GenmojiSupport {
  final bool available;
  final String reason;
  final String? detail;
  final int maximumDescriptionLength;

  const GenmojiSupport({
    required this.available,
    required this.reason,
    this.detail,
    this.maximumDescriptionLength = defaultMaximumDescriptionLength,
  });

  static const int defaultMaximumDescriptionLength = 500;

  factory GenmojiSupport.fromMap(Map<String, dynamic> json) => GenmojiSupport(
    available: json['available'] == true,
    reason: json['reason'] as String? ?? 'undetermined',
    detail: json['detail'] as String?,
    maximumDescriptionLength: (json['maximum_description_length'] as num?)?.toInt() ?? defaultMaximumDescriptionLength,
  );
}

/// One image from `POST /api/v2/genmoji` or `POST /api/v2/genmoji/library/images`, sent
/// inline as base64.
///
/// A freshly created one carries [filePath] (where the server staged it in its upload store);
/// one read from the library carries its library [identifier].
@immutable
class GenmojiImage {
  final Uint8List png;
  final String? filePath;
  final String? identifier;
  final int width;
  final int height;

  const GenmojiImage({required this.png, this.filePath, this.identifier, required this.width, required this.height});

  factory GenmojiImage.fromMap(Map<String, dynamic> json) => GenmojiImage(
    png: base64Decode(json['data'] as String),
    filePath: json['file_path'] as String?,
    identifier: json['identifier'] as String?,
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
  );
}

/// One Genmoji in the server Mac's library (`GET /api/v2/genmoji/library`).
///
/// The Mac's library is the sticker store Messages' own picker shows, synced through iCloud,
/// so this is the same set the user sees on their other Apple devices. Metadata only: the
/// images are separate requests, by [identifier], and are cached on disk by
/// `GenmojiLibraryService`.
@immutable
class GenmojiLibraryEntry {
  /// The content identifier a sent Genmoji carries; what the image and delete routes take.
  final String identifier;

  /// The prompt as Image Playground condensed it — what VoiceOver reads.
  final String description;
  final String? language;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  /// The stored sizes, in pixels, smallest first.
  final List<int> sizes;

  const GenmojiLibraryEntry({
    required this.identifier,
    required this.description,
    this.language,
    this.createdAt,
    this.lastUsedAt,
    this.sizes = const [],
  });

  int? get largestSize => sizes.isEmpty ? null : sizes.reduce((a, b) => a > b ? a : b);

  factory GenmojiLibraryEntry.fromMap(Map<String, dynamic> json) => GenmojiLibraryEntry(
    identifier: json['identifier'] as String,
    description: json['description'] as String? ?? '',
    language: json['language'] as String?,
    createdAt: _date(json['created_at']),
    lastUsedAt: _date(json['last_used_at']),
    sizes: ((json['sizes'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
  );

  /// Same keys as the server sends, so the on-disk cache reads back through [fromMap].
  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'description': description,
    'language': language,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'last_used_at': lastUsedAt?.millisecondsSinceEpoch,
    'sizes': sizes,
  };

  static DateTime? _date(dynamic value) => value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;
}

/// One page of `GET /api/v2/genmoji/library`.
///
/// [reason] is set (and [entries] empty) when the Mac's sticker store can't be read or its
/// macOS keeps no Genmoji. [entityTag] is the response's `ETag`: send it back to get a 304
/// while the library is unchanged.
@immutable
class GenmojiLibraryPage {
  final List<GenmojiLibraryEntry> entries;
  final int total;
  final String? revision;
  final String? reason;
  final String? entityTag;

  const GenmojiLibraryPage({required this.entries, required this.total, this.revision, this.reason, this.entityTag});
}

/// `POST /api/v2/genmoji/library/images`: the images found, and the identifiers that named
/// nothing (deleted since the last listing).
typedef GenmojiLibraryImages = ({List<GenmojiImage> images, List<String> missing});

/// Thrown by the Genmoji API when the server refuses a request. [message] is the sentence to
/// show the user; [reason] is the server's stable word (`creation_failed`, `no_answer`,
/// `no_image`, a status `reason`, or a subscription refusal), when it sent one.
class GenmojiException implements Exception {
  final String message;
  final String? reason;
  final int? statusCode;

  const GenmojiException(this.message, {this.reason, this.statusCode});

  @override
  String toString() => message;
}
