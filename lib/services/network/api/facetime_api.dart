import 'package:bluebubbles/models/facetime.dart';
import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:dio/dio.dart';

class FaceTimeApi {
  final BaseApi _svc;

  FaceTimeApi(this._svc);

  /// Answer a FaceTime call with the given [callUuid].
  /// The response is a data object with a `link` key containing the call link.
  Future<Response> answer(String callUuid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/facetime/answer/$callUuid",
        queryParameters: _svc.buildQueryParams(),
        data: {},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Leave a FaceTime call with the given [callUuid]
  Future<Response> leave(String callUuid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/facetime/leave/$callUuid",
        queryParameters: _svc.buildQueryParams(),
        data: {},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// `POST facetime/call` — has the server's Mac ring [address] on FaceTime, and hands back a
  /// link to join the call. The Mac leaves on its own once someone has joined.
  ///
  /// **v2 only**: gate on `ServerDetails.supportsFaceTimeCalls`. [video] false rings the
  /// callee as FaceTime Audio.
  ///
  /// Refusals are thrown as [FaceTimeException] with the server's sentence: FaceTime or
  /// outgoing calls switched off on the server (403), or an address that isn't on FaceTime
  /// (400, checked before anything rings). When the call rang but no link came back, the
  /// exception carries the [FaceTimeCall] so the caller can hang it up.
  ///
  /// The server takes a list of addresses, but dials them as one 1:1 request; group calls
  /// aren't a supported flow, so this takes one.
  Future<PlacedFaceTimeCall> call(String address, {bool video = true, CancelToken? cancelToken}) async {
    final Response response;
    try {
      response = await _svc.runApiGuarded(() async {
        final response = await _svc.dio.post(
          "${_svc.apiRootV2}/facetime/call",
          queryParameters: _svc.buildQueryParams(),
          data: {
            'addresses': [address],
            'video': video,
          },
          // An availability check, a dial (up to 20s) and a link (up to 15s) on the Mac.
          options: Options(receiveTimeout: _svc.dio.options.receiveTimeout! * 3),
          cancelToken: cancelToken,
        );
        return _svc.returnSuccessOrError(response);
      });
    } on Response catch (r) {
      throw _refusal(r);
    } on DioException catch (e) {
      if (e.response == null || CancelToken.isCancel(e)) rethrow;
      throw _refusal(e.response!);
    }

    final data = (response.data['data'] as Map).cast<String, dynamic>();
    return PlacedFaceTimeCall(
      link: (data['link'] as Map)['url'] as String,
      call: FaceTimeCall.fromMap((data['call'] as Map).cast<String, dynamic>()),
    );
  }

  FaceTimeException _refusal(Response r) {
    final body = r.data is Map ? r.data as Map : const {};
    final error = body['error'] is Map ? body['error'] as Map : const {};
    final data = body['data'] is Map ? body['data'] as Map : const {};
    final message = (error['message'] ?? body['message'])?.toString();
    final call = data['call'] is Map ? FaceTimeCall.fromMap((data['call'] as Map).cast<String, dynamic>()) : null;
    return FaceTimeException(
      message == null || message.isEmpty ? "The server returned ${r.statusCode}" : message,
      statusCode: r.statusCode,
      call: call,
    );
  }
}
