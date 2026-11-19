import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
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

  /// Whether the current [_client] has delivered a signal. A client that never did means there is no usable
  /// session bus (or the sandbox blocks it), which a retry on every unread change won't fix.
  static bool _connected = false;
  static bool _unavailable = false;

  /// Desktop file ID for the current packaging: the Snap ships `<snap>_bluebubbles.desktop`;
  /// Flatpak and everything else use the application ID (`linux/CMakeLists.txt`).
  /// A parallel Snap install (`bluebubbles_foo`) is exported by snapd as `bluebubbles+foo_bluebubbles.desktop`.
  static String get desktopId {
    if (isSnap) return '${(snapInstanceName ?? 'bluebubbles').replaceFirst('_', '+')}_bluebubbles.desktop';
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
    if (_unavailable) return;
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
      _connected = true;
    } catch (e) {
      // A failed client is unusable either way. One that had worked lost its connection, so reconnect on the next
      // update; one that never worked won't start working, so stop until restart.
      final client = _client;
      final wasConnected = _connected;
      _client = null;
      _connected = false;
      unawaited(client?.close().catchError((_) {}));
      if (wasConnected) {
        Logger.warn('Lost the session bus, reconnecting on the next update: $e', tag: 'LinuxLauncherBadge');
      } else {
        _unavailable = true;
        Logger.warn('Launcher badge unavailable, disabled until restart: $e', tag: 'LinuxLauncherBadge');
      }
    }
  }
}
