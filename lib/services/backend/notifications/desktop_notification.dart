import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_windows/src/details/notification_to_xml.dart';

class _Callbacks {
  const _Callbacks({this.onOpen, this.onAction, this.onReply});

  final FutureOr<void> Function()? onOpen;
  final FutureOr<void> Function(int index)? onAction;
  final FutureOr<void> Function(String text)? onReply;
}

/// Self-contained message notification context. It is encoded into the toast
/// payload, so it remains available after the process that posted the toast exits.
class DesktopMessageData {
  const DesktopMessageData({required this.chatGuid, this.messageGuid, this.actions = const []});

  final String chatGuid;
  final String? messageGuid;
  final List<String> actions;

  Map<String, dynamic> toJson() => {'v': 1, 'c': chatGuid, if (messageGuid != null) 'm': messageGuid, 'a': actions};

  String get payload => 'dm:${base64UrlEncode(utf8.encode(jsonEncode(toJson()))).replaceAll('=', '')}';

  String actionPayload(String action) => '$payload:$action';

  static DesktopMessageData? fromJson(Map<String, dynamic> json) {
    try {
      final String? chatGuid = json['c'] as String?;
      if (json['v'] != 1 || chatGuid == null || chatGuid.isEmpty) return null;
      final List<String> actions = (json['a'] as List? ?? const []).whereType<String>().toList();
      return DesktopMessageData(chatGuid: chatGuid, messageGuid: json['m'] as String?, actions: actions);
    } catch (_) {
      return null;
    }
  }

  static DesktopMessageData? fromPayload(String value) {
    final List<String> parts = value.split(':');
    if (parts.length < 2 || parts.first != 'dm') return null;
    try {
      return fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map),
      );
    } catch (_) {
      return null;
    }
  }
}

class DesktopMessageInteraction {
  const DesktopMessageInteraction({required this.data, this.action, this.reply});

  final DesktopMessageData data;
  final String? action;
  final String? reply;

  static DesktopMessageInteraction? fromResponse(NotificationResponse response) {
    final String source = response.actionId?.startsWith('dm:') ?? false ? response.actionId! : response.payload ?? '';
    final List<String> parts = source.split(':');
    final DesktopMessageData? data = DesktopMessageData.fromPayload(source);
    if (data == null) return null;
    if (parts.length == 2) return DesktopMessageInteraction(data: data);
    if (parts.length == 3 && parts[2] == 'reply') {
      final String reply = response.input ?? response.data['reply']?.toString() ?? '';
      return reply.isEmpty ? null : DesktopMessageInteraction(data: data, reply: reply);
    }
    if (parts.length == 4 && parts[2] == 'action') {
      final int? index = int.tryParse(parts[3]);
      if (index != null && index >= 0 && index < data.actions.length) {
        return DesktopMessageInteraction(data: data, action: data.actions[index]);
      }
    }
    return null;
  }
}

/// Desktop (Windows + Linux) notifications on top of flutter_local_notifications.
///
/// [_post] owns the shared plumbing — id allocation, callback routing, raw-XML generation,
/// teardown — while each show* method fully defines its own per-type layout (avatar
/// placement, buttons, sounds, scenario).
///
/// The plugin reports every interaction through one global callback, and on Windows a
/// button click replaces the toast payload with the button's `arguments` string. The
/// notification id is therefore encoded into the payload (`dn:{id}`) and into every
/// action (`dn:{id}:{index}`, reply = `dn:{id}:reply`) so [handleResponse] can route
/// each response back to the notification that raised it. Message payloads also carry
/// their chat GUID (`dn:{id}:chat:{base64-guid}`), allowing a post-restart tap to be
/// routed after the in-memory callback map has been lost.
class DesktopNotifications {
  DesktopNotifications._();

  static const String _prefix = 'dn';
  static const String _replyId = 'reply';
  static const int _maxWindowsButtons = 5;

  static FlutterLocalNotificationsPlugin? _plugin;
  static final Map<int, _Callbacks> _callbacks = {};
  static FutureOr<void> Function(DesktopMessageInteraction interaction)? _messageInteractionHandler;
  static int _nextId = 1000;

  /// Grouped toasts (message toasts for one chat) draw ids from a deterministic
  /// per-group range, so the group's live notifications can be recognized in
  /// [activeIds] and swept by [cancelGroup] — even ones dismissed to Action
  /// Center or left over from a previous run, which no in-memory map remembers.
  static const int groupRange = 100;
  static final Map<String, int> _groupSeq = {};

  // FNV-1a: String.hashCode isn't guaranteed stable across runs, and these ids
  // must survive an app restart.
  static int groupBase(String group) {
    int h = 0x811c9dc5;
    for (final int c in group.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return 1000000 + (h % 1000000) * groupRange;
  }

  // Sequential within the range: an id is never reused until 100 later toasts,
  // and callers sweep the range via [cancelGroup] before showing, so a fresh
  // toast can't land on a still-live id (which would replace silently on
  // Windows instead of popping).
  static int _nextGroupId(String group) {
    final int seq = _groupSeq[group] = ((_groupSeq[group] ?? -1) + 1) % groupRange;
    return groupBase(group) + seq;
  }

  /// Cancels every notification in [group]'s id range that the OS still lists
  /// as active — including toasts dismissed to Action Center and ones shown by
  /// a previous run of the app.
  static Future<void> cancelGroup(String group) async {
    final int base = groupBase(group);
    for (final int id in await activeIds()) {
      if (id >= base && id < base + groupRange) await cancel(id);
    }
  }

  /// Whether [id] was shown by this run of the app (its callbacks are live).
  static bool isLive(int id) => _callbacks.containsKey(id);

  /// Startup sweep: cancels leftovers from a previous run — their callbacks died
  /// with the process. Keeps toasts shown by this session (live callbacks) and
  /// toasts in the id range of any group in [keepGroups] (chats still unread).
  static Future<void> cancelStale({List<String> keepGroups = const []}) async {
    final List<int> bases = keepGroups.map(groupBase).toList();
    for (final int id in await activeIds()) {
      if (_callbacks.containsKey(id)) continue;
      if (bases.any((base) => id >= base && id < base + groupRange)) continue;
      await cancel(id);
    }
  }

  static void registerPlugin(FlutterLocalNotificationsPlugin plugin) => _plugin = plugin;

  static void registerMessageInteractionHandler(
    FutureOr<void> Function(DesktopMessageInteraction interaction)? handler,
  ) => _messageInteractionHandler = handler;

  static void handleResponse(NotificationResponse response) {
    Logger.error(response);
    final DesktopMessageInteraction? messageInteraction = DesktopMessageInteraction.fromResponse(response);
    if (messageInteraction != null) {
      _messageInteractionHandler?.call(messageInteraction);
      return;
    }
    final List<String> parts = (response.actionId ?? response.payload ?? '').split(':');
    Logger.info(parts);
    if (parts.length < 2 || parts.first != _prefix) return;
    final int? id = int.tryParse(parts[1]);
    if (id == null) return;
    final _Callbacks? callbacks = _callbacks.remove(id);
    if (callbacks == null) return;

    if (parts.length == 2) {
      callbacks.onOpen?.call();
    } else if (parts[2] == _replyId) {
      // Windows never fills response.input; reply text arrives in response.data keyed by input id.
      final String text = response.input ?? response.data[_replyId]?.toString() ?? '';
      if (text.isNotEmpty) callbacks.onReply?.call(text);
    } else {
      final int? index = int.tryParse(parts[2]);
      if (index != null) callbacks.onAction?.call(index);
    }
  }

  static Future<void> cancel(int id) async {
    _callbacks.remove(id);
    try {
      await _plugin?.cancel(id: id);
    } catch (e, s) {
      Logger.error('Failed to cancel desktop notification', error: e, trace: s, tag: 'DesktopNotifications');
    }
  }

  /// Ids of notifications currently in Action Center (per the OS, not our callback map).
  static Future<List<int>> activeIds() async {
    try {
      final List<ActiveNotification> active = await _plugin?.getActiveNotifications() ?? [];
      return active.map((n) => n.id).nonNulls.toList();
    } catch (e, s) {
      Logger.error('Failed to get active desktop notifications', error: e, trace: s, tag: 'DesktopNotifications');
      return [];
    }
  }

  static Future<void> cancelAll() async {
    _callbacks.clear();
    try {
      await _plugin?.cancelAll();
    } catch (e, s) {
      Logger.error('Failed to cancel all desktop notifications', error: e, trace: s, tag: 'DesktopNotifications');
    }
  }

  // ---------------- Per-type layouts ----------------

  /// Plain toast (failed-to-send, alias warnings): title + body, tap to open.
  /// Only one is kept at a time — a new text toast dismisses the previous one.
  static Future<int?> showText({required String title, required String body, FutureOr<void> Function()? onOpen}) async {
    if (_lastTextId != null) await cancel(_lastTextId!);
    final int? id = await _post(
      title: title,
      body: body,
      callbacks: _Callbacks(onOpen: onOpen),
      windows: (id) => const WindowsNotificationDetails(duration: WindowsNotificationDuration.short),
      linux: (id) => const LinuxNotificationDetails(),
    );
    if (id != null) _lastTextId = id;
    return id;
  }

  static int? _lastTextId;

  /// Message toast: small circular sender avatar, optional reply field and tapback
  /// buttons, SMS sound, optional attribution line, replaceable in place.
  static Future<int?> showMessage({
    String? group,
    int? replaceId,
    bool suppressPopup = false,
    String? avatarPath,
    required String title,
    required String body,
    String? attributionText,
    List<String> actionLabels = const [],
    bool replyInput = false,
    bool silent = false,
    DesktopMessageData? messageData,
    FutureOr<void> Function()? onOpen,
    FutureOr<void> Function(int index)? onAction,
    FutureOr<void> Function(String text)? onReply,
  }) {
    final List<String> labels = actionLabels.take(_maxWindowsButtons - (replyInput ? 1 : 0)).toList();
    return _post(
      group: group,
      replaceId: replaceId,
      suppressPopup: suppressPopup,
      title: title,
      body: body,
      payload: messageData?.payload,
      // Payload-backed message notifications must not depend on process-local
      // callbacks. Keep the legacy path only for callers without message data.
      callbacks: messageData == null ? _Callbacks(onOpen: onOpen, onAction: onAction, onReply: onReply) : null,
      // Attribution text (the small dim line at the bottom) has no public API — splice it in.
      editXml: attributionText == null
          ? null
          : (xml) => xml.replaceFirst(
              '</binding>',
              '<text placement="attribution">${_escapeXml(attributionText)}</text></binding>',
            ),
      windows: (id) => WindowsNotificationDetails(
        duration: WindowsNotificationDuration.short,
        images: [
          if (avatarPath != null)
            WindowsImage(
              Uri.file(avatarPath, windows: true),
              altText: 'avatar',
              placement: WindowsImagePlacement.appLogoOverride,
              crop: WindowsImageCrop.circle,
            ),
        ],
        inputs: [if (replyInput) const WindowsTextInput(id: _replyId, placeHolderContent: 'Type a reply...')],
        actions: [
          if (replyInput)
            WindowsAction(
              content: 'Reply',
              arguments: messageData?.actionPayload(_replyId) ?? '$_prefix:$id:$_replyId',
              inputId: _replyId,
            ),
          for (int i = 0; i < labels.length; i++)
            WindowsAction(content: labels[i], arguments: messageData?.actionPayload('action:$i') ?? '$_prefix:$id:$i'),
        ],
        audio: silent
            ? WindowsNotificationAudio.silent()
            : WindowsNotificationAudio.preset(sound: WindowsNotificationSound.sms),
      ),
      linux: (id) => LinuxNotificationDetails(
        icon: avatarPath != null ? FilePathLinuxIcon(avatarPath) : null,
        actions: [
          for (int i = 0; i < labels.length; i++)
            LinuxNotificationAction(
              key: messageData?.actionPayload('action:$i') ?? '$_prefix:$id:$i',
              label: labels[i],
            ),
        ],
        sound: silent ? null : ThemeLinuxSound('message-new-instant'),
        suppressSound: silent,
      ),
    );
  }

  /// Incoming-call toast: stays on screen ringing until acted on, large circular caller
  /// photo, and green Answer / red Decline buttons (Windows). Buttons only appear when
  /// [onAnswer]/[onDecline] are provided.
  static Future<int?> showFaceTime({
    required String caller,
    String? avatarPath,
    required String body,
    FutureOr<void> Function()? onOpen,
    FutureOr<void> Function()? onAnswer,
    FutureOr<void> Function()? onDecline,
  }) {
    final bool answerable = onAnswer != null || onDecline != null;
    return _post(
      title: caller,
      body: body,
      callbacks: _Callbacks(onOpen: onOpen, onAction: (index) => index == 0 ? onAnswer?.call() : onDecline?.call()),
      editXml: (xml) => xml
          .replaceFirst('<toast', '<toast useButtonStyle="true"')
          .replaceFirst('ms-winsoundevent:Notification.Looping.Call1', 'ms-winsoundevent:Notification.Looping.Call'),
      windows: (id) => WindowsNotificationDetails(
        scenario: WindowsNotificationScenario.incomingCall,
        images: [
          if (avatarPath != null)
            WindowsImage(Uri.file(avatarPath, windows: true), altText: 'caller avatar', crop: WindowsImageCrop.circle),
        ],
        actions: [
          if (answerable) ...[
            WindowsAction(content: 'Answer', arguments: '$_prefix:$id:0', buttonStyle: WindowsButtonStyle.success),
            WindowsAction(content: 'Decline', arguments: '$_prefix:$id:1', buttonStyle: WindowsButtonStyle.critical),
          ],
        ],
        audio: WindowsNotificationAudio.preset(sound: WindowsNotificationSound.call1, shouldLoop: true),
      ),
      linux: (id) => LinuxNotificationDetails(
        icon: avatarPath != null ? FilePathLinuxIcon(avatarPath) : null,
        actions: [
          if (answerable) ...[
            LinuxNotificationAction(key: '$_prefix:$id:0', label: 'Answer'),
            LinuxNotificationAction(key: '$_prefix:$id:1', label: 'Decline'),
          ],
        ],
        sound: ThemeLinuxSound('phone-incoming-call'),
        urgency: LinuxNotificationUrgency.critical,
        resident: true,
        timeout: const LinuxNotificationTimeout.expiresNever(),
      ),
    );
  }

  // ---------------- Shared plumbing ----------------

  static Future<int?> _post({
    String? group,
    int? replaceId,
    bool suppressPopup = false,
    required String title,
    required String body,
    String? payload,
    _Callbacks? callbacks,
    required WindowsNotificationDetails Function(int id) windows,
    required LinuxNotificationDetails Function(int id) linux,
    String Function(String xml)? editXml,
  }) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) {
      Logger.warn('Notification shown before plugin registration', tag: 'DesktopNotifications');
      return null;
    }
    // New toasts get a fresh id. [replaceId] reuses one instead: Windows swaps the
    // toast in place, keeping a single Action Center entry.
    final int id = replaceId ?? (group == null ? _nextId++ : _nextGroupId(group));
    if (callbacks != null) _callbacks[id] = callbacks;
    final String notificationPayload = payload ?? '$_prefix:$id';

    try {
      // Resolves to the Windows implementation only on Windows (the plugin checks the
      // platform internally) — and lets tests inject a fake to exercise either branch.
      final FlutterLocalNotificationsWindows? windowsPlugin = plugin
          .resolvePlatformSpecificImplementation<FlutterLocalNotificationsWindows>();
      if (windowsPlugin != null) {
        // Windows toasts always go through raw XML: the plugin pretty-prints its XML, which
        // collapses newlines in the body to spaces (package:xml normalizeText), so newlines
        // hide behind a sentinel and come back as &#10; after generation — and the per-type
        // editXml splices have no public API equivalent.
        String xml = notificationToXml(
          title: title,
          body: body.replaceAll('\n', _newlineSentinel),
          payload: notificationPayload,
          notificationDetails: windows(id),
        );
        if (editXml != null) xml = editXml(xml);
        xml = xml.replaceAll(_newlineSentinel, '&#10;');
        Logger.debug(xml);
        await windowsPlugin.showRawXml(id: id, xml: xml, suppressPopup: suppressPopup);
      } else {
        await plugin.show(
          id: id,
          title: title,
          body: body,
          payload: notificationPayload,
          notificationDetails: NotificationDetails(linux: linux(id)),
        );
      }
    } catch (e, s) {
      Logger.error('Failed to show desktop notification', error: e, trace: s, tag: 'DesktopNotifications');
      _callbacks.remove(id);
      return null;
    }
    return id;
  }

  // Private-use character: valid in XML, untouched by the pretty-printer's whitespace
  // normalization, and never present in real message text.
  static final String _newlineSentinel = String.fromCharCode(0xE000);

  static String _escapeXml(String text) =>
      text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
