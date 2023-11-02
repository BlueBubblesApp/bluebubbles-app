import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class ContactNetworkService implements SubNetworkService {
  Future<dynamic> getAll({bool withAvatars = false, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getByAddresses(List<String> addresses, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> create(List<Map<String, dynamic>> contacts, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}