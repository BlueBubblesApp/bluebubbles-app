import 'package:bluebubbles/app/wrappers/bb_annotated_region.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window_effect.dart';

/// BlueBubbles standardized Scaffold wrapper
///
/// Combines BBAnnotatedRegion with Scaffold and handles common patterns:
/// - Automatic window effect transparency
/// - System UI overlay styling
/// - Theme-aware defaults
///
/// Example:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return BBScaffold(
///     appBar: AppBar(title: Text('My Page')),
///     body: YourContent(),
///   );
/// }
/// ```
class BBScaffold extends StatelessWidget {
  /// The primary content of the scaffold
  final Widget? body;

  /// App bar for the scaffold
  final PreferredSizeWidget? appBar;

  /// Background color override
  ///
  /// If null, automatically uses transparent for window effects or theme background
  final Color? backgroundColor;

  /// Floating action button
  final Widget? floatingActionButton;

  /// Position of the floating action button
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Bottom navigation bar
  final Widget? bottomNavigationBar;

  /// Drawer widget
  final Widget? drawer;

  /// End drawer widget
  final Widget? endDrawer;

  /// Bottom sheet widget
  final Widget? bottomSheet;

  /// Whether the body should extend behind app bar
  final bool extendBodyBehindAppBar;

  /// Whether the body should extend behind the bottom navigation bar / gesture pill.
  ///
  /// Defaults to true so the scaffold's background fills edge-to-edge on
  /// modern Android edge-to-edge rendering.
  final bool extendBodyBehindBottomPill;

  /// Resize to avoid bottom inset
  final bool? resizeToAvoidBottomInset;

  /// Persistent footer buttons
  final List<Widget>? persistentFooterButtons;

  /// Persistent footer alignment
  final AlignmentDirectional? persistentFooterAlignment;

  /// Whether to apply top SafeArea padding to the body.
  ///
  /// Defaults to false because an AppBar typically handles the status bar inset.
  final bool safeAreaTop;

  /// Whether to apply bottom SafeArea padding to the body.
  ///
  /// If null, defaults to `false` when immersive mode is enabled and
  /// [extendBodyBehindBottomPill] is true (so the body can extend edge-to-edge
  /// behind the transparent gesture pill), and `true` otherwise (so content
  /// isn't obscured by the opaque nav bar).
  final bool? safeAreaBottom;

  /// Whether to apply left SafeArea padding to the body.
  final bool safeAreaLeft;

  /// Whether to apply right SafeArea padding to the body.
  final bool safeAreaRight;

  /// Keeps the bottom SafeArea padding stable while the keyboard is visible
  /// (SafeArea.maintainBottomViewPadding). Use when the body must not shift
  /// as viewInsets animate.
  final bool safeAreaMaintainBottomViewPadding;

  const BBScaffold({
    super.key,
    this.body,
    this.appBar,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.extendBodyBehindAppBar = true,
    this.extendBodyBehindBottomPill = true,
    this.resizeToAvoidBottomInset,
    this.persistentFooterButtons,
    this.persistentFooterAlignment,
    this.safeAreaTop = false,
    this.safeAreaBottom,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.safeAreaMaintainBottomViewPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    // Wrapping this in Obx may cause issues, so removingit for now.
    // If we need to react to changes in settings, this needs to come from the "top down",
    // instead of going through GetX's reactive system here.
    final effectiveBackgroundColor = backgroundColor ??
        (SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface);

    final effectiveSafeAreaBottom =
        safeAreaBottom ?? !(SettingsSvc.settings.immersiveMode.value && extendBodyBehindBottomPill);

    // SafeArea is applied to the body in all cases so content doesn't overlap
    // system bars. The Scaffold itself is never wrapped in SafeArea — this
    // ensures the Scaffold's backgroundColor fills edge-to-edge, including
    // the bottom gesture pill area on modern Android edge-to-edge rendering.
    // Wrapping the Scaffold in SafeArea would prevent it from filling the
    // gesture area, making it appear black.
    final effectiveBody = body == null
        ? null
        : SafeArea(
            top: safeAreaTop,
            bottom: effectiveSafeAreaBottom,
            left: safeAreaLeft,
            right: safeAreaRight,
            maintainBottomViewPadding: safeAreaMaintainBottomViewPadding,
            child: body!,
          );

    final scaffold = Scaffold(
      backgroundColor: effectiveBackgroundColor,
      appBar: appBar,
      body: effectiveBody,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBodyBehindBottomPill,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      persistentFooterButtons: persistentFooterButtons,
      persistentFooterAlignment: persistentFooterAlignment ?? AlignmentDirectional.centerEnd,
    );

    return BBAnnotatedRegion(child: scaffold);
  }
}
