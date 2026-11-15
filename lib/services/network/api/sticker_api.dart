import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// The server Mac's sticker library (`/api/v2/sticker`) and placing stickers on messages
/// (`/api/v2/message/sticker`).
///
/// **v2 only**. Sending needs the Private API; listing and downloading only need the server to have
/// Full Disk Access. There is no send-by-identifier: download [image] and hand the bytes to [send].
class StickerApi {
  final BaseApi _svc;

  StickerApi(this._svc);

  static const int _pageLimit = 100;

  /// `GET sticker`: the whole library, newest first. [reason] is the server's sentence when it has no
  /// sticker store to read (nothing ever added, or no Full Disk Access).
  Future<({List<LibrarySticker> stickers, String? reason})> library({CancelToken? cancelToken}) async {
    final stickers = <LibrarySticker>[];
    String? reason;
    while (true) {
      final response = await _svc.runApiGuarded(() async {
        final response = await _svc.dio.get(
          "${_svc.apiRootV2}/sticker",
          queryParameters: _svc.buildQueryParams({'limit': _pageLimit, 'offset': stickers.length}),
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      });
      final body = response.data as Map;
      final metadata = body['metadata'] is Map ? body['metadata'] as Map : const {};
      final page = ((body['data'] as List?) ?? const [])
          .map((e) => LibrarySticker.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
      stickers.addAll(page);
      reason = metadata['reason']?.toString();
      final total = (metadata['total'] as num?)?.toInt();
      if (page.length < _pageLimit || (total != null && stickers.length >= total)) break;
    }
    return (stickers: stickers, reason: reason);
  }

  /// `GET sticker/:id/image`: the full-size image, or the picker thumbnail with [thumbnail]
  /// (the full-size one when the sticker has no thumbnail).
  Future<Uint8List> image(String identifier, {bool thumbnail = false, CancelToken? cancelToken}) async {
    final response = await _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRootV2}/sticker/${Uri.encodeComponent(identifier)}/image",
        queryParameters: _svc.buildQueryParams({if (thumbnail) 'role': 'keyboard'}),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
    return Uint8List.fromList(response.data as List<int>);
  }

  /// `POST sticker`: adds the image in [bytes] to the Mac's library. Needs the Private API. It always lands in
  /// Recents: Messages has no way in to the saved drawer. Null when the server added it but can't read the library
  /// back (no Full Disk Access).
  Future<LibrarySticker?> save({
    required Uint8List bytes,
    required String fileName,
    String? name,
    CancelToken? cancelToken,
  }) async {
    final response = await _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRootV2}/sticker",
        queryParameters: _svc.buildQueryParams(),
        data: FormData.fromMap({'attachment': MultipartFile.fromBytes(bytes, filename: fileName), 'name': ?name}),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
    final data = response.data['data'];
    return data is Map && data['identifier'] is String ? LibrarySticker.fromMap(data.cast<String, dynamic>()) : null;
  }

  /// `POST message/sticker`: puts the sticker in [bytes] on part [partIndex] of [messageGuid].
  ///
  /// With [tapback] it goes out as a sticker tapback, replacing your previous tapback on that message;
  /// [remove] (with [tapback]) takes it back. The server answers with the sticker's own message.
  Future<Response> send({
    required String chatGuid,
    required String messageGuid,
    required Uint8List bytes,
    required String fileName,
    int partIndex = 0,
    bool tapback = false,
    bool remove = false,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRootV2}/message/sticker",
        queryParameters: _svc.buildQueryParams(),
        data: FormData.fromMap({
          'attachment': MultipartFile.fromBytes(bytes, filename: fileName),
          'chatGuid': chatGuid,
          'selectedMessageGuid': messageGuid,
          'partIndex': partIndex.toString(),
          if (tapback) 'tapback': 'true',
          if (remove) 'remove': 'true',
        }),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}

/// What the server said when it refused a sticker request: its sentence for the user and, for a `402` (the server
/// lacks the subscription tier), the page to get one. Both null for a failure the server didn't answer.
({String? message, String? purchaseUrl}) stickerRefusal(Object? error) {
  final response = switch (error) {
    Response() => error,
    DioException() => error.response,
    _ => null,
  };
  final body = response?.data is Map ? response!.data as Map : const {};
  final err = body['error'] is Map ? body['error'] as Map : const {};
  final data = body['data'] is Map
      ? body['data'] as Map
      : err['data'] is Map
      ? err['data'] as Map
      : const {};
  final message = (err['message'] ?? body['message'])?.toString();
  return (message: message == null || message.isEmpty ? null : message, purchaseUrl: data['purchase_url']?.toString());
}
