import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showMetadataDialog(Attachment a, BuildContext context) {
  List<Widget> metaWidgets = [];
  final metadataMap = <String, dynamic>{
    'filename': a.transferName,
    'mime': a.mimeType,
  }..addAll(a.metadata ?? {});
  for (MapEntry entry in metadataMap.entries.where((element) => element.value != null)) {
    metaWidgets.add(RichText(
      text: TextSpan(
        children: [
          TextSpan(text: "${entry.key}: ", style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2)),
          TextSpan(text: entry.value.toString(), style: context.theme.textTheme.bodyLarge)
        ],
      ),
    ));
  }

  if (metaWidgets.isEmpty) {
    metaWidgets.add(Text(
      "No metadata available",
      style: context.theme.textTheme.bodyLarge,
      textAlign: TextAlign.center,
    ));
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        "Metadata",
        style: context.theme.textTheme.titleLarge,
      ),
      backgroundColor: context.theme.colorScheme.properSurface,
      content: SizedBox(
        width: ns.width(context) * 3 / 5,
        height: context.height * 1 / 4,
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: context.theme.backgroundColor,
            borderRadius: BorderRadius.circular(10)
          ),
          child: ListView(
            physics: ThemeSwitcher.getScrollPhysics(),
            children: metaWidgets,
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            "Close",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}