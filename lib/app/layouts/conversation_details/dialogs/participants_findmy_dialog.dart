import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

/// Opens a 90%-height bottom sheet with an interactive map for conversation participants.
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
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        alignment: Alignment.bottomCenter,
        child: _themedSheet(
          context,
          _ParticipantsFindMyMapSheet(controller: controller, chat: chat),
        ),
      ),
    );
  } finally {
    onSheetClosed?.call();
  }
}

Widget _themedSheet(BuildContext parentContext, Widget child) {
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

class _ParticipantsFindMyMapSheet extends StatefulWidget {
  final FindMyController controller;
  final Chat chat;

  const _ParticipantsFindMyMapSheet({required this.controller, required this.chat});

  @override
  State<_ParticipantsFindMyMapSheet> createState() => _ParticipantsFindMyMapSheetState();
}

class _ParticipantsFindMyMapSheetState extends State<_ParticipantsFindMyMapSheet> with ThemeHelpers {
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

  String _groupParticipantLabel(int count) => '$count ${count == 1 ? "Person" : "People"}';

  String _locationDescription(FindMyFriend friend) {
    if (SettingsSvc.settings.redactedMode.value) return "Location";
    final description = (friend.longAddress ?? '').trim();
    if (description.isEmpty) return "Location";
    return description;
  }

  String _locationStateLabel(FindMyFriend friend) {
    final status = friend.status;
    if (status == null) return "Location";
    return "${status.name.capitalize!} Location";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ColoredBox(
            color: context.theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: NavigationToolbar(
                  middle: Obx(() {
                    widget.controller.friendsWithLocation.length;
                    final visibleParticipants = widget.controller.participantFriendsWithLocation;
                    if (visibleParticipants.isEmpty) {
                      return Text("Location", style: context.theme.textTheme.titleMedium);
                    }
                    final isGroup = widget.chat.isGroup;

                    final title = _chatTitle;
                    final subtitleStyle = context.theme.textTheme.bodySmall;
                    final subtitle = isGroup ? _groupParticipantLabel(visibleParticipants.length) : null;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.textTheme.titleMedium,
                        ),
                        if (isGroup)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _locationDescription(visibleParticipants.first),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: subtitleStyle,
                                ),
                              ),
                              Text(' • ${_locationStateLabel(visibleParticipants.first)}', style: subtitleStyle),
                            ],
                          ),
                      ],
                    );
                  }),
                  centerMiddle: true,
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "Done",
                        style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
