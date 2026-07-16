import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle buildSystemUiOverlayStyle({
  required Color surfaceColor,
  required bool immersiveMode,
  Color? systemNavigationBarColor,
  Color statusBarColor = Colors.transparent,
  Brightness? backgroundBrightness,
  Brightness? systemNavigationBarIconBrightness,
  Brightness? statusBarIconBrightness,
}) {
  final brightness = backgroundBrightness ?? ThemeData.estimateBrightnessForColor(surfaceColor);
  final foregroundBrightness = _oppositeBrightness(brightness);

  return SystemUiOverlayStyle(
    systemNavigationBarColor: immersiveMode ? Colors.transparent : systemNavigationBarColor ?? surfaceColor,
    systemNavigationBarDividerColor: immersiveMode ? Colors.transparent : null,
    systemNavigationBarIconBrightness: systemNavigationBarIconBrightness ?? foregroundBrightness,
    systemNavigationBarContrastEnforced: immersiveMode ? false : null,
    statusBarColor: statusBarColor,
    statusBarBrightness: brightness,
    statusBarIconBrightness: statusBarIconBrightness ?? foregroundBrightness,
    systemStatusBarContrastEnforced: false,
  );
}

Brightness _oppositeBrightness(Brightness brightness) {
  return brightness == Brightness.light ? Brightness.dark : Brightness.light;
}
