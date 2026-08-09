import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Expressive empty-state prompt shown before the first analysis on the
/// Material/Samsung skins — same content as the iOS `StorageAnalyzePrompt`,
/// styled with `M3ETonalButton` and wrapped for the M3E entry transition.
class StorageExpressiveAnalyzePrompt extends StatelessWidget {
  const StorageExpressiveAnalyzePrompt({super.key, required this.controller});

  final StorageAnalyzerController controller;

  @override
  Widget build(BuildContext context) {
    return M3EMotion.spatialDefault.container(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline,
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
              SizedBox(
                width: 160,
                child: M3ETonalButton(
                  icon: Icons.pie_chart_outline,
                  label: "Analyze",
                  onPressed: controller.analyze,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
