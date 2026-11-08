import 'dart:convert';

import 'package:bluebubbles/models/genmoji.dart';
import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Genmoji generation through Apple Intelligence on the server's Mac (`/api/v2/genmoji`).
///
/// **v2 only** — the v1 (Electron) server has no such route. Gate every call on
/// `ServerDetails.supportsGenmoji`. Whether the Mac itself can generate (macOS 15.4+, Apple
/// Intelligence on, a subscription, the BlueBubbles app hosting the server on macOS 27) is
/// what [status] answers; call it before offering the prompt.
///
/// The `library` routes read the Genmoji the user already has: the Mac's sticker store, which
/// syncs through iCloud. `GenmojiLibraryService` keeps the on-disk copy; go through it rather
/// than calling them from UI code.
///
/// Refusals are thrown as [GenmojiException], carrying the server's sentence for the user and
/// its stable `reason` word.
class GenmojiApi {
  final BaseApi _svc;

  GenmojiApi(this._svc);

  /// `GET genmoji/status` — whether `POST genmoji` would work on this Mac, and if not, why.
  Future<GenmojiSupport> status({CancelToken? cancelToken}) async {
    final response = await _guard(
      () => _svc.runApiGuarded(() async {
        final response = await _svc.dio.get(
          "${_svc.apiRootV2}/genmoji/status",
          queryParameters: _svc.buildQueryParams(),
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      }),
    );
    return GenmojiSupport.fromMap((response.data['data'] as Map).cast<String, dynamic>());
  }

  /// `POST genmoji` — draws [count] (1–4) Genmoji for [description].
  ///
  /// Each image is a model run of roughly ten seconds (longer when the server has to drive the
  /// Image Playground sheet), so this gets the same extended receive timeout as the app's
  /// other slow routes rather than the global API timeout.
  Future<List<GenmojiImage>> create(String description, {int count = 1, CancelToken? cancelToken}) async {
    final response = await _guard(
      () => _svc.runApiGuarded(() async {
        final response = await _svc.dio.post(
          "${_svc.apiRootV2}/genmoji",
          queryParameters: _svc.buildQueryParams(),
          data: {'description': description, 'count': count},
          options: Options(receiveTimeout: _svc.dio.options.receiveTimeout! * 12),
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      }),
    );
    final images = (response.data['data']['images'] as List?) ?? const [];
    return images.map((e) => GenmojiImage.fromMap((e as Map).cast<String, dynamic>())).toList();
  }

  /// Largest page `GET genmoji/library` serves.
  static const int libraryPageLimit = 100;

  /// Most identifiers, and largest `size`, `POST genmoji/library/images` takes in one request.
  static const int libraryBatchLimit = 50;
  static const int libraryBatchMaxSize = 320;

  /// Largest `size` `GET genmoji/library/:id/image` serves.
  static const int libraryImageMaxSize = 1024;

  /// `GET genmoji/library` — one page of the Mac's Genmoji, newest first, metadata only.
  ///
  /// Pass the [GenmojiLibraryPage.entityTag] from the last listing as [ifNoneMatch]: an
  /// unchanged library answers 304, returned here as null. The tag names the page window too,
  /// so only reuse it with the same [limit] and [offset].
  Future<GenmojiLibraryPage?> library({
    int limit = libraryPageLimit,
    int offset = 0,
    String? ifNoneMatch,
    CancelToken? cancelToken,
  }) async {
    final response = await _guard(
      () => _svc.runApiGuarded(() async {
        final response = await _svc.dio.get(
          "${_svc.apiRootV2}/genmoji/library",
          queryParameters: _svc.buildQueryParams({'limit': limit, 'offset': offset}),
          options: Options(
            headers: {'If-None-Match': ?ifNoneMatch},
            // A 304 is the cache answering, not a failure: let it through untouched.
            validateStatus: (status) => status != null && ((status >= 200 && status < 300) || status == 304),
          ),
          cancelToken: cancelToken,
        );
        if (response.statusCode == 304) return response;
        return _svc.returnSuccessOrError(response);
      }),
    );
    if (response.statusCode == 304) return null;

    final body = response.data as Map;
    final metadata = body['metadata'] is Map ? body['metadata'] as Map : const {};
    final entries = ((body['data'] as List?) ?? const [])
        .map((e) => GenmojiLibraryEntry.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
    return GenmojiLibraryPage(
      entries: entries,
      total: (metadata['total'] as num?)?.toInt() ?? offset + entries.length,
      revision: metadata['revision']?.toString(),
      reason: metadata['reason']?.toString(),
      entityTag: response.headers.value('etag'),
    );
  }

  /// `POST genmoji/library/images` — up to [libraryBatchLimit] Genmoji at one [size] (at most
  /// [libraryBatchMaxSize]), inline, for filling the cache in one round trip.
  Future<GenmojiLibraryImages> libraryImages(
    List<String> identifiers, {
    int size = libraryBatchMaxSize,
    CancelToken? cancelToken,
  }) async {
    final response = await _guard(
      () => _svc.runApiGuarded(() async {
        final response = await _svc.dio.post(
          "${_svc.apiRootV2}/genmoji/library/images",
          queryParameters: _svc.buildQueryParams(),
          data: {'identifiers': identifiers, 'size': size, 'format': 'png'},
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      }),
    );
    final data = response.data['data'] as Map;
    return (
      images: ((data['images'] as List?) ?? const [])
          .map((e) => GenmojiImage.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      missing: ((data['missing'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }

  /// `GET genmoji/library/:id/image` — one Genmoji as PNG, its longest edge [size] pixels
  /// (1 to [libraryImageMaxSize]; never enlarged past what the Mac stores).
  Future<Uint8List> libraryImage(String identifier, {int size = 512, CancelToken? cancelToken}) async {
    final response = await _guard(
      () => _svc.runApiGuarded(() async {
        final response = await _svc.dio.get(
          "${_svc.apiRootV2}/genmoji/library/${Uri.encodeComponent(identifier)}/image",
          queryParameters: _svc.buildQueryParams({'size': size, 'format': 'png'}),
          options: Options(responseType: ResponseType.bytes),
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      }),
    );
    return Uint8List.fromList(response.data as List<int>);
  }

  /// `DELETE genmoji/library/:id` — removes a Genmoji from the Mac and, through iCloud, from
  /// every device on the account. Needs the server's Private API helper; without it, or when
  /// the Mac's store never stops listing it (`not_removed`), this throws [GenmojiException].
  Future<void> deleteFromLibrary(String identifier, {CancelToken? cancelToken}) async {
    await _guard(
      () => _svc.runApiGuarded(() async {
        final response = await _svc.dio.delete(
          "${_svc.apiRootV2}/genmoji/library/${Uri.encodeComponent(identifier)}",
          queryParameters: _svc.buildQueryParams(),
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      }),
    );
  }

  /// Rethrows a server refusal as a [GenmojiException]: a non-200 [Response] for a JSON
  /// request (how `ApiInterceptor` surfaces one), or a [DioException] carrying the server's
  /// JSON envelope as bytes for the image route. Cancellation and transport failures pass
  /// through untouched.
  Future<Response> _guard(Future<Response> Function() request) async {
    try {
      return await request();
    } on Response catch (r) {
      throw _refusal(r);
    } on DioException catch (e) {
      final r = e.response;
      if (r == null || CancelToken.isCancel(e)) rethrow;
      if (r.data is List<int>) {
        try {
          r.data = jsonDecode(utf8.decode(r.data as List<int>));
        } on FormatException {
          // Not the server's envelope; the status code alone still says what happened.
        }
      }
      throw _refusal(r);
    }
  }

  GenmojiException _refusal(Response r) {
    final body = r.data is Map ? r.data as Map : const {};
    final error = body['error'] is Map ? body['error'] as Map : const {};
    final data = body['data'] is Map
        ? body['data'] as Map
        : error['data'] is Map
        ? error['data'] as Map
        : const {};
    final message = (error['message'] ?? body['message'])?.toString();
    return GenmojiException(
      message == null || message.isEmpty ? "The server returned ${r.statusCode}" : message,
      reason: data['reason']?.toString(),
      statusCode: r.statusCode,
    );
  }
}
