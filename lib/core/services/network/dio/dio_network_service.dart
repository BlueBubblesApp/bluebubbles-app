import 'package:bluebubbles/core/abstractions/network/attachment_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/chat_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/contact_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/facetime_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/fcm_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/findmy_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/firebase_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/handle_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/message_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/abstractions/network/scheduled_messages_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/server_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/settings_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/theme_network_service.dart';
import 'package:bluebubbles/core/abstractions/service.dart';
import 'package:bluebubbles/core/lib/definitions/network_cancel_token.dart';
import 'package:bluebubbles/core/logging/named_logger.dart';
import 'package:bluebubbles/core/services/network/dio/dio_attachment_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_chat_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_contact_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_facetime_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_fcm_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_findmy_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_firebase_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_handle_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_message_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_scheduled_messages_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_server_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_settings_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_theme_network_service.dart';
import 'package:dio/dio.dart';
import 'package:bluebubbles/core/services/services.dart' as services;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';


class DioNetworkService extends NetworkService {
  @override
  String name = 'Dio Network Service';

  @override
  int version = 1;

  @override
  List<Service> dependencies = [services.settings];

  late Dio dio;

  String? originOverride;

  // Default opts for all requests
  Options get defaultOpts => Options(
    sendTimeout: Duration(seconds: services.settings.config.apiTimeout.value),
    receiveTimeout: Duration(seconds: services.settings.config.apiTimeout.value),
    followRedirects: true,
    maxRedirects: 1,
    headers: services.settings.config.customHeaders,
  );

  // Default opts for JSON requests
  Options get defaultJsonOpts => defaultOpts.copyWith(
    responseType: ResponseType.json,
    contentType: "application/json"
  );

  // Default opts for file Download requests
  Options get defaultDownloadOpts => defaultOpts.copyWith(
     responseType: ResponseType.bytes,
     sendTimeout: defaultOpts.receiveTimeout! * 12,
     receiveTimeout: defaultOpts.receiveTimeout! * 12,
     headers: services.settings.config.customHeaders
  );

  String get origin => originOverride ?? (Uri.parse(services.settings.config.serverAddress.value).hasScheme ? Uri.parse(services.settings.config.serverAddress.value).origin : '');
  String get apiRoot => "$origin/api/v1";

  @override
  MessageNetworkService get messages => DioMessageNetworkService(this);

  @override
  HandleNetworkService get handles => DioHandleNetworkService(this);

  @override
  ChatNetworkService get chats => DioChatNetworkService(this);

  @override
  AttachmentNetworkService get attachments => DioAttachmentNetworkService(this);

  @override
  FcmNetworkService get fcm => DioFcmNetworkService(this);

  @override
  FaceTimeNetworkService get facetime => DioFaceTimeNetworkService(this);

  @override
  FindMyNetworkService get findmy => DioFindMyNetworkService(this);

  @override
  ServerNetworkService get server => DioServerNetworkService(this);

  @override
  FirebaseNetworkService get firebase => DioFirebaseNetworkService(this);

  @override
  ContactNetworkService get contacts => DioContactNetworkService(this);

  @override
  SettingsNetworkService get settings => DioSettingsNetworkService(this);

  @override
  ThemeNetworkService get themes => DioThemeNetworkService(this);

  @override
  ScheduledMessagesNetworkService get scheduled => DioScheduledMessagesNetworkService(this);

  @override
  Future<void> initAllPlatforms() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: 15000),
    ));
    dio.interceptors.add(ApiInterceptor());
    return Future.value();
  }

  /// Helper function to build query params, this way we only need to add the
  /// required guid auth param in one place
  Map<String, dynamic> buildQueryParams([Map<String, dynamic> params = const {}]) {
    // we can't add items to a const map
    if (params.isEmpty) {
      params = {};
    }

    params['guid'] = services.settings.config.guidAuthKey.value;
    return params;
  }
  
   /// Global try-catch function
  Future<dynamic> requestWrapper(Future<dynamic> Function() func, {bool checkOrigin = true}) async {
    if (origin.isEmpty && checkOrigin) {
      return Future.error("No server URL!");
    }

    if (!hasInitialized) {
      await init();
    }

    int totalTries = 3;
    int retries = 0;
    List<int> retryCodes = [502, 503, 504];

    while (retries < totalTries) {
      try {
        return await func();
      } catch (e, s) {
        if (e is Response && retryCodes.contains(e.statusCode)) {
          retries++;

          log.warn("Retrying request due to ${e.statusCode} error");
          await Future.delayed(const Duration(seconds: 1));
        } else {
          return Future.error(e, s);
        }
      }
    }
  }

  /// Return the future with either a value or error, depending on response from API
  Future<dynamic> raiseForStatus(Response r) {
    // Default to 500 because if we don't get a status code back,
    // it's likely due to an error.
    if ((r.statusCode ?? 500) < 400) {
      return Future.value(r.data);
    } else {
      return Future.error(r.data);
    }
  }

  Future<dynamic> get(
    String path,
    {
      Map<String, dynamic> params = const {},
      Map<String, dynamic> headers = const {},
      NetworkCancelToken? cancelToken,
      Options? options,
      void Function(int, int)? onReceiveProgress
    }
  ) {
    return requestWrapper(() async {
      path = (path.startsWith('/')) ? path : '/$path';

      Options opts = options ?? defaultJsonOpts;
      opts.headers?.addAll(headers);

      final response = await dio.get(
          "$apiRoot$path",
          queryParameters: buildQueryParams(params),
          options: options ?? defaultJsonOpts,
          onReceiveProgress: onReceiveProgress
      );

      return raiseForStatus(response);
    });
  }

  Future<dynamic> post(
    String path,
    {
      Map<String, dynamic> params = const {},
      dynamic json = const {},
      Object? data,
      Map<String, dynamic> headers = const {},
      NetworkCancelToken? cancelToken,
      Options? options,
      void Function(int, int)? onReceiveProgress
    }
  ) {
    return dataRequest(
      "POST", path,
      params: params,
      json: json,
      data: data,
      headers: headers,
      cancelToken: cancelToken,
      options: options,
      onReceiveProgress: onReceiveProgress
    );
  }

  Future<dynamic> put(
    String path,
    {
      Map<String, dynamic> params = const {},
      dynamic json = const {},
      Object? data,
      Map<String, dynamic> headers = const {},
      NetworkCancelToken? cancelToken,
      Options? options,
      void Function(int, int)? onReceiveProgress
    }
  ) {
    return dataRequest(
      "PUT", path,
      params: params,
      json: json,
      data: data,
      headers: headers,
      cancelToken: cancelToken,
      options: options,
      onReceiveProgress: onReceiveProgress
    );
  }

  Future<dynamic> patch(
    String path,
    {
      Map<String, dynamic> params = const {},
      dynamic json = const {},
      Object? data,
      Map<String, dynamic> headers = const {},
      NetworkCancelToken? cancelToken,
      Options? options,
      void Function(int, int)? onReceiveProgress
    }
  ) {
    return dataRequest(
      "PATCH", path,
      params: params,
      json: json,
      data: data,
      headers: headers,
      cancelToken: cancelToken,
      options: options,
      onReceiveProgress: onReceiveProgress
    );
  }

  Future<dynamic> delete(
    String path,
    {
      Map<String, dynamic> params = const {},
      dynamic json = const {},
      Object? data,
      Map<String, dynamic> headers = const {},
      NetworkCancelToken? cancelToken,
      Options? options,
      void Function(int, int)? onReceiveProgress
    }
  ) {
    return dataRequest(
      "DELETE", path,
      params: params,
      json: json,
      data: data,
      headers: headers,
      cancelToken: cancelToken,
      options: options,
      onReceiveProgress: onReceiveProgress
    );
  }

  Future<dynamic> dataRequest(
    String method,
    String path,
    {
      Map<String, dynamic> params = const {},
      Object? data,
      dynamic json = const {},
      Map<String, dynamic> headers = const {},
      NetworkCancelToken? cancelToken,
      Options? options,
      void Function(int, int)? onReceiveProgress
    }
  ) {
    return requestWrapper(() async {
      if (!path.startsWith('http')) {
        path = (path.startsWith('/')) ? path : '/$path';
        path = "$apiRoot$path";
      }

      Options opts = options ?? defaultJsonOpts;
      opts.headers?.addAll(headers);

      dynamic call = dio.post;
      if (method.toUpperCase() == 'PUT') {
        call = dio.put;
      } else if (method.toUpperCase() == 'PATCH') {
        call = dio.patch;
      } else if (method.toUpperCase() == 'DELETE') {
        call = dio.delete;
      }

      final response = await call(
          "$apiRoot$path",
          queryParameters: buildQueryParams(params),
          data: data ?? json,
          options: options ?? defaultJsonOpts,
          onReceiveProgress: onReceiveProgress
      );

      return raiseForStatus(response);
    });
  }

  /// Test most API GET requests (the ones that don't have required parameters)
  void testApi() {
    Stopwatch s = Stopwatch();
    group("API Service Test", () {
      test("Ping", () async {
        s.start();
        var res = await server.ping();
        expect(res.data['message'], "pong");
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Info", () async {
        s.start();
        var res = await server.info();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Totals", () async {
        s.start();
        var res = await server.totalStatistics();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Media", () async {
        s.start();
        var res = await server.mediaStatistics();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Logs", () async {
        s.start();
        var res = await server.logs();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("FCM Client", () async {
        s.start();
        var res = await fcm.getClientJson();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Attachment Count", () async {
        s.start();
        var res = await attachments.count();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chats", () async {
        s.start();
        var res = await chats.query();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chat Count", () async {
        s.start();
        var res = await chats.count();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Message Count", () async {
        s.start();
        var res = await messages.count();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("My Message Count", () async {
        s.start();
        var res = await messages.count(onlyMe: true);
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Messages", () async {
        s.start();
        var res = await messages.query();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Handle Count", () async {
        s.start();
        var res = await handles.count();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("iCloud Contacts", () async {
        s.start();
        var res = await contacts.getAll();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Theme Backup", () async {
        s.start();
        var res = await themes.getAll();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Settings Backup", () async {
        s.start();
        var res = await settings.getAll();
        expect(res.data['status'], 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Landing Page", () async {
        s.start();
        var res = await server.landingPage();
        expect(res.statusCode, 200);
        s.stop();
        log.info("Request took ${s.elapsedMilliseconds} ms");
      });
    });
  }
}

/// Intercepts API requests, responses, and errors and logs them to console
class ApiInterceptor extends Interceptor {

  final log = NamedLogger("API Interceptor");

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log.info("[Request]: ${options.method} ${options.path}");
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log.info("[Response]: ${response.statusCode} ${response.requestOptions.path}");
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log.error("PATH: ${err.requestOptions.path}");
    log.error(err.error);
    log.error(err.requestOptions.contentType);
    log.error(err.response?.data);
    if (err.response != null && err.response!.data is Map) return handler.resolve(err.response!);
    if (err.response != null) {
      return handler.resolve(Response(data: {
        'status': err.response!.statusCode,
        'error': {
          'type': 'Error',
          'error': err.response!.data.toString()
        }
      }, requestOptions: err.requestOptions, statusCode: err.response!.statusCode));
    }
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