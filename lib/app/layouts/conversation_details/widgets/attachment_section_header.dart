import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:flutter/material.dart';

/// Section header row for an attachment preview list. Delegates to [M3ESectionHeader]
/// with a sentence-case label and a "See all" trailing action.
class AttachmentSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onShowMore;

  const AttachmentSectionHeader({
    super.key,
    required this.title,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    return M3ESectionHeader(
      label: title,
      // Left inset matches the settings tiles / attachment content below (attachmentSectionHorizontalPadding).
      padding: EdgeInsets.only(left: attachmentSectionHorizontalPadding().toDouble(), right: 8, top: 16, bottom: 8),
      trailing: TextButton.icon(
        onPressed: onShowMore,
        label: const Text("See all"),
        icon: const Icon(Icons.chevron_right, size: 18),
        iconAlignment: IconAlignment.end,
      ),
    );
  }
}
