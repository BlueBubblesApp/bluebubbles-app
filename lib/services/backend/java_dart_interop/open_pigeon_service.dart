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
  static final Map<String, Future<Map<String, dynamic>?>> _payloads = {};
  static VoidCallback? _onKeyboardSend;

  /// The server can carry the payloads; OpenPigeon may still need installing.
  static bool get supported =>
      !kIsWeb &&
      Platform.isAndroid &&
      SettingsSvc.serverDetails.isV2Server &&
      SettingsSvc.settings.enablePrivateAPI.value;

  static bool get available => supported && installed.value;

  static bool isGame(Message message) => message.balloonBundleId == balloonBundleId;

  static Future<void> init() async {
    _channel.setMethodCallHandler(_handle);
    await refreshInstalled();
    EventDispatcherSvc.stream.listen((e) async {
      if (e.type != 'new-message' || !available) return;
      final message = e.data['message'] as Message;
      if (!isGame(message) || message.guid == null) return;
      final payload = await payloadFor(message.guid!);
      if (payload != null) await _channel.invokeMethod('message-updated', payload);
    });
  }

  static Future<void> refreshInstalled() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      installed.value = await _channel.invokeMethod<bool>('installed') ?? false;
    } on PlatformException catch (e) {
      Logger.warn('Could not check for OpenPigeon', error: e, tag: 'OpenPigeon');
    } on MissingPluginException {
      // Engines other than MainActivity's have no OpenPigeon channel
    }
  }

  static Future<void> openStore() => launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName'),
        mode: LaunchMode.externalApplication,
      );

  /// The Madrid message fields for an app message, from the server's decoded payload.
  static Future<Map<String, dynamic>?> payloadFor(String guid) {
    return _payloads[guid] ??= HttpSvc.message.getAppMessage(guid).then<Map<String, dynamic>?>((response) {
      final data = response.data['data'] as Map<String, dynamic>;
      return <String, dynamic>{
        'messageGuid': guid,
        'url': data['url'],
        'session': data['session_id'],
        'ldText': data['summary'],
        'caption': data['caption'],
      };
    }).catchError((Object e) {
      Logger.warn('Could not load OpenPigeon payload for $guid', error: e, tag: 'OpenPigeon');
      _payloads.remove(guid);
      return null;
    });
  }

  /// Number of people in [chat], counting the user, which OpenPigeon uses to hide games.
  static int userCount(Chat chat) => chat.participants.length + 1;

  /// Called by the game picker sheet so it can close once a game is sent.
  static void onKeyboardSend(VoidCallback? callback) => _onKeyboardSend = callback;

  static Future<bool> _handle(MethodCall call) async {
    if (call.method != 'send') return false;
    final args = (call.arguments as Map).cast<String, dynamic>();
    if (args['fromKeyboard'] == true) _onKeyboardSend?.call();
    await HttpSvc.message.sendAppMessage(
      args['chatGuid'] as String,
      balloonBundleId: balloonBundleId,
      url: args['url'] as String,
      sessionId: args['session'] as String?,
      appName: 'GamePigeon',
      appId: 1124197642,
      summary: args['ldText'] as String?,
      caption: args['caption'] as String?,
    );
    return true;
  }
}
