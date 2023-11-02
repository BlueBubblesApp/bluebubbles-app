import 'package:bluebubbles/core/abstractions/network/handle_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioHandleNetworkService implements HandleNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioHandleNetworkService(this.network);
  
  @override
  Future count({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/handle/count",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future get(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/handle/$guid",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }

  @override
  Future query({List<String> withQuery = const [], String? address, int offset = 0, int limit = 100, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/handle/query",
      json: {
        "with": withQuery,
        "address": address,
        "offset": offset,
        "limit": limit
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getFaceTimeAvailability(String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/handle/availability/facetime",
      params: {
        "address": address,
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getFocusState(String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/handle/$address/focus",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getiMessageAvailability(String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/handle/availability/imessage",
      params: {
        "address": address,
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}