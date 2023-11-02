import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class FaceTimeNetworkService implements SubNetworkService {
  Future<dynamic> answer(String callUuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> leave(String callUuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}