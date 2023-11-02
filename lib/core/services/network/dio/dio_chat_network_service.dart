import 'package:bluebubbles/core/abstractions/network/chat_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:dio/dio.dart';


class DioChatNetworkService implements ChatNetworkService {

  DioNetworkService network;

  DioChatNetworkService(this.network);
  
  @override
  Future count({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/chat/count",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future create(List<String> addresses, String? message, String service, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/new",
      json: {
        "addresses": addresses,
        "message": message,
        "service": service,
        "method": settings.config.enablePrivateAPI.value ? 'private-api' : 'apple-script'
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future delete(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.delete(
      "/chat/$guid",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future get(String guid, {String withQuery = "", NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
        "/chat/$guid",
        params: {"with": withQuery},
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress
    );
  }

  @override
  Future update(String guid, String displayName, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.put(
      "/chat/$guid",
      json: {"displayName": displayName},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future leave(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/$guid/leave",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future markRead(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/$guid/read",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future markUnread(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/$guid/unread",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future messages(String guid, {String withQuery = "", String sort = "DESC", int? before, int? after, int offset = 0, int limit = 100, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/chat/$guid/message",
      params: {
        "with": withQuery,
        "sort": sort,
        "before": before,
        "after": after,
        "offset": offset,
        "limit": limit
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future query({List<String> withQuery = const [], int offset = 0, int limit = 100, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/query",
      json: {
        "with": withQuery,
        "offset": offset,
        "limit": limit
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }

  @override
  Future addParticipant(String guid, String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/$guid/participant/add",
      json: {"address": address},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future removeParticipant(String guid, String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/chat/$guid/participant/add",
      json: {"address": address},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }

  @override
  Future getIcon(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/chat/$guid/icon",
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }
  
  @override
  Future setIcon(String guid, String path, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    final formData = FormData.fromMap({
      "icon": await MultipartFile.fromFile(path),
    });
    
    return await network.post(
      "/chat/$guid/icon",
      data: formData,
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }

  @override
  Future removeIcon(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.delete(
      "/chat/$guid/icon",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}