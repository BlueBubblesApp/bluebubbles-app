import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_text_field.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
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

  SettingsScaffold(
      {required this.title,
      required this.initialHeader,
      required this.iosSubtitle,
      required this.materialSubtitle,
      required this.headerColor,
      required this.tileColor,
      required this.bodySlivers,
      this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final Rx<Color> _headerColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent).obs;
    final Rx<Color> _tileColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? tileColor : Colors.transparent).obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        _headerColor.value = effect != WindowEffect.disabled ? Colors.transparent : headerColor;
        _tileColor.value = effect != WindowEffect.disabled ? Colors.transparent : tileColor;
      });
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (SettingsManager().settings.skin.value != Skins.Samsung || controller.positions.length != 1) return;
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
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(() => Scaffold(
        backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? _tileColor.value : _headerColor.value,
        appBar: SettingsManager().settings.skin.value == Skins.Samsung
            ? null
            : PreferredSize(
                preferredSize: Size(CustomNavigator.width(context), 50),
                child: AppBar(
                  systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                  toolbarHeight: 50,
                  elevation: 0,
                  scrolledUnderElevation: 3,
                  surfaceTintColor: context.theme.colorScheme.primary,
                  leading: buildBackButton(context),
                  backgroundColor: _headerColor.value,
                  centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
                  title: Text(
                    title,
                    style: context.theme.textTheme.titleLarge,
                  ),
                ),
              ),
        body: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            if (SettingsManager().settings.skin.value != Skins.Samsung) return false;
            final scrollDistance = context.height / 3 - 57;
            if (controller.offset > 0 &&
                controller.offset < scrollDistance &&
                controller.offset != controller.position.maxScrollExtent) {
              final double snapOffset = controller.offset / scrollDistance > 0.5 ? scrollDistance : 0;

              Future.microtask(
                  () => controller.animateTo(snapOffset, duration: Duration(milliseconds: 200), curve: Curves.linear));
            }
            return false;
          },
          child: ScrollbarWrapper(
            showScrollbar: true,
            controller: controller,
            child: Obx(
              () => CustomScrollView(
                controller: controller,
                shrinkWrap: true,
                physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                    ? NeverScrollableScrollPhysics()
                    : ThemeSwitcher.getScrollPhysics(),
                slivers: <Widget>[
                  if (SettingsManager().settings.skin.value == Skins.Samsung)
                    Obx(() => SliverAppBar(
                      backgroundColor: _headerColor.value,
                      pinned: true,
                      stretch: true,
                      expandedHeight: context.height / 3,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      flexibleSpace: LayoutBuilder(
                        builder: (context, _) {
                          var expandRatio = 1 - (controller.offset) / (context.height / 3 - 50);
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
                                child: Center(child: Text(title, style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
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
                                        style: context.theme.textTheme.titleLarge,
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
                    )),
                  if (SettingsManager().settings.skin.value != Skins.Samsung && initialHeader != null)
                    SliverToBoxAdapter(
                      child: Obx(() => Container(
                          height: 50,
                          alignment: Alignment.bottomLeft,
                          color: SettingsManager().settings.skin.value == Skins.iOS ? _headerColor.value : _tileColor.value,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8.0, left: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 15),
                            child: Text(initialHeader!.psCapitalize,
                                style: SettingsManager().settings.skin.value == Skins.iOS
                                    ? iosSubtitle
                                    : materialSubtitle),
                          ))),
                    ),
                  ...bodySlivers,
                  SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        Obx(() => SettingsManager().settings.skin.value == Skins.Samsung
                            ? Container(height: remainingHeight.value)
                            : SizedBox.shrink()),
                        Obx(() => Container(
                          height: 30,
                          color: SettingsManager().settings.skin.value != Skins.Material ? _headerColor.value : _tileColor.value,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap as void Function()?,
        onLongPress: onLongPress as void Function()?,
        splashColor: context.theme.colorScheme.surfaceVariant,
        splashFactory: context.theme.splashFactory,
        child: GestureDetector(
          onSecondaryTapUp: (details) => onLongPress as void Function()?,
          child: ListTile(
            leading: leading,
            title: title != null ? Text(
              title!,
              style: context.theme.textTheme.bodyLarge,
            ) : null,
            trailing: trailing,
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface, height: isThreeLine ? 1.5 : 1),
                    maxLines: isThreeLine ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            isThreeLine: isThreeLine,
          ),
        ),
      ),
    );
  }
}

class SettingsSubtitle extends StatelessWidget {
  const SettingsSubtitle({
    Key? key,
    this.subtitle,
    this.unlimitedSpace = false,
  }) : super(key: key);

  final String? subtitle;
  final bool unlimitedSpace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ListTile(
        title: subtitle != null ? Text(
          subtitle!,
          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
          maxLines: unlimitedSpace ? 100 : 2,
          overflow: TextOverflow.ellipsis,
        ) : null,
        minVerticalPadding: 0,
        visualDensity: VisualDensity(horizontal: 0, vertical: -4),
        dense: true,
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
                style: Theme.of(context).textTheme.bodyMedium,
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
                  style: Theme.of(context).textTheme.bodyMedium!.apply(
                      color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      fontSizeDelta: -0.25),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: 1,
                  placeholder: placeholder ?? "Enter your text here",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.labelLarge,
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
    this.isThreeLine = false,
  }) : super(key: key);
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    final thumbColor = context.theme.colorScheme.surface.computeDifference(backgroundColor) < 15
        ? context.theme.colorScheme.onSurface.withOpacity(0.6) : context.theme.colorScheme.surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged.call(!initialVal),
        splashColor: context.theme.colorScheme.surfaceVariant,
        splashFactory: context.theme.splashFactory,
        child: SwitchListTile(
          title: Text(
            title,
            style: context.theme.textTheme.bodyLarge,
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface, height: isThreeLine ? 1.5 : 1),
                  maxLines: isThreeLine ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          value: initialVal,
          activeColor: context.theme.colorScheme.primary,
          activeTrackColor: context.theme.colorScheme.primaryContainer,
          // make sure the track color does not blend in with the background color of the tiles
          inactiveTrackColor: context.theme.colorScheme.surfaceVariant.computeDifference(backgroundColor) < 15
              ? context.theme.colorScheme.surface.computeDifference(backgroundColor) < 15
              ? thumbColor.darkenPercent(20)
              : context.theme.colorScheme.surface.withOpacity(0.6)
              : context.theme.colorScheme.surfaceVariant,
          inactiveThumbColor: thumbColor,
          onChanged: onChanged,
          isThreeLine: isThreeLine,
        ),
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
    this.materialCustomWidgets,
    required this.initial,
    this.textProcessing,
    this.onMaterialTap,
    required this.title,
    this.subtitle,
    this.capitalize = true,
    this.backgroundColor,
    this.secondaryColor,
    this.useCupertino = true,
    this.cursor = SystemMouseCursors.click,
  }) : super(key: key);
  final String title;
  final void Function(T?) onChanged;
  final List<T> options;
  final Iterable<Widget>? cupertinoCustomWidgets;
  final Widget? Function(T)? materialCustomWidgets;
  final T initial;
  final String Function(T)? textProcessing;
  final void Function()? onMaterialTap;
  final String? subtitle;
  final bool capitalize;
  final Color? backgroundColor;
  final Color? secondaryColor;
  final bool useCupertino;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.iOS && useCupertino) {
      final texts = options.map((e) => Text(capitalize ? textProcessing!(e).capitalize! : textProcessing!(e), style: context.theme.textTheme.bodyLarge!.copyWith(color: e == initial ? context.theme.colorScheme.onPrimary : null)));
      final map = Map<T, Widget>.fromIterables(options, cupertinoCustomWidgets ?? texts);
      return Container(
        color: backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: 13),
        height: 50,
        width: context.width,
          child: MouseRegion(
            cursor: cursor,
            hitTestBehavior: HitTestBehavior.deferToChild,
            child: CupertinoSlidingSegmentedControl<T>(
          children: map,
          groupValue: initial,
          thumbColor: context.theme.colorScheme.primary,
          backgroundColor: backgroundColor ?? CupertinoColors.tertiarySystemFill,
          onValueChanged: onChanged,
          padding: EdgeInsets.zero,
        ),
          ),
      );
    }
    Color surfaceColor = context.theme.colorScheme.properSurface;
    if (SettingsManager().settings.skin.value == Skins.Material
        && surfaceColor.computeDifference(context.theme.colorScheme.background) < 15) {
      surfaceColor = context.theme.colorScheme.surfaceVariant;
    }
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      child: Text(
                        title,
                        style: context.theme.textTheme.bodyLarge,
                      ),
                    ),
                    (subtitle != null)
                        ? Container(
                            child: Padding(
                              padding: EdgeInsets.only(top: 3.0),
                              child: Text(
                                subtitle ?? "",
                                style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                              ),
                            ),
                          )
                        : Container(),
                  ]),
            ),
            SizedBox(width: 15),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: secondaryColor ?? surfaceColor,
              ),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    dropdownColor: secondaryColor ?? surfaceColor,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: context.theme.textTheme.bodyLarge!.color,
                    ),
                    value: initial,
                    items: options.map<DropdownMenuItem<T>>((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: materialCustomWidgets?.call(e) ?? Text(
                          capitalize ? textProcessing!(e).capitalize! : textProcessing!(e),
                          style: context.theme.textTheme.bodyLarge,
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                    onTap: onMaterialTap,
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
      this.onChangeEnd,
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
  final Function(double val)? onChangeEnd;
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

    return ListTile(
      leading: leading,
      trailing: Text(value, style: context.theme.textTheme.bodyLarge),
      title: SettingsManager().settings.skin.value == Skins.iOS
          ? MouseRegion(
          cursor: SystemMouseCursors.click,
          hitTestBehavior: HitTestBehavior.deferToChild,
          child: CupertinoSlider(
              activeColor: context.theme.colorScheme.primary.withOpacity(0.6),
              thumbColor: context.theme.colorScheme.primary,
              value: startingVal,
              onChanged: update,
              onChangeEnd: onChangeEnd,
              divisions: divisions,
              min: min,
              max: max,
            ),)
          : Slider(
              activeColor: context.theme.colorScheme.primary.withOpacity(0.6),
              thumbColor: context.theme.colorScheme.primary,
              inactiveColor: context.theme.colorScheme.primary.withOpacity(0.2),
              value: startingVal,
              onChanged: update,
              onChangeEnd: onChangeEnd,
              label: value,
              divisions: divisions,
              min: min,
              max: max,
              mouseCursor: SystemMouseCursors.click,
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
    final Rx<Color> _headerColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent).obs;
    final Rx<Color> _tileColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? tileColor : Colors.transparent).obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        _headerColor.value = effect != WindowEffect.disabled ? Colors.transparent : headerColor;
        _tileColor.value = effect != WindowEffect.disabled ? Colors.transparent : tileColor;
      });
    }

    if (SettingsManager().settings.skin.value == Skins.Samsung) return SizedBox(height: 15);
    return Column(children: [
      Obx(() => Container(
          height: SettingsManager().settings.skin.value == Skins.iOS ? 60 : 40,
          alignment: Alignment.bottomLeft,
          color: SettingsManager().settings.skin.value == Skins.iOS ? _headerColor.value : _tileColor.value,
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0, left: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 15),
            child: Text(text.psCapitalize,
                style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
          ))),
    ]);
  }
}

class SettingsSection extends StatelessWidget {
  final List<Widget> children;
  final Color backgroundColor;

  SettingsSection({required this.children, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: SettingsManager().settings.skin.value == Skins.iOS ? const EdgeInsets.symmetric(horizontal: 10) : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius:
            SettingsManager().settings.skin.value == Skins.Samsung ? BorderRadius.circular(25) :
            SettingsManager().settings.skin.value == Skins.iOS ? BorderRadius.circular(10) : BorderRadius.circular(0),
        clipBehavior: SettingsManager().settings.skin.value != Skins.Material ? Clip.antiAlias : Clip.none,
        child: Container(
          padding: SettingsManager().settings.skin.value == Skins.Samsung ? EdgeInsets.symmetric(vertical: 5) : null,
          color: backgroundColor,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
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
          shape: SettingsManager().settings.skin.value == Skins.Samsung
              ? SquircleBorder(
                  side: BorderSide(
                      color: SettingsManager().settings.skin.value == Skins.Samsung
                          ? containerColor ?? Colors.grey
                          : Colors.transparent,
                      width: 3.0),
                )
              : null,
          color: SettingsManager().settings.skin.value == Skins.Samsung
              ? containerColor ?? Colors.grey
              : Colors.transparent,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: SettingsManager().settings.skin.value == Skins.iOS
                  ? containerColor ?? Colors.grey
                  : Colors.transparent,
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
        color: color ?? context.theme.colorScheme.outline.withOpacity(0.5),
        thickness: 0.5,
        height: 0.5,
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
