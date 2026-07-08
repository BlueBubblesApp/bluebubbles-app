import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_dialog.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ParticipantsFindMyMapCard extends StatefulWidget {
  final Chat chat;

  const ParticipantsFindMyMapCard({super.key, required this.chat});

  @override
  State<ParticipantsFindMyMapCard> createState() => _ParticipantsFindMyMapCardState();
}

class _ParticipantsFindMyMapCardState extends State<ParticipantsFindMyMapCard> {
  static String _controllerTag(String guid) => 'findmy-$guid';
  static const double _mapAspectRatio = 2.2;
  static const double _footerHeight = 56;

  FindMyController? _controller;
  StreamSubscription? _participantsSub;
  bool _sheetOpen = false;

  ChatState? get _chatState => ChatsSvc.chatStates[widget.chat.guid];

  List<Handle> get _currentParticipants {
    final state = _chatState;
    if (state != null) return state.participants.map((hs) => hs.handle).toList();
    return widget.chat.handles.toList();
  }

  Map<String, String> get _participantDisplayNames {
    final state = _chatState;
    if (state == null) return {};
    return {
      for (final hs in state.participants)
        hs.handle.address: hs.displayName.value ?? hs.handle.displayName,
    };
  }

  @override
  void initState() {
    super.initState();
    _initController();
    _participantsSub = _chatState?.participants.listen((_) {
      if (!mounted) return;
      _controller?.updateParticipantFilter(_currentParticipants, displayNames: _participantDisplayNames);
      setState(() {});
    });
  }

  void _initController() {
    final tag = _controllerTag(widget.chat.guid);
    if (Get.isRegistered<FindMyController>(tag: tag)) {
      _controller = Get.find<FindMyController>(tag: tag);
      _controller!.updateParticipantFilter(_currentParticipants, displayNames: _participantDisplayNames);
    } else {
      _controller = Get.put(
        FindMyController(participantFilter: _currentParticipants),
        tag: tag,
      );
      _controller!.participantDisplayNames = _participantDisplayNames;
    }
  }

  Future<void> _openExpandedMap() async {
    final controller = _controller;
    if (controller == null || _sheetOpen) return;

    setState(() => _sheetOpen = true);
    await showParticipantsFindMyMap(
      context,
      controller: controller,
      chat: widget.chat,
      onSheetClosed: () {
        if (mounted) setState(() => _sheetOpen = false);
      },
    );
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    final tag = _controllerTag(widget.chat.guid);
    if (Get.isRegistered<FindMyController>(tag: tag)) {
      Get.delete<FindMyController>(tag: tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !SettingsSvc.serverDetails.isMinCatalina) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final controller = _controller;
    if (controller == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return Obx(() {
      controller.friendsWithLocation.length;
      final visibleParticipants = controller.participantFriendsWithLocation;
      final isLoadingParticipants = controller.fetching2.value == true;

      if (!isLoadingParticipants && visibleParticipants.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      final isGroup = widget.chat.isGroup;
      final locationTitle = visibleParticipants.isNotEmpty ? _singleChatLocationTitle(visibleParticipants.first) : null;
      final groupTitle = _chatState?.title.value ?? widget.chat.getTitle();

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Material(
            color: context.theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _sheetOpen ? null : _openExpandedMap,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: _mapAspectRatio,
                    child: _sheetOpen
                        ? const ColoredBox(color: Colors.transparent)
                        : isLoadingParticipants
                            ? _buildMapLoadingPlaceholder(context)
                            : IgnorePointer(
                                child: FindMyMapWidget(
                                  controller: controller,
                                  interactive: false,
                                  onMapReady: () => controller.fitMapToParticipantMarkers(),
                                ),
                              ),
                  ),
                  Container(
                    height: _footerHeight,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    color: context.tileColor,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: context.theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isGroup ? groupTitle : (locationTitle ?? 'Loading Location'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.theme.textTheme.titleSmall,
                              ),
                              if (isLoadingParticipants)
                                Text(
                                  'Loading…',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.theme.textTheme.bodySmall,
                                )
                              else if (isGroup)
                                Text(
                                  _groupParticipantLabel(visibleParticipants.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.theme.textTheme.bodySmall,
                                )
                              else
                                Text(
                                  _locationStateLabel(visibleParticipants.first),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  String _singleChatLocationTitle(FindMyFriend friend) {
    if (SettingsSvc.settings.redactedMode.value) return 'Location';
    final description = (friend.longAddress ?? '').trim();
    if (description.isEmpty) return 'Location';
    return description;
  }

  String _groupParticipantLabel(int count) => '$count ${count == 1 ? "Person" : "People"}';

  String _locationStateLabel(FindMyFriend friend) {
    final status = friend.status;
    if (status == null) return 'Location';
    return '${status.name.capitalize!} Location';
  }

  Widget _buildMapLoadingPlaceholder(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: context.theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
