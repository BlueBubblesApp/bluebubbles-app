import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

class ThemeManager {
  factory ThemeManager() {
    return _manager;
  }

  static final ThemeManager _manager = ThemeManager._internal();

  ThemeManager._internal();

  ScrollPhysics get scrollPhysics {
    if (SettingsManager().settings.skin.value == Skins.Material || SettingsManager().settings.skin.value == Skins.Samsung) {
      return AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
    } else if (SettingsManager().settings.skin.value == Skins.iOS) {
      return AlwaysScrollableScrollPhysics(
        parent: CustomBouncingScrollPhysics(),
      );
    } else {
      return AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
    }
  }

  bool inDarkMode(BuildContext context) {
    return (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ||
        (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.system &&
            SchedulerBinding.instance.window.platformBrightness == Brightness.dark));
  }
}
