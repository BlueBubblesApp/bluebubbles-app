import 'dart:io';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:tuple/tuple.dart';

enum EffectDependencies { brightness, color }

class WindowEffects {
  static final _effects = [
    WindowEffect.tabbed,
    WindowEffect.mica,
    WindowEffect.aero,
    WindowEffect.acrylic,
    WindowEffect.transparent,
    WindowEffect.disabled
  ];

  static final Map<WindowEffect, int> _versions = {
    WindowEffect.tabbed: 22523,
    WindowEffect.mica: 22000,
    WindowEffect.aero: 0,
    WindowEffect.acrylic: 17134,
    WindowEffect.transparent: 0,
    WindowEffect.disabled: 0,
  };

  static List<WindowEffect> get effects =>
      _effects.where((effect) => parsedWindowsVersion() >= _versions[effect]!).toList();

  static final _descriptions = {
    WindowEffect.tabbed: "Tabbed is a Mica-like material that incorporates theme and desktop wallpaper, but is more "
        "sensitive to desktop wallpaper color. Works only on later Windows 11 versions (build 22523 or higher).",
    WindowEffect.mica: "Mica replaces your background color with an incorporation of the desktop wallpaper and your "
        "theme. It is not affected by your background color. Works only on Windows 11 or greater (build 22000 or higher).",
    WindowEffect.aero: "Aero glass effect. Windows Vista & Windows 7 like glossy blur effect.",
    WindowEffect.acrylic: "Acrylic is a translucent brush effect that works best with colors other than pure white "
        "and pure black. Works only on Windows 10 version 1803 or higher (build 17134 or higher).",
    WindowEffect.transparent: "Transparent window background.",
    WindowEffect.disabled: "Default window background.",
  };

  static final Map<WindowEffect, List<EffectDependencies>> _dependencies = {
    WindowEffect.tabbed: [EffectDependencies.brightness],
    WindowEffect.mica: [EffectDependencies.brightness],
    WindowEffect.aero: [EffectDependencies.color],
    WindowEffect.acrylic: [EffectDependencies.color],
    WindowEffect.transparent: [EffectDependencies.color],
    WindowEffect.disabled: [],
  };

  // Map from window effect to opacity in <dark theme, light theme>
  static final Map<WindowEffect, Tuple2<double, double>> _opacities = {
    WindowEffect.tabbed: Tuple2(0, 0),
    WindowEffect.mica: Tuple2(0, 0),
    WindowEffect.aero: Tuple2(0.6, 0.75),
    WindowEffect.acrylic: Tuple2(0, 0.6),
    WindowEffect.transparent: Tuple2(0.7, 0.7),
    WindowEffect.disabled: Tuple2(1, 1),
  };

  static Map<WindowEffect, String> get descriptions {
    return Map.fromEntries(effects.map((effect) => MapEntry(effect, _descriptions[effect] ?? "")));
  }

  static double getOpacity({required Color color}) {
    bool dark = isDark(color: color);

    if (dark) {
      return SettingsManager().settings.windowEffectCustomOpacityDark.value;
    }
    return SettingsManager().settings.windowEffectCustomOpacityLight.value;
  }

  static double defaultOpacity({required bool dark}) {
    WindowEffect effect = SettingsManager().settings.windowEffect.value;
    return dark ? _opacities[effect]!.item1 : _opacities[effect]!.item2;
  }

  static bool dependsOnColor() {
    WindowEffect effect = SettingsManager().settings.windowEffect.value;
    return _dependencies[effect]!.contains(EffectDependencies.color);
  }

  static Color withOpacity({required Color color}) {
    return color.withOpacity(getOpacity(color: color));
  }

  static bool isDark({required Color color}) {
    return color.computeLuminance() <= 0.5;
  }

  static Future<void> setEffect({required Color color}) async {
    if (!kIsDesktop || !Platform.isWindows) return;
    WindowEffect effect = SettingsManager().settings.windowEffect.value;
    if (!effects.contains(effect)) SettingsManager().settings.windowEffect.value = WindowEffect.disabled;
    SettingsManager().saveSettings(SettingsManager().settings);

    bool supportsTransparentAcrylic = parsedWindowsVersion() >= 22000;
    bool addOpacity = SettingsManager().settings.windowEffect.value == WindowEffect.acrylic && !supportsTransparentAcrylic;

    // withOpacity uses withAlpha((255.0 * opacity).round());
    // so, the minimum nonzero alpha can be made with opacity 1 / 255
    double _extra = 1 / 255;
    bool _dark = true;

    if (_dependencies[effect]?.contains(EffectDependencies.brightness) ?? false) {
      _dark = isDark(color: color);
    }
    await Window.setEffect(effect: effect, color: color.withOpacity(addOpacity ? _extra : 0), dark: _dark);
  }
}

int parsedWindowsVersion() {
  String raw = Platform.operatingSystemVersion;
  return int.tryParse(raw.substring(raw.indexOf("Build") + 6, raw.length - 1)) ?? 0;
}
