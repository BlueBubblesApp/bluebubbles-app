import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// M3E list row: leading tonal icon container, title, optional supporting text, trailing widget.
class M3EListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? supportingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool destructive;
  final bool nested;

  const M3EListTile({
    super.key,
    required this.icon,
    required this.title,
    this.supportingText,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final accent = destructive ? colorScheme.error : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashFactory: context.theme.splashFactory,
        child: Padding(
          padding: EdgeInsets.only(left: nested ? 32 : 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.all(Radius.circular(M3EShapes.md)),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.theme.textTheme.bodyLarge?.copyWith(
                            color: destructive ? colorScheme.error : null,
                          ),
                        ),
                        if (supportingText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              supportingText!,
                              style: context.theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
