import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:dio/dio.dart';

class ContactApi {
  final BaseApi _svc;

  ContactApi(this._svc);

  /// Get all iCloud contacts. The v2 server returns at most 1,000 per request, paged by [limit] and [offset]; 1.x
  /// servers ignore both and return everything.
  Future<Response> fetchAll({bool withAvatars = false, int? limit, int? offset, CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/contact",
        queryParameters: _svc.buildQueryParams({
          if (withAvatars) "extraProperties": "avatar",
          "limit": ?limit,
          "offset": ?offset,
        }),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get specific iCloud contacts with a list of [addresses], either phone
  /// numbers or emails
  Future<Response> query(List<String> addresses, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/contact/query",
        queryParameters: _svc.buildQueryParams(),
        data: {"addresses": addresses},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Update server contacts in place, each map carrying the server `id` it replaces
  Future<Response> update(
    List<Map<String, dynamic>> contacts, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.put(
        "${_svc.apiRoot}/contact",
        queryParameters: _svc.buildQueryParams(),
        data: contacts,
        onSendProgress: onSendProgress,
        options: Options(
          sendTimeout: _svc.dio.options.sendTimeout! * 12,
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Delete server contacts by their server [ids]
  Future<Response> delete(List<dynamic> ids, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.delete(
        "${_svc.apiRoot}/contact",
        queryParameters: _svc.buildQueryParams(),
        data: ids.map((id) => {'id': id}).toList(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Add a contact to the server
  Future<Response> create(
    List<Map<String, dynamic>> contacts, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/contact",
        queryParameters: _svc.buildQueryParams(),
        data: contacts,
        onSendProgress: onSendProgress,
        options: Options(
          sendTimeout: _svc.dio.options.sendTimeout! * 12,
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}
