import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';

class TitleBarWrapper extends StatelessWidget {
  TitleBarWrapper({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return kIsDesktop
        ? WindowBorder(
            color: Colors.transparent,
            width: 0,
            child: Stack(children: <Widget>[child, TitleBar()]),
          )
        : child;
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
        iconNormal: context.theme.primaryColor,
        mouseOver: context.theme.primaryColor,
        mouseDown: context.theme.primaryColorDark,
        iconMouseOver: context.theme.accentColor,
        iconMouseDown: context.theme.primaryColorLight);

    WindowButtonColors closeButtonColors = WindowButtonColors(
        mouseOver: Color(0xFFD32F2F),
        mouseDown: Color(0xFFB71C1C),
        iconNormal: context.theme.primaryColor,
        iconMouseOver: Colors.white);
    return Row(
        children: [
          MinimizeWindowButton(colors: buttonColors),
          MaximizeWindowButton(colors: buttonColors),
          CloseWindowButton(colors: closeButtonColors),
        ],
    );
  }
}
