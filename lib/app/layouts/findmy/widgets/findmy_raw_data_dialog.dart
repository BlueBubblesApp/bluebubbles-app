import 'dart:convert';

import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FindMyRawDataDialog extends StatelessWidget {
  final dynamic item;

  const FindMyRawDataDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent("     ");
    final str = encoder.convert(item.toJson());

    return AlertDialog(
      title: Text("Raw FindMy Data", style: context.theme.textTheme.titleLarge),
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      content: SizedBox(
        width: NavigationSvc.width(context) * 3 / 5,
        height: context.height * 1 / 4,
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: SingleChildScrollView(child: SelectableText(str, style: context.theme.textTheme.bodyLarge)),
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            "Close",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
