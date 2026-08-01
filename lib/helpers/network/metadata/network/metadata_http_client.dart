import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/network/metadata/models/metadata_fetch_result.dart';
import 'package:bluebubbles/helpers/network/metadata/network/url_safety_guard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// What kind of resource a response body holds.
enum FetchedContentKind {
  html,
  image,
  json,

  /// Anything we cannot extract metadata from (PDF, video, archive...).
  unsupported;

  static FetchedContentKind fromContentType(String? contentType) {
    if (contentType == null) return FetchedContentKind.unsupported;
    final mime = contentType.split(';').first.trim().toLowerCase();

    if (mime == 'text/html' || mime == 'application/xhtml+xml' || mime == 'application/xml' || mime == 'text/xml') {
      return FetchedContentKind.html;
    }
    if (mime.startsWith('image/')) return FetchedContentKind.image;
    if (mime == 'application/json' || mime.endsWith('+json')) return FetchedContentKind.json;
    return FetchedContentKind.unsupported;
  }
}

/// A capped, decoded response.
@immutable
class FetchedResource {
  const FetchedResource({
    required this.bytes,
    required this.statusCode,
    required this.finalUri,
    required this.contentType,
    required this.kind,
    required this.truncated,
  });

  final Uint8List bytes;
  final int statusCode;

  /// The URL the request landed on after redirects.
  final Uri finalUri;

  final String? contentType;
  final FetchedContentKind kind;

  /// True when the body hit the size cap and was cut short. Harmless for
  /// HTML — everything we parse lives in `<head>` — but means an image is
  /// unusable.
  final bool truncated;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Thrown internally to carry a specific failure status out of the client.
class MetadataFetchException implements Exception {
  MetadataFetchException(this.status, {this.httpStatusCode, this.cause});

  final MetadataFetchStatus status;
  final int? httpStatusCode;
  final Object? cause;

  @override
  String toString() => 'MetadataFetchException(${status.name}, http: $httpStatusCode, cause: $cause)';
}

/// The HTTP client used for third-party metadata fetches.
///
/// Deliberately **not** `HttpSvc.dio`. That instance is configured for the
/// BlueBubbles server and carries two things that must never reach an
/// arbitrary website:
///
///  * the user's `customHeaders` (Cloudflare Access secrets, reverse-proxy
///    tokens, basic auth) applied as default headers on every request;
///  * `ApiInterceptor`, which resolves HTTP errors and timeouts into synthetic
///    success responses. That is correct for the server API and catastrophic
///    here — it made real failures look like successes, so the fallback path
///    never ran and transient errors were cached permanently.
class MetadataHttpClient {
  MetadataHttpClient({
    Dio? dio,
    this.connectTimeout = const Duration(seconds: 8),
    this.receiveTimeout = const Duration(seconds: 10),
    this.maxRedirects = 5,
  }) : _dio = dio ?? _buildDio(connectTimeout, receiveTimeout, maxRedirects);

  final Dio _dio;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxRedirects;

  /// Metadata lives in `<head>`; there is no reason to pull down a multi-
  /// megabyte page to read it.
  static const int maxHtmlBytes = 512 * 1024;

  /// Upper bound for a preview image download.
  static const int maxImageBytes = 8 * 1024 * 1024;

  /// oEmbed and similar JSON payloads are tiny.
  static const int maxJsonBytes = 128 * 1024;

  /// Identifies the app as a link-preview crawler.
  ///
  /// The old code sent either Dart's default `Dart/3.x (dart:io)` — which most
  /// large sites answer with a 403 or a JavaScript shell — or a Google+
  /// snippet-fetcher string for a service that was shut down in 2019. Sites
  /// recognise and serve Open Graph tags to the Facebook crawler string, and
  /// the appended product token keeps us honest about who is actually asking.
  static const String userAgent =
      'Mozilla/5.0 (compatible; facebookexternalhit/1.1; +http://www.facebook.com/externalhit_uatext.php) '
      'BlueBubbles/1.0 (+https://bluebubbles.app)';

  static Dio _buildDio(Duration connectTimeout, Duration receiveTimeout, int maxRedirects) {
    return Dio(BaseOptions(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: connectTimeout,
      // Redirects are followed by hand in [fetch] so that [UrlSafetyGuard] can
      // vet every hop. Letting dio follow them internally means only the first
      // URL is ever checked, and a public URL can 302 into the user's LAN.
      followRedirects: false,
      // Report the real status instead of throwing, so the caller can tell a
      // retryable 503 from a permanent 404 — and so 3xx reaches the redirect
      // handling below rather than surfacing as an error.
      validateStatus: (_) => true,
      headers: const {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/*;q=0.8,*/*;q=0.7',
        'Accept-Language': 'en-US,en;q=0.9',
        // gzip only: it is the one encoding the platform HTTP client inflates
        // transparently. Advertising deflate/br/zstd would get us a body the
        // parser sees as binary noise.
        'Accept-Encoding': 'gzip',
      },
    ));
  }

  /// Status codes that carry a `Location` header.
  static const Set<int> _redirectCodes = {301, 302, 303, 307, 308};

  /// Fetches [uri], reading at most [maxBytes] of the body.
  ///
  /// Redirects are followed manually so that [UrlSafetyGuard] runs against
  /// **every** hop. This is the only place the guard is applied, which means it
  /// covers the page fetch, the oEmbed endpoint discovered from page markup,
  /// preview image downloads, and every redirect in between.
  ///
  /// Throws [MetadataFetchException] with a specific status for every failure
  /// mode so the orchestrator can decide whether the attempt is retryable.
  Future<FetchedResource> fetch(
    Uri uri, {
    required int maxBytes,
    Set<FetchedContentKind>? accept,
  }) async {
    var current = uri;
    final visited = <String>{};

    for (var hop = 0; hop <= maxRedirects; hop++) {
      final blocked = await UrlSafetyGuard.checkResolved(current);
      if (blocked != null) throw MetadataFetchException(blocked);

      // A fresh token per hop: aborting one hop's body must not poison the
      // next request.
      final token = CancelToken();

      Response<ResponseBody> response;
      try {
        response = await _dio.getUri<ResponseBody>(
          current,
          options: Options(responseType: ResponseType.stream),
          cancelToken: token,
        );
      } on DioException catch (ex) {
        throw MetadataFetchException(_statusForDioError(ex), cause: ex);
      } catch (ex) {
        throw MetadataFetchException(MetadataFetchStatus.networkError, cause: ex);
      }

      final status = response.statusCode ?? 0;
      if (!_redirectCodes.contains(status)) {
        return _readResource(response, status, maxBytes, accept, token);
      }

      final location = response.headers.value('location');
      await _drain(response.data, token);

      final next = _resolveLocation(current, location);
      if (next == null) {
        throw MetadataFetchException(MetadataFetchStatus.httpError, httpStatusCode: status);
      }
      if (!visited.add(next.toString())) {
        throw MetadataFetchException(MetadataFetchStatus.tooManyRedirects, httpStatusCode: status);
      }
      current = next;
    }

    throw MetadataFetchException(MetadataFetchStatus.tooManyRedirects);
  }

  /// Resolves a `Location` header against the URL that produced it.
  ///
  /// Returns null when the header is missing, unparseable, or points somewhere
  /// other than http(s) — an `intent://` or `javascript:` redirect target is
  /// not something to chase.
  Uri? _resolveLocation(Uri current, String? location) {
    if (location == null || location.trim().isEmpty) return null;
    try {
      final next = current.resolve(location.trim());
      if (next.scheme != 'http' && next.scheme != 'https') return null;
      if (next.host.isEmpty) return null;
      return next;
    } on FormatException {
      return null;
    }
  }

  /// Validates and reads a non-redirect response.
  Future<FetchedResource> _readResource(
    Response<ResponseBody> response,
    int statusCode,
    int maxBytes,
    Set<FetchedContentKind>? accept,
    CancelToken token,
  ) async {
    final contentType = response.headers.value(Headers.contentTypeHeader);
    final kind = FetchedContentKind.fromContentType(contentType);

    if (statusCode < 200 || statusCode >= 300) {
      await _drain(response.data, token);
      throw MetadataFetchException(MetadataFetchStatus.httpError, httpStatusCode: statusCode);
    }

    // Reject on the declared Content-Length before reading a single chunk.
    final declaredLength = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '');
    if (declaredLength != null && declaredLength > maxBytes && kind == FetchedContentKind.image) {
      await _drain(response.data, token);
      throw MetadataFetchException(MetadataFetchStatus.unsupportedContent, httpStatusCode: statusCode);
    }

    // Servers omit or misreport Content-Type often enough that an unsupported
    // label is worth sniffing past when the caller wanted HTML. Any other
    // mismatch (a PDF, a video, an archive) is rejected before we read a byte.
    final mayBeMislabelledHtml =
        kind == FetchedContentKind.unsupported && (accept?.contains(FetchedContentKind.html) ?? false);

    if (accept != null && !accept.contains(kind) && !mayBeMislabelledHtml) {
      await _drain(response.data, token);
      throw MetadataFetchException(MetadataFetchStatus.unsupportedContent, httpStatusCode: statusCode);
    }

    final (bytes, truncated) = await _readCapped(response.data, maxBytes, token);

    var resolvedKind = kind;
    if (resolvedKind == FetchedContentKind.unsupported && _looksLikeHtml(bytes)) {
      resolvedKind = FetchedContentKind.html;
    }

    if (accept != null && !accept.contains(resolvedKind)) {
      throw MetadataFetchException(MetadataFetchStatus.unsupportedContent, httpStatusCode: statusCode);
    }

    return FetchedResource(
      bytes: bytes,
      statusCode: statusCode,
      finalUri: response.realUri,
      contentType: contentType,
      kind: resolvedKind,
      truncated: truncated,
    );
  }

  /// Reads the stream until [maxBytes], then stops.
  ///
  /// Returns the bytes gathered and whether the body was cut short.
  Future<(Uint8List, bool)> _readCapped(ResponseBody? body, int maxBytes, CancelToken token) async {
    if (body == null) return (Uint8List(0), false);

    final builder = BytesBuilder(copy: false);
    var truncated = false;

    try {
      await for (final chunk in body.stream) {
        builder.add(chunk);
        if (builder.length >= maxBytes) {
          truncated = true;
          break;
        }
      }
    } on DioException catch (ex) {
      if (builder.isEmpty) throw MetadataFetchException(_statusForDioError(ex), cause: ex);
      // A mid-stream failure after we already have the head of the document is
      // still usable — the metadata is at the top.
      truncated = true;
    } catch (ex) {
      if (builder.isEmpty) throw MetadataFetchException(MetadataFetchStatus.networkError, cause: ex);
      truncated = true;
    } finally {
      if (truncated && !token.isCancelled) {
        // Stop the transfer rather than letting the rest of the body arrive.
        token.cancel('metadata size cap reached');
      }
    }

    final bytes = builder.takeBytes();
    return (bytes, truncated);
  }

  /// Consumes and discards a body we are not going to use, so the connection
  /// can be released back to the pool.
  Future<void> _drain(ResponseBody? body, CancelToken token) async {
    if (body == null) return;
    if (!token.isCancelled) token.cancel('metadata response discarded');
    try {
      await body.stream.drain();
    } catch (_) {
      // Cancelling mid-stream surfaces here; nothing to do.
    }
  }

  /// Leading bytes to skip when sniffing: space, tab, LF, CR, and the three
  /// bytes of a UTF-8 byte-order mark.
  static const Set<int> _sniffSkippable = {0x20, 0x09, 0x0A, 0x0D, 0xEF, 0xBB, 0xBF};

  static bool _looksLikeHtml(Uint8List bytes) {
    final limit = bytes.length < 512 ? bytes.length : 512;
    for (var i = 0; i < limit; i++) {
      final byte = bytes[i];
      if (_sniffSkippable.contains(byte)) continue;
      return byte == 0x3C; // '<'
    }
    return false;
  }

  static MetadataFetchStatus _statusForDioError(DioException ex) {
    switch (ex.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return MetadataFetchStatus.timeout;
      case DioExceptionType.cancel:
        return MetadataFetchStatus.cancelled;
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
        return MetadataFetchStatus.networkError;
      case DioExceptionType.badResponse:
        return MetadataFetchStatus.httpError;
      case DioExceptionType.unknown:
        return ex.error is TimeoutException ? MetadataFetchStatus.timeout : MetadataFetchStatus.networkError;
    }
  }

  void close() => _dio.close(force: true);
}
