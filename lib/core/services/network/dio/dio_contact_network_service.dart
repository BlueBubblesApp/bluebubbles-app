import 'package:bluebubbles/core/abstractions/network/contact_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioContactNetworkService implements ContactNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioContactNetworkService(this.network);
  
  @override
  Future create(List<Map<String, dynamic>> contacts, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/contact",
      json: contacts,
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getAll({bool withAvatars = false, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/contact",
      params: withAvatars ? {"extraProperties": "avatar"} : {},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getByAddresses(List<String> addresses, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/contact/query",
      json: {"addresses": addresses},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}