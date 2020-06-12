import 'package:flutter/material.dart';

class NavigatorManager {
  factory NavigatorManager() {
    return _manager;
  }

  static final NavigatorManager _manager = NavigatorManager._internal();

  NavigatorManager._internal();
  final GlobalKey<NavigatorState> navigatorKey =
      new GlobalKey<NavigatorState>();
}
