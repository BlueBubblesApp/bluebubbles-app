import 'package:bluebubbles/app/components/m3e/m3e.dart';
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
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: sheetContext.iOS ? 0.92 : 0.9,
        alignment: Alignment.bottomCenter,
        child: _ParticipantsFindMyMapSheetBody(
          controller: controller,
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

class _ParticipantsFindMyMapSheetBody extends StatefulWidget {
  final FindMyController controller;
  final Chat chat;

  const _ParticipantsFindMyMapSheetBody({
    required this.controller,
    required this.chat,
  });

  @override
  State<_ParticipantsFindMyMapSheetBody> createState() => _ParticipantsFindMyMapSheetBodyState();
}

class _ParticipantsFindMyMapSheetBodyState extends State<_ParticipantsFindMyMapSheetBody> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    widget.controller.participantSheetMapController = _mapController;
  }

  @override
  void dispose() {
    if (identical(widget.controller.participantSheetMapController, _mapController)) {
      widget.controller.participantSheetMapController = null;
    }
    _mapController.dispose();
    super.dispose();
  }

  String _chatTitle() {
    final state = ChatsSvc.chatStates[widget.chat.guid];
    return state?.title.value ?? widget.chat.getTitle();
  }

  @override
  Widget build(BuildContext context) {
    final topRadius = context.iOS ? 16.0 : M3EShapes.xl;
    final borderRadius = BorderRadius.vertical(top: Radius.circular(topRadius));

    return Material(
      color: context.iOS ? context.theme.colorScheme.surface : context.tileColor,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Obx(() {
            widget.controller.friendsWithLocation.length;
            final visibleParticipants = widget.controller.participantFriendsWithLocation;
            final firstFriend = visibleParticipants.isEmpty ? null : visibleParticipants.first;
            final data = _ParticipantsFindMyHeaderData(
              title: visibleParticipants.isEmpty ? 'Location' : _chatTitle(),
              isGroup: widget.chat.isGroup,
              participantCount: visibleParticipants.length,
              singleLocationDescription: firstFriend == null ? null : _findMyLocationDescription(firstFriend),
              singleLocationState: firstFriend == null ? null : _findMyLocationStateLabel(firstFriend),
            );
            return _buildHeader(context, data, () => Navigator.of(context).pop());
          }),
          Expanded(
            child: FindMyMapWidget(
              controller: widget.controller,
              mapController: _mapController,
              interactive: true,
              initialZoom: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _ParticipantsFindMyHeaderData data, VoidCallback closeSheet) {
    if (context.iOS) return _buildIosHeader(context, data, closeSheet);
    return _buildExpressiveHeader(context, data, closeSheet);
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

  Widget _buildExpressiveHeader(BuildContext context, _ParticipantsFindMyHeaderData data, VoidCallback closeSheet) {
    final subtitle = data.isGroup
        ? _findMyGroupParticipantLabel(data.participantCount)
        : (data.singleLocationState ?? 'Location');
    final subtitleStyle = context.theme.textTheme.bodySmall?.copyWith(
      color: context.theme.colorScheme.onSurfaceVariant,
    );

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 68,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: M3ESpacing.xs),
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: M3ESpacing.sm),
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
