import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class FcmNetworkService implements SubNetworkService {
  Future<dynamic> addDevice(String name, String identifier, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgres});
  Future<dynamic> getClientJson({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgres});
}