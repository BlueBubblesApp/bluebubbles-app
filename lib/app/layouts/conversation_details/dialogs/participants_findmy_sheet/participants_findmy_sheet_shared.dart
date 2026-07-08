import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

class ParticipantsFindMyHeaderData {
  final String title;
  final bool isGroup;
  final int participantCount;
  final String? singleLocationDescription;
  final String? singleLocationState;

  const ParticipantsFindMyHeaderData({
    required this.title,
    required this.isGroup,
    required this.participantCount,
    required this.singleLocationDescription,
    required this.singleLocationState,
  });
}

typedef ParticipantsFindMyHeaderBuilder = Widget Function(
  BuildContext context,
  ParticipantsFindMyHeaderData data,
  VoidCallback closeSheet,
);

class ParticipantsFindMyMapSheetBody extends StatefulWidget {
  final FindMyController controller;
  final Chat chat;
  final ParticipantsFindMyHeaderBuilder buildHeader;
  final BorderRadius borderRadius;

  const ParticipantsFindMyMapSheetBody({
    super.key,
    required this.controller,
    required this.chat,
    required this.buildHeader,
    required this.borderRadius,
  });

  @override
  State<ParticipantsFindMyMapSheetBody> createState() => _ParticipantsFindMyMapSheetBodyState();
}

class _ParticipantsFindMyMapSheetBodyState extends State<ParticipantsFindMyMapSheetBody> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String get _chatTitle {
    final state = ChatsSvc.chatStates[widget.chat.guid];
    return state?.title.value ?? widget.chat.getTitle();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.theme.colorScheme.surface,
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Obx(() {
            widget.controller.friendsWithLocation.length;
            final visibleParticipants = widget.controller.participantFriendsWithLocation;
            final firstFriend = visibleParticipants.isEmpty ? null : visibleParticipants.first;
            final data = ParticipantsFindMyHeaderData(
              title: visibleParticipants.isEmpty ? 'Location' : _chatTitle,
              isGroup: widget.chat.isGroup,
              participantCount: visibleParticipants.length,
              singleLocationDescription:
                  firstFriend == null ? null : findMyLocationDescription(firstFriend),
              singleLocationState: firstFriend == null ? null : findMyLocationStateLabel(firstFriend),
            );
            return widget.buildHeader(context, data, () => Navigator.of(context).pop());
          }),
          Expanded(
            child: FindMyMapWidget(
              controller: widget.controller,
              mapController: _mapController,
              interactive: true,
              initialZoom: 13,
              onMapReady: () => widget.controller.fitMapToParticipantMarkers(_mapController),
            ),
          ),
        ],
      ),
    );
  }
}

String findMyGroupParticipantLabel(int count) => '$count ${count == 1 ? "Person" : "People"}';

String findMyLocationDescription(FindMyFriend friend) {
  if (SettingsSvc.settings.redactedMode.value) return 'Location';
  final description = (friend.longAddress ?? '').trim();
  if (description.isEmpty) return 'Location';
  return description;
}

String findMyLocationStateLabel(FindMyFriend friend) {
  final status = friend.status;
  if (status == null) return 'Location';
  return '${status.name.capitalize!} Location';
}
