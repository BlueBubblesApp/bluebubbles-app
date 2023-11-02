import 'package:bluebubbles/core/abstractions/network/facetime_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioFaceTimeNetworkService implements FaceTimeNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioFaceTimeNetworkService(this.network);
  
  @override
  Future answer(String callUuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/facetime/answer/$callUuid",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future leave(String callUuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/facetime/leave/$callUuid",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}