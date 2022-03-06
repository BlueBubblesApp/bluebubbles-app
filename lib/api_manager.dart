import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:universal_io/io.dart';

/// Get an instance of our [ApiService]
ApiService api = Get.isRegistered<ApiService>() ? Get.find<ApiService>() : Get.put(ApiService());

/// Class that manages foreground network requests from client to server, using
/// GET or POST requests.
class ApiService extends GetxService {
  late Dio dio;

  /// Get the URL origin from the current server address
  String get origin => Uri.parse(SettingsManager().settings.serverAddress.value).origin + "/api/v1";

  /// Helper function to build query params, this way we only need to add the
  /// required guid auth param in one place
  Map<String, dynamic> buildQueryParams([Map<String, dynamic> params = const {}]) {
    // we can't add items to a const map
    if (params.isEmpty) {
      params = {};
    }
    params['guid'] = SettingsManager().settings.guidAuthKey;
    return params;
  }

  /// Initialize dio with a couple options and intercept all requests for logging
  @override
  void onInit() {
    dio = Dio(BaseOptions(connectTimeout: 15000, receiveTimeout: 15000, sendTimeout: 15000));
    dio.interceptors.add(ApiInterceptor());
    // Uncomment to run tests on most API requests
    // testAPI();
    super.onInit();
  }

  /// Check ping time for server
  Future<Response> ping({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/ping",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get server metadata like server version, macOS version, current URL, etc
  Future<Response> serverInfo({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/server/info",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get server totals (number of handles, messages, chats, and attachments)
  Future<Response> serverStatTotals({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/server/statistics/totals",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get server media totals (number of images, videos, and locations)
  Future<Response> serverStatMedia({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/server/statistics/media",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get server logs, [count] defines the length of logs
  Future<Response> serverLogs({int count = 100, CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/server/logs",
        queryParameters: buildQueryParams({"count": count}),
        cancelToken: cancelToken
    );
  }

  /// Add a new FCM Device to the server. Must provide [name] and [identifier]
  Future<Response> addFcmDevice(String name, String identifier, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/fcm/device",
        data: {"name": name, "identifier": identifier},
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get the current FCM data from the server
  Future<Response> fcmClient({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/fcm/client",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get the attachemnt data for the specified [guid]
  Future<Response> attachment(String guid, {CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/attachment/$guid",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get the attachment data for the specified [guid]
  Future<Response> downloadAttachment(String guid, {void Function(int, int)? onReceiveProgress, CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/attachment/$guid/download",
        queryParameters: buildQueryParams(),
        options: Options(responseType: ResponseType.bytes, receiveTimeout: 1800000),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
    );
  }

  /// Get the number of attachments in the server iMessage DB
  Future<Response> attachmentCount({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/attachment/count",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Query the chat DB. Use [withQuery] to specify what you would like in the
  /// response or how to query the DB.
  ///
  /// [withQuery] options: `"participants"`, `"lastmessage"`, `"sms"`, `"archived"`
  Future<Response> chats({List<String> withQuery = const [], int offset = 0, int limit = 100, CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/chat/query",
        queryParameters: buildQueryParams(),
        data: {"with": withQuery, "offset": offset, "limit": limit},
        cancelToken: cancelToken
    );
  }

  /// Get the messages for the specified chat (using [guid]). Use [withQuery]
  /// to specify what you would like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"attachment"` / `"attachments"`, `"handle"` / `"handles"`
  /// `"sms"` (set as one string, comma separated, no spaces)
  Future<Response> chatMessages(String guid, {String withQuery = "", String sort = "DESC", int before = 10, int after = 10, int offset = 0, int limit = 100, CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/chat/$guid/message",
        queryParameters: buildQueryParams({"with": withQuery, "sort": sort, "before": before, "after": after, "offset": offset, "limit": limit}),
        cancelToken: cancelToken
    );
  }

  /// Add / remove a participant to the specified chat (using [guid]). [method]
  /// tells whether to add or remove, and use [address] to specify the address
  /// of the participant to add / remove.
  Future<Response> chatParticipant(String method, String guid, String address, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/chat/$guid/participant/$method",
        queryParameters: buildQueryParams(),
        data: {"address": address},
        cancelToken: cancelToken
    );
  }

  /// Update the specified chat (using [guid]). Use [displayName] to specify the
  /// new chat name.
  Future<Response> updateChat(String guid, String displayName, {CancelToken? cancelToken}) async {
    return await dio.put(
        "$origin/chat/$guid",
        queryParameters: buildQueryParams(),
        data: {"displayName": displayName},
        cancelToken: cancelToken
    );
  }

  /// Create a chat with the specified [addresses]. Requires an initial [message]
  /// to send.
  Future<Response> createChat(List<String> addresses, String? message, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/chat/new",
        queryParameters: buildQueryParams(),
        data: {"addresses": addresses},
        cancelToken: cancelToken
    );
  }

  /// Get the number of chats in the server iMessage DB
  Future<Response> chatCount({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/chat/count",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get a single chat by its [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"participants"`, `"lastmessage"`
  /// (set as one string, comma separated, no spaces)
  Future<Response> singleChat(String guid, {String withQuery = "", CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/chat/$guid",
        queryParameters: buildQueryParams({"with": withQuery}),
        cancelToken: cancelToken
    );
  }

  /// Get the number of messages in the server iMessage DB
  Future<Response> messageCount({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/message/count",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get the number of messages the current user has sent in the server iMessage
  /// DB
  Future<Response> myMessageCount({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/message/count/me",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Query the messages DB. Use [withQuery] to specify what you would like in
  /// the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"handle"`, `"sms"`, `"chats.participants"` / `"chat.participants"`
  Future<Response> messages({List<String> withQuery = const [], List<String> where = const [], String sort = "DESC", int? before, int? after, String? chatGuid, int offset = 0, int limit = 100, CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/message/query",
        queryParameters: buildQueryParams(),
        data: {"with": withQuery, "where": where, "sort": sort, "before": before, "after": after, "chatGuid": chatGuid, "offset": offset, "limit": limit},
        cancelToken: cancelToken
    );
  }

  /// Get a single message by [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"chats.participants"` / `"chat.participants"`
  /// (set as one string, comma separated, no spaces)
  Future<Response> singleMessage(String guid, {String withQuery = "", CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/message/$guid",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Send a message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [message] is the
  /// body of the message. Optionally provide [method] to send via private API,
  /// [effectId] to send with an effect, or [subject] to send with a subject.
  Future<Response> sendMessage(String chatGuid, String tempGuid, String message, {String? method, String? effectId, String? subject, String? selectedMessageGuid, CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/message/text",
        queryParameters: buildQueryParams(),
        data: {
          "chatGuid": chatGuid,
          "tempGuid": tempGuid,
          "message": message.isEmpty && (subject?.isNotEmpty ?? false) ? " " : message,
          "method": method,
          "effectId": effectId,
          "subject": subject,
          "selectedMessageGuid": selectedMessageGuid,
        },
        cancelToken: cancelToken
    );
  }

  /// Send an attachment. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [file] is the
  /// body of the message.
  Future<Response> sendAttachment(String chatGuid, String tempGuid, File file, {void Function(int, int)? onSendProgress, CancelToken? cancelToken}) async {
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
      "chatGuid": chatGuid,
      "tempGuid": tempGuid,
      "name": fileName,
    });
    return await dio.post(
      "$origin/message/attachment",
      queryParameters: buildQueryParams(),
      cancelToken: cancelToken,
      data: formData,
      onSendProgress: onSendProgress
    );
  }

  /// Send a reaction. [chatGuid] specifies the chat, [selectedMessageText]
  /// specifies the text of the message being reacted on, [selectedMessageGuid]
  /// is the guid of the message, and [reaction] is the reaction type.
  Future<Response> sendTapback(String chatGuid, String selectedMessageText, String selectedMessageGuid, String reaction, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/message/react",
        queryParameters: buildQueryParams(),
        data: {
          "chatGuid": chatGuid,
          "selectedMessageText": selectedMessageText,
          "selectedMessageGuid": selectedMessageGuid,
          "reaction": reaction,
        },
        cancelToken: cancelToken
    );
  }

  /// Get the number of handles in the server iMessage DB
  Future<Response> handleCount({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/handle/count",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get a single handle by [guid]
  Future<Response> handle(String guid, {CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/handle/$guid",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get all icloud contacts
  Future<Response> contacts({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/contact",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get specific icloud contacts with a list of [addresses], either phone
  /// numbers or emails
  Future<Response> contactByAddresses(List<String> addresses, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/contact/query",
        queryParameters: buildQueryParams(),
        data: {"addresses": addresses},
        cancelToken: cancelToken
    );
  }

  /// Get backup theme JSON, if any
  Future<Response> getTheme({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/backup/theme",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Set theme backup with the provided [json]
  Future<Response> setTheme(String name, Map<String, dynamic> json, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/backup/theme",
        data: {"name": name, "data": json},
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get settings backup, if any
  Future<Response> getSettings({CancelToken? cancelToken}) async {
    return await dio.get(
        "$origin/backup/settings",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Set settings backup with the provided [json]
  Future<Response> setSettings(String name, Map<String, dynamic> json, {CancelToken? cancelToken}) async {
    return await dio.post(
        "$origin/backup/settings",
        data: {"name": name, "data": json},
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  /// Get the basic landing page for the server URL
  Future<Response> landingPage({CancelToken? cancelToken}) async {
    return await dio.get(
        origin.replaceAll("/api/v1", ""),
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
    );
  }

  Future<Response> downloadGiphy(String url, {CancelToken? cancelToken}) async {
    return await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
    );
  }

  /// Test most API GET requests (the ones that don't have required parameters)
  void testAPI() {
    Stopwatch s = Stopwatch();
    group("API Service Test", () {
      test("Ping", () async {
        s.start();
        var res = await ping();
        expect(res.data['message'], "pong");
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Info", () async {
        s.start();
        var res = await serverInfo();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Totals", () async {
        s.start();
        var res = await serverStatTotals();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Media", () async {
        s.start();
        var res = await serverStatMedia();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Logs", () async {
        s.start();
        var res = await serverLogs();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("FCM Client", () async {
        s.start();
        var res = await fcmClient();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Attachment Count", () async {
        s.start();
        var res = await attachmentCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chats", () async {
        s.start();
        var res = await chats();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chat Count", () async {
        s.start();
        var res = await chatCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Message Count", () async {
        s.start();
        var res = await messageCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("My Message Count", () async {
        s.start();
        var res = await myMessageCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Messages", () async {
        s.start();
        var res = await messages();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Handle Count", () async {
        s.start();
        var res = await handleCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("iCloud Contacts", () async {
        s.start();
        var res = await contacts();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Theme Backup", () async {
        s.start();
        var res = await getTheme();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Settings Backup", () async {
        s.start();
        var res = await getSettings();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Landing Page", () async {
        s.start();
        var res = await landingPage();
        expect(res.statusCode, 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
    });
  }
}

/// Intercepts API requests, responses, and errors and logs them to console
class ApiInterceptor extends Interceptor {

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Logger.info("PATH: ${options.path}", tag: "REQUEST[${options.method}]");
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Logger.info("PATH: ${response.requestOptions.path}", tag: "RESPONSE[${response.statusCode}]");
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    Logger.error("PATH: ${err.requestOptions.path}", tag: "ERROR[${err.response?.statusCode}]");
    Logger.error(err.error, tag: "ERROR[${err.response?.statusCode}]");
    Logger.error(err.requestOptions.contentType, tag: "ERROR[${err.response?.statusCode}]");
    Logger.error(err.response?.data, tag: "ERROR[${err.response?.statusCode}]");
    if (err.response != null) return handler.resolve(err.response!);
    if (describeEnum(err.type).contains("Timeout")) {
      return handler.resolve(Response(data: {
        'status': 500,
        'error': {
          'type': 'timeout',
          'error': 'Failed to receive response from server.'
        }
      }, requestOptions: err.requestOptions, statusCode: 500));
    }
    return super.onError(err, handler);
  }
}