import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The expanded card a selected Find My row turns into: name, distance,
/// street, status, then the actions, raised above the rest of the list.
class FindMySelectedCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? distance;
  final String? street;
  final String? status;
  final bool live;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDirections;
  final VoidCallback? onContact;

  const FindMySelectedCard({
    super.key,
    this.leading,
    required this.title,
    this.distance,
    this.street,
    this.status,
    this.live = false,
    this.onTap,
    this.onLongPress,
    this.onDirections,
    this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final textTheme = context.theme.textTheme;
    final secondary = textTheme.bodyMedium!.copyWith(color: scheme.onSurface.withValues(alpha: 0.75));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.06), context.theme.colorScheme.surface),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600)),
                      if (distance != null)
                        Text(distance!, style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600)),
                      if (street != null) Text(street!, style: secondary),
                      if (status != null)
                        Text(status!, style: live ? secondary.copyWith(color: Colors.green.shade600) : secondary),
                      if (onDirections != null || onContact != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (onDirections != null)
                              Expanded(
                                child: _FindMyPillButton(
                                  icon: Icons.directions_car,
                                  label: 'Directions',
                                  foreground: scheme.primary,
                                  background: scheme.primary.withValues(alpha: 0.15),
                                  onPressed: onDirections!,
                                ),
                              ),
                            if (onDirections != null && onContact != null) const SizedBox(width: 8),
                            if (onContact != null)
                              Expanded(
                                child: _FindMyPillButton(
                                  icon: Icons.account_circle,
                                  label: 'Contact',
                                  foreground: scheme.onSurface.withValues(alpha: 0.8),
                                  background: scheme.onSurface.withValues(alpha: 0.08),
                                  onPressed: onContact!,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FindMyPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  const _FindMyPillButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(42),
        textStyle: context.theme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
