import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSubtitle extends StatelessWidget {
  const SettingsSubtitle({
    super.key,
    this.subtitle,
    this.unlimitedSpace = false,
    this.bottomPadding = true,
    this.topPadding = 0,
  });

  final String? subtitle;
  final bool unlimitedSpace;
  final bool bottomPadding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: bottomPadding ? 10.0 : 0,
      ),
      child: ListTile(
        title: subtitle != null
            ? Text(
                subtitle!,
                style: context.theme.textTheme.bodySmall!
                    .copyWith(color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75)),
                maxLines: unlimitedSpace ? 100 : 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        minVerticalPadding: 0,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        dense: true,
      ),
    );
  }
}
