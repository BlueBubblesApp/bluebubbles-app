import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsOptions<T extends Object> extends StatelessWidget {
  SettingsOptions({
    super.key,
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
    this.secondaryColor,
    this.useCupertino = true,
    this.clampWidth = true,
  });
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
  final Color? secondaryColor;
  final bool useCupertino;
  final bool clampWidth;

  @override
  Widget build(BuildContext context) {
    if (ss.settings.skin.value == Skins.iOS && useCupertino) {
      final texts = options.map((e) => Text(capitalize ? textProcessing!(e).capitalize! : textProcessing!(e), style: context.theme.textTheme.bodyLarge!.copyWith(color: e == initial ? context.theme.colorScheme.onPrimary : null)));
      final map = Map<T, Widget>.fromIterables(options, cupertinoCustomWidgets ?? texts);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        height: 50,
        width: context.width,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: CupertinoSlidingSegmentedControl<T>(
            children: map,
            groupValue: initial,
            thumbColor: context.theme.colorScheme.primary,
            backgroundColor: Colors.transparent,
            onValueChanged: onChanged,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }
    Color surfaceColor = context.theme.colorScheme.properSurface;
    if (ss.settings.skin.value == Skins.Material
        && surfaceColor.computeDifference(context.theme.colorScheme.background) < 15) {
      surfaceColor = context.theme.colorScheme.surfaceVariant;
    }
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ns.width(context) * 3 / 5, minWidth: ns.width(context) / 5),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.theme.textTheme.bodyLarge,
                    ),
                    (subtitle != null)
                        ? Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            subtitle ?? "",
                            style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                          ),
                        )
                        : const SizedBox.shrink(),
                  ]),
            ),
            const SizedBox(width: 15),
            if (clampWidth) const Spacer(),
            Builder(
              builder: (context) {
                final widget = Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: secondaryColor ?? surfaceColor,
                  ),
                  child: Center(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<T>(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: secondaryColor?.withOpacity(1) ?? surfaceColor,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: context.theme.textTheme.bodyLarge!.color,
                        ),
                        isExpanded: true,
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
                );
                if (clampWidth) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ns.width(context) * 2 / 5 - 47),
                    child: widget,
                  );
                } else {
                  return Expanded(
                    child: widget,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
