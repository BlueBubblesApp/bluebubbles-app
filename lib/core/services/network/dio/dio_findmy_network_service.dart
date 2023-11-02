import 'package:bluebubbles/core/abstractions/network/findmy_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioFindMyNetworkService implements FindMyNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioFindMyNetworkService(this.network);
  
  @override
  Future devices({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/icloud/findmy/devices",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future friends({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/icloud/findmy/friends",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future refreshDevices({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/icloud/findmy/devices/refresh",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: network.defaultDownloadOpts,
    );
  }

}