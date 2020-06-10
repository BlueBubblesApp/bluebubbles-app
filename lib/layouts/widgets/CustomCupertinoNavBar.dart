import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Standard iOS navigation bar height without the status bar.
///
/// This height is constant and independent of accessibility as it is in iOS.
const double _kNavBarPersistentHeight = 80.0;

const Color _kDefaultNavBarBorderColor = Color(0x4D000000);

const Border _kDefaultNavBarBorder = Border(
  bottom: BorderSide(
    color: _kDefaultNavBarBorderColor,
    width: 0.0, // One physical pixel.
    style: BorderStyle.solid,
  ),
);

// There's a single tag for all instances of navigation bars because they can
// all transition between each other (per Navigator) via Hero transitions.
const _HeroTag _defaultHeroTag = _HeroTag(null);

class _HeroTag {
  const _HeroTag(this.navigator);

  final NavigatorState navigator;

  // Let the Hero tag be described in tree dumps.
  @override
  String toString() => 'Default Hero tag for Cupertino navigation bars with navigator $navigator';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _HeroTag
        && other.navigator == navigator;
  }

  @override
  int get hashCode {
    return identityHashCode(navigator);
  }
}

class CustomCupertinoNavBar extends CupertinoNavigationBar {
  /// Creates a navigation bar in the iOS style.
  const CustomCupertinoNavBar({
    Key key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.automaticallyImplyMiddle = true,
    this.previousPageTitle,
    this.middle,
    this.trailing,
    this.border = _kDefaultNavBarBorder,
    this.backgroundColor,
    this.brightness,
    this.padding,
    this.actionsForegroundColor,
    this.transitionBetweenRoutes = false,
    this.heroTag = _defaultHeroTag,
  }) : assert(automaticallyImplyLeading != null),
       assert(automaticallyImplyMiddle != null),
       assert(transitionBetweenRoutes != null),
       assert(
         heroTag != null,
         'heroTag cannot be null. Use transitionBetweenRoutes = false to '
         'disable Hero transition on this navigation bar.'
       ),
       assert(
         !transitionBetweenRoutes || identical(heroTag, _defaultHeroTag),
         'Cannot specify a heroTag override if this navigation bar does not '
         'transition due to transitionBetweenRoutes = false.'
       ),
       super(
          key: key,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          automaticallyImplyMiddle: automaticallyImplyMiddle,
          previousPageTitle: previousPageTitle,
          middle: middle,
          trailing: trailing,
          border: border,
          backgroundColor: backgroundColor,
          brightness: brightness,
          padding: padding,
          actionsForegroundColor: actionsForegroundColor,
          transitionBetweenRoutes: transitionBetweenRoutes,
          heroTag: heroTag
        );

  final Widget leading;
  final bool automaticallyImplyLeading;
  final bool automaticallyImplyMiddle;
  final String previousPageTitle;
  final Widget middle;
  final Widget trailing;
  final Color backgroundColor;
  final Brightness brightness;
  final EdgeInsetsDirectional padding;
  final Border border;

  @Deprecated(
    'Use CupertinoTheme and primaryColor to propagate color. '
    'This feature was deprecated after v1.1.2.'
  )
  final Color actionsForegroundColor;
  final bool transitionBetweenRoutes;
  final Object heroTag;

  @override
  Size get preferredSize {
    return const Size.fromHeight(_kNavBarPersistentHeight);
  }
}
