import 'package:flutter/foundation.dart';

@immutable
class LocationAttachmentData {
  final String guid;
  final String fileName;
  final Uint8List bytes;

  /// Preview image for the location, when Apple Maps supplied one. Null is a
  /// normal outcome — the location is still sendable without a thumbnail.
  final String? mapImageUrl;

  final String? title;

  const LocationAttachmentData({
    required this.guid,
    required this.fileName,
    required this.bytes,
    this.mapImageUrl,
    this.title,
  });
}
