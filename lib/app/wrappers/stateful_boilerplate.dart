import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [GetxController] with support for widget update callbacks
class StatefulController extends GetxController {
  final Map<Object, List<Function>> updateWidgetFunctions = {};

  void updateWidgets<T>(Object? arg) {
    updateWidgetFunctions[T]?.forEach((e) => e.call(arg));
  }
}

/// [StatefulWidget] with a built-in [GetxController]
abstract class CustomStateful<T extends StatefulController> extends StatefulWidget {
  const CustomStateful({super.key, required this.parentController});

  final T parentController;
}

/// [State] with controller lifecycle management and a built-in [GetxController]
abstract class CustomState<T extends CustomStateful, R, S extends StatefulController> extends State<T>
    with ThemeHelpers {
  @protected

  /// Convenience getter for the [GetxController]
  S get controller => widget.parentController as S;

  @protected
  String? _tag;

  /// Set tag of associated [GetxController] if needed
  set tag(String t) => _tag = t;

  @protected
  bool _forceDelete = true;

  /// Set forceDelete false if needed
  set forceDelete(bool fd) => _forceDelete = fd;

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    widget.parentController.updateWidgetFunctions[T] ??= [];
    widget.parentController.updateWidgetFunctions[T]!.add(updateWidget);
  }

  @override

  /// Force delete the [GetxController] when the page has disposed (unless we
  /// don't want to)
  void dispose() {
    widget.parentController.updateWidgetFunctions[T]?.remove(updateWidget);
    if (_forceDelete) Get.delete<S>(tag: _tag);
    super.dispose();
  }

  @protected
  @mustCallSuper
  @optionalTypeArgs

  /// Override this method to update the widget easily
  /// ```
  /// @override
  /// void updateWidget(int newVal) {
  ///   controller.currentPage = newVal;
  ///   super.updateWidget(newVal);
  /// }
  /// ```
  void updateWidget(R newVal) {
    setState(() {});
  }
}
