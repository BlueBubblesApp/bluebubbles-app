import 'package:bluebubbles/core/abstractions/network/message_network_service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/models/global/platform_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;


class DioMessageNetworkService implements MessageNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioMessageNetworkService(this.network);

  @override
  Future<dynamic> count({bool updated = false, bool onlyMe = false, DateTime? after, DateTime? before, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    // we don't have a query that supports providing updated and onlyMe
    if (updated && onlyMe) {
      throw Exception("Cannot provide both updated and onlyMe");
    }

    Map<String, dynamic> params = {};
    if (after != null) params['after'] = after.millisecondsSinceEpoch;
    if (before != null) params['before'] = before.millisecondsSinceEpoch;

    return await network.get(
      "/message/count${updated ? "/updated" : onlyMe ? "/me" : ""}",
      params: params,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  /// Query the messages DB. Use [withQuery] to specify what you would like in
  /// the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"handle"`, `"chats.participants"` / `"chat.participants"`,  `"attachment.metadata"`, `"attributedBody"
  @override
  Future<dynamic> query({List<String> withQuery = const [], List<dynamic> where = const [], String sort = "DESC", int? before, int? after, String? chatGuid, int offset = 0, int limit = 100, bool convertAttachments = true, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/message/query",
      json: {
        "with": withQuery,
        "where": where,
        "sort": sort,
        "before": before,
        "after": after,
        "chatGuid": chatGuid,
        "offset": offset,
        "limit": limit,
        "convertAttachments": convertAttachments
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  /// Get a single message by [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"chats.participants"` / `"chat.participants"`, `"attributedBody"` (set as one string, comma separated, no spaces)
  @override
  Future<dynamic> get(String guid, {String withQuery = "", NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/message/$guid",
      params: {"with": withQuery},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  /// Get embedded media for a single digital touch or handwritten message by [guid].
  @override
  Future<dynamic> getEmbeddedMedia(String guid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.get(
      "/message/$guid/embedded-media",
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  /// Send a message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [message] is the
  /// body of the message. Optionally provide [method] to send via private API,
  /// [effectId] to send with an effect, or [subject] to send with a subject.
  @override
  Future<dynamic> sendText(String chatGuid, String tempGuid, String message, {String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? ddScan, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    Map<String, dynamic> data = {
      "chatGuid": chatGuid,
      "tempGuid": tempGuid,
      "message": message.isEmpty && (subject?.isNotEmpty ?? false) ? " " : message,
      "method": method,
    };

    data.addAllIf(settings.config.enablePrivateAPI.value && settings.config.privateAPISend.value, {
      "effectId": effectId,
      "subject": subject,
      "selectedMessageGuid": selectedMessageGuid,
      "partIndex": partIndex,
      "ddScan": ddScan,
    });

    return await network.post(
      "/message/text",
      json: data,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }

  /// Send an attachment. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [file] is the
  /// body of the message.
  @override
  Future<dynamic> sendAttachment(String chatGuid, String tempGuid, PlatformFile file, {String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? isAudioMessage, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    final fileName = file.name;
    final formData = FormData.fromMap({
      "attachment": kIsWeb ? MultipartFile.fromBytes(file.bytes!, filename: fileName) : await MultipartFile.fromFile(file.path!, filename: fileName),
      "chatGuid": chatGuid,
      "tempGuid": tempGuid,
      "name": fileName,
      "method": method
    });

    if (settings.config.enablePrivateAPI.value && settings.config.privateAPIAttachmentSend.value) {
      Map<String, dynamic> papiData = {
        "effectId": effectId,
        "subject": subject,
        "selectedMessageGuid": selectedMessageGuid,
        "partIndex": partIndex,
        "isAudioMessage": isAudioMessage,
      };

      papiData.removeWhere((key, value) => value == null);
      formData.fields.addAll(papiData.entries.map((entry) => MapEntry(entry.key, entry.value.toString())));
    }

    return await network.post(
      "/message/attachment",
      data: formData,
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  /// Send a message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [message] is the
  /// body of the message. Optionally provide [method] to send via private API,
  /// [effectId] to send with an effect, or [subject] to send with a subject.
  @override
  Future<dynamic> sendMultipart(String chatGuid, String tempGuid, List<Map<String, dynamic>> parts, {String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? ddScan, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    Map<String, dynamic> data = {
      "chatGuid": chatGuid,
      "tempGuid": tempGuid,
      "effectId": effectId,
      "subject": subject,
      "selectedMessageGuid": selectedMessageGuid,
      "partIndex": partIndex,
      "parts": parts,
      "ddScan": ddScan,
    };

    return await network.post(
      "/message/multipart",
      json: data,
      options: network.defaultDownloadOpts,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  /// Send a reaction. [chatGuid] specifies the chat, [selectedMessageText]
  /// specifies the text of the message being reacted on, [selectedMessageGuid]
  /// is the guid of the message, and [reaction] is the reaction type.
  @override
  Future<dynamic> sendTapback(String chatGuid, String selectedMessageText, String selectedMessageGuid, String reaction, {int? partIndex, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/message/react",
      json: {
        "chatGuid": chatGuid,
        "selectedMessageText": selectedMessageText,
        "selectedMessageGuid": selectedMessageGuid,
        "reaction": reaction,
        "partIndex": partIndex,
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future<dynamic> unsend(String selectedMessageGuid, {int? partIndex, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/message/$selectedMessageGuid/unsend",
      json: {
        "partIndex": partIndex ?? 0,
      },
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
  
  @override
  Future<dynamic> edit(String selectedMessageGuid, String edit, String backwardsCompatText, {int? partIndex, NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/message/$selectedMessageGuid/edit",
      json: {
        "editedMessage": edit,
        "backwardsCompatibilityMessage": backwardsCompatText,
        "partIndex": partIndex ?? 0,
      },
      cancelToken: cancelToken
    );
  }
  
  @override
  Future<dynamic> notify(String selectedMessageGuid, {NetworkCancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    return await network.post(
      "/message/$selectedMessageGuid/notify",
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress
    );
  }
}