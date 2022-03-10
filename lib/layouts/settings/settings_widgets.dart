import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_text_field.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:get/get.dart';

class SettingsScaffold extends StatelessWidget {
  final ScrollController controller = ScrollController();
  final String title;
  final String? initialHeader;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final Color headerColor;
  final Color tileColor;
  final List<Widget> bodySlivers;
  final List<Widget> actions;
  final RxDouble remainingHeight = RxDouble(0);

  SettingsScaffold({
    required this.title,
    required this.initialHeader,
    required this.iosSubtitle,
    required this.materialSubtitle,
    required this.headerColor,
    required this.tileColor,
    required this.bodySlivers,
    this.actions = const []
  });

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      if (SettingsManager().settings.skin.value != Skins.Samsung) return;
      // this is so settings pages that would normally not scroll can still scroll
      // to make the header large or small
      if (controller.position.viewportDimension < context.height) {
        remainingHeight.value = context.height - controller.position.viewportDimension + (context.height / 3 - 50);
      } else if (controller.position.maxScrollExtent < context.height / 3 - 50) {
        remainingHeight.value = context.height / 3 - 50 - controller.position.maxScrollExtent;
      }
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? tileColor : headerColor,
        appBar: SettingsManager().settings.skin.value == Skins.Samsung ? null : PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                systemOverlayStyle: ThemeData.estimateBrightnessForColor(headerColor) == Brightness.dark
                      ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  title,
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            if (SettingsManager().settings.skin.value != Skins.Samsung) return false;
            final scrollDistance = context.height / 3 - 57;
            if (controller.offset > 0 && controller.offset < scrollDistance && controller.offset != controller.position.maxScrollExtent) {
              final double snapOffset =
              controller.offset / scrollDistance > 0.5 ? scrollDistance : 0;

              Future.microtask(() => controller.animateTo(snapOffset,
                  duration: Duration(milliseconds: 200), curve: Curves.linear));
            }
            return false;
          },
          child: ImprovedScrolling(
            enableMMBScrolling: true,
            mmbScrollConfig: MMBScrollConfig(
              customScrollCursor: DefaultCustomScrollCursor(
                cursorColor: context.textTheme.subtitle1!.color!,
                backgroundColor: Colors.white,
                borderColor: context.textTheme.headline1!.color!,
              ),
            ),
            scrollController: controller,
            child: CustomScrollView(
              controller: controller,
              shrinkWrap: true,
              physics: ThemeSwitcher.getScrollPhysics(),
              slivers: <Widget>[
                if (SettingsManager().settings.skin.value == Skins.Samsung)
                  SliverAppBar(
                    backgroundColor: headerColor,
                    pinned: true,
                    stretch: true,
                    expandedHeight: context.height / 3,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    flexibleSpace: LayoutBuilder(
                      builder: (context, _) {
                        var expandRatio = 1 - (controller.offset)
                            / (context.height / 3 - 50);
                        if (expandRatio > 1.0) expandRatio = 1.0;
                        if (expandRatio < 0.1) expandRatio = 0.0;
                        final animation = AlwaysStoppedAnimation<double>(expandRatio);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            FadeTransition(
                              opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                                parent: animation,
                                curve: Interval(0.3, 1.0, curve: Curves.easeIn),
                              )),
                              child: Center(
                                  child: Text(title, textScaleFactor: 2.5, textAlign: TextAlign.center)
                              ),
                            ),
                            FadeTransition(
                              opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                                parent: animation,
                                curve: Interval(0.0, 0.7, curve: Curves.easeOut),
                              )),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  padding: EdgeInsets.only(left: 50),
                                  height: 50,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      title,
                                      style: Theme.of(context).textTheme.headline1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  height: 50,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: buildBackButton(context),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                height: 50,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    children: actions,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (SettingsManager().settings.skin.value != Skins.Samsung && initialHeader != null)
                        Container(
                            height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                            alignment: Alignment.bottomLeft,
                            decoration: SettingsManager().settings.skin.value == Skins.iOS
                                ? BoxDecoration(
                              color: headerColor,
                              border: Border(
                                  bottom: BorderSide(
                                      color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                            )
                                : BoxDecoration(
                              color: tileColor,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                              child: Text(initialHeader!.psCapitalize,
                                  style:
                                  SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                            )),
                      Container(
                          color: SettingsManager().settings.skin.value == Skins.Samsung ? null : tileColor,
                          padding: EdgeInsets.only(top: 5.0)
                      ),
                    ]
                  )
                ),
                ...bodySlivers,
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Obx(() => SettingsManager().settings.skin.value == Skins.Samsung ? Container(
                        height: remainingHeight.value
                      ) : SizedBox.shrink()),
                      Container(
                          color: SettingsManager().settings.skin.value == Skins.Samsung ? null : tileColor,
                          padding: EdgeInsets.only(top: SettingsManager().settings.skin.value == Skins.Samsung ? 30 : 5.0)
                      ),
                      if (SettingsManager().settings.skin.value != Skins.Samsung)
                        Container(
                          height: 30,
                          decoration: SettingsManager().settings.skin.value == Skins.iOS
                              ? BoxDecoration(
                            color: headerColor,
                            border: Border(
                                top: BorderSide(
                                    color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                          )
                              : null,
                        ),
                    ]
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    Key? key,
    this.onTap,
    this.onLongPress,
    this.title,
    this.trailing,
    this.leading,
    this.subtitle,
    this.backgroundColor,
    this.isThreeLine = false,
  }) : super(key: key);

  final Function? onTap;
  final Function? onLongPress;
  final String? subtitle;
  final String? title;
  final Widget? trailing;
  final Widget? leading;
  final Color? backgroundColor;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SettingsManager().settings.skin.value == Skins.Samsung ? null : backgroundColor,
      child: ListTile(
        onLongPress: onLongPress as void Function()?,
        tileColor: SettingsManager().settings.skin.value == Skins.Samsung ? null : backgroundColor,
        onTap: onTap as void Function()?,
        leading: leading,
        title: Text(
          title!,
          style: Theme.of(context).textTheme.bodyText1,
        ),
        trailing: trailing,
        subtitle: subtitle != null
            ? Text(
          subtitle!,
          style: Theme.of(context).textTheme.subtitle1,
        )
            : null,
        isThreeLine: isThreeLine,
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  const SettingsTextField(
      {Key? key,
        this.onTap,
        required this.title,
        this.trailing,
        required this.controller,
        this.placeholder,
        this.maxLines = 14,
        this.keyboardType = TextInputType.multiline,
        this.inputFormatters = const []})
      : super(key: key);

  final TextEditingController controller;
  final Function? onTap;
  final String title;
  final String? placeholder;
  final Widget? trailing;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: onTap as void Function()?,
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                title,
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: trailing,
              subtitle: Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: CustomCupertinoTextField(
                  cursorColor: Theme.of(context).primaryColor,
                  onLongPressStart: () {
                    Feedback.forLongPress(context);
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: inputFormatters,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                      color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      fontSizeDelta: -0.25),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: 1,
                  placeholder: placeholder ?? "Enter your text here",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.subtitle1,
                  autofocus: SettingsManager().settings.autoOpenKeyboard.value,
                  decoration: BoxDecoration(
                    color: Theme.of(context).backgroundColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Divider(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
              thickness: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  SettingsSwitch({
    Key? key,
    required this.initialVal,
    required this.onChanged,
    required this.title,
    this.backgroundColor,
    this.subtitle,
  }) : super(key: key);
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SettingsManager().settings.skin.value == Skins.Samsung ? null : backgroundColor,
      child: SwitchListTile(
        tileColor: SettingsManager().settings.skin.value == Skins.Samsung ? null : backgroundColor,
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyText1,
        ),
        subtitle: subtitle != null
            ? Text(
          subtitle!,
          style: Theme.of(context).textTheme.subtitle1,
        )
            : null,
        value: initialVal,
        activeColor: Theme.of(context).primaryColor,
        activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
        inactiveTrackColor: backgroundColor == Theme.of(context).colorScheme.secondary
            ? Theme.of(context).backgroundColor.withOpacity(0.6)
            : Theme.of(context).colorScheme.secondary.withOpacity(0.6),
        inactiveThumbColor: backgroundColor == Theme.of(context).colorScheme.secondary
            ? Theme.of(context).backgroundColor
            : Theme.of(context).colorScheme.secondary,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsOptions<T extends Object> extends StatelessWidget {
  SettingsOptions({
    Key? key,
    required this.onChanged,
    required this.options,
    this.cupertinoCustomWidgets,
    required this.initial,
    this.textProcessing,
    required this.title,
    this.subtitle,
    this.capitalize = true,
    this.backgroundColor,
    this.secondaryColor,
  }) : super(key: key);
  final String title;
  final void Function(T?) onChanged;
  final List<T> options;
  final Iterable<Widget>? cupertinoCustomWidgets;
  final T initial;
  final String Function(T)? textProcessing;
  final String? subtitle;
  final bool capitalize;
  final Color? backgroundColor;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      final texts = options.map((e) => Text(capitalize ? textProcessing!(e).capitalize! : textProcessing!(e)));
      final map = Map<T, Widget>.fromIterables(options, cupertinoCustomWidgets ?? texts);
      return Container(
        color: backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: 13),
        height: 50,
        width: context.width,
        child: CupertinoSlidingSegmentedControl<T>(
          children: map,
          groupValue: initial,
          thumbColor: secondaryColor != null && secondaryColor == backgroundColor
              ? secondaryColor!.lightenOrDarken(20)
              : secondaryColor ?? Colors.white,
          backgroundColor: backgroundColor ?? CupertinoColors.tertiarySystemFill,
          onValueChanged: onChanged,
        ),
      );
    }
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                  ),
                  (subtitle != null)
                      ? Container(
                    constraints: BoxConstraints(maxWidth: CustomNavigator.width(context) * 2 / 3),
                    child: Padding(
                      padding: EdgeInsets.only(top: 3.0),
                      child: Text(
                        subtitle ?? "",
                        style: Theme.of(context).textTheme.subtitle1,
                      ),
                    ),
                  )
                      : Container(),
                ]),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    dropdownColor: Theme.of(context).colorScheme.secondary,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).textTheme.bodyText1!.color,
                    ),
                    value: initial,
                    items: options.map<DropdownMenuItem<T>>((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(
                          capitalize ? textProcessing!(e).capitalize! : textProcessing!(e),
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSlider extends StatelessWidget {
  SettingsSlider(
      {required this.startingVal,
        this.update,
        required this.text,
        this.formatValue,
        required this.min,
        required this.max,
        required this.divisions,
        this.leading,
        this.backgroundColor,
        Key? key})
      : super(key: key);

  final double startingVal;
  final Function(double val)? update;
  final String text;
  final Function(double value)? formatValue;
  final double min;
  final double max;
  final int divisions;
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    String value = startingVal.toString();
    if (formatValue != null) {
      value = formatValue!(startingVal);
    }

    return Container(
      color: SettingsManager().settings.skin.value == Skins.Samsung ? null : backgroundColor,
      child: ListTile(
        tileColor: SettingsManager().settings.skin.value == Skins.Samsung ? null : backgroundColor,
        leading: leading,
        trailing: Text(value),
        title: SettingsManager().settings.skin.value == Skins.iOS
            ? CupertinoSlider(
          activeColor: Theme.of(context).primaryColor,
          value: startingVal,
          onChanged: update,
          divisions: divisions,
          min: min,
          max: max,
        ) : Slider(
          activeColor: Theme.of(context).primaryColor,
          inactiveColor: Theme.of(context).primaryColor.withOpacity(0.2),
          value: startingVal,
          onChanged: update,
          label: value,
          divisions: divisions,
          min: min,
          max: max,
        ),
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final Color headerColor;
  final Color tileColor;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final String text;

  SettingsHeader(
      {required this.headerColor,
        required this.tileColor,
        required this.iosSubtitle,
        required this.materialSubtitle,
        required this.text});

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.Samsung) return SizedBox(height: 15);
    return Column(children: [
      Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
      Container(
          height: SettingsManager().settings.skin.value == Skins.iOS ? 60 : 40,
          alignment: Alignment.bottomLeft,
          decoration: SettingsManager().settings.skin.value == Skins.iOS
              ? BoxDecoration(
            color: headerColor,
            border: Border.symmetric(
                horizontal: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
          )
              : BoxDecoration(
            color: tileColor,
            border:
            Border(top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 15),
            child: Text(text.psCapitalize,
                style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
          )),
      Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
    ]);
  }
}

class SettingsSection extends StatelessWidget {
  final List<Widget> children;
  final Color backgroundColor;

  SettingsSection({required this.children, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: SettingsManager().settings.skin.value == Skins.Samsung ? BorderRadius.circular(25) : BorderRadius.circular(0),
      child: Container(
        color: backgroundColor,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children
        ),
      ),
    );
  }
}

class SettingsLeadingIcon extends StatelessWidget {
  final IconData iosIcon;
  final IconData materialIcon;
  final Color? containerColor;

  SettingsLeadingIcon({
    required this.iosIcon,
    required this.materialIcon,
    this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Material(
          shape: SettingsManager().settings.skin.value == Skins.Samsung ? SquircleBorder(
            side: BorderSide(color: SettingsManager().settings.skin.value == Skins.Samsung ? containerColor ?? Colors.grey : Colors.transparent, width: 3.0),
          ) : null,
          color: SettingsManager().settings.skin.value == Skins.Samsung ? containerColor ?? Colors.grey : Colors.transparent,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
              SettingsManager().settings.skin.value == Skins.iOS ? containerColor ?? Colors.grey : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? iosIcon : materialIcon,
                color: SettingsManager().settings.skin.value != Skins.Material ? Colors.white : Colors.grey,
                size: SettingsManager().settings.skin.value != Skins.Material ? 23 : 30),
          ),
        ),
      ],
    );
  }
}

class SettingsDivider extends StatelessWidget {
  final double thickness;
  final Color? color;

  SettingsDivider({
    this.thickness = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      return Divider(
        color: color ?? Theme.of(context).colorScheme.secondary.withOpacity(0.5),
        thickness: 1,
      );
    } else {
      return Container();
    }
  }
}

class SquircleBorder extends ShapeBorder {
  final BorderSide side;
  final double superRadius;

  const SquircleBorder({
    this.side = BorderSide.none,
    this.superRadius = 5.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return SquircleBorder(
      side: side.scale(t),
      superRadius: superRadius * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _squirclePath(rect.deflate(side.width), superRadius);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _squirclePath(rect, superRadius);
  }

  static Path _squirclePath(Rect rect, double superRadius) {
    final c = rect.center;
    final dx = c.dx * (1.0 / superRadius);
    final dy = c.dy * (1.0 / superRadius);
    return Path()
      ..moveTo(c.dx, 0.0)
      ..relativeCubicTo(c.dx - dx, 0.0, c.dx, dy, c.dx, c.dy)
      ..relativeCubicTo(0.0, c.dy - dy, -dx, c.dy, -c.dx, c.dy)
      ..relativeCubicTo(-(c.dx - dx), 0.0, -c.dx, -dy, -c.dx, -c.dy)
      ..relativeCubicTo(0.0, -(c.dy - dy), dx, -c.dy, c.dx, -c.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        var path = getOuterPath(rect.deflate(side.width / 2.0), textDirection: textDirection);
        canvas.drawPath(path, side.toPaint());
    }
  }
}