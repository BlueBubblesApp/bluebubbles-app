import 'package:bluebubbles/app/components/animated_dropdown_menu.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/settings_leading_icon.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsOptions<T extends Object> extends StatelessWidget {
  const SettingsOptions({
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
    this.leading,
    this.useModernMenu = false,
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
  final SettingsLeadingIcon? leading;

  /// Renders the Material/Samsung control as an anchored [AnimatedDropdownMenu]
  /// (matching the conversation list header / custom group menus) instead of
  /// the legacy native [DropdownButton]. Opt-in so existing call sites keep
  /// their current look until migrated.
  final bool useModernMenu;

  String _labelFor(T value) => capitalize ? textProcessing!(value).capitalize! : textProcessing!(value);

  @override
  Widget build(BuildContext context) {
    if (SettingsSvc.settings.skin.value == Skins.iOS && useCupertino) {
      final texts = options.map((e) => Text(capitalize ? textProcessing!(e).capitalize! : textProcessing!(e),
          style: context.theme.textTheme.bodyLarge!
              .copyWith(color: e == initial ? context.theme.colorScheme.onPrimary : null)));
      final map = Map<T, Widget>.fromIterables(options, cupertinoCustomWidgets ?? texts);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        height: 50,
        width: context.width,
        child: MouseRegion(
          cursor: MouseCursor.defer,
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
    Color surfaceColor = context.theme.colorScheme.surfaceContainerHighest;
    if (SettingsSvc.settings.skin.value == Skins.Material &&
        surfaceColor.computeDifference(context.theme.colorScheme.surface) < 15) {
      surfaceColor = context.theme.colorScheme.surfaceVariant;
    }
    return Container(
      color: Colors.transparent,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runAlignment: WrapAlignment.spaceBetween,
          runSpacing: 8.0,
          spacing: 15.0,
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(left: 5.0, right: 10.0),
                child: leading,
              ),
            // Omitted entirely rather than rendered empty: a caller that already
            // shows its own title/description above this control (so the field
            // reads as one tile instead of two) passes "", and an empty `Text`
            // would still have reserved a blank line here.
            if (title.isNotEmpty)
              Column(
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
                            style: context.theme.textTheme.bodySmall!
                                .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            Builder(
              builder: (context) {
                final widget = useModernMenu
                    ? _ModernDropdownTrigger<T>(
                        options: options,
                        initial: initial,
                        onChanged: onChanged,
                        materialCustomWidgets: materialCustomWidgets,
                        labelBuilder: _labelFor,
                        surfaceColor: secondaryColor ?? surfaceColor,
                        onTap: onMaterialTap,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: secondaryColor ?? surfaceColor,
                        ),
                        child: Center(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<T>(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: secondaryColor?.withValues(alpha: 1) ?? surfaceColor,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: context.theme.textTheme.bodyLarge!.color,
                              ),
                              isExpanded: true,
                              value: initial,
                              items: options.map<DropdownMenuItem<T>>((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: materialCustomWidgets?.call(e) ??
                                      Text(
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
                    constraints: BoxConstraints(
                        maxWidth: leading != null
                            ? NavigationSvc.width(context) * 2 / 5 - 80 // Account for leading icon space
                            : NavigationSvc.width(context) * 2 / 5 - 47),
                    child: widget,
                  );
                } else {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: leading != null ? 200 : 250, // Reasonable max width
                    ),
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

/// Anchored popup trigger for [SettingsOptions] — same visual language as
/// [DropdownMenuCard]/[MenuItemRow], with a trailing check on the active option.
class _ModernDropdownTrigger<T extends Object> extends StatelessWidget {
  const _ModernDropdownTrigger({
    required this.options,
    required this.initial,
    required this.onChanged,
    required this.materialCustomWidgets,
    required this.labelBuilder,
    required this.surfaceColor,
    this.onTap,
  });

  final List<T> options;
  final T initial;
  final void Function(T?) onChanged;
  final Widget? Function(T)? materialCustomWidgets;
  final String Function(T) labelBuilder;
  final Color surfaceColor;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedDropdownMenu(
      menuWidth: 220,
      trigger: (context, showMenu) => GestureDetector(
        onTap: () {
          onTap?.call();
          showMenu();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: surfaceColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: materialCustomWidgets?.call(initial) ??
                    Text(
                      labelBuilder(initial),
                      style: context.theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              Icon(Icons.arrow_drop_down, color: context.theme.textTheme.bodyLarge!.color),
            ],
          ),
        ),
      ),
      menuBuilder: (overlayContext, hideMenu) {
        return DropdownMenuCard(
          width: 220,
          children: [
            for (final option in options)
              InkWell(
                onTap: () => hideMenu().then((_) => onChanged(option)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: materialCustomWidgets?.call(option) ??
                              Text(
                                labelBuilder(option),
                                style: overlayContext.theme.textTheme.bodyLarge?.copyWith(
                                  color: overlayContext.theme.colorScheme.onSurfaceVariant,
                                  fontWeight: option == initial ? FontWeight.w600 : null,
                                ),
                              ),
                        ),
                        if (option == initial)
                          Icon(Icons.check, size: 18, color: overlayContext.theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
