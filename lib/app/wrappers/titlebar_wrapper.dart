import 'dart:io';

import 'package:bluebubbles/app/components/desktop/desktop_menu_bar.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';
import 'package:window_manager/window_manager.dart';

class TitleBarWrapper extends StatefulWidget {
  TitleBarWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<TitleBarWrapper> createState() => _TitleBarWrapperState();
}

class _TitleBarWrapperState extends State<TitleBarWrapper> {
  final RxBool showMenuBar = false.obs;

  @override
  Widget build(BuildContext context) {
    if (!kIsDesktop) {
      return Stack(
        children: <Widget>[
          child,
          if (ss.settings.showConnectionIndicator.value) const ConnectionIndicator(),
        ],
      );
    }

    return Obx(() => Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.altLeft) {
          showMenuBar.value = !showMenuBar.value;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: (ss.settings.useCustomTitleBar.value && Platform.isLinux) || (kIsDesktop && !Platform.isLinux) ? WindowBorder(
          color: Colors.transparent,
          width: 0,
          child: Stack(
            children: <Widget>[
              Column(
                children: [
                  if (showMenuBar.value)
                    const DesktopMenuBar(),
                  Expanded(child: widget.child),
                ],
              ),
              const TitleBar(),
              if (ss.settings.showConnectionIndicator.value)
                const ConnectionIndicator(),
            ]
          ),
        ) : Stack(
          children: <Widget>[
            Column(
              children: [
                if (showMenuBar.value)
                  const DesktopMenuBar(),
                Expanded(child: widget.child),
              ],
            ),
            if (ss.settings.showConnectionIndicator.value)
              const ConnectionIndicator(),
          ],
        ),
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
          Expanded(
            child: MoveWindow(),
          ),
        ],
      ),
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
          onPressed: () async => ss.settings.minimizeToTray.value ? await windowManager.hide() : await windowManager.minimize(),
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
