import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class FaceTimeNetworkService {
  Future<dynamic> answer(String callUuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> leave(String callUuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}