import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:flutter/material.dart';

/// Section header row for an attachment preview list. On [expressive], delegates to
/// [M3ESectionHeader] with a sentence-case label and a "See all" trailing action; otherwise
/// renders the legacy ALL CAPS label + "See More" button.
class AttachmentSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onShowMore;
  final bool expressive;

  const AttachmentSectionHeader({
    super.key,
    required this.title,
    required this.onShowMore,
    this.expressive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (expressive) {
      return M3ESectionHeader(
        label: title,
        trailing: TextButton.icon(
          onPressed: onShowMore,
          label: const Text("See all"),
          icon: const Icon(Icons.chevron_right, size: 18),
          iconAlignment: IconAlignment.end,
        ),
      );
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 5, left: 20, right: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          TextButton(
            onPressed: onShowMore,
            child: const Text("See More"),
          ),
        ],
      ),
    );
  }
}
