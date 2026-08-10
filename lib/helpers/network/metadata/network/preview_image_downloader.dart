import 'package:bluebubbles/helpers/network/metadata/models/metadata_fetch_result.dart';
import 'package:bluebubbles/helpers/network/metadata/network/metadata_http_client.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:bluebubbles/services/backend/interfaces/image_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/file_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;
import 'package:universal_io/io.dart';

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

  /// In-flight downloads, keyed by URL, so concurrent callers share one
  /// request. [MetadataMemoryCache] already does this for metadata; without the
  /// same here, the same image is fetched once per widget asking for it.
  ///
  /// More than one widget asking is the normal case, not an edge case: the
  /// message popup renders a **second copy** of the bubble against the same
  /// `MessageState`, so a long-press — and every "Refresh Preview", which is
  /// dispatched while that copy is still mounted — runs two identical loads.
  /// Two different messages linking the same og:image scrolling into view
  /// together lands here too.
  final Map<String, Future<CachedPreviewImage?>> _inFlight = {};

  /// URLs that failed for a reason a retry cannot change, and when that
  /// verdict expires. See [failureTtl].
  ///
  /// Only *permanent* failures land here. A timeout or a 5xx is left out
  /// deliberately, so a preview that failed because the network was down still
  /// loads once it comes back.
  final Map<String, DateTime> _permanentFailures = {};

  /// Anything smaller in either dimension is a spacer, a bullet or a tracking
  /// pixel rather than a preview.
  static const int minDimension = 16;

  /// A body this small cannot be a real image.
  static const int minBytes = 128;

  /// How long a *permanent* failure is remembered.
  ///
  /// Without this, a URL that can never produce an image is re-requested every
  /// time a card is built — and cards are built constantly: scrolling one into
  /// view, opening the message popup (which renders a second copy of the
  /// bubble), and every "Refresh Preview". The metadata fetch has had a retry
  /// TTL all along; the image download did not, so a dead icon cost a full
  /// round trip per build, forever.
  ///
  /// The common case this exists for is [IconParser]'s `/favicon.ico` guess:
  /// when a page declares no usable icon the parser falls back to that path,
  /// and plenty of sites answer it with their SPA shell as `text/html`, 200.
  static const Duration failureTtl = Duration(hours: 1);

  /// Upper bound on remembered failures, so a long session cannot grow this
  /// without limit.
  static const int _maxFailureEntries = 256;

  /// Formats the `Image` widget cannot decode, and that this downloader has no
  /// conversion path for either. SVG in particular is common for favicons and
  /// would render as a permanent error box.
  static const Set<String> unsupportedMimeTypes = {
    'image/svg+xml',
    'image/heic',
    'image/heif',
    'image/avif',
  };

  /// Formats the `Image` widget cannot decode but that [ImageInterface] can —
  /// converted to PNG in [_convert] before anything else runs, so every check
  /// after that point (dimensions, the disk cache, `_optimize`) sees a normal
  /// PNG and needs no format-specific handling of its own.
  static const Set<String> _convertibleMimeTypes = {
    'image/x-icon',
    'image/vnd.microsoft.icon',
  };

  /// Longest side an optimised preview image is resized down to.
  ///
  /// Mirrors `AttachmentsSvc`'s base, and for the same reason: an og:image is
  /// routinely 1200x630 or larger, but a link card draws it at a few hundred
  /// logical points. Without this the full bitmap is decoded and held in
  /// Flutter's image cache for every preview on screen.
  static const int optimizedMaxDimension = 1080;

  /// JPEG quality for the re-encode. High enough that the result is
  /// indistinguishable at card size.
  static const int optimizedQuality = 85;

  /// Formats that must not be re-encoded even when oversized.
  ///
  /// GIF because `img.decodeImage` returns the first frame only, so a re-encode
  /// silently kills the animation. PNG because JPEG has no alpha, and a
  /// transparent og:image would gain a black background.
  static const Set<String> _doNotReencodeMimeTypes = {'image/gif', 'image/png', 'image/apng'};

  /// Downloads [imageUrl], validates it, and stores it in the shared preview
  /// cache. Returns null when the image is unusable for any reason.
  ///
  /// Set [optimize] for the card's hero image, which is the one that is large
  /// enough to be worth downsampling. Icons are left alone: a favicon is
  /// already tiny, and re-encoding one as JPEG would flatten its alpha.
  ///
  /// Keyed by [imageUrl] **alone**, deliberately — not by `'$imageUrl|$optimize'`.
  /// Both variants resolve to the same file, because the cache path is a digest
  /// of the downloaded bytes and [_optimize] renames its result over that same
  /// path. Keying on [optimize] as well let a hero and an icon download of one
  /// URL run concurrently and race to write it, with the loser reporting
  /// pre-resize dimensions for a file that had already been downsampled.
  ///
  /// The consequence is that when a page uses one URL for both its `og:image`
  /// and its icon, whichever request arrives first decides whether the shared
  /// file gets downsampled. That is safe in practice: [_optimize] already skips
  /// the formats an icon cares about (PNG/APNG keep their alpha, GIF keeps its
  /// frames) and anything already within [optimizedMaxDimension], which a
  /// favicon always is.
  Future<CachedPreviewImage?> download(String imageUrl, {bool optimize = false}) {
    if (kIsWeb) return Future.value();

    if (_isKnownBad(imageUrl)) {
      Logger.debug('Skipping $imageUrl; a previous attempt failed permanently', tag: 'PreviewImage');
      return Future.value();
    }

    final pending = _inFlight[imageUrl];
    if (pending != null) {
      Logger.debug('Joining in-flight download for $imageUrl', tag: 'PreviewImage');
      return pending;
    }

    final future = _download(imageUrl, optimize: optimize);
    _inFlight[imageUrl] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[imageUrl], future)) _inFlight.remove(imageUrl);
    });
  }

  /// The actual fetch, validation and caching. Always reached through
  /// [download], which collapses concurrent callers onto one of these.
  Future<CachedPreviewImage?> _download(String imageUrl, {bool optimize = false}) async {
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
        return _reject(imageUrl, 'exceeded the ${MetadataHttpClient.maxImageBytes ~/ (1024 * 1024)}MB size cap');
      }

      final mime = resource.contentType?.split(';').first.trim().toLowerCase();
      if (mime != null && unsupportedMimeTypes.contains(mime)) {
        return _reject(imageUrl, 'content type $mime cannot be decoded');
      }

      var bytes = resource.bytes;
      // Converted up front so every check below — the size floor, the
      // dimension floor, the disk cache, [_optimize] — runs against ordinary
      // PNG bytes and never needs to know ICO was ever involved.
      var effectiveMime = mime;
      if (mime != null && _convertibleMimeTypes.contains(mime)) {
        final converted = await ImageInterface.convertIcoToPng(bytes);
        if (converted == null) {
          return _reject(imageUrl, 'content type $mime failed to decode');
        }
        bytes = converted;
        effectiveMime = 'image/png';
      }

      if (bytes.length < minBytes) {
        return _reject(imageUrl, 'body of ${bytes.length}B is too small to be an image');
      }

      final size = _dimensions(bytes);
      if (size != null && (size.$1 < minDimension || size.$2 < minDimension)) {
        return _reject(imageUrl, '${size.$1}x${size.$2} is likely a tracking pixel');
      }

      final hash = await FilesystemSvc.saveUrlPreviewImage(Uint8List.fromList(bytes));
      final path = FilesystemSvc.urlPreviewImagePath(hash);

      final optimized = optimize ? await _optimize(path, mime: effectiveMime, size: size) : null;

      return CachedPreviewImage(
        path: path,
        hash: hash,
        fromDisk: false,
        width: optimized?.$1 ?? size?.$1,
        height: optimized?.$2 ?? size?.$2,
      );
    } on MetadataFetchException catch (ex) {
      // Reuses the fetch layer's own verdict rather than re-deriving it, so
      // "which failures are worth retrying" is defined in exactly one place.
      final retryable = MetadataFetchResult.failure(ex.status, httpStatusCode: ex.httpStatusCode).isRetryable;
      if (retryable) {
        // No stack trace: a transient network failure is expected and the
        // trace is always the same 25 frames of this pipeline.
        Logger.debug('Preview image $imageUrl failed (${ex.status.name}, retryable)', tag: 'PreviewImage');
        return null;
      }
      return _reject(imageUrl, '${ex.status.name}${ex.httpStatusCode != null ? ' (HTTP ${ex.httpStatusCode})' : ''}');
    } catch (ex, stack) {
      // An unexpected error genuinely is worth a trace — but it is not a
      // verdict about the URL, so it is not remembered.
      Logger.warn('Unexpected error downloading preview image $imageUrl',
          error: ex, trace: stack, tag: 'PreviewImage');
      return null;
    }
  }

  /// Records [imageUrl] as permanently unusable and returns null.
  ///
  /// Logged without a stack trace on purpose: every one of these is an ordinary
  /// property of the remote resource, not a fault in this code, and the trace
  /// is identical every time.
  CachedPreviewImage? _reject(String imageUrl, String reason) {
    Logger.debug('Discarding preview image $imageUrl: $reason', tag: 'PreviewImage');

    if (_permanentFailures.length >= _maxFailureEntries) {
      _permanentFailures.removeWhere((_, expiry) => DateTime.now().isAfter(expiry));
      // Still full of live entries — drop the one closest to expiring.
      if (_permanentFailures.length >= _maxFailureEntries) {
        final oldest = _permanentFailures.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b);
        _permanentFailures.remove(oldest.key);
      }
    }

    _permanentFailures[imageUrl] = DateTime.now().add(failureTtl);
    return null;
  }

  /// Whether [imageUrl] is inside its [failureTtl] after a permanent failure.
  bool _isKnownBad(String imageUrl) {
    final expiry = _permanentFailures[imageUrl];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _permanentFailures.remove(imageUrl);
      return false;
    }
    return true;
  }

  /// Forgets every remembered failure, so the next request retries for real.
  ///
  /// Called when the user explicitly asks for a refresh — a deliberate action
  /// should not be answered out of a negative cache.
  void clearFailures() => _permanentFailures.clear();

  /// Shrinks an oversized cached preview image in place, returning its new
  /// dimensions, or null when it was left untouched.
  ///
  /// Runs through [ImageInterface.generatePreview] — the same isolate action
  /// `AttachmentsSvc` uses for inline attachment previews — rather than a
  /// second downsampling implementation. That also means EXIF orientation is
  /// baked into the pixels and the tag dropped, so the file on disk is always
  /// upright and nothing downstream may re-apply a rotation.
  ///
  /// Skipped for anything already within [optimizedMaxDimension], and for the
  /// formats in [_doNotReencodeMimeTypes]. Failure is not an error: the
  /// original file is already on disk and perfectly renderable, so the worst
  /// case is a preview that is merely bigger than it needed to be.
  ///
  /// Note the cache hash stays a digest of the **downloaded** bytes, not of
  /// what ends up on disk. That is deliberate — it keeps two messages linking
  /// the same og:image on one cache entry regardless of what the resize did.
  Future<(int, int)?> _optimize(String path, {String? mime, (int, int)? size}) async {
    if (mime != null && _doNotReencodeMimeTypes.contains(mime)) return null;
    if (size == null) return null;

    final longestSide = size.$1 > size.$2 ? size.$1 : size.$2;
    if (longestSide <= optimizedMaxDimension) return null;

    // Write beside the target and rename in, so a kill mid-write cannot leave a
    // truncated file that exists() would then accept forever. `.jpg` stays last
    // for the benefit of any format-validating encoder in the chain.
    final tempPath = '$path.tmp.jpg';
    try {
      final ok = await ImageInterface.generatePreview(
        path: path,
        outputPath: tempPath,
        maxDimension: optimizedMaxDimension,
        quality: optimizedQuality,
      );
      if (!ok) return null;
      await moveFile(File(tempPath), path);
    } catch (ex, stack) {
      Logger.debug('Failed to downsample preview image: $ex', error: ex, trace: stack, tag: 'PreviewImage');
      try {
        final temp = File(tempPath);
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      return null;
    }

    final scale = optimizedMaxDimension / longestSide;
    return ((size.$1 * scale).round(), (size.$2 * scale).round());
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
