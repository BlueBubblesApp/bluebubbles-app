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

  /// Create a fresh FaceTime Link via the Mac's Private API
  /// (FaceTime → Create Link). The link can be shared with anyone — Apple or
  /// not — so they can join from a browser. Requires server with macOS
  /// Monterey+ and Private API enabled.
  ///
  /// Response shape: `{ "data": { "link": "<url>" } }`
  Future<Response> createSession({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/facetime/session",
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
}
