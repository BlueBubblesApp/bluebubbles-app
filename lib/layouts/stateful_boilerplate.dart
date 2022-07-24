import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

class StatefulController extends GetxController {
  final Map<Object, Function> updateWidgetFunctions = {};
}

abstract class CustomStateful<T extends StatefulController> extends StatefulWidget {
  CustomStateful({Key? key, required this.parentController}) : super(key: key);

  final T parentController;
}

abstract class CustomState<T extends CustomStateful, R, S> extends State<T> {
  final animCompleted = Completer<void>();

  @protected
  S get controller => widget.parentController as S;

  @override
  @mustCallSuper
  void initState() {
    super.initState();

    widget.parentController.updateWidgetFunctions[T] = updateWidget;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
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

  @protected
  @mustCallSuper
  @optionalTypeArgs
  void updateWidget(R newVal) {
    setState(() {});
  }

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;

    void checkFrame() {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        SchedulerBinding.instance.endOfFrame.then((_) {
          if (mounted) super.setState(fn);
        });
      } else {
        super.setState(fn);
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

  Future<void> setStateAsync(VoidCallback fn) async {
    if (!mounted) return;

    Future<void> checkFrame() async {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        await SchedulerBinding.instance.endOfFrame;
        if (mounted) super.setState(fn);
      } else {
        super.setState(fn);
      }
    }

    if (animCompleted.isCompleted) {
      await checkFrame();
    } else {
      await animCompleted.future;
      await checkFrame();
    }
  }
}

/// Used for cases where we don't need a specific [GetxController], the main
/// benefit of this class is to provide an optimized [setState] function to
/// minimize lag and jank.
abstract class OptimizedState<T extends StatefulWidget> extends State<T> {
  final animCompleted = Completer<void>();

  @override
  @mustCallSuper
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
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
  void setState(VoidCallback fn) {
    if (!mounted) return;

    void checkFrame() {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        SchedulerBinding.instance.endOfFrame.then((_) {
          if (mounted) super.setState(fn);
        });
      } else {
        super.setState(fn);
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

  Future<void> setStateAsync(VoidCallback fn) async {
    if (!mounted) return;

    Future<void> checkFrame() async {
      // if there's a current frame,
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // wait for the end of that frame.
        await SchedulerBinding.instance.endOfFrame;
        if (mounted) super.setState(fn);
      } else {
        super.setState(fn);
      }
    }

    if (animCompleted.isCompleted) {
      await checkFrame();
    } else {
      await animCompleted.future;
      await checkFrame();
    }
  }
}
