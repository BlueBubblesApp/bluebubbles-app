import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/send_message_actions.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:get_it/get_it.dart';

/// Interface layer for outgoing HTTP sends.
///
/// Routes each call through [GlobalIsolate] when on the main thread so that
/// in-flight sends survive the app being backgrounded.  When already running
/// inside the isolate, calls the action directly.
class SendMessageInterface {
  /// Sends a text message and returns the decoded server response body.
  static Future<Map<String, dynamic>> sendTextMessage({
    required String chatGuid,
    required String tempGuid,
    required String message,
    String? method,
    String? effectId,
    String? subject,
    String? selectedMessageGuid,
    int? partIndex,
    bool? ddScan,
  }) async {
    final data = {
      'chatGuid': chatGuid,
      'tempGuid': tempGuid,
      'message': message,
      'method': method,
      'effectId': effectId,
      'subject': subject,
      'selectedMessageGuid': selectedMessageGuid,
      'partIndex': partIndex,
      'ddScan': ddScan,
    };
    if (isIsolate) {
      return await SendMessageActions.sendTextMessage(data);
    }
    return await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(IsolateRequestType.sendTextMessage, input: data);
  }

  /// Sends a tapback and returns the decoded server response body.
  static Future<Map<String, dynamic>> sendTapback({
    required String chatGuid,
    required String selectedMessageText,
    required String selectedMessageGuid,
    required String reaction,
    int? partIndex,
    String? emoji,
  }) async {
    final data = {
      'chatGuid': chatGuid,
      'selectedMessageText': selectedMessageText,
      'selectedMessageGuid': selectedMessageGuid,
      'reaction': reaction,
      'partIndex': partIndex,
      'emoji': emoji,
    };
    if (isIsolate) {
      return await SendMessageActions.sendTapback(data);
    }
    return await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(IsolateRequestType.sendTapback, input: data);
  }

  /// Sends a multipart (mention / mixed-content) message and returns the decoded
  /// server response body.
  static Future<Map<String, dynamic>> sendMultipartMessage({
    required String chatGuid,
    required String tempGuid,
    required List<Map<String, dynamic>> parts,
    String? effectId,
    String? subject,
    String? selectedMessageGuid,
    int? partIndex,
    bool? ddScan,
  }) async {
    final data = {
      'chatGuid': chatGuid,
      'tempGuid': tempGuid,
      'parts': parts,
      'effectId': effectId,
      'subject': subject,
      'selectedMessageGuid': selectedMessageGuid,
      'partIndex': partIndex,
      'ddScan': ddScan,
    };
    if (isIsolate) {
      return await SendMessageActions.sendMultipartMessage(data);
    }
    return await GetIt.I<GlobalIsolate>()
        .send<Map<String, dynamic>>(IsolateRequestType.sendMultipartMessage, input: data);
  }

  /// Sends an attachment and returns the decoded server response body.
  ///
  /// The isolate reads [filePath] from disk and constructs the multipart form
  /// locally. Upload progress is not reported in v1.
  static Future<Map<String, dynamic>> sendAttachmentMessage({
    required String chatGuid,
    required String tempGuid,
    required String filePath,
    required String fileName,
    required int fileSize,
    String? method,
    String? effectId,
    String? subject,
    String? selectedMessageGuid,
    int? partIndex,
    bool? isAudioMessage,
  }) async {
    final data = {
      'chatGuid': chatGuid,
      'tempGuid': tempGuid,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'method': method,
      'effectId': effectId,
      'subject': subject,
      'selectedMessageGuid': selectedMessageGuid,
      'partIndex': partIndex,
      'isAudioMessage': isAudioMessage ?? false,
    };
    if (isIsolate) {
      return await SendMessageActions.sendAttachmentMessage(data);
    }
    return await GetIt.I<GlobalIsolate>()
        .send<Map<String, dynamic>>(IsolateRequestType.sendAttachmentMessage, input: data);
  }
}
