import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/database/models.dart' hide PayloadType;
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bridge to OpenPigeon, an Android GamePigeon client that plugs in as a Madrid extension
/// (`OpenPigeonHost.kt`). It renders the game picker and game bubbles; this sends its turns
/// through the v2 server's app-message route.
class OpenPigeon {
  static const packageName = 'com.openbubbles.openpigeon';
  static const balloonBundleId =
      'com.apple.messages.MSMessageExtensionBalloonPlugin:EWFNLB79LQ:com.gamerdelights.gamepigeon.ext';

  /// GamePigeon's App Store id.
  static const appId = 1124197642;

  static const _channel = MethodChannel('com.bluebubbles.messaging/openpigeon');
  static final RxBool installed = false.obs;

  /// The server has a subscription; the app-message routes refuse (402) without one.
  static final RxBool licensed = false.obs;

  /// Where the server says a subscription can be bought.
  static String? purchaseUrl;
  static final Map<String, Future<Map<String, dynamic>?>> _payloads = {};
  static ({String chatGuid, ValueChanged<Map<String, dynamic>> callback})? _keyboard;

  /// Platform views OpenPigeon failed to fill, which show our own fallback instead.
  static final RxSet<int> failedViews = <int>{}.obs;

  // Mirrors the server's app-message routes: reading a payload needs Pro, and sending one also needs the server's
  // Private API.
  static bool get _onV2 => !kIsWeb && Platform.isAndroid && SettingsSvc.serverDetails.isV2Server;

  /// The server could send games with a subscription, so they're shown, locked if it has none.
  static bool get offered => _onV2 && SettingsSvc.settings.serverPrivateAPI.value == true;

  /// The server can send games; OpenPigeon may still need installing.
  static bool get supported => offered && licensed.value;

  /// OpenPigeon can draw games: it's installed and the server hands out their payloads.
  static bool get canDraw => _onV2 && licensed.value && installed.value;

  static final Map<String, Future<Uint8List?>> _snapshots = {};

  /// A still of [message]'s game as OpenPigeon draws it, [width] logical pixels wide and as tall as its layout (up to
  /// [maxHeight]), for the turns GamePigeon sends without an image. Null when OpenPigeon can't draw it; a failure is retried the next time it's asked for.
  static Future<Uint8List?> snapshot(Message message, Chat chat, double width, double maxHeight) {
    final guid = message.guid!;
    return _snapshots[guid] ??= payloadFor(message).then((payload) async {
      if (payload == null) return null;
      try {
        return await _channel.invokeMethod<Uint8List>('snapshot', {
          ...payload,
          'chatGuid': chat.guid,
          'userCount': userCount(chat),
          'width': width,
          'maxHeight': maxHeight,
        });
      } on PlatformException catch (e) {
        Logger.warn('OpenPigeon could not draw $guid', error: e, tag: 'OpenPigeon');
        return null;
      }
    }).then((png) {
      if (png == null) _snapshots.remove(guid);
      return png;
    });
  }

  /// Sessions opened in OpenPigeon this run. Bubbles are drawn from the sender's image, so OpenPigeon only hears
  /// about a game once it's been tapped.
  static final Set<String> _openedSessions = {};

  static bool isGame(Message message) => AppSessionTypes.isGamePigeon(message.balloonBundleId);

  static Future<void> init() async {
    _channel.setMethodCallHandler(_handle);
    await refresh();
    EventDispatcherSvc.stream.listen((e) async {
      if (e.type != 'new-message' || _openedSessions.isEmpty) return;
      final message = e.data['message'] as Message;
      if (!isGame(message) || message.guid == null) return;
      final payload = await payloadFor(message);
      if (payload == null || !_openedSessions.contains(payload['session'])) return;
      try {
        await _channel.invokeMethod('message-updated', payload);
      } on PlatformException catch (e) {
        Logger.warn('OpenPigeon could not take a new move', error: e, tag: 'OpenPigeon');
      }
    });
  }

  /// Re-checks the install and the server's license, either of which can change while the app is in the background.
  static Future<void> refresh() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      installed.value = await _channel.invokeMethod<bool>('installed') ?? false;
    } on PlatformException catch (e) {
      Logger.warn('Could not check for OpenPigeon', error: e, tag: 'OpenPigeon');
    } on MissingPluginException {
      // Engines other than MainActivity's have no OpenPigeon channel
      return;
    }
    if (!SettingsSvc.serverDetails.isV2Server) {
      licensed.value = false;
      return;
    }
    final dio.Response response;
    try {
      response = await HttpSvc.server.subscription();
    } catch (e) {
      // A 4xx is the server's answer. Anything else (a timeout, no connection, a 5xx) says nothing about the license,
      // so the last answer stands rather than locking games every time a resume beats the network
      final status = switch (e) {
        dio.Response() => e.statusCode,
        dio.DioException() => e.response?.statusCode,
        _ => null,
      };
      if (status != null && status >= 400 && status < 500) {
        Logger.warn('The server refused the subscription check ($status)', tag: 'OpenPigeon');
        licensed.value = false;
      } else {
        Logger.warn('Could not check the server subscription', error: e, tag: 'OpenPigeon');
      }
      return;
    }
    try {
      final data = response.data['data'] as Map<String, dynamic>;
      final tiers = (data['available_tiers'] as List? ?? const []).whereType<Map>().toList();
      final pro = tiers.firstWhereOrNull((t) => t['id'] == 'pro');
      final held = tiers.firstWhereOrNull((t) => t['id'] == data['tier']);
      purchaseUrl = pro?['purchase_url'] as String?;
      // The app-message routes need Pro or above, compared by rank. A tier the server doesn't list is newer than its
      // build, and the server still ranks it from the license, so only a listed tier below Pro is refused.
      licensed.value = data['tier'] != null &&
          (held == null || pro == null || (held['rank'] as int) >= (pro['rank'] as int));
    } catch (e) {
      // A reply this build can't read isn't an answer either
      Logger.warn('Could not read the server subscription', error: e, tag: 'OpenPigeon');
    }
  }

  static Future<void> openStore() => launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName'),
        mode: LaunchMode.externalApplication,
      );

  /// The Madrid message fields for [message]: from its own payload when that carries the session, otherwise from
  /// the server's decoded copy.
  static Future<Map<String, dynamic>?> payloadFor(Message message) {
    final guid = message.guid!;
    final app = message.payloadData?.appData?.firstOrNull;
    if (app?.url != null && app?.sessionId != null) {
      return Future.value(
          _madrid(guid, message.balloonBundleId, app!.url, app.sessionId, app.ldText, app.userInfo?.caption));
    }
    return _payloads[guid] ??= HttpSvc.message.getAppMessage(guid).then<Map<String, dynamic>?>((response) {
      final data = response.data['data'] as Map<String, dynamic>;
      return _madrid(
          guid, message.balloonBundleId, data['url'], data['session_id'], data['summary'], data['caption']);
    }).catchError((Object e) {
      Logger.warn('Could not load OpenPigeon payload for $guid', error: e, tag: 'OpenPigeon');
      _payloads.remove(guid);
      return null;
    });
  }

  /// Number of people in [chat], counting the user, which OpenPigeon uses to hide games.
  static int userCount(Chat chat) => chat.isGroup ? chat.handles.length + 1 : 2;

  /// Set by the game picker for [chatGuid]: a game picked there goes to its composer rather than straight out.
  static void onKeyboardMessage(String chatGuid, ValueChanged<Map<String, dynamic>> callback) =>
      _keyboard = (chatGuid: chatGuid, callback: callback);

  /// Clears [callback], unless a newer picker has already replaced it.
  static void clearKeyboardMessage(ValueChanged<Map<String, dynamic>> callback) {
    // Tear-offs of one object's method are equal, not identical
    if (_keyboard?.callback == callback) _keyboard = null;
  }

  static Future<bool> _handle(MethodCall call) async {
    final args = call.arguments is Map ? (call.arguments as Map).cast<String, dynamic>() : <String, dynamic>{};
    if (call.method == 'view-failed') {
      if (args['id'] is int) failedViews.add(args['id'] as int);
      return true;
    }
    if (call.method != 'send') return false;
    // OpenPigeon's messages are only checked for what sending needs; its payload is passed through untouched
    if (args['chatGuid'] is! String || args['url'] is! String || (args['url'] as String).isEmpty) {
      Logger.warn('Ignoring an OpenPigeon message without a payload', tag: 'OpenPigeon');
      return false;
    }
    if (args['fromKeyboard'] == true) {
      // A late pick from a picker since closed must not land in another chat's composer
      final keyboard = _keyboard;
      if (keyboard == null || keyboard.chatGuid != args['chatGuid']) {
        Logger.warn('Ignoring a game picked in a chat whose picker is closed', tag: 'OpenPigeon');
        return false;
      }
      keyboard.callback(args);
      return true;
    }
    final chat = Chat.findOne(guid: args['chatGuid'] as String);
    if (chat == null) {
      Logger.warn("Ignoring an OpenPigeon turn for a chat that isn't saved", tag: 'OpenPigeon');
      return false;
    }
    return await sendGame(chat, args);
  }

  /// Opens the game [payload] (from [payloadFor]) belongs to.
  static Future<bool> open(Map<String, dynamic> payload, Chat chat) async {
    try {
      await _channel.invokeMethod('open', {...payload, 'chatGuid': chat.guid, 'userCount': userCount(chat)});
      if (payload['session'] is String) _openedSessions.add(payload['session'] as String);
      return true;
    } on PlatformException catch (e) {
      Logger.warn('Could not open the game', error: e, tag: 'OpenPigeon');
      return false;
    }
  }

  /// Queues an OpenPigeon message ([game] holds its `url`, `session`, `ldText`, `caption` and `imageBase64`) in
  /// [chat], drawn at once like any other send. False, after telling the user, when its picture is one the server
  /// would refuse, so it isn't queued only to fail on every retry.
  static Future<bool> sendGame(Chat chat, Map<String, dynamic> game) async {
    var image = gameImage(game);
    if (image != null && image.length > _maxImageBytes) image = await _shrink(image);
    final type = image == null ? null : _imageType(image);
    if (image != null && (type == null || image.length > _maxImageBytes)) {
      Logger.warn("Not sending a game whose picture the server won't take (${image.length} bytes)",
          tag: 'OpenPigeon');
      showSnackbar("Error", "This game's picture can't be sent", type: SnackbarType.error);
      return false;
    }
    final message = gameMessage(game)..generateTempGuid();
    await OutgoingMsgHandler.queue(OutgoingAppMessage(
      chat: chat,
      message: message,
      attachment: image == null || type == null
          ? null
          : Attachment(
              guid: message.guid,
              isOutgoing: true,
              mimeType: type.mimeType,
              uti: type.uti,
              transferName: 'game.${type.extension}',
              totalBytes: image.length,
              bytes: image,
            ),
    ));
    return true;
  }

  /// The most a balloon's picture may be, as the server caps it (`AppPreviewImage.maximumBytes`).
  static const _maxImageBytes = 4 * 1024 * 1024;

  /// [image] re-encoded as a smaller JPEG, or unchanged if it can't be.
  static Future<Uint8List> _shrink(Uint8List image) async {
    try {
      return await FlutterImageCompress.compressWithList(image, minWidth: 1280, minHeight: 1280, quality: 80);
    } catch (e) {
      Logger.warn('Could not shrink a game picture', error: e, tag: 'OpenPigeon');
      return image;
    }
  }

  /// [bytes]' type, read from the bytes themselves as the server does: JPEG, PNG or HEIC, the three it accepts.
  static ({String mimeType, String uti, String extension})? _imageType(Uint8List bytes) {
    bool startsWith(List<int> magic, [int offset = 0]) =>
        bytes.length >= offset + magic.length && magic.indexed.every((e) => bytes[offset + e.$1] == e.$2);
    if (startsWith(const [0xFF, 0xD8, 0xFF])) return (mimeType: 'image/jpeg', uti: 'public.jpeg', extension: 'jpg');
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return (mimeType: 'image/png', uti: 'public.png', extension: 'png');
    }
    // An ISO base-media `ftyp` box naming a HEIF brand
    if (bytes.length >= 12 &&
        startsWith(ascii.encode('ftyp'), 4) &&
        const ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
      return (mimeType: 'image/heic', uti: 'public.heic', extension: 'heic');
    }
    return null;
  }

  /// The message [game] becomes once sent, so it can be drawn the same way before then.
  static Message gameMessage(Map<String, dynamic> game) => Message(
        text: "",
        dateCreated: DateTime.now(),
        isFromMe: true,
        handleId: 0,
        balloonBundleId: _gameBundleId(game['balloonBundleId']),
        hasAttachments: gameImage(game) != null,
        payloadData: PayloadData(type: PayloadType.app, appData: [
          iMessageAppData(
            appName: 'GamePigeon',
            ldText: _string(game['ldText']),
            url: game['url'] as String?,
            sessionId: _string(game['session']),
            userInfo: UserInfo(caption: _string(game['caption'])),
          ),
        ]),
      );

  /// The extension's own part of [balloonBundleId], the same whichever developer team id precedes it.
  static final _extensionSuffix = balloonBundleId.substring(balloonBundleId.lastIndexOf(':'));

  /// The balloon id a turn goes out under: the one its game was opened from, so the server threads it into that
  /// session (it matches the id exactly), or GamePigeon's current one for a new game.
  static String _gameBundleId(Object? id) => id is String && id.endsWith(_extensionSuffix) ? id : balloonBundleId;

  /// The picture OpenPigeon drew for [game], if it sent one.
  static Uint8List? gameImage(Map<String, dynamic> game) {
    final image = _string(game['imageBase64']);
    if (image == null) return null;
    try {
      return base64Decode(image);
    } on FormatException {
      return null;
    }
  }

  /// A game turn a newer turn of the same session has replaced. Messages hides these when sent and shrinks them to
  /// the app's icon and the game when received. Messages links every turn to the session's first message as type 2,
  /// then rewrites the replaced ones to 3 (MessageActions.retireEarlierTurns does the same for turns sync brings in).
  static bool isEarlierTurn(Message message) =>
      isGame(message) && message.associatedMessageType == AppSessionTypes.SUPERSEDED;

  /// Session ids are lowercased because OpenPigeon matches them exactly and makes its own lowercase, while the
  /// server reports `NSUUID`'s uppercase.
  ///
  /// `balloonBundleId` isn't a Madrid field: it rides along so a game opened from [guid] sends its turns under the id
  /// its session started with.
  static Map<String, dynamic>? _madrid(
    String guid,
    String? bundleId,
    Object? url,
    Object? session,
    Object? ldText,
    Object? caption,
  ) {
    if (url is! String || url.isEmpty) return null;
    return {
      'messageGuid': guid,
      'balloonBundleId': bundleId,
      'url': url,
      'session': _string(session)?.toLowerCase(),
      'ldText': _string(ldText),
      'caption': _string(caption),
    };
  }

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;
}
