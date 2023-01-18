import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/window_effects.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';
import 'package:window_manager/window_manager.dart';

class TitleBarWrapper extends StatelessWidget {
  TitleBarWrapper({
    Key? key,
    required this.child,
    this.hideInSplitView = false
  }) : super(key: key);

  final Widget child;
  final bool hideInSplitView;

  @override
  Widget build(BuildContext context) {
    if (chromeOS) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: child,
      );
    } else if (kIsWeb || (!kIsWeb && !kIsDesktop)) {
      return child;
    }

    bool showAltLayout = ss.settings.tabletMode.value
        && (!context.isPhone || context.width / context.height > 0.8)
        && context.width > 600;

    if (showAltLayout && hideInSplitView) {
      return child;
    }

    return Obx(() => (ss.settings.useCustomTitleBar.value && Platform.isLinux) || (kIsDesktop && !Platform.isLinux)
      ? WindowBorder(
          color: Colors.transparent,
          width: 0,
          child: Stack(children: <Widget>[
            child,
            const TitleBar()
          ]),
        )
      : child
    );
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: Row(
        children: [
          Expanded(
            child: MoveWindow(),
          ),
          const WindowButtons()
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);

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
          onPressed: () async => ss.settings.minimizeToTray.value
              ? await WindowManager.instance.hide()
              : await WindowManager.instance.minimize(),
          animate: true,
        ),
        MaximizeWindowButton(
          colors: buttonColors,
          animate: true,
        ),
        CloseWindowButton(
          colors: closeButtonColors,
          onPressed: () async => ss.settings.closeToTray.value
              ? await WindowManager.instance.hide()
              : await WindowManager.instance.close(),
          animate: true,
        ),
      ],
    );
  }
}
