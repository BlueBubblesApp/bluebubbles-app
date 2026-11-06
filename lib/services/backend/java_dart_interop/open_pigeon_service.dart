import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/database/models.dart' hide PayloadType;
import 'package:bluebubbles/helpers/helpers.dart';
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

  /// GamePigeon's App Store id.
  static const appId = 1124197642;

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

  /// The newest message seen in each game session, by lowercase session id. Older turns collapse to the app's icon,
  /// as in Messages.
  static final RxMap<String, ({String guid, DateTime date})> latestInSession =
      <String, ({String guid, DateTime date})>{}.obs;

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

  /// Matched on the suffix: the team id in the middle belongs to the developer and can change.
  static bool isGame(Message message) =>
      message.balloonBundleId?.endsWith(':com.gamerdelights.gamepigeon.ext') ?? false;

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
    try {
      final data = (await HttpSvc.server.subscription()).data['data'] as Map<String, dynamic>;
      final tiers = (data['available_tiers'] as List? ?? const []).whereType<Map>().toList();
      final pro = tiers.firstWhereOrNull((t) => t['id'] == 'pro');
      final held = tiers.firstWhereOrNull((t) => t['id'] == data['tier']);
      purchaseUrl = pro?['purchase_url'] as String?;
      // The app-message routes need Pro or above, compared by rank. A tier the server doesn't list is newer than its
      // build, and the server still ranks it from the license, so only a listed tier below Pro is refused.
      licensed.value = data['tier'] != null &&
          (held == null || pro == null || (held['rank'] as int) >= (pro['rank'] as int));
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
      return Future.value(_madrid(guid, app!.url, app.sessionId, app.ldText, app.userInfo?.caption));
    }
    return _payloads[guid] ??= HttpSvc.message.getAppMessage(guid).then<Map<String, dynamic>?>((response) {
      final data = response.data['data'] as Map<String, dynamic>;
      return _madrid(guid, data['url'], data['session_id'], data['summary'], data['caption']);
    }).catchError((Object e) {
      Logger.warn('Could not load OpenPigeon payload for $guid', error: e, tag: 'OpenPigeon');
      _payloads.remove(guid);
      return null;
    });
  }

  /// Number of people in [chat], counting the user, which OpenPigeon uses to hide games.
  static int userCount(Chat chat) => chat.isGroup ? chat.handles.length + 1 : 2;

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
    final chat = Chat.findOne(guid: args['chatGuid'] as String);
    if (chat == null) {
      Logger.warn("Ignoring an OpenPigeon turn for a chat that isn't saved", tag: 'OpenPigeon');
      return false;
    }
    await sendGame(chat, args);
    return true;
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
  /// [chat], drawn at once like any other send.
  static Future<void> sendGame(Chat chat, Map<String, dynamic> game) async {
    final message = gameMessage(game)..generateTempGuid();
    final image = gameImage(game);
    await OutgoingMsgHandler.queue(OutgoingAppMessage(
      chat: chat,
      message: message,
      attachment: image == null
          ? null
          : Attachment(
              guid: message.guid,
              isOutgoing: true,
              mimeType: 'image/jpeg',
              uti: 'public.jpeg',
              transferName: 'game.jpg',
              totalBytes: image.length,
              bytes: image,
            ),
    ));
  }

  /// The message [game] becomes once sent, so it can be drawn the same way before then.
  static Message gameMessage(Map<String, dynamic> game) => Message(
        text: "",
        dateCreated: DateTime.now(),
        isFromMe: true,
        handleId: 0,
        balloonBundleId: balloonBundleId,
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

  /// Records [message] as a turn of [session] (lowercase), so earlier turns collapse.
  static void noteTurn(Message message, String? session) {
    // A turn still sending isn't a turn yet: it's noted once it has its real GUID
    if (session == null || message.guid!.startsWith('temp')) return;
    final date = message.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0);
    final latest = latestInSession[session];
    if (latest == null || date.isAfter(latest.date)) latestInSession[session] = (guid: message.guid!, date: date);
  }

  /// A game turn a newer turn of the same session has replaced. Messages hides these when sent and shrinks them to
  /// the app's icon and the game when received.
  ///
  /// Messages links every turn to the session's first message and marks the live one type 2; once a newer turn
  /// arrives, the earlier ones become type 3. A turn sent without that link, or one whose rewrite to 3 we never
  /// heard about, falls back to the newest turn seen in its session.
  static bool isEarlierTurn(Message message) {
    if (!isGame(message) || message.guid!.startsWith('temp')) return false;
    if (message.associatedMessageType == '3') return true;
    final session = message.payloadData?.appData?.firstOrNull?.sessionId?.toLowerCase();
    final latest = session == null ? null : latestInSession[session];
    return latest != null && latest.guid != message.guid;
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
