import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// [GetxController] with support for optimized state management
class StatefulController extends GetxController {
  final Map<Object, List<Function>> updateWidgetFunctions = {};
  late final void Function(VoidCallback) updateObx;

  void updateWidgets<T>(Object? arg) {
    updateWidgetFunctions[T]?.forEach((e) => e.call(arg));
  }
}

/// [StatefulWidget] with support for optimized state management and a built-in
/// [GetxController]
abstract class CustomStateful<T extends StatefulController> extends StatefulWidget {
  const CustomStateful({Key? key, required this.parentController}) : super(key: key);

  final T parentController;
}

/// [State] with support for optimized state management using a custom
/// [GetxController]
abstract class CustomState<T extends CustomStateful, R, S extends StatefulController> extends State<T> with ThemeHelpers {
  // completer to check if the page animation is complete
  final animCompleted = Completer<void>();

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

    // set functions in the custom [GetxController]
    // this if clause allows us to only set the late final variable
    // when we are sure the controller is a fresh one
    if (widget.parentController.updateWidgetFunctions.isEmpty) {
      widget.parentController.updateObx = updateObx;
    }
    widget.parentController.updateWidgetFunctions[T] ??= [];
    widget.parentController.updateWidgetFunctions[T]!.add(updateWidget);

    // complete the completer when we know the page animation has finished
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.animation != null) {
        if (ModalRoute.of(context)?.animation?.status != AnimationStatus.completed) {
          late final AnimationStatusListener listener;
          listener = (AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              animCompleted.complete();
              ModalRoute.of(context)?.animation?.removeStatusListener(listener);
            }
          };
          ModalRoute.of(context)?.animation?.addStatusListener(listener);
        } else {
          animCompleted.complete();
        }
      } else {
        animCompleted.complete();
      }
    });
  }

  @override
  /// Force delete the [GetxController] when the page has disposed (unless we
  /// don't want to)
  void dispose() {
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

  @override
  /// Optimized [setState] function
  void setState(VoidCallback fn) {
    _optimizedUpdate(() {
      super.setState(fn);
    });
  }

  /// Optimized method to perform an update for any [Rx] variable
  void updateObx(VoidCallback fn) {
    _optimizedUpdate(fn);
  }

  /// Asynchronous [setState] function, in case we need to perform something
  /// after we are sure the state has been set
  Future<void> setStateAsync(VoidCallback fn) async {
    if (!mounted) return;

    Future<void> checkFrame() async {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        await SchedulerBinding.instance.endOfFrame;
        if (mounted) super.setState(fn);
      } else {
        if (mounted) super.setState(fn);
      }
    }

    if (animCompleted.isCompleted) {
      await checkFrame();
    } else {
      await animCompleted.future;
      await checkFrame();
    }
  }

  /// Internal function that runs the optimized widget updating code
  void _optimizedUpdate(VoidCallback fn) {
    if (!mounted) return;

    void checkFrame() {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        SchedulerBinding.instance.endOfFrame.then((_) {
          if (mounted) fn.call();
        });
      } else {
        if (mounted) fn.call();
      }
    }

    // make sure the page animation is completed before trying to update the state
    if (animCompleted.isCompleted) {
      checkFrame();
    } else {
      animCompleted.future.then((_) {
        checkFrame();
      });
    }
  }
}

/// Used for cases where we don't need a specific [GetxController], the main
/// benefit of this class is to provide an optimized [setState] function to
/// minimize lag and jank.
abstract class OptimizedState<T extends StatefulWidget> extends State<T> with ThemeHelpers {
  final animCompleted = Completer<void>();

  @override
  @mustCallSuper
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted && ModalRoute.of(context)?.animation != null) {
        if (ModalRoute.of(context)?.animation?.status != AnimationStatus.completed) {
          late final AnimationStatusListener listener;
          listener = (AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              animCompleted.complete();
              ModalRoute.of(context)?.animation?.removeStatusListener(listener);
            }
          };
          ModalRoute.of(context)?.animation?.addStatusListener(listener);
        } else {
          animCompleted.complete();
        }
      } else {
        animCompleted.complete();
      }
    });
  }

  @override
  void setState(VoidCallback fn) {
    _optimizedUpdate(() {
      super.setState(fn);
    });
  }

  void updateObx(VoidCallback fn) {
    _optimizedUpdate(fn);
  }

  Future<void> setStateAsync(VoidCallback fn) async {
    if (!mounted) return;

    Future<void> checkFrame() async {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        await SchedulerBinding.instance.endOfFrame;
        if (mounted) super.setState(fn);
      } else {
        if (mounted) super.setState(fn);
      }
    }

    if (animCompleted.isCompleted) {
      await checkFrame();
    } else {
      await animCompleted.future;
      await checkFrame();
    }
  }

  void _optimizedUpdate(VoidCallback fn) {
    if (!mounted) return;

    void checkFrame() {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        SchedulerBinding.instance.endOfFrame.then((_) {
          if (mounted) fn.call();
        });
      } else {
        if (mounted) fn.call();
      }
    }

    if (animCompleted.isCompleted) {
      checkFrame();
    } else {
      animCompleted.future.then((_) {
        checkFrame();
      });
    }
  }
}
