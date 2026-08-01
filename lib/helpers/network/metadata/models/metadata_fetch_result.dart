import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:flutter/foundation.dart';

/// Why a metadata fetch ended the way it did.
///
/// The distinction that matters most is [MetadataFetchResult.isRetryable]:
/// a transient failure must not be persisted as "already attempted", or the
/// message is stuck without a preview forever.
enum MetadataFetchStatus {
  /// Usable metadata was extracted.
  success,

  /// The page was fetched and parsed but contained nothing worth showing.
  empty,

  /// The user turned link preview fetching off.
  disabledByUser,

  /// The string could not be parsed as a URL at all.
  invalidUrl,

  /// The scheme was not http(s) (`mailto:`, `javascript:`, `file:` ...).
  unsupportedScheme,

  /// The host resolved to a loopback, private or link-local address.
  blockedHost,

  /// The response was not HTML or an image (a PDF, a zip, a video ...).
  unsupportedContent,

  /// The server answered with a non-success status code.
  httpError,

  /// DNS/socket/TLS failure.
  networkError,

  /// The request exceeded its deadline.
  timeout,

  /// The request was cancelled (widget disposed, size cap hit).
  cancelled,

  /// The document parsed but every strategy threw.
  parseError,
}

/// The outcome of a single metadata fetch.
@immutable
class MetadataFetchResult {
  final MetadataFetchStatus status;

  /// Populated for [MetadataFetchStatus.success]; may also be non-null for
  /// [MetadataFetchStatus.empty] when only a site name or icon was found.
  final UrlMetadata? metadata;

  /// The HTTP status code, when the request got that far.
  final int? httpStatusCode;

  /// The underlying error object, for logging.
  final Object? error;

  const MetadataFetchResult({
    required this.status,
    this.metadata,
    this.httpStatusCode,
    this.error,
  });

  const MetadataFetchResult.success(UrlMetadata this.metadata, {this.httpStatusCode})
      : status = MetadataFetchStatus.success,
        error = null;

  const MetadataFetchResult.failure(this.status, {this.error, this.httpStatusCode, this.metadata});

  bool get isSuccess => status == MetadataFetchStatus.success && metadata != null;

  /// Whether a later attempt could plausibly succeed.
  ///
  /// Retryable outcomes are deliberately *not* recorded as "attempted" in the
  /// message row, so the preview is tried again next time the bubble is built
  /// (subject to the store's TTL).
  bool get isRetryable {
    switch (status) {
      case MetadataFetchStatus.networkError:
      case MetadataFetchStatus.timeout:
      case MetadataFetchStatus.cancelled:
        return true;
      case MetadataFetchStatus.httpError:
        final code = httpStatusCode;
        if (code == null) return true;
        // Rate limiting, request timeout, "too early", and every server-side
        // error can succeed on a later attempt. Other 4xx responses (404, 401,
        // 403 bot blocks) will not change on their own.
        return code == 408 || code == 425 || code == 429 || code >= 500;
      case MetadataFetchStatus.disabledByUser:
        // The user can turn the setting back on; never poison the row for it.
        return true;
      case MetadataFetchStatus.success:
      case MetadataFetchStatus.empty:
      case MetadataFetchStatus.invalidUrl:
      case MetadataFetchStatus.unsupportedScheme:
      case MetadataFetchStatus.blockedHost:
      case MetadataFetchStatus.unsupportedContent:
      case MetadataFetchStatus.parseError:
        return false;
    }
  }

  /// Whether this outcome should be written to the message as a completed
  /// attempt, suppressing further fetches until the retry TTL elapses.
  bool get shouldMarkAttempted => !isRetryable;

  @override
  String toString() => 'MetadataFetchResult(${status.name}'
      '${httpStatusCode != null ? ', http: $httpStatusCode' : ''}'
      '${error != null ? ', error: $error' : ''})';
}
