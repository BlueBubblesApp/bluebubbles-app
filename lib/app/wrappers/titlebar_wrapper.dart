import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';
import 'package:window_manager/window_manager.dart';

class TitleBarWrapper extends StatelessWidget {
  const TitleBarWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsDesktop) {
      return Stack(
        children: <Widget>[
          child,
          const ConnectionIndicator(),
        ],
      );
    }

    return Obx(
      () => (SettingsSvc.settings.titleBarStyle.value == BBTitleBarStyle.custom && Platform.isLinux) ||
              (kIsDesktop && !Platform.isLinux)
          ? WindowBorder(
              color: Colors.transparent,
              width: 0,
              child: Stack(children: <Widget>[
                child,
                const TitleBar(),
                const ConnectionIndicator(),
              ]),
            )
          : Stack(
              children: <Widget>[
                child,
                const ConnectionIndicator(),
              ],
            ),
    );
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: Row(
        children: [
          const Expanded(
            child: _DragStrip(),
          ),
          const WindowButtons()
        ],
      ),
    );
  }
}

/// bitsdojo's MoveWindow, from raw pointer events: its GestureDetector beat every tap under it in the gesture arena
class _DragStrip extends StatefulWidget {
  const _DragStrip();

  @override
  State<_DragStrip> createState() => _DragStripState();
}

class _DragStripState extends State<_DragStrip> {
  Offset? _down;
  Offset? _lastClick;
  Duration? _lastClickTime;

  bool _onTapTarget(PointerEvent event) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    return result.path.any((entry) {
      final target = entry.target;
      return target is RenderSemanticsGestureHandler && target.onTap != null;
    });
  }

  void _onDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _down = event.position;
    final last = _lastClick, lastTime = _lastClickTime;
    final isDouble = last != null &&
        lastTime != null &&
        event.timeStamp - lastTime < kDoubleTapTimeout &&
        (event.position - last).distance < kDoubleTapSlop;
    _lastClick = event.position;
    _lastClickTime = event.timeStamp;
    if (!isDouble) return;
    _lastClick = null;
    if (!_onTapTarget(event)) appWindow.maximizeOrRestore();
  }

  void _onMove(PointerMoveEvent event) {
    final down = _down;
    if (down == null || (event.position - down).distance < kTouchSlop) return;
    _down = null;
    _lastClick = null;
    appWindow.startDragging();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (_) => _down = null,
      onPointerCancel: (_) => _down = null,
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    WindowButtonColors buttonColors = WindowButtonColors(
        iconNormal: context.theme.colorScheme.primary,
        mouseOver: context.theme.colorScheme.primary,
        mouseDown: context.theme.colorScheme.primaryContainer,
        iconMouseOver: context.theme.colorScheme.onPrimary,
        iconMouseDown: context.theme.colorScheme.onPrimaryContainer);

    WindowButtonColors closeButtonColors = WindowButtonColors(
        mouseOver: context.theme.colorScheme.errorContainer,
        mouseDown: context.theme.colorScheme.onError,
        iconNormal: context.theme.colorScheme.primary,
        iconMouseOver: context.theme.colorScheme.onErrorContainer);
    return Row(
      children: [
        MinimizeWindowButton(
          colors: buttonColors,
          onPressed: () async =>
              SettingsSvc.settings.minimizeToTray.value ? await windowManager.hide() : await windowManager.minimize(),
          animate: true,
        ),
        MaximizeWindowButton(
          colors: buttonColors,
          animate: true,
        ),
        CloseWindowButton(
          colors: closeButtonColors,
          onPressed: () async => await windowManager.close(),
          animate: true,
        ),
      ],
    );
  }
}
