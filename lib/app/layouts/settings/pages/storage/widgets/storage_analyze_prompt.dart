import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Empty-state prompt shown before the first analysis — modeled on
/// `_AnalyzePrompt` in `chat_stats_content_tab.dart:73-113`.
class StorageAnalyzePrompt extends StatelessWidget {
  const StorageAnalyzePrompt({super.key, required this.controller});

  final StorageAnalyzerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              context.iOS ? CupertinoIcons.chart_pie : Icons.pie_chart_outline,
              size: 40.0,
              color: context.theme.colorScheme.outline,
            ),
            const SizedBox(height: 12.0),
            Text(
              "Analyze Storage",
              style: context.theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              "Scans attachment files on this device. Nothing is deleted from your server.",
              style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            context.iOS
                ? CupertinoButton.filled(
                    color: context.theme.colorScheme.primary,
                    onPressed: controller.analyze,
                    child: const Text("Analyze"),
                  )
                : FilledButton(
                    onPressed: controller.analyze,
                    child: const Text("Analyze"),
                  ),
          ],
        ),
      ),
    );
  }
}
