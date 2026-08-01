import 'dart:typed_data';

import 'package:bluebubbles/helpers/network/metadata/network/metadata_http_client.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;

/// A validated, disk-cached preview image.
@immutable
class CachedPreviewImage {
  const CachedPreviewImage({
    required this.path,
    required this.hash,
    required this.fromDisk,
    this.width,
    this.height,
  });

  /// Absolute path to the cached file.
  final String path;

  /// SHA-256 of the image bytes, which is also the filename. Persisted on the
  /// message so the same image is shared across every message that links it.
  final String hash;

  /// True when the file was already on disk, so the UI can skip the grow-in
  /// animation.
  final bool fromDisk;

  final int? width;
  final int? height;
}

/// Downloads preview images with validation before anything touches disk.
///
/// The old path wrote whatever bytes came back, which meant a 1x1 tracking
/// pixel or an `og:video` URL that happened to resolve was cached and then
/// rendered as "Failed to display image". Validating here also lets the
/// hardcoded `renderTimingPixel.png` / `fls-na.amazon.com` blocklists go away:
/// a tracking pixel fails the dimension check no matter who serves it.
class PreviewImageDownloader {
  PreviewImageDownloader(this._client);

  final MetadataHttpClient _client;

  /// Anything smaller in either dimension is a spacer, a bullet or a tracking
  /// pixel rather than a preview.
  static const int minDimension = 32;

  /// A body this small cannot be a real image.
  static const int minBytes = 128;

  /// Formats the `Image` widget cannot decode. SVG in particular is common for
  /// favicons and would render as a permanent error box.
  static const Set<String> unsupportedMimeTypes = {
    'image/svg+xml',
    'image/x-icon',
    'image/vnd.microsoft.icon',
    'image/heic',
    'image/heif',
    'image/avif',
  };

  /// Downloads [imageUrl], validates it, and stores it in the shared preview
  /// cache. Returns null when the image is unusable for any reason.
  Future<CachedPreviewImage?> download(String imageUrl) async {
    if (kIsWeb) return null;

    final uri = MetadataUrls.parse(imageUrl);
    if (uri == null) return null;

    // Host safety is enforced inside [MetadataHttpClient] for every hop, so
    // preview images — which come straight out of attacker-influenced markup
    // and may redirect — get the same treatment as the page itself.
    try {
      final resource = await _client.fetch(
        uri,
        maxBytes: MetadataHttpClient.maxImageBytes,
        accept: const {FetchedContentKind.image},
      );

      if (resource.truncated) {
        Logger.debug('Preview image exceeded the size cap: $imageUrl', tag: 'PreviewImage');
        return null;
      }

      final mime = resource.contentType?.split(';').first.trim().toLowerCase();
      if (mime != null && unsupportedMimeTypes.contains(mime)) return null;

      final bytes = resource.bytes;
      if (bytes.length < minBytes) return null;

      final size = _dimensions(bytes);
      if (size != null && (size.$1 < minDimension || size.$2 < minDimension)) {
        Logger.debug('Discarding ${size.$1}x${size.$2} preview image (likely a tracking pixel): $imageUrl',
            tag: 'PreviewImage');
        return null;
      }

      final hash = await FilesystemSvc.saveUrlPreviewImage(Uint8List.fromList(bytes));
      return CachedPreviewImage(
        path: FilesystemSvc.urlPreviewImagePath(hash),
        hash: hash,
        fromDisk: false,
        width: size?.$1,
        height: size?.$2,
      );
    } catch (ex, stack) {
      Logger.debug('Failed to download preview image $imageUrl: $ex', error: ex, trace: stack, tag: 'PreviewImage');
      return null;
    }
  }

  /// Reads the intrinsic size from the image header without decoding pixels.
  ///
  /// Returns null for formats `image_size_getter` does not recognise, in which
  /// case the dimension check is skipped rather than failing the image.
  (int, int)? _dimensions(Uint8List bytes) {
    try {
      final size = isg.ImageSizeGetter.getSizeResult(isg.MemoryInput(bytes)).size;
      if (size.width <= 0 || size.height <= 0) return null;
      return (size.width, size.height);
    } catch (_) {
      return null;
    }
  }
}
