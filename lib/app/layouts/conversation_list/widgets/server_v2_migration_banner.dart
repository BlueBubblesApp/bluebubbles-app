import 'dart:ui';

import 'package:bluebubbles/services/backend/sync/server_v2_migrations.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ServerV2MigrationBanner extends StatelessWidget {
  const ServerV2MigrationBanner({super.key});

  static final _countFormat = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = ServerV2Migrations.progress.value;
      if (status == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final count = status.completed != null && status.total != null
          ? '${_countFormat.format(status.completed)} / ${_countFormat.format(status.total)} messages'
          : 'Checking messages…';
      final overall = status.progress == null
          ? null
          : (status.stepNumber - 1 + status.progress!) / ServerV2Migrations.stepNames.length;

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Updating messages for new v2 features', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Step ${status.stepNumber} of 5 · $count', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: overall, minHeight: 3),
                    const SizedBox(height: 6),
                    Text(status.step, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
