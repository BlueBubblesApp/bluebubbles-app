import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class ThemeNetworkService {
  Future<dynamic> getAll({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> set(String name, Map<String, dynamic> json, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> delete(String name, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}