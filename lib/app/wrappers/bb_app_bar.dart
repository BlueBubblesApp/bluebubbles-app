import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// BlueBubbles standardized AppBar wrapper
///
/// Baked-in defaults matching the app's existing conventions:
/// - `elevation` is always 0
/// - `scrolledUnderElevation` defaults to 3.0
/// - `backgroundColor` defaults to `context.headerColor`
/// - `centerTitle` defaults to `context.iOS`
/// - `surfaceTintColor` defaults to `context.theme.colorScheme.primary`
/// - `systemOverlayStyle` defers to Flutter's AppBar behavior unless provided
/// - `toolbarHeight` defaults to 80 on desktop, 50 on mobile
/// - `automaticallyImplyLeading` defaults to false
///
/// Use [titleText] for the common case of a plain string title styled with
/// [titleStyle] (defaults to `context.theme.textTheme.titleLarge`).
/// Pass a custom [title] widget only when you need something beyond plain text.
///
/// Being a [PreferredSizeWidget], it can be passed directly to
/// [Scaffold.appBar] without a [PreferredSize] wrapper.
///
/// Example:
/// ```dart
/// appBar: BBAppBar(
///   titleText: 'Settings',
///   leading: buildBackButton(context),
///   actions: [IconButton(...)],
/// ),
/// ```
class BBAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Custom title widget. Use [titleText] instead for plain string titles.
  final Widget? title;

  /// Plain-text title. Rendered as `Text(titleText, style: titleStyle ?? titleLarge)`.
  /// Ignored when [title] is provided.
  final String? titleText;

  /// Style for [titleText]. Defaults to `context.theme.textTheme.titleLarge`.
  final TextStyle? titleStyle;

  final Widget? leading;
  final List<Widget>? actions;

  /// Defaults to `context.headerColor`.
  final Color? backgroundColor;

  /// Defaults to `kIsDesktop ? 80.0 : 50.0`.
  final double? toolbarHeight;

  /// Defaults to 3.0.
  final double scrolledUnderElevation;

  /// Defaults to `context.theme.colorScheme.primary`.
  final Color? surfaceTintColor;

  /// Defaults to `context.iOS`.
  final bool? centerTitle;

  /// Optional manual override for the status/navigation bar overlay style.
  ///
  /// When null, Flutter's [AppBar] chooses the overlay style from the effective
  /// app bar background color and theme defaults.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Defaults to false.
  final bool automaticallyImplyLeading;

  final double? leadingWidth;
  final IconThemeData? iconTheme;

  /// Optional bottom widget (e.g. a [TabBar]).
  /// Its height is included in [preferredSize].
  final PreferredSizeWidget? bottom;

  const BBAppBar({
    super.key,
    this.title,
    this.titleText,
    this.titleStyle,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.toolbarHeight,
    this.scrolledUnderElevation = 3.0,
    this.surfaceTintColor,
    this.centerTitle,
    this.systemOverlayStyle,
    this.automaticallyImplyLeading = false,
    this.leadingWidth,
    this.iconTheme,
    this.bottom,
  });

  double get _resolvedToolbarHeight => toolbarHeight ?? (kIsDesktop ? 80.0 : 50.0);

  @override
  Size get preferredSize => Size.fromHeight(_resolvedToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? context.headerColor;
    // A transparent app bar shows the theme surface through it, but its literal
    // color (0x00000000) reads as pure black to brightness estimation — without
    // this, transparent app bars would flip status bar/icon colors to light-on-dark
    // contrast even in a light theme. Estimate from the real visible color instead.
    final effectiveBrightnessColor = effectiveBg == Colors.transparent ? context.theme.colorScheme.surface : effectiveBg;
    final effectiveCenterTitle = centerTitle ?? context.iOS;
    final effectiveSurfaceTint = surfaceTintColor ?? context.theme.colorScheme.primary;
    final effectiveTitle =
        title ?? (titleText != null ? Text(titleText!, style: titleStyle ?? context.theme.textTheme.titleLarge) : null);

    return AppBar(
      title: effectiveTitle,
      leading: leading,
      actions: actions,
      backgroundColor: effectiveBg,
      toolbarHeight: _resolvedToolbarHeight,
      elevation: 0,
      scrolledUnderElevation: scrolledUnderElevation,
      surfaceTintColor: effectiveSurfaceTint,
      centerTitle: effectiveCenterTitle,
      systemOverlayStyle: systemOverlayStyle ??
          context.systemUiOverlayStyle(
            statusBarColor: effectiveBg,
            backgroundBrightness: ThemeData.estimateBrightnessForColor(effectiveBrightnessColor),
          ),
      automaticallyImplyLeading: automaticallyImplyLeading,
      leadingWidth: leadingWidth,
      iconTheme: iconTheme,
      bottom: bottom,
    );
  }
}
