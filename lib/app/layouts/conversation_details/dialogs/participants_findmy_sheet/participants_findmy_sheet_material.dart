import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet_shared.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> showParticipantsFindMyMapMaterial(
  BuildContext context, {
  required FindMyController controller,
  required Chat chat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      alignment: Alignment.bottomCenter,
      child: ParticipantsFindMyMapSheetBody(
        controller: controller,
        chat: chat,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        buildHeader: (context, data, closeSheet) {
          final subtitleStyle = context.theme.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          );
          return ColoredBox(
            color: context.theme.colorScheme.surfaceContainerHigh,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: closeSheet,
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.textTheme.titleMedium,
                          ),
                          Text(
                            data.isGroup
                                ? findMyGroupParticipantLabel(data.participantCount)
                                : (data.singleLocationState ?? 'Location'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
