import 'dart:convert';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:universal_io/io.dart';

/// Isolate-dispatchable actions for sending messages via HTTP.
///
/// Each method accepts `Map<String, dynamic>` (as required by [IsolateAction])
/// and returns the decoded server response body so the main isolate can
/// hydrate a [Message] via `Message.fromMap(result['data'])`.
///
class SendMessageActions {
  /// Sends a text message via HTTP.
  static Future<Map<String, dynamic>> sendTextMessage(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final chatGuid = map['chatGuid'] as String;
    final tempGuid = map['tempGuid'] as String;
    final message = map['message'] as String;
    final method = map['method'] as String?;
    final effectId = map['effectId'] as String?;
    final subject = map['subject'] as String?;
    final selectedMessageGuid = map['selectedMessageGuid'] as String?;
    final partIndex = map['partIndex'] as int?;
    final ddScan = map['ddScan'] as bool?;

    final response = await HttpSvc.message.sendText(
      chatGuid,
      tempGuid,
      message,
      method: method,
      effectId: effectId,
      subject: subject,
      selectedMessageGuid: selectedMessageGuid,
      partIndex: partIndex,
      ddScan: ddScan,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Sends a tapback via HTTP.
  static Future<Map<String, dynamic>> sendTapback(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final chatGuid = map['chatGuid'] as String;
    final selectedMessageText = map['selectedMessageText'] as String;
    final selectedMessageGuid = map['selectedMessageGuid'] as String;
    final reaction = map['reaction'] as String;
    final partIndex = map['partIndex'] as int?;
    final emoji = map['emoji'] as String?;

    final response = await HttpSvc.message.sendTapback(
      chatGuid,
      selectedMessageText,
      selectedMessageGuid,
      reaction,
      partIndex: partIndex,
      emoji: emoji,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Sends a multipart (mention / mixed-content) message via HTTP.
  static Future<Map<String, dynamic>> sendMultipartMessage(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final chatGuid = map['chatGuid'] as String;
    final tempGuid = map['tempGuid'] as String;
    final parts = (map['parts'] as List).cast<Map<String, dynamic>>();
    final effectId = map['effectId'] as String?;
    final subject = map['subject'] as String?;
    final selectedMessageGuid = map['selectedMessageGuid'] as String?;
    final partIndex = map['partIndex'] as int?;
    final ddScan = map['ddScan'] as bool?;

    final response = await HttpSvc.message.sendMultipart(
      chatGuid,
      tempGuid,
      parts,
      effectId: effectId,
      subject: subject,
      selectedMessageGuid: selectedMessageGuid,
      partIndex: partIndex,
      ddScan: ddScan,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Uploads each file, then sends one multipart message naming them in order.
  static Future<Map<String, dynamic>> sendMultiAttachmentMessage(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final chatGuid = map['chatGuid'] as String;
    final tempGuid = map['tempGuid'] as String;
    final files = (map['files'] as List).cast<Map<String, dynamic>>();

    final parts = <Map<String, dynamic>>[];
    for (final (index, file) in files.indexed) {
      final attachmentGuid = file['guid'] as String;
      final name = file['name'] as String;
      final upload = await HttpSvc.attachment.upload(
        file['path'] as String,
        name,
        onSendProgress: (count, total) {
          if (total <= 0) return;
          IsolateEventEmitter.emit(
            IsolateEvent.attachmentUploadProgress,
            {
              'chatGuid': chatGuid,
              'messageGuid': tempGuid,
              'attachmentGuid': attachmentGuid,
              'progress': count / total,
            },
          );
        },
      );
      parts.add({'partIndex': index, 'attachment': upload.data['data']['path'], 'name': name});
    }

    final response = await HttpSvc.message.sendMultipart(
      chatGuid,
      tempGuid,
      parts,
      effectId: map['effectId'] as String?,
      subject: map['subject'] as String?,
      selectedMessageGuid: map['selectedMessageGuid'] as String?,
      partIndex: map['partIndex'] as int?,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Sends an iMessage app balloon, with the picture at `imagePath` (if any) as its image.
  static Future<Map<String, dynamic>> sendAppMessage(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final imagePath = map['imagePath'] as String?;
    final response = await HttpSvc.message.sendAppMessage(
      map['chatGuid'] as String,
      balloonBundleId: map['balloonBundleId'] as String,
      url: map['url'] as String,
      sessionId: map['sessionId'] as String?,
      appName: map['appName'] as String?,
      appId: map['appId'] as int?,
      summary: map['summary'] as String?,
      caption: map['caption'] as String?,
      image: imagePath == null ? null : base64Encode(await File(imagePath).readAsBytes()),
      tempGuid: map['tempGuid'] as String,
      liveLayout: map['liveLayout'] as bool? ?? false,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Sends an attachment via HTTP.
  ///
  /// Reads the file from [filePath] inside the isolate and constructs
  /// [FormData] locally, avoiding cross-isolate byte transfer.
  static Future<Map<String, dynamic>> sendAttachmentMessage(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final chatGuid = map['chatGuid'] as String;
    final tempGuid = map['tempGuid'] as String;
    final filePath = map['filePath'] as String;
    final fileName = map['fileName'] as String;
    final fileSize = map['fileSize'] as int;
    final method = map['method'] as String?;
    final effectId = map['effectId'] as String?;
    final subject = map['subject'] as String?;
    final selectedMessageGuid = map['selectedMessageGuid'] as String?;
    final partIndex = map['partIndex'] as int?;
    final isAudioMessage = map['isAudioMessage'] as bool? ?? false;

    final response = await HttpSvc.message.sendAttachment(
      chatGuid,
      tempGuid,
      PlatformFile(
        name: fileName,
        path: filePath,
        size: fileSize,
      ),
      method: method,
      effectId: effectId,
      subject: subject,
      selectedMessageGuid: selectedMessageGuid,
      partIndex: partIndex,
      isAudioMessage: isAudioMessage,
      onSendProgress: (count, total) {
        if (total <= 0) return;
        IsolateEventEmitter.emit(
          IsolateEvent.attachmentUploadProgress,
          {
            'chatGuid': chatGuid,
            'messageGuid': tempGuid,
            'progress': count / total,
          },
        );
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
