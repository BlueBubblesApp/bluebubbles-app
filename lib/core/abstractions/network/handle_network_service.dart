import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class HandleNetworkService implements SubNetworkService {
  Future<dynamic> count({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> query({List<String> withQuery = const [], String? address, int offset = 0, int limit = 100, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> get(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getFocusState(String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getiMessageAvailability(String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getFaceTimeAvailability(String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}