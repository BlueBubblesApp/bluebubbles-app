import 'package:flutter/material.dart';

/// [NavigatorManager] is responsible for keeping a global key in which other managers can push views without a [BuildContext]
///
/// [navigatorKey] is set in main.dart
/// This class is a singleton
class NavigatorManager {
  factory NavigatorManager() {
    return _manager;
  }

  static final NavigatorManager _manager = NavigatorManager._internal();

  NavigatorManager._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
