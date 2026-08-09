import 'package:bluebubbles/helpers/types/helpers/misc_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/file_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:launch_at_startup/launch_at_startup.dart' as las;
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

class LaunchAtStartup {
  /// Recorded in [setup] so the flatpak portal path can pass it on the autostart commandline.
  static bool _minimized = false;

  static Future<bool> enable() => isFlatpak ? _portalAutostart(true) : las.LaunchAtStartup.instance.enable();

  static Future<bool> disable() => isFlatpak ? _portalAutostart(false) : las.LaunchAtStartup.instance.disable();

  /// Flatpak is sandboxed out of the real `~/.config/autostart`, so enable/disable go through the XDG
  /// Background portal, which creates/removes `~/.config/autostart/<app-id>.desktop` on the host for us.
  /// commandline[0] becomes the flatpak `--command`, so it must be the manifest command (`bluebubbles`).
  static Future<bool> _portalAutostart(bool enable) async {
    final cmdline = _minimized ? "['bluebubbles', 'minimized']" : "['bluebubbles']";
    final options = "{'reason': <'Launch BlueBubbles at login'>, "
        "'autostart': <$enable>, 'commandline': <$cmdline>}";
    final result = await Process.run('gdbus', [
      'call', '--session',
      '--dest', 'org.freedesktop.portal.Desktop',
      '--object-path', '/org/freedesktop/portal/desktop',
      '--method', 'org.freedesktop.portal.Background.RequestBackground',
      '', options,
    ]);
    if (result.exitCode != 0) {
      Logger.error('Background portal RequestBackground failed: ${result.stderr}', tag: 'LaunchAtStartup');
      return false;
    }
    return enable;
  }

  /// Where the current platform's startup entry lives — matches what the package's enable() creates.
  static String? get shortcutPath {
    final appName = FilesystemSvc.packageInfo.appName;
    if (Platform.isWindows) {
      if (isMsix) {
        return p.join(Platform.environment['APPDATA']!, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup',
            '$appName.lnk');
      }
      return 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\$appName';
    } else if (Platform.isLinux) {
      final fileName = isFlatpak ? '${Platform.environment['FLATPAK_ID']}.desktop' : '$appName.desktop';
      return p.join(Platform.environment['HOME']!, '.config', 'autostart', fileName);
    }
    return null;
  }

  /// Reveals the startup entry in the file manager, except Windows non-MSIX where the entry is a
  /// registry key (Run), not a file — there we open regedit at that key.
  static Future<void> revealShortcut() async {
    final path = shortcutPath;
    if (path == null) return;
    if (Platform.isWindows && !isMsix) {
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit',
        '/v',
        'LastKey',
        '/d',
        r'Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run',
        '/f'
      ]);
      // regedit requires elevation; 'start' uses ShellExecute so the UAC prompt appears
      await Process.start('cmd', ['/c', 'start', '', 'regedit']);
      return;
    }
    await revealInFileManager(path);
  }

  static void setup(String appName, bool minimized) {
    _minimized = minimized;
    String appPath;
    String? packageName;
    if (isMsix) {
      final segments = p.split(Platform.resolvedExecutable);
      final parts = segments[segments.indexOf('WindowsApps') + 1].split('_');
      final familyName = '${parts.first}_${parts.last}';
      packageName = parts.first;
      appPath = 'shell:AppsFolder\\$familyName!bluebubbles';
    } else if (isFlatpak) {
      appPath = 'flatpak run app.bluebubbles.BlueBubbles';
    } else {
      appPath = Platform.resolvedExecutable;
    }
    las.LaunchAtStartup.instance.setup(
      appName: appName,
      appPath: appPath,
      packageName: packageName,
      args: minimized ? ['minimized'] : [],
    );
  }
}
