import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';

class ServerApi {
  final BaseApi _svc;

  ServerApi(this._svc);

  /// Cache for server info to avoid redundant requests
  Response? _serverInfoCache;
  DateTime? _lastServerInfoFetch;

  /// Check ping time for server
  Future<Response> ping({String? customUrl, CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        customUrl != null ? "$customUrl/api/v1/ping" : "${_svc.apiRoot}/ping",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Lock Mac device
  Future<Response> lockMac({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/mac/lock",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Restart iMessage app
  Future<Response> restartImessage({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/mac/imessage/restart",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get the server's complete chat list with each chat's current read state.
  ///
  /// Used to reconcile after being offline. The live `chat-read-status-changed`
  /// event only reaches a connected client, and no event exists at all for a
  /// chat deleted on the Apple side, so without this the device keeps stale
  /// unread dots and threads Apple no longer has.
  Future<Response> chatStateSnapshot({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/chat-state/snapshot",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get server metadata like server version, macOS version, current URL, etc
  Future<Response> info({CancelToken? cancelToken}) async {
    final now = DateTime.now();
    if (_serverInfoCache != null &&
        _lastServerInfoFetch != null &&
        now.difference(_lastServerInfoFetch!) < const Duration(minutes: 1)) {
      Logger.debug("Server info was recently fetched. Using cache...");
      return _serverInfoCache!;
    }

    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/info",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        _serverInfoCache = response;
        _lastServerInfoFetch = now;
      }

      return _svc.returnSuccessOrError(response);
    });
  }

  /// Restart the server app services
  Future<Response> softRestart({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/restart/soft",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Restart the entire server app
  Future<Response> hardRestart({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/restart/hard",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Check for new server versions
  Future<Response> checkUpdate({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/update/check",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Install a pending server update
  Future<Response> installUpdate({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/server/update/install",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get server totals (number of handles, messages, chats, and attachments)
  Future<Response> getTotalStats({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/statistics/totals",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get server media totals (number of images, videos, and locations)
  ///
  /// Optionally fetch totals split by chat
  Future<Response> getMediaStats({bool byChat = false, CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/statistics/media${byChat ? "/chat" : ""}",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get server logs, [count] defines the length of logs
  Future<Response> getLogs({int count = 10000, CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/server/logs",
        queryParameters: _svc.buildQueryParams({"count": count}),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get the basic landing page for the server URL
  Future<Response> landingPage({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        _svc.origin,
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}
