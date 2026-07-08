import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_map_dialog.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
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
      if (controller.fetching2.value == true) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      if (controller.participantFriendsWithLocation.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Material(
            color: context.theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _sheetOpen ? null : _openExpandedMap,
              child: SizedBox(
                height: 160,
                child: _sheetOpen
                    ? const ColoredBox(color: Colors.transparent)
                    : IgnorePointer(
                        child: FindMyMapWidget(
                          controller: controller,
                          interactive: false,
                          onMapReady: () => controller.fitMapToParticipantMarkers(),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
