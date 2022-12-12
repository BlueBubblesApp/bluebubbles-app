import 'package:launch_at_startup/launch_at_startup.dart' as las;
import 'package:universal_io/io.dart';

class LaunchAtStartup {
  static Future<void> enable() async => await las.LaunchAtStartup.instance.enable();

  static Future<void> disable() async => await las.LaunchAtStartup.instance.disable();

  static setup(String appName) => las.LaunchAtStartup.instance.setup(
    appName: appName,
    appPath: Platform.resolvedExecutable,
  );
}