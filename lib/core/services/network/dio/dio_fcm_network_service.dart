import 'package:bluebubbles/core/abstractions/network/fcm_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioFcmNetworkService implements FcmNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioFcmNetworkService(this.network);

  @override
  Future addDevice(String name, String identifier, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgres}) async {
    return await network.post(
      "/fcm/device",
      json: {"name": name, "identifier": identifier},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgres
    );
  }

  @override
  Future getClientJson({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgres}) async {
    return await network.get(
      "/fcm/client",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgres
    );
  }
}