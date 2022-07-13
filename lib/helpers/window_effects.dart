import 'dart:io';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:tuple/tuple.dart';

enum EffectDependencies {
  brightness,
  color
}

class WindowEffects {

  static final effects = [WindowEffect.tabbed, WindowEffect.mica, WindowEffect.aero, WindowEffect.acrylic, WindowEffect.transparent, WindowEffect.disabled];

  static final _descriptions = {
    WindowEffect.tabbed: "Tabbed is a Mica-like material that incorporates theme and desktop wallpaper, but is more "
        "sensitive to desktop wallpaper color. Works only on later Windows 11 versions (builds "
        "higher than 22523).",
    WindowEffect.mica: "Mica is an opaque, dynamic material that incorporates theme and desktop wallpaper to paint "
        "the background of long-lived windows. Works only on Windows 11 or greater.",
    WindowEffect.aero: "Aero glass effect. Windows Vista & Windows 7 like glossy blur effect.",
    WindowEffect.acrylic: "Acrylic is a type of brush that creates a translucent texture. You can apply acrylic to "
        "app surfaces to add depth and help establish a visual hierarchy. Works only on Windows 10 version 1803 or "
        "higher.",
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
    WindowEffect.aero: Tuple2(0.6, 0.5),
    WindowEffect.acrylic: Tuple2(0, 0.6),
    WindowEffect.transparent: Tuple2(0.7, 0.7),
    WindowEffect.disabled: Tuple2(1, 1),
  };

  static Map<WindowEffect, String> get descriptions {
    return Map.fromEntries(effects.map((effect) => MapEntry(effect, _descriptions[effect] ?? "")));
  }

  static double getOpacity({required Color color, double? defaultOpacity}) {
    if (!kIsDesktop) return defaultOpacity ?? 1;

    WindowEffect effect = SettingsManager().settings.windowEffect.value;

    Tuple2? opacities = _opacities[effect];
    if (opacities == null) return 1;

    bool dark = isDark(color: color);
    if (dark) return opacities.item1;
    return opacities.item2;
  }

  static Color withOpacity({required Color color, double? defaultOpacity}) {
    return color.withOpacity(getOpacity(color: color, defaultOpacity: defaultOpacity));
  }

  static bool isDark({required Color color}) {
    return color.computeLuminance() <= 0.5;
  }

  static Future<void> setEffect({required Color color}) async {
    if (!kIsDesktop || !Platform.isWindows) return;
    WindowEffect effect = SettingsManager().settings.windowEffect.value;

    Color _color = Colors.transparent;
    bool _dark = true;
    if (_dependencies[effect]?.contains(EffectDependencies.color) ?? false) {
      _color = withOpacity(color: color);
    }
    if (_dependencies[effect]?.contains(EffectDependencies.brightness) ?? false) {
      _dark = isDark(color: color);
    }
    await Window.setEffect(effect: effect, color: _color, dark: _dark);
  }
}