import 'package:bluebubbles/core/abstractions/network/theme_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioThemeNetworkService implements ThemeNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioThemeNetworkService(this.network);
  
  @override
  Future delete(String name, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.delete(
      "/backup/theme",
      json: {"name": name},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getAll({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/backup/theme",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future set(String name, Map<String, dynamic> json, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/backup/theme",
      json: {"name": name, "data": json},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}