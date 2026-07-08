import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet_ios.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet_material.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet_samsung.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

Future<void> showParticipantsFindMyMap(
  BuildContext context, {
  required FindMyController controller,
  required Chat chat,
  VoidCallback? onSheetClosed,
}) async {
  try {
    await _showSkinSheet(context, controller: controller, chat: chat);
  } finally {
    onSheetClosed?.call();
  }
}

Future<void> _showSkinSheet(
  BuildContext context, {
  required FindMyController controller,
  required Chat chat,
}) {
  switch (SettingsSvc.settings.skin.value) {
    case Skins.iOS:
      return showParticipantsFindMyMapIOS(
        context,
        controller: controller,
        chat: chat,
      );
    case Skins.Material:
      return showParticipantsFindMyMapMaterial(
        context,
        controller: controller,
        chat: chat,
      );
    case Skins.Samsung:
      return showParticipantsFindMyMapSamsung(
        context,
        controller: controller,
        chat: chat,
      );
  }
}

Widget themedParticipantsFindMySheet(BuildContext parentContext, Widget child) {
  final theme = Theme.of(parentContext);
  final adaptive = AdaptiveTheme.maybeOf(parentContext);
  if (adaptive == null) return Theme(data: theme, child: child);
  return AdaptiveTheme(
    light: adaptive.theme,
    dark: adaptive.darkTheme,
    initial: adaptive.mode,
    builder: (_, __) => Theme(data: theme, child: child),
  );
}
