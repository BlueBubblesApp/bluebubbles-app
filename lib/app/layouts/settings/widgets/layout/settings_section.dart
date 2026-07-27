import 'package:bluebubbles/app/components/m3e/m3e_section.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'settings_divider.dart';
import '../search/searchable_setting_item.dart';

class SettingsSection extends StatelessWidget {
  final List<Widget>? children;
  // group searchable settings into a rounded rectangle
  final List<SearchableSettingItem>? searchableSettingsItems;
  final Color backgroundColor;

  const SettingsSection({
    super.key,
    this.children,
    required this.backgroundColor,
    this.searchableSettingsItems,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> displayedChildren = [];

    if (searchableSettingsItems != null) {
      // No filtering here - parent already filtered if needed
      final items = searchableSettingsItems!.map((item) => item.child).toList();
      // Interleave dividers between items (SettingsDivider is a no-op on non-iOS skins)
      for (int i = 0; i < items.length; i++) {
        displayedChildren.add(items[i]);
        if (i < items.length - 1) {
          displayedChildren.add(const SettingsDivider());
        }
      }
    } else if (children != null) {
      displayedChildren = children!;
    }

    // If no children, hide section
    if (displayedChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    if (SettingsSvc.settings.skin.value != Skins.iOS) {
      // Strip interleaved SettingsDividers - they're SizedBox.shrink() off-iOS but would
      // still occupy an index and corrupt M3EShapes.grouped()'s corner sequence.
      final m3eChildren = displayedChildren.where((child) => child is! SettingsDivider).toList(growable: false);
      return M3ESection(
        backgroundColor: backgroundColor,
        children: m3eChildren,
      );
    }

    // Always return section container
    return Padding(
      padding: SettingsSvc.settings.skin.value == Skins.iOS
          ? const EdgeInsets.symmetric(horizontal: 20)
          : SettingsSvc.settings.skin.value == Skins.Samsung
              ? const EdgeInsets.symmetric(vertical: 5)
              : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: SettingsSvc.settings.skin.value == Skins.Samsung
            ? BorderRadius.circular(25)
            : SettingsSvc.settings.skin.value == Skins.iOS
                ? BorderRadius.circular(10)
                : BorderRadius.circular(0),
        clipBehavior: SettingsSvc.settings.skin.value != Skins.Material ? Clip.antiAlias : Clip.none,
        child: Container(
          color: SettingsSvc.settings.skin.value == Skins.iOS ? null : backgroundColor,
          decoration: SettingsSvc.settings.skin.value == Skins.iOS
              ? BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: backgroundColor.darkenAmount(0.1).withValues(alpha: 0.25),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: displayedChildren,
          ),
        ),
      ),
    );
  }
}
