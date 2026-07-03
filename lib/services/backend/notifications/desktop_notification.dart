import 'dart:async';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum _DesktopSound { defaultSound, sms, callLoop, silent }

class _Callbacks {
  _Callbacks({this.onOpen, this.onAction, this.onReply});

  final FutureOr<void> Function()? onOpen;
  final FutureOr<void> Function(int index)? onAction;
  final FutureOr<void> Function(String text)? onReply;
}

/// Desktop (Linux + Windows) notifications on top of flutter_local_notifications.
///
/// flnp reports every tap/action through one global callback, so this owns an
/// id -> callbacks registry and [handleResponse] fans each response back to the
/// notification that raised it. Each `show*` returns the notification id for a
/// later [cancel].
class DesktopNotifications {
  DesktopNotifications._();

  static const String _replyInputId = 'reply';
  static const String _openActionKey = 'open';

  static FlutterLocalNotificationsPlugin? _plugin;
  static final Map<int, _Callbacks> _callbacks = {};
  static int _idCounter = 1000;

  static void registerPlugin(FlutterLocalNotificationsPlugin plugin) => _plugin = plugin;

  static void handleResponse(NotificationResponse response) {
    final int? id = int.tryParse(response.payload ?? '');
    if (id == null) return;
    final _Callbacks? cb = _callbacks[id];
    if (cb == null) return;

    switch (response.notificationResponseType) {
      case NotificationResponseType.selectedNotification:
        cb.onOpen?.call();
        break;
      case NotificationResponseType.selectedNotificationAction:
        final String? actionId = response.actionId;
        final String? input = response.input;
        if (actionId == _openActionKey) {
          cb.onOpen?.call();
        } else if (input != null && input.isNotEmpty) {
          cb.onReply?.call(input);
        } else {
          final int? index = int.tryParse(actionId ?? '');
          if (index != null) {
            cb.onAction?.call(index);
          } else {
            cb.onOpen?.call();
          }
        }
        break;
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

  /// Simple title/body notification (alias deregistered, failed-to-send).
  static Future<int?> showText({
    required String title,
    required String body,
    FutureOr<void> Function()? onOpen,
  }) {
    return _show(title: title, body: body, onOpen: onOpen);
  }

  /// Incoming-message notification (avatar, actions, optional reply field).
  static Future<int?> showMessage({
    int? id,
    String? imagePath,
    required String title,
    String? body,
    String? attributionText,
    List<String> actionLabels = const [],
    bool replyInput = false,
    bool silent = false,
    FutureOr<void> Function()? onOpen,
    FutureOr<void> Function(int index)? onAction,
    FutureOr<void> Function(String text)? onReply,
  }) {
    return _show(
      id: id,
      imagePath: imagePath,
      title: title,
      body: attributionText != null ? '$attributionText$body' : body,
      actionLabels: actionLabels,
      replyInput: replyInput,
      showOpenAction: true,
      sound: silent ? _DesktopSound.silent : _DesktopSound.sms,
      onOpen: onOpen,
      onAction: onAction,
      onReply: onReply,
    );
  }

  /// Incoming-FaceTime notification: resident, looping ring, answer/decline.
  static Future<int?> showFaceTime({
    required String caller,
    String? imagePath,
    required String body,
    List<String> actionLabels = const [],
    FutureOr<void> Function()? onOpen,
    FutureOr<void> Function(int index)? onAction,
  }) {
    return _show(
      imagePath: imagePath,
      title: caller,
      body: body,
      actionLabels: actionLabels,
      persistent: true,
      sound: _DesktopSound.callLoop,
      onOpen: onOpen,
      onAction: onAction,
    );
  }

  static Future<int?> _show({
    int? id,
    String? imagePath,
    String? title,
    String? body,
    List<String> actionLabels = const [],
    bool replyInput = false,
    bool showOpenAction = false,
    bool persistent = false,
    _DesktopSound sound = _DesktopSound.defaultSound,
    FutureOr<void> Function()? onOpen,
    FutureOr<void> Function(int index)? onAction,
    FutureOr<void> Function(String text)? onReply,
  }) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) {
      Logger.warn('DesktopNotifications.show called before registerPlugin', tag: 'DesktopNotifications');
      return null;
    }
    final int notifId = id ?? _idCounter++;
    _callbacks[notifId] = _Callbacks(onOpen: onOpen, onAction: onAction, onReply: onReply);

    try {
      await plugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          linux: _linuxDetails(imagePath, actionLabels, showOpenAction, persistent, sound),
          windows: _windowsDetails(imagePath, actionLabels, replyInput, showOpenAction, persistent, sound),
        ),
        payload: '$notifId',
      );
    } catch (e, s) {
      Logger.error('Failed to show desktop notification', error: e, trace: s, tag: 'DesktopNotifications');
    }
    return notifId;
  }

  static LinuxNotificationDetails _linuxDetails(
      String? imagePath, List<String> actionLabels, bool showOpenAction, bool persistent, _DesktopSound sound) {
    final bool suppress = sound == _DesktopSound.silent || sound == _DesktopSound.callLoop;
    return LinuxNotificationDetails(
      icon: imagePath != null ? FilePathLinuxIcon(imagePath) : null,
      actions: [
        if (showOpenAction) const LinuxNotificationAction(key: _openActionKey, label: 'Open'),
        for (int i = 0; i < actionLabels.length; i++) LinuxNotificationAction(key: '$i', label: actionLabels[i]),
      ],
      defaultActionName: 'default',
      sound: suppress ? null : ThemeLinuxSound(sound == _DesktopSound.callLoop ? 'phone-incoming-call' : 'message-new-instant'),
      suppressSound: suppress,
      urgency: persistent ? LinuxNotificationUrgency.critical : LinuxNotificationUrgency.normal,
      resident: persistent,
      timeout:
          persistent ? const LinuxNotificationTimeout.expiresNever() : const LinuxNotificationTimeout.systemDefault(),
    );
  }

  static WindowsNotificationDetails _windowsDetails(String? imagePath, List<String> actionLabels, bool replyInput,
      bool showOpenAction, bool persistent, _DesktopSound sound) {
    final WindowsNotificationSound presetSound = sound == _DesktopSound.callLoop
        ? WindowsNotificationSound.call1
        : sound == _DesktopSound.sms
            ? WindowsNotificationSound.sms
            : WindowsNotificationSound.defaultSound;
    return WindowsNotificationDetails(
      images: [
        if (imagePath != null) WindowsImage(Uri.file(imagePath), altText: 'avatar'),
      ],
      inputs: [
        if (replyInput) const WindowsTextInput(id: _replyInputId, placeHolderContent: 'Type a reply...'),
      ],
      actions: [
        if (showOpenAction) const WindowsAction(content: 'Open', arguments: _openActionKey),
        if (replyInput) const WindowsAction(content: 'Reply', arguments: _replyInputId, inputId: _replyInputId),
        for (int i = 0; i < actionLabels.length; i++) WindowsAction(content: actionLabels[i], arguments: '$i'),
      ],
      scenario: persistent ? WindowsNotificationScenario.incomingCall : null,
      audio: sound == _DesktopSound.silent
          ? WindowsNotificationAudio.silent()
          : WindowsNotificationAudio.preset(sound: presetSound, shouldLoop: sound == _DesktopSound.callLoop),
    );
  }
}
