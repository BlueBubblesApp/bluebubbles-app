import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// A vertically-stacked single-select control -- every option gets its own
/// full-width row instead of splitting one row's width `n` ways (as a
/// segmented control does), so labels stay readable as the option count
/// grows instead of getting crushed/truncated.
///
/// Skin-specific entry point, following the [BBSwitch]/[BBSlider] pattern:
/// picks the implementation for the active skin. iOS is the only
/// implementation right now -- Material/Samsung throw until one exists.
class BBVerticalSelect<T> extends StatelessWidget {
  final List<T> options;
  final T value;
  final String Function(T option) labelBuilder;
  final IconData? Function(T option)? iconBuilder;
  final ValueChanged<T> onChanged;

  const BBVerticalSelect({
    super.key,
    required this.options,
    required this.value,
    required this.labelBuilder,
    required this.onChanged,
    this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (context.iOS) {
      return _CupertinoVerticalSelect<T>(
        options: options,
        value: value,
        labelBuilder: labelBuilder,
        iconBuilder: iconBuilder,
        onChanged: onChanged,
      );
    }

    throw UnimplementedError(
      'BBVerticalSelect has no Material/Samsung implementation yet -- only the iOS skin is supported.',
    );
  }
}

class _CupertinoVerticalSelect<T> extends StatelessWidget {
  final List<T> options;
  final T value;
  final String Function(T option) labelBuilder;
  final IconData? Function(T option)? iconBuilder;
  final ValueChanged<T> onChanged;

  const _CupertinoVerticalSelect({
    required this.options,
    required this.value,
    required this.labelBuilder,
    required this.onChanged,
    this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SettingsDivider(padding: EdgeInsets.only(left: 16)),
          _buildRow(context, options[i]),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, T option) {
    final selected = option == value;
    final icon = iconBuilder?.call(option);
    return SettingsTile(
      leading: icon == null ? null : Icon(icon, color: context.theme.colorScheme.onSurfaceVariant),
      title: labelBuilder(option),
      trailing:
          selected ? Icon(CupertinoIcons.check_mark, color: context.theme.colorScheme.primary, size: 20) : null,
      onTap: () => onChanged(option),
    );
  }
}
