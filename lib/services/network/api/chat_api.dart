import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';

class ChatApi {
  final BaseApi _svc;

  ChatApi(this._svc);

  /// Query the chat DB. Use [withQuery] to specify what you would like in the
  /// response or how to query the DB.
  ///
  /// [withQuery] options: `"participants"`, `"lastmessage"`, `"sms"`, `"archived"`
  Future<Response> query({
    List<String> withQuery = const [],
    int offset = 0,
    int limit = 100,
    String? sort,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/query",
        queryParameters: _svc.buildQueryParams(),
        data: {"with": withQuery, "offset": offset, "limit": limit, "sort": sort},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get the messages for the specified chat (using [guid]). Use [withQuery]
  /// to specify what you would like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"attachment"` / `"attachments"`, `"handle"` / `"handles"`,
  /// `"sms"`, `"message.attributedbody"` (set as one string, comma separated, no spaces)
  Future<Response> getMessages(
    String guid, {
    String withQuery = "",
    String sort = "DESC",
    int? before,
    int? after,
    int offset = 0,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/chat/$guid/message",
        queryParameters: _svc.buildQueryParams(
            {"with": withQuery, "sort": sort, "before": before, "after": after, "offset": offset, "limit": limit}),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Add / remove a participant to the specified chat (using [guid]). [method]
  /// tells whether to add or remove, and use [address] to specify the address
  /// of the participant to add / remove.
  Future<Response> modifyParticipant(String method, String guid, String address, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/participant/$method",
        queryParameters: _svc.buildQueryParams(),
        data: {"address": address},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Leave a chat
  Future<Response> leave(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/leave",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Update the specified chat (using [guid]). Use [displayName] to specify the
  /// new chat name.
  Future<Response> setDisplayName(String guid, String displayName, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.put(
        "${_svc.apiRoot}/chat/$guid",
        queryParameters: _svc.buildQueryParams(),
        data: {"displayName": displayName},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Create a chat with the specified [addresses]. Requires an initial [message]
  /// to send.
  Future<Response> create(List<String> addresses, String? message, String service, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/new",
        queryParameters: _svc.buildQueryParams(),
        data: {
          "addresses": addresses,
          "message": message,
          "service": service,
          "method": SettingsSvc.settings.enablePrivateAPI.value ? 'private-api' : 'apple-script',
        },
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get the number of chats in the server iMessage DB
  Future<Response> getCount({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/chat/count",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get a single chat by its [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"participants"`, `"lastmessage"`
  /// (set as one string, comma separated, no spaces)
  Future<Response> fetchOne(String guid, {String withQuery = "", CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/chat/$guid",
        queryParameters: _svc.buildQueryParams({"with": withQuery}),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Mark a chat read by its [guid]
  Future<Response> markRead(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/read",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Mark a chat unread by its [guid]
  Future<Response> markUnread(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/unread",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Start a typing indicator for the chat with [guid]
  Future<Response> startTyping(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/typing",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Stop a typing indicator for the chat with [guid]
  Future<Response> stopTyping(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.delete(
        "${_svc.apiRoot}/chat/$guid/typing",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get a group chat icon by the chat [guid]
  Future<Response> getIcon(
    String guid, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/chat/$guid/icon",
        queryParameters: _svc.buildQueryParams(),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Set a group chat icon by the chat [guid]
  Future<Response> setIcon(
    String guid,
    String path, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      "icon": await MultipartFile.fromFile(path),
    });
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/icon",
        queryParameters: _svc.buildQueryParams(),
        data: formData,
        options: Options(
          sendTimeout: _svc.dio.options.sendTimeout! * 12,
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Delete the group chat icon for the chat [guid]
  Future<Response> removeIcon(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.delete(
        "${_svc.apiRoot}/chat/$guid/icon",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Delete a chat by [guid]
  Future<Response> delete(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.delete(
        "${_svc.apiRoot}/chat/$guid",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Delete a message by [guid]
  Future<Response> deleteMessage(String guid, String messageGuid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.delete(
        "${_svc.apiRoot}/chat/$guid/$messageGuid",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}
