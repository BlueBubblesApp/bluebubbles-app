import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/message_actions.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:get_it/get_it.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';

class MessageInterface {
  static Future<List<Message?>> getMessages() async {
    final isolate = GetIt.I<GlobalIsolate>();

    final stopwatch = Stopwatch()..start();
    final results = await isolate.send<List<Message?>>(
      IsolateRequestType.getMessages,
      input: null,
    );
    stopwatch.stop();
    Logger.info(
        'Fetched ${results.length} messages from CUSTOM ISOLATE in ${stopwatch.elapsedMilliseconds}ms: ${results.map((m) => m?.guid).join(", ")}');
    return results;
  }

  static Future<Message> replaceMessage(
      {required String? oldGuid, required Map<String, dynamic> newMessageData}) async {
    final data = {
      'oldGuid': oldGuid,
      'newMessageData': newMessageData,
    };

    late int messageId;
    if (isIsolate) {
      messageId = await MessageActions.replaceMessage(data);
    } else {
      messageId = await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.replaceMessage, input: data);
    }

    // Fetch message by ID using get
    final message = Database.messages.get(messageId);
    if (message == null) {
      throw Exception('Failed to fetch message with ID $messageId after replace');
    }

    return message;
  }

  static Future<void> deleteMessage({
    required String guid,
  }) async {
    final data = {
      'guid': guid,
    };

    if (isIsolate) {
      return await MessageActions.deleteMessage(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.deleteMessage, input: data);
    }
  }

  static Future<void> softDeleteMessage({
    required String guid,
  }) async {
    final data = {
      'guid': guid,
    };

    if (isIsolate) {
      return await MessageActions.softDeleteMessage(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.softDeleteMessage, input: data);
    }
  }

  static Future<Map<String, dynamic>> fetchAssociatedMessagesAsync({
    required String messageGuid,
    required int? messageId,
    String? threadOriginatorGuid,
  }) async {
    final data = {
      'messageGuid': messageGuid,
      'messageId': messageId,
      'threadOriginatorGuid': threadOriginatorGuid,
    };

    if (isIsolate) {
      return await MessageActions.fetchAssociatedMessagesAsync(data);
    } else {
      return await GetIt.I<GlobalIsolate>()
          .send<Map<String, dynamic>>(IsolateRequestType.fetchAssociatedMessagesAsync, input: data);
    }
  }

  static Future<Message?> saveMessageAsync({
    required Map<String, dynamic> messageData,
    Map<String, dynamic>? chatData,
    required bool updateIsBookmarked,
  }) async {
    final data = {
      'messageData': messageData,
      'chatData': chatData,
      'updateIsBookmarked': updateIsBookmarked,
    };

    late int messageId;
    if (isIsolate) {
      messageId = await MessageActions.saveMessageAsync(data);
    } else {
      messageId = await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.saveMessageAsync, input: data);
    }

    // Fetch message by ID using get
    final message = Database.messages.get(messageId);
    return message;
  }

  static Future<Message?> findOneAsync({String? guid, String? associatedMessageGuid}) async {
    final data = {
      'guid': guid,
      'associatedMessageGuid': associatedMessageGuid,
    };

    late int? messageId;
    if (isIsolate) {
      messageId = await MessageActions.findOneAsync(data);
    } else {
      messageId = await GetIt.I<GlobalIsolate>().send<int?>(IsolateRequestType.findOneAsync, input: data);
    }

    if (messageId == null) return null;

    // Fetch message by ID using get
    final message = Database.messages.get(messageId);
    return message;
  }

  static Future<List<Message>> findAsync({String? conditionJson}) async {
    final data = {
      'conditionJson': conditionJson,
    };

    late List<int> messageIds;
    if (isIsolate) {
      messageIds = await MessageActions.findAsync(data);
    } else {
      messageIds = await GetIt.I<GlobalIsolate>().send<List<int>>(IsolateRequestType.findAsync, input: data);
    }

    // Fetch messages by ID using getMany for efficiency
    final messages = Database.messages.getMany(messageIds).whereType<Message>().toList();
    return messages;
  }

  /// Re-links any message whose `handleId` matches [handleId] (the sender's
  /// server-side ROWID) to the local handle [localHandleId]. Used by the
  /// "Handle Auditing" remediation flow to re-attach messages that were left
  /// unlinked because the handle's `originalROWID` was missing at the time
  /// the message was originally saved. Returns the number of messages relinked.
  static Future<int> relinkMessagesToHandle({
    required int handleId,
    required int localHandleId,
  }) async {
    final data = {
      'handleId': handleId,
      'localHandleId': localHandleId,
    };

    if (isIsolate) {
      return await MessageActions.relinkMessagesToHandle(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.relinkMessagesToHandle, input: data);
    }
  }
}
