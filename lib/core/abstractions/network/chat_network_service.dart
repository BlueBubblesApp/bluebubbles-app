import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';


abstract class ChatNetworkService implements SubNetworkService {
  Future<dynamic> query({List<String> withQuery = const [], int offset = 0, int limit = 100, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> messages(String guid, {String withQuery = "", String sort = "DESC", int? before, int? after, int offset = 0, int limit = 100, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> addParticipant(String guid, String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> removeParticipant(String guid, String address, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> leave(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> update(String guid, String displayName, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> create(List<String> addresses, String? message, String service, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> count({NetworkCancelToken? cancelToken});
  Future<dynamic> get(String guid, {String withQuery = "", NetworkCancelToken? cancelToken});
  Future<dynamic> markRead(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> markUnread(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getIcon(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> setIcon(String guid, String path, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> removeIcon(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> delete(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}