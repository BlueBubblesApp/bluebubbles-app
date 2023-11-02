import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';

abstract class ScheduledMessagesNetworkService {
  Future<dynamic> getAll({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> create(String chatGuid, String message, DateTime date, Map<String, dynamic> schedule, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> update(int id, String chatGuid, String message, DateTime date, Map<String, dynamic> schedule, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
  Future<dynamic> delete(int id, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress});
}