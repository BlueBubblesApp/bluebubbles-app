import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

Future<void> showParticipantsFindMyMap(
  BuildContext context, {
  required FindMyController controller,
  required Chat chat,
  VoidCallback? onSheetClosed,
}) async {
  final mapController = controller.participantMapController;
  if (mapController == null) return;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: !context.iOS,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: sheetContext.iOS ? 0.92 : (sheetContext.samsung ? 0.95 : 0.9),
        alignment: Alignment.bottomCenter,
        child: _ParticipantsFindMyMapSheetBody(
          controller: controller,
          mapController: mapController,
          chat: chat,
        ),
      ),
    );
  } finally {
    onSheetClosed?.call();
  }
}

class _ParticipantsFindMyHeaderData {
  final String title;
  final bool isGroup;
  final int participantCount;
  final String? singleLocationDescription;
  final String? singleLocationState;

  const _ParticipantsFindMyHeaderData({
    required this.title,
    required this.isGroup,
    required this.participantCount,
    required this.singleLocationDescription,
    required this.singleLocationState,
  });
}

class _ParticipantsFindMyMapSheetBody extends StatelessWidget {
  final FindMyController controller;
  final MapController mapController;
  final Chat chat;

  const _ParticipantsFindMyMapSheetBody({
    required this.controller,
    required this.mapController,
    required this.chat,
  });

  String _chatTitle() {
    final state = ChatsSvc.chatStates[chat.guid];
    return state?.title.value ?? chat.getTitle();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.vertical(top: Radius.circular(context.samsung ? 20 : 16));

    return Material(
      color: context.theme.colorScheme.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Obx(() {
            controller.friendsWithLocation.length;
            final visibleParticipants = controller.participantFriendsWithLocation;
            final firstFriend = visibleParticipants.isEmpty ? null : visibleParticipants.first;
            final data = _ParticipantsFindMyHeaderData(
              title: visibleParticipants.isEmpty ? 'Location' : _chatTitle(),
              isGroup: chat.isGroup,
              participantCount: visibleParticipants.length,
              singleLocationDescription: firstFriend == null ? null : _findMyLocationDescription(firstFriend),
              singleLocationState: firstFriend == null ? null : _findMyLocationStateLabel(firstFriend),
            );
            return _buildHeader(context, data, () => Navigator.of(context).pop());
          }),
          Expanded(
            child: FindMyMapWidget(
              controller: controller,
              mapController: mapController,
              interactive: true,
              initialZoom: 13,
              onMapReady: () => controller.onParticipantMapReady(mapController),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _ParticipantsFindMyHeaderData data, VoidCallback closeSheet) {
    if (context.iOS) return _buildIosHeader(context, data, closeSheet);
    if (context.samsung) return _buildSamsungHeader(context, data, closeSheet);
    return _buildMaterialHeader(context, data, closeSheet);
  }

  Widget _buildIosHeader(BuildContext context, _ParticipantsFindMyHeaderData data, VoidCallback closeSheet) {
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
                    _findMyGroupParticipantLabel(data.participantCount),
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
  }

  Widget _buildSamsungHeader(BuildContext context, _ParticipantsFindMyHeaderData data, VoidCallback closeSheet) {
    final subtitle = data.isGroup
        ? _findMyGroupParticipantLabel(data.participantCount)
        : (data.singleLocationState ?? 'Location');
    return ColoredBox(
      color: context.headerColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 92,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(onPressed: closeSheet, icon: const Icon(Icons.close)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleLarge,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialHeader(BuildContext context, _ParticipantsFindMyHeaderData data, VoidCallback closeSheet) {
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
              IconButton(onPressed: closeSheet, icon: const Icon(Icons.close)),
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
                          ? _findMyGroupParticipantLabel(data.participantCount)
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
  }
}

String _findMyGroupParticipantLabel(int count) => '$count ${count == 1 ? "Person" : "People"}';

String _findMyLocationDescription(FindMyFriend friend) {
  if (shouldRedactFindMyContactInfo()) return 'Location';
  final description = (friend.longAddress ?? '').trim();
  if (description.isEmpty) return 'Location';
  return description;
}

String _findMyLocationStateLabel(FindMyFriend friend) {
  final status = friend.status;
  if (status == null) return 'Location';
  return '${status.name.capitalize!} Location';
}
