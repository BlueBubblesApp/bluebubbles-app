import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sentence-case section label for an [M3ESection] group. The accent colour is
/// `colorScheme.primary`, which on the conversation details page is the chat's bubble colour.
class M3ESectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const M3ESectionHeader({
    super.key,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.theme.textTheme.titleSmall?.copyWith(
                color: context.theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
