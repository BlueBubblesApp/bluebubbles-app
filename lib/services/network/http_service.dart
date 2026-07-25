import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/network/api/attachment_api.dart';
import 'package:bluebubbles/services/network/api/backup_api.dart';
import 'package:bluebubbles/services/network/api/base_api.dart';
import 'package:bluebubbles/services/network/api/chat_api.dart';
import 'package:bluebubbles/services/network/api/contact_api.dart';
import 'package:bluebubbles/services/network/api/facetime_api.dart';
import 'package:bluebubbles/services/network/api/fcm_api.dart';
import 'package:bluebubbles/services/network/api/icloud_api.dart';
import 'package:bluebubbles/services/network/api/firebase_api.dart';
import 'package:bluebubbles/services/network/api/handle_api.dart';
import 'package:bluebubbles/services/network/api/message_api.dart';
import 'package:bluebubbles/services/network/api/server_api.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/services/network/user_certificates.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:universal_io/io.dart';
import 'package:get_it/get_it.dart';

/// Get an instance of our [HttpService]
// ignore: non_constant_identifier_names
HttpService get HttpSvc => GetIt.I<HttpService>();

/// Class that manages foreground network requests from client to server, using
/// GET or POST requests.
class HttpService implements BaseApi {
  @override
  late Dio dio;
  String? originOverride;

  // ── Sub-services ────────────────────────────────────────────────────────────
  late ServerApi server;
  late FcmApi fcm;
  late AttachmentApi attachment;
  late ChatApi chat;
  late MessageApi message;
  late HandleApi handle;
  late ContactApi contact;
  late BackupApi backup;
  late FaceTimeApi faceTime;
  late iCloudApi icloud;
  late FirebaseApi firebase;

  /// Get the URL origin from the current server address
  @override
  String get origin =>
      originOverride ??
      (Uri.parse(SettingsSvc.settings.serverAddress.value).hasScheme
          ? Uri.parse(SettingsSvc.settings.serverAddress.value).origin
          : '');
  @override
  String get apiRoot => "$origin/api/v1";

  /// iOS font download status
  RxBool downloadingFont = false.obs;
  RxnDouble fontDownloadProgress = RxnDouble();
  RxnInt fontDownloadTotalSize = RxnInt();

  /// Helper function to build query params, this way we only need to add the
  /// required guid auth param in one place
  @override
  Map<String, dynamic> buildQueryParams([Map<String, dynamic> params = const {}]) {
    // we can't add items to a const map
    if (params.isEmpty) {
      params = {};
    }
    params['guid'] = SettingsSvc.settings.guidAuthKey.value;
    return params;
  }

  @override
  Future<Response> runApiGuarded(Future<Response> Function() func, {bool checkOrigin = true}) async {
    if (HttpSvc.origin.isEmpty && checkOrigin) {
      return Future.error("No server URL!");
    }
    try {
      return await func();
    } catch (e, s) {
      // try again if 502 error and Cloudflare
      if (e is Response && e.statusCode == 502 && apiRoot.contains("trycloudflare")) {
        try {
          return await func();
        } catch (e, s) {
          return Future.error(e, s);
        }
      }
      return Future.error(e, s);
    }
  }

  /// Return the future with either a value or error, depending on response from API
  @override
  Future<Response> returnSuccessOrError(Response r) {
    if (r.statusCode == 200) {
      return Future.value(r);
    } else {
      return Future.error(r);
    }
  }

  @override
  Map<String, String> get headers {
    final extraHeaders = Map<String, String>.from(SettingsSvc.settings.customHeaders.value);
    if (SettingsSvc.settings.serverAddress.contains('ngrok')) {
      extraHeaders['ngrok-skip-browser-warning'] = 'true';
    } else if (SettingsSvc.settings.serverAddress.contains('zrok')) {
      extraHeaders['skip_zrok_interstitial'] = 'true';
    }

    return extraHeaders;
  }

  Future<void> init() async {
    dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: SettingsSvc.settings.apiTimeout.value),
      receiveTimeout: Duration(milliseconds: SettingsSvc.settings.apiTimeout.value),
      sendTimeout: Duration(milliseconds: SettingsSvc.settings.apiTimeout.value),
      headers: headers,
    ));
    // Use IOHttpClientAdapter with certificate validation so that:
    // 1. Self-signed server certs are accepted via shouldAcceptCertificate.
    // 2. Device-level user-installed certificates (Android) are trusted by
    //    loading them into the SecurityContext via UserCertificates.
    // NativeAdapter was removed because it bypasses Dart's HttpOverrides and
    // therefore the shouldAcceptCertificate callback, breaking self-signed cert support.
    if (!kIsWeb) {
      // Pre-fetch user cert context (async; Android only — null on other platforms).
      final SecurityContext? userCertContext = await UserCertificates().getContext();
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient(context: userCertContext);
          client.badCertificateCallback = shouldAcceptCertificate;
          return client;
        },
      );
    }
    dio.interceptors.add(ApiInterceptor());

    // Initialise sub-services after dio is ready.
    server = ServerApi(this);
    fcm = FcmApi(this);
    attachment = AttachmentApi(this);
    chat = ChatApi(this);
    message = MessageApi(this);
    handle = HandleApi(this);
    contact = ContactApi(this);
    backup = BackupApi(this);
    faceTime = FaceTimeApi(this);
    icloud = iCloudApi(this);
    firebase = FirebaseApi(this);

    // Uncomment to run tests on most API requests
    // testAPI();
  }

  void updateHeaders() {
    dio.options.headers = headers;
  }

  Future<Response> downloadFromUrl(String url, {Function(int, int)? progress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        url,
        options: Options(
            responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: progress,
      );
      return returnSuccessOrError(response);
    });
  }

  Future<void> downloadAppleEmojiFont() async {
    if (downloadingFont.value) return;

    final response = await downloadFromUrl(
        "https://github.com/BlueBubblesApp/bluebubbles-fonts/releases/latest/download/AppleColorEmoji.ttf",
        progress: (current, total) {
      if (current <= total) {
        downloadingFont.value = true;
        fontDownloadProgress.value = current / total;
        fontDownloadTotalSize.value = total;
      }
    }).catchError((error) {
      downloadingFont.value = false;
      fontDownloadProgress.value = null;
      fontDownloadTotalSize.value = null;

      return Response(requestOptions: RequestOptions(path: ''));
    });

    if (response.statusCode == 200) {
      try {
        final Uint8List data = response.data;
        final file = File(join(FilesystemSvc.fontPath, 'apple.ttf'));
        await file.create(recursive: true);
        await file.writeAsBytes(data);
        FilesystemSvc.fontExistsOnDisk.value = true;
        final fontLoader = FontLoader("Apple Color Emoji");
        final cachedFontBytes = ByteData.view(data.buffer);
        fontLoader.addFont(
          Future<ByteData>.value(cachedFontBytes),
        );
        await fontLoader.load();
        showSnackbar("Notice", "Font loaded");
      } catch (e, stack) {
        Logger.error("Failed to load font!", error: e, trace: stack);
        showSnackbar("Error", "Failed to load font! Error: ${e.toString()}");
      }
    }

    // Reset download state after all processing (HTTP download + file write) is complete.
    // This keeps downloadingFont = true during file write, preventing the user from
    // re-tapping the tile and starting a duplicate download.
    downloadingFont.value = false;
    fontDownloadProgress.value = null;
    fontDownloadTotalSize.value = null;
  }

  /// Test most API GET requests (the ones that don't have required parameters)
  void testAPI() {
    Stopwatch s = Stopwatch();
    group("API Service Test", () {
      test("Ping", () async {
        s.start();
        var res = await server.ping();
        expect(res.data['message'], "pong");
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Info", () async {
        s.start();
        var res = await server.info();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Totals", () async {
        s.start();
        var res = await server.getTotalStats();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Media", () async {
        s.start();
        var res = await server.getMediaStats();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Logs", () async {
        s.start();
        var res = await server.getLogs();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("FCM Client", () async {
        s.start();
        var res = await fcm.getServiceAccount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Attachment Count", () async {
        s.start();
        var res = await attachment.getCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chats", () async {
        s.start();
        var res = await chat.query();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chat Count", () async {
        s.start();
        var res = await chat.getCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Message Count", () async {
        s.start();
        var res = await message.getCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("My Message Count", () async {
        s.start();
        var res = await message.getCount(onlyMe: true);
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Messages", () async {
        s.start();
        var res = await message.query();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Handle Count", () async {
        s.start();
        var res = await handle.handleCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("iCloud Contacts", () async {
        s.start();
        var res = await contact.fetchAll();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Theme Backup", () async {
        s.start();
        var res = await backup.getTheme();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Settings Backup", () async {
        s.start();
        var res = await backup.getSettings();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Landing Page", () async {
        s.start();
        var res = await server.landingPage();
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
    Logger.info("Request: [${options.method}] ${options.path}", tag: "HTTP Service");
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Logger.info("Response: [${response.statusCode}] ${response.requestOptions.path}", tag: "HTTP Service");
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Get params without sensitive info. Must be a copy — queryParameters is the
    // live map on the request, so removing from it in place strips the auth key
    // off the request itself.
    final params = Map<String, dynamic>.from(err.requestOptions.queryParameters);
    params.remove("guid");
    params.remove("password");

    // Make a nice log of what failed
    Logger.error("""Failed Request: [${err.requestOptions.method}] ${err.requestOptions.path}
  -> Error: ${err.error ?? 'No Error'}
  -> Request Params: ${params.toString()}
  -> Request Data: ${err.requestOptions.data ?? 'No Data'}
  -> Response Status: ${err.response?.statusCode ?? 'No Response'}
  -> Response Data: ${err.response?.data ?? 'No Data'}""", tag: "HTTP Service");

    if (err.response != null && err.response!.data is Map) return handler.resolve(err.response!);
    if (err.response != null) {
      return handler.resolve(Response(data: {
        'status': err.response!.statusCode,
        'error': {'type': 'Error', 'error': err.response!.data.toString()}
      }, requestOptions: err.requestOptions, statusCode: err.response!.statusCode));
    }
    if (err.type.name.contains("Timeout")) {
      return handler.resolve(Response(data: {
        'status': 500,
        'error': {'type': 'timeout', 'error': 'Failed to receive response from server.'}
      }, requestOptions: err.requestOptions, statusCode: 500));
    }
    return super.onError(err, handler);
  }
}
