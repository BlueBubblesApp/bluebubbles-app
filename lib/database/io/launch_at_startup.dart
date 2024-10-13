import 'package:bluebubbles/helpers/types/helpers/misc_helpers.dart';
import 'package:launch_at_startup/launch_at_startup.dart' as las;
import 'package:universal_io/io.dart';

class LaunchAtStartup {
  static Future<void> enable() async => await las.LaunchAtStartup.instance.enable();

  static Future<void> disable() async => await las.LaunchAtStartup.instance.disable();

  static setup(String appName, bool minimized) => las.LaunchAtStartup.instance.setup(
    appName: appName,
    appPath: isFlatpak ? "flatpak run app.bluebubbles.BlueBubbles" : Platform.resolvedExecutable,
    args: minimized ? ["minimized"] : [],
  );
}