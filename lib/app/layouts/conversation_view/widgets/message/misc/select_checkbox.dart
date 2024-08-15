import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelectCheckbox extends StatelessWidget {
  const SelectCheckbox({super.key, required this.message, required this.controller});

  final Message message;
  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() => AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: !controller.inSelectMode.value ? const SizedBox.shrink() : (ss.settings.skin.value == Skins.iOS ? InkWell(
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            color: controller.isSelected(message.guid!)
                ? context.theme.colorScheme.primary
                : null,
            border: Border.all(
              color: controller.isSelected(message.guid!)
                  ? context.theme.colorScheme.primary
                  : context.theme.colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(25)
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: Icon(CupertinoIcons.check_mark,
              size: 18,
              color: controller.isSelected(message.guid!)
                  ? context.theme.colorScheme.onPrimary
                  : context.theme.colorScheme.outline
            ),
          ),
        ),
        onTap: () {
          if (controller.isSelected(message.guid!)) {
            controller.selected.remove(message);
          } else {
            controller.selected.add(message);
          }
        }
      ) : Checkbox(
        value: controller.isSelected(message.guid!),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onChanged: (val) {
          if (controller.isSelected(message.guid!)) {
            controller.selected.remove(message);
          } else {
            controller.selected.add(message);
          }
        }
      )),
    ));
  }
}
