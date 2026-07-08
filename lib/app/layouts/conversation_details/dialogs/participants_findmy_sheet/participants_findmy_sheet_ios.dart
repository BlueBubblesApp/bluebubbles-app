import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet_shared.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> showParticipantsFindMyMapIOS(
  BuildContext context, {
  required FindMyController controller,
  required Chat chat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      alignment: Alignment.bottomCenter,
      child: ParticipantsFindMyMapSheetBody(
        controller: controller,
        chat: chat,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        buildHeader: (context, data, closeSheet) {
          final subtitleStyle = context.theme.textTheme.bodySmall;
          return ColoredBox(
            color: context.theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: NavigationToolbar(
                  centerMiddle: true,
                  middle: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleMedium,
                      ),
                      if (data.isGroup)
                        Text(
                          findMyGroupParticipantLabel(data.participantCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        )
                      else if (data.singleLocationDescription != null && data.singleLocationState != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                data.singleLocationDescription!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                            ),
                            Text(' • ${data.singleLocationState!}', style: subtitleStyle),
                          ],
                        ),
                    ],
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: closeSheet,
                      child: Text(
                        'Done',
                        style: context.theme.textTheme.bodyLarge!.copyWith(
                          color: context.theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
