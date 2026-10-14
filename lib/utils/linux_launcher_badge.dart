import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dbus/dbus.dart';

/// Unread-count badge for Linux docks and launchers via the Unity LauncherEntry D-Bus API.
///
/// Emits `com.canonical.Unity.LauncherEntry.Update` on the session bus, which is honored by
/// Plank, KDE Plasma's task manager, Ubuntu Dock / Dash to Dock, and other docks. The signal
/// targets the app's .desktop file via an `application://<desktop-id>` URI, so the badge only
/// shows if the dock can match that desktop file to the running app.
class LinuxLauncherBadge {
  static const String _interface = 'com.canonical.Unity.LauncherEntry';

  static DBusClient? _client;
  static int? _lastCount;
  static bool _warned = false;

  /// Desktop file ID for the current packaging: the Snap ships `<snap>_bluebubbles.desktop`;
  /// Flatpak and everything else use the application ID (`linux/CMakeLists.txt`).
  static String get desktopId {
    final snapName = Platform.environment['SNAP_INSTANCE_NAME'] ?? Platform.environment['SNAP_NAME'];
    if (snapName != null && snapName.isNotEmpty) return '${snapName}_bluebubbles.desktop';
    final flatpakId = Platform.environment['FLATPAK_ID'];
    if (flatpakId != null && flatpakId.isNotEmpty) return '$flatpakId.desktop';
    return 'app.bluebubbles.BlueBubbles.desktop';
  }

  /// Object path in the form libunity uses (`/com/canonical/unity/launcherentry/<g_str_hash(uri)>`).
  /// Snap's unity7 interface only permits LauncherEntry signals from paths matching
  /// `/com/canonical/unity/launcherentry/[0-9]*`.
  static DBusObjectPath _pathFor(String appUri) {
    var hash = 5381;
    for (final byte in utf8.encode(appUri)) {
      hash = ((hash << 5) + hash + byte) & 0xFFFFFFFF;
    }
    return DBusObjectPath('/com/canonical/unity/launcherentry/$hash');
  }

  /// Shows [count] on the launcher icon, or hides the badge when [count] is 0.
  static Future<void> update(int count) async {
    if (count == _lastCount) return;
    final appUri = 'application://$desktopId';
    try {
      _client ??= DBusClient.session();
      await _client!.emitSignal(
        path: _pathFor(appUri),
        interface: _interface,
        name: 'Update',
        values: [
          DBusString(appUri),
          DBusDict.stringVariant({'count': DBusInt64(count), 'count-visible': DBusBoolean(count > 0)}),
        ],
      );
      _lastCount = count;
      _warned = false;
    } catch (e) {
      // A failed connect leaves the client unusable, so start fresh on the next update.
      final client = _client;
      _client = null;
      unawaited(client?.close().catchError((_) {}));
      if (!_warned) {
        _warned = true;
        Logger.warn('Failed to update launcher badge: $e', tag: 'LinuxLauncherBadge');
      }
    }
  }
}
