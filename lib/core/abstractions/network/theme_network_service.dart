import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class ThemeNetworkService implements SubNetworkService {
  Future<dynamic> getAll({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> set(String name, Map<String, dynamic> json, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> delete(String name, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}