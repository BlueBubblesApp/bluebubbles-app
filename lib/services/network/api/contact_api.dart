import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:dio/dio.dart';

class ContactApi {
  final BaseApi _svc;

  ContactApi(this._svc);

  /// Get all iCloud contacts
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

  /// Contacts per [fetchAllPages] request on a v2 server.
  static const fetchAllPageSize = 1000;

  /// Stops [fetchAllPages] on a server that keeps returning full pages, rather than reading forever.
  static const fetchAllMaxPages = 200;

  /// Every server contact. A v2 server returns at most [fetchAllPageSize] per request, so this pages; 1.x ignores
  /// paging and returns everything in one. Throws [StateError] rather than return a list it knows is incomplete, since
  /// callers prune or delete whatever the list leaves out.
  Future<List<Map<String, dynamic>>> fetchAllPages({required bool isV2Server, bool withAvatars = false}) async {
    final contacts = <Map<String, dynamic>>[];
    final seenIds = <dynamic>{};
    for (int i = 0; i < fetchAllMaxPages; i++) {
      final response = await fetchAll(
        withAvatars: withAvatars,
        limit: isV2Server ? fetchAllPageSize : null,
        offset: isV2Server ? contacts.length : null,
      );
      final page = (response.data['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final firstId = page.firstOrNull?['id'];
      if (firstId != null && !seenIds.add(firstId)) {
        throw StateError('Server returned contact $firstId again at offset ${contacts.length}; it is ignoring offset');
      }
      contacts.addAll(page);
      if (!isV2Server || page.length < fetchAllPageSize) return contacts;
    }
    throw StateError('Server still returning full pages after ${contacts.length} contacts');
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
        options: _bulkWriteOptions(),
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
        options: _bulkWriteOptions(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Uploading a whole address book takes far longer than an ordinary request.
  Options _bulkWriteOptions() => Options(
        sendTimeout: _svc.dio.options.sendTimeout! * 12,
        receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
        headers: _svc.headers,
      );
}
