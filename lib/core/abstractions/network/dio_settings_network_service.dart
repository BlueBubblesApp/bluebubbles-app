import 'package:bluebubbles/core/abstractions/network/settings_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioSettingsNetworkService implements SettingsNetworkService {

  DioNetworkService network;

  DioSettingsNetworkService(this.network);
  
  @override
  Future delete(String name, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.delete(
      "/backup/settings",
      json: {"name": name},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getAll({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/backup/settings",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future set(String name, Map<String, dynamic> json, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/backup/settings",
      json: {"name": name, "data": json},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
}