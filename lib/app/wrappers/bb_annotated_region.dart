import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BlueBubbles base page wrapper that handles system UI overlay styling
///
/// Provides consistent status bar and navigation bar styling across the app.
class BBAnnotatedRegion extends StatelessWidget {
  /// The child widget to wrap
  final Widget child;

  /// Custom status bar icon brightness (defaults to theme-based)
  final Brightness? statusBarIconBrightness;

  /// Custom navigation bar icon brightness (defaults to theme-based)
  final Brightness? systemNavigationBarIconBrightness;

  /// Custom navigation bar color (defaults to theme surface or transparent in immersive mode)
  final Color? systemNavigationBarColor;

  /// Custom status bar color (defaults to transparent)
  final Color? statusBarColor;

  const BBAnnotatedRegion({
    super.key,
    required this.child,
    this.statusBarIconBrightness,
    this.systemNavigationBarIconBrightness,
    this.systemNavigationBarColor,
    this.statusBarColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.systemUiOverlayStyle(
        systemNavigationBarColor: systemNavigationBarColor,
        systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
        statusBarColor: statusBarColor ?? Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
      ),
      child: child,
    );
  }
}
