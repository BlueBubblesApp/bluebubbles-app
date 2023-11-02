import 'package:bluebubbles/core/abstractions/network/scheduled_messages_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';
import 'package:bluebubbles/core/services/services.dart';


class DioScheduledMessagesNetworkService implements ScheduledMessagesNetworkService {

  DioNetworkService network;

  DioScheduledMessagesNetworkService(this.network);
  
  @override
  Future create(String chatGuid, String message, DateTime date, Map<String, dynamic> schedule, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/message/schedule",
      json: {
        "type": "send-message",
        "payload": {
          "chatGuid": chatGuid,
          "message": message,
          "method": settings.config.privateAPISend.value ? 'private-api' : "apple-script"
        },
        "scheduledFor": date.millisecondsSinceEpoch,
        "schedule": schedule,
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future delete(int id, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.delete(
      "/message/schedule/$id",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future getAll({NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/message/schedule",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future update(int id, String chatGuid, String message, DateTime date, Map<String, dynamic> schedule, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.put(
      "/message/schedule/$id",
      json: {
        "type": "send-message",
        "payload": {
          "chatGuid": chatGuid,
          "message": message,
          "method": "apple-script"
        },
        "scheduledFor": date.millisecondsSinceEpoch,
        "schedule": schedule,
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}