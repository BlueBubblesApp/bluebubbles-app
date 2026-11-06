import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

class MessageApi {
  final BaseApi _svc;

  MessageApi(this._svc);

  /// Get the number of messages in the server iMessage DB
  Future<Response> getCount({
    bool updated = false,
    bool onlyMe = false,
    DateTime? after,
    DateTime? before,
    CancelToken? cancelToken,
  }) async {
    // we don't have a query that supports providing updated and onlyMe
    assert(updated != true && onlyMe != true);
    Map<String, dynamic> params = {};
    if (after != null) params['after'] = after.millisecondsSinceEpoch;
    if (before != null) params['before'] = before.millisecondsSinceEpoch;
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/message/count${updated ? "/updated" : onlyMe ? "/me" : ""}",
        queryParameters: _svc.buildQueryParams(params),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Query the messages DB. Use [withQuery] to specify what you would like in
  /// the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"handle"`, `"chats.participants"` / `"chat.participants"`,
  /// `"attachment.metadata"`, `"attributedBody"`
  Future<Response> query({
    List<String> withQuery = const [],
    List<dynamic> where = const [],
    String sort = "DESC",
    int? before,
    int? after,
    String? chatGuid,
    int offset = 0,
    int limit = 100,
    bool convertAttachments = true,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/query",
        queryParameters: _svc.buildQueryParams(),
        data: {
          "with": withQuery,
          "where": where,
          "sort": sort,
          "before": before,
          "after": after,
          "chatGuid": chatGuid,
          "offset": offset,
          "limit": limit,
          "convertAttachments": convertAttachments,
        },
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get a single message by [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"chats.participants"` / `"chat.participants"`, `"attributedBody"`
  /// (set as one string, comma separated, no spaces)
  Future<Response> fetchOne(String guid, {String withQuery = "", CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/message/$guid",
        queryParameters: _svc.buildQueryParams({"with": withQuery}),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get embedded media for a single digital touch or handwritten message by [guid]
  Future<Response> downloadEmbeddedMedia(
    String guid, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/message/$guid/embedded-media",
        queryParameters: _svc.buildQueryParams(),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Send a message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [message] is the
  /// body of the message. Optionally provide [method] to send via private API,
  /// [effectId] to send with an effect, or [subject] to send with a subject.
  Future<Response> sendText(
    String chatGuid,
    String tempGuid,
    String message, {
    String? method,
    String? effectId,
    String? subject,
    String? selectedMessageGuid,
    int? partIndex,
    bool? ddScan,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      Map<String, dynamic> data = {
        "chatGuid": chatGuid,
        "tempGuid": tempGuid,
        "message": message.isEmpty && (subject?.isNotEmpty ?? false) ? " " : message,
        "method": method,
      };

      data.addAllIf(SettingsSvc.settings.enablePrivateAPI.value && SettingsSvc.settings.privateAPISend.value, {
        "effectId": effectId,
        "subject": subject,
        "selectedMessageGuid": selectedMessageGuid,
        "partIndex": partIndex,
      });

      if (SettingsSvc.settings.enablePrivateAPI.value &&
          SettingsSvc.settings.privateAPISend.value &&
          SettingsSvc.serverDetails.isMinVentura) {
        data["ddScan"] = ddScan;
      }

      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/text",
        queryParameters: _svc.buildQueryParams(),
        data: data,
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Send an attachment. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [file] is the
  /// body of the message.
  Future<Response> sendAttachment(
    String chatGuid,
    String tempGuid,
    PlatformFile file, {
    void Function(int, int)? onSendProgress,
    String? method,
    String? effectId,
    String? subject,
    String? selectedMessageGuid,
    int? partIndex,
    bool? isAudioMessage,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final fileName = file.name;
      final formData = FormData.fromMap({
        "attachment": kIsWeb
            ? MultipartFile.fromBytes(file.bytes!, filename: fileName)
            : await MultipartFile.fromFile(file.path!, filename: fileName),
        "chatGuid": chatGuid,
        "tempGuid": tempGuid,
        "name": fileName,
        "method": method,
      });

      if (SettingsSvc.settings.enablePrivateAPI.value && SettingsSvc.settings.privateAPIAttachmentSend.value) {
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

      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/attachment",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          sendTimeout: _svc.dio.options.sendTimeout! * 12,
          receiveTimeout: _svc.dio.options.receiveTimeout! * 12,
          headers: _svc.headers,
        ),
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Send a multipart message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [parts] is the list
  /// of message parts.
  Future<Response> sendMultipart(
    String chatGuid,
    String tempGuid,
    List<Map<String, dynamic>> parts, {
    String? effectId,
    String? subject,
    String? selectedMessageGuid,
    int? partIndex,
    bool? ddScan,
    bool hasAttachments = false,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      Map<String, dynamic> data = {
        "chatGuid": chatGuid,
        "tempGuid": tempGuid,
        "effectId": effectId,
        "subject": subject,
        "selectedMessageGuid": selectedMessageGuid,
        "partIndex": partIndex,
        "parts": parts,
      };

      if (SettingsSvc.serverDetails.isMinVentura) {
        data["ddScan"] = ddScan;
      }

      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/multipart",
        queryParameters: _svc.buildQueryParams(),
        data: data,
        cancelToken: cancelToken,
        // As with sendAttachment, the server answers once iMessage has sent the media
        options: hasAttachments ? Options(receiveTimeout: _svc.dio.options.receiveTimeout! * 12) : null,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get the decoded iMessage app payload (url, session id, captions) of message [guid]. v2 servers only.
  Future<Response> getAppMessage(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.origin}/api/v2/message/app/$guid",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Send an iMessage app balloon with the app's own payload [url], passed through untouched. v2 servers only.
  /// [image] is the balloon's picture (e.g. the game board) as base64 JPEG, PNG or HEIC, at most 4 MB. [tempGuid]
  /// lets the server drop a retried duplicate. [liveLayout] marks the balloon live, so a recipient with the app draws
  /// it rather than the template.
  Future<Response> sendAppMessage(
    String chatGuid, {
    required String balloonBundleId,
    required String url,
    String? sessionId,
    String? appName,
    int? appId,
    String? summary,
    String? caption,
    String? image,
    String? tempGuid,
    bool liveLayout = false,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.origin}/api/v2/message/app",
        queryParameters: _svc.buildQueryParams(),
        data: {
          "chatGuid": chatGuid,
          "balloonBundleId": balloonBundleId,
          "url": url,
          "sessionId": sessionId,
          "appName": appName,
          "appId": appId,
          "summary": summary,
          "caption": caption,
          "image": image,
          "tempGuid": tempGuid,
          "liveLayout": liveLayout,
        },
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Send a reaction. [chatGuid] specifies the chat, [selectedMessageText]
  /// specifies the text of the message being reacted on, [selectedMessageGuid]
  /// is the guid of the message, and [reaction] is the reaction type.
  Future<Response> sendTapback(
    String chatGuid,
    String selectedMessageText,
    String selectedMessageGuid,
    String reaction, {
    int? partIndex,
    String? emoji,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/react",
        queryParameters: _svc.buildQueryParams(),
        data: {
          "chatGuid": chatGuid,
          "selectedMessageText": selectedMessageText,
          "selectedMessageGuid": selectedMessageGuid,
          "reaction": reaction,
          "partIndex": partIndex,
          // Required with reaction "emoji" / "-emoji"
          "emoji": ?emoji,
        },
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Unsend a message part
  Future<Response> unsend(String selectedMessageGuid, {int? partIndex, CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/$selectedMessageGuid/unsend",
        queryParameters: _svc.buildQueryParams(),
        data: {"partIndex": partIndex ?? 0},
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Edit a sent message
  Future<Response> edit(
    String selectedMessageGuid,
    String edit,
    String backwardsCompatText, {
    int? partIndex,
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/$selectedMessageGuid/edit",
        queryParameters: _svc.buildQueryParams(),
        data: {
          "editedMessage": edit,
          "backwardsCompatibilityMessage": backwardsCompatText,
          "partIndex": partIndex ?? 0,
        },
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Notify (ping) a message
  Future<Response> notify(String selectedMessageGuid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/$selectedMessageGuid/notify",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Get scheduled messages from server
  Future<Response> getScheduled({CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.get(
        "${_svc.apiRoot}/message/schedule",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Create a scheduled message
  Future<Response> createScheduled(
    String chatGuid,
    String message,
    DateTime date,
    Map<String, dynamic> schedule, {
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/message/schedule",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
        data: {
          "type": "send-message",
          "payload": {
            "chatGuid": chatGuid,
            "message": message,
            "method": SettingsSvc.settings.privateAPISend.value ? 'private-api' : "apple-script",
          },
          "scheduledFor": date.millisecondsSinceEpoch,
          "schedule": schedule,
        },
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Update a scheduled message
  Future<Response> updateScheduled(
    int id,
    String chatGuid,
    String message,
    DateTime date,
    Map<String, dynamic> schedule, {
    CancelToken? cancelToken,
  }) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.put(
        "${_svc.apiRoot}/message/schedule/$id",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
        data: {
          "type": "send-message",
          "payload": {"chatGuid": chatGuid, "message": message, "method": "apple-script"},
          "scheduledFor": date.millisecondsSinceEpoch,
          "schedule": schedule,
        },
      );
      return _svc.returnSuccessOrError(response);
    });
  }

  /// Delete a scheduled message
  Future<Response> deleteScheduled(int id, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.delete(
        "${_svc.apiRoot}/message/schedule/$id",
        queryParameters: _svc.buildQueryParams(),
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}
