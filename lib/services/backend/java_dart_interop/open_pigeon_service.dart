import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  static const _channel = MethodChannel('com.bluebubbles.messaging/openpigeon');
  static final RxBool installed = false.obs;

  /// The server has a subscription; the app-message routes refuse (402) without one.
  static final RxBool licensed = false.obs;

  /// Where the server says a subscription can be bought.
  static String? purchaseUrl;
  static final Map<String, Future<Map<String, dynamic>?>> _payloads = {};
  static ValueChanged<Map<String, dynamic>>? _onKeyboardMessage;

  /// Platform views OpenPigeon failed to fill, which show our own fallback instead.
  static final RxSet<int> failedViews = <int>{}.obs;

  /// The newest message seen in each game session, by session id. Only that one is live; older turns collapse to
  /// the app's icon, as in Messages.
  static final RxMap<String, ({String guid, DateTime date})> latestInSession =
      <String, ({String guid, DateTime date})>{}.obs;

  /// The server could carry games with a subscription, so they're shown, locked if it has none.
  static bool get offered =>
      !kIsWeb && Platform.isAndroid && SettingsSvc.serverDetails.isV2Server && SettingsSvc.settings.enablePrivateAPI.value;

  /// The server can carry the payloads; OpenPigeon may still need installing.
  static bool get supported => offered && licensed.value;

  static bool get available => supported && installed.value;

  /// Matched on the suffix: the team id in the middle belongs to the developer and can change.
  static bool isGame(Message message) =>
      message.balloonBundleId?.endsWith(':com.gamerdelights.gamepigeon.ext') ?? false;

  static Future<void> init() async {
    _channel.setMethodCallHandler(_handle);
    await refresh();
    EventDispatcherSvc.stream.listen((e) async {
      if (e.type != 'new-message' || !available) return;
      final message = e.data['message'] as Message;
      if (!isGame(message) || message.guid == null) return;
      final payload = await payloadFor(message);
      if (payload == null) return;
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
    try {
      final data = (await HttpSvc.server.subscription()).data['data'] as Map<String, dynamic>;
      purchaseUrl = (data['available_tiers'] as List?)?.whereType<Map>().firstOrNull?['purchase_url'] as String?;
      licensed.value = data['tier'] != null;
    } catch (e) {
      Logger.warn('Could not check the server subscription', error: e, tag: 'OpenPigeon');
      licensed.value = false;
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
      return Future.value(_noted(message, _madrid(guid, app!.url, app.sessionId, app.ldText, app.userInfo?.caption)));
    }
    return _payloads[guid] ??= HttpSvc.message.getAppMessage(guid).then<Map<String, dynamic>?>((response) {
      final data = response.data['data'] as Map<String, dynamic>;
      return _noted(message, _madrid(guid, data['url'], data['session_id'], data['summary'], data['caption']));
    }).catchError((Object e) {
      Logger.warn('Could not load OpenPigeon payload for $guid', error: e, tag: 'OpenPigeon');
      _payloads.remove(guid);
      return null;
    });
  }

  /// Number of people in [chat], counting the user, which OpenPigeon uses to hide games.
  static int userCount(Chat chat) => chat.participants.length + 1;

  /// Set by the game picker sheet: a picked game goes to the composer rather than straight out.
  static void onKeyboardMessage(ValueChanged<Map<String, dynamic>>? callback) => _onKeyboardMessage = callback;

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
      _onKeyboardMessage?.call(args);
      return true;
    }
    await sendGame(args['chatGuid'] as String, args);
    return true;
  }

  /// Opens the game [payload] (from [payloadFor]) belongs to.
  static Future<bool> open(Map<String, dynamic> payload, Chat chat) async {
    try {
      await _channel.invokeMethod('open', {...payload, 'chatGuid': chat.guid, 'userCount': userCount(chat)});
      return true;
    } on PlatformException catch (e) {
      Logger.warn('Could not open the game', error: e, tag: 'OpenPigeon');
      return false;
    }
  }

  /// Sends an OpenPigeon message ([game] holds its `url`, `session`, `ldText` and `caption`) to [chatGuid].
  static Future<void> sendGame(String chatGuid, Map<String, dynamic> game) async {
    await HttpSvc.message.sendAppMessage(
      chatGuid,
      balloonBundleId: balloonBundleId,
      url: game['url'] as String,
      sessionId: _string(game['session']),
      appName: 'GamePigeon',
      appId: 1124197642,
      summary: _string(game['ldText']),
      caption: _string(game['caption']),
    );
  }

  static Map<String, dynamic>? _noted(Message message, Map<String, dynamic>? payload) {
    final session = payload?['session'] as String?;
    if (session == null) return payload;
    final date = message.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0);
    final latest = latestInSession[session];
    if (latest == null || date.isAfter(latest.date)) latestInSession[session] = (guid: message.guid!, date: date);
    return payload;
  }

  /// Session ids are lowercased because OpenPigeon matches them exactly and makes its own lowercase, while the
  /// server reports `NSUUID`'s uppercase.
  static Map<String, dynamic>? _madrid(String guid, Object? url, Object? session, Object? ldText, Object? caption) {
    if (url is! String || url.isEmpty) return null;
    return {
      'messageGuid': guid,
      'url': url,
      'session': _string(session)?.toLowerCase(),
      'ldText': _string(ldText),
      'caption': _string(caption),
    };
  }

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;
}
