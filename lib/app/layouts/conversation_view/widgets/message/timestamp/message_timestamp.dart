import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageTimestamp extends StatelessWidget {
  const MessageTimestamp({Key? key, required this.controller, required this.cvController}) : super(key: key);

  final MessageWidgetController controller;
  final ConversationViewController cvController;

  Message get message => controller.message;

  @override
  Widget build(BuildContext context) {
    final oneLine = ss.settings.skin.value == Skins.Samsung ? true : buildDate(message.dateCreated) == buildTime(message.dateCreated);
    final time = oneLine ? "   ${buildTime(message.dateCreated)}" : "   ${buildDate(message.dateCreated)}\n   ${buildTime(message.dateCreated).toLowerCase()}";
    return Obx(() => AnimatedContainer(
      duration: Duration(milliseconds: cvController.timestampOffset.value == 0 ? 150 : 0),
      width: ss.settings.skin.value == Skins.Samsung ? null : min(max(-cvController.timestampOffset.value, 0), 70),
      child: Offstage(
        offstage: ss.settings.skin.value != Skins.Samsung && cvController.timestampOffset.value == 0,
        child: Text(
          time,
          style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
          overflow: TextOverflow.visible,
          softWrap: false,
          maxLines: oneLine ? 1 : 2,
        ),
      ),
    ));
  }
}
