import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConversationListFAB extends StatefulWidget {
  const ConversationListFAB({Key? key, required this.parentController}) : super(key: key);

  final ConversationListController parentController;

  @override
  State<StatefulWidget> createState() => _ConversationListFABState();
}

class _ConversationListFABState extends OptimizedState<ConversationListFAB> with ThemeHelpers {

  ConversationListController get controller => widget.parentController;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (SettingsManager().settings.cameraFAB.value && iOS)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 45,
              maxHeight: 45,
            ),
            child: FloatingActionButton(
              child: Icon(
                iOS ? CupertinoIcons.camera : Icons.photo_camera,
                size: 20,
                color: context.theme.colorScheme.onPrimaryContainer
              ),
              onPressed: () => controller.openCamera(context),
              heroTag: null,
              backgroundColor: context.theme.colorScheme.primaryContainer,
            ),
          ),
        if (SettingsManager().settings.cameraFAB.value && iOS)
          const SizedBox(
            height: 10,
          ),
        InkWell(
          onLongPress: iOS || !SettingsManager().settings.cameraFAB.value
            ? null : () => controller.openCamera(context),
          child: FloatingActionButton(
            backgroundColor: context.theme.colorScheme.primary,
            child: Icon(
              iOS ? CupertinoIcons.pencil : Icons.message,
              color: context.theme.colorScheme.onPrimary,
              size: 25
            ),
            onPressed: () => controller.openNewChatCreator(context)
          ),
        ),
      ],
    ));
  }
}
