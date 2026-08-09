import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Themed placeholder shown in place of media (e.g. an image) that failed to
/// decode/render entirely. Mirrors the sizing behavior of the loading-state
/// placeholders so it doesn't collapse to a sliver inside a top-aligned [Stack].
class MediaUnavailablePlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final IconData iosIcon;
  final IconData materialIcon;
  final String message;
  final VoidCallback? onViewDetails;

  const MediaUnavailablePlaceholder({
    super.key,
    required this.width,
    required this.height,
    required this.iosIcon,
    required this.materialIcon,
    required this.message,
    this.onViewDetails,
  });

  bool get _iOS => SettingsSvc.settings.skin.value == Skins.iOS;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: max(width, 120),
      height: max(height, 100),
      alignment: Alignment.center,
      color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iOS ? iosIcon : materialIcon,
              size: 30,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
            ),
            if (onViewDetails != null) ...[
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onViewDetails,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text(
                    "View Details",
                    style: context.theme.textTheme.bodySmall!.copyWith(
                      color: context.theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
