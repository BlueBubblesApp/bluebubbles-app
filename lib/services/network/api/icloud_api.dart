import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:dio/dio.dart';

// ignore: camel_case_types
class iCloudApi {
  final BaseApi _svc;

  iCloudApi(this._svc);

  /// Get FindMy devices from server
  Future<Response> getDevices({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/icloud/findmy/devices",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Refresh FindMy devices on server
  Future<Response> refreshDevices({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/icloud/findmy/devices/refresh",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get FindMy friends from server
  Future<Response> getFriends({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/icloud/findmy/friends",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Refresh FindMy friends on server
  Future<Response> refreshFriends({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/icloud/findmy/friends/refresh",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get iCloud account info
  Future<Response> getAccountInfo({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/icloud/account",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get the iCloud contact card: your own, or the one [address] shared with you
  Future<Response> getAccountContact({String? address, CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/icloud/contact",
        queryParameters: _svc.buildQueryParams({"address": ?address}),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Set iCloud account alias
  Future<Response> setAccountAlias(String alias, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/icloud/account/alias",
        data: {"alias": alias},
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}
