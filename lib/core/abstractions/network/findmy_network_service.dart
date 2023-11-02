import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class FindMyNetworkService implements SubNetworkService {
  Future<dynamic> devices({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> refreshDevices({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> friends({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}