import 'package:bluebubbles/core/abstractions/network/server_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioServerNetworkService implements ServerNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioServerNetworkService(this.network);
  
  @override
  Future checkForUpdate({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/server/update/check",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future hardRestart({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/server/restart/hard",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future installUpdate({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/server/update/install",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future landingPage({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      '/',
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future lockMac({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/mac/lock",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future ping({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
        "/ping",
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future restartImessage({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/mac/imessage/restart",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future info({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/server/info",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future logs({int count = 1000, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/server/logs",
      params: {"count": count},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future mediaStatistics({bool byChat = false, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/server/statistics/media${byChat ? "/chat" : ""}",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future totalStatistics({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
        "/server/statistics/totals",
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future softRestart({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/server/restart/soft",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}