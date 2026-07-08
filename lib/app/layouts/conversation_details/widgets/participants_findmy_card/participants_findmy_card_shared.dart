import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

typedef ParticipantsFindMyCardBuilder = Widget Function(BuildContext context, ParticipantsFindMyCardViewModel vm);

class ParticipantsFindMyMapCardScaffold extends StatefulWidget {
  final Chat chat;
  final ParticipantsFindMyCardBuilder builder;

  const ParticipantsFindMyMapCardScaffold({
    super.key,
    required this.chat,
    required this.builder,
  });

  @override
  State<ParticipantsFindMyMapCardScaffold> createState() => _ParticipantsFindMyMapCardScaffoldState();
}

class _ParticipantsFindMyMapCardScaffoldState extends State<ParticipantsFindMyMapCardScaffold> {
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
      for (final hs in state.participants) hs.handle.address: hs.displayName.value ?? hs.handle.displayName,
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

      final vm = ParticipantsFindMyCardViewModel(
        chat: widget.chat,
        controller: controller,
        visibleParticipants: visibleParticipants,
        isLoadingParticipants: isLoadingParticipants,
        isGroup: widget.chat.isGroup,
        groupTitle: _chatState?.title.value ?? widget.chat.getTitle(),
        locationTitle:
            visibleParticipants.isNotEmpty ? singleChatLocationTitle(visibleParticipants.first) : null,
        sheetOpen: _sheetOpen,
        openExpandedMap: _openExpandedMap,
        mapAspectRatio: _mapAspectRatio,
        footerHeight: _footerHeight,
      );

      return widget.builder(context, vm);
    });
  }
}

class ParticipantsFindMyCardViewModel {
  final Chat chat;
  final FindMyController controller;
  final List<FindMyFriend> visibleParticipants;
  final bool isLoadingParticipants;
  final bool isGroup;
  final String groupTitle;
  final String? locationTitle;
  final bool sheetOpen;
  final VoidCallback openExpandedMap;
  final double mapAspectRatio;
  final double footerHeight;

  const ParticipantsFindMyCardViewModel({
    required this.chat,
    required this.controller,
    required this.visibleParticipants,
    required this.isLoadingParticipants,
    required this.isGroup,
    required this.groupTitle,
    required this.locationTitle,
    required this.sheetOpen,
    required this.openExpandedMap,
    required this.mapAspectRatio,
    required this.footerHeight,
  });
}

String singleChatLocationTitle(FindMyFriend friend) {
  if (SettingsSvc.settings.redactedMode.value) return 'Location';
  final description = (friend.longAddress ?? '').trim();
  if (description.isEmpty) return 'Location';
  return description;
}

String groupParticipantLabel(int count) => '$count ${count == 1 ? "Person" : "People"}';

String locationStateLabel(FindMyFriend friend) {
  final status = friend.status;
  if (status == null) return 'Location';
  return '${status.name.capitalize!} Location';
}

Widget buildFindMyMapPreview(BuildContext context, ParticipantsFindMyCardViewModel vm) {
  return AspectRatio(
    aspectRatio: vm.mapAspectRatio,
    child: vm.sheetOpen
        ? const ColoredBox(color: Colors.transparent)
        : vm.isLoadingParticipants
            ? buildMapLoadingPlaceholder(context)
            : IgnorePointer(
                child: FindMyMapWidget(
                  controller: vm.controller,
                  interactive: false,
                  onMapReady: () => vm.controller.fitMapToParticipantMarkers(),
                ),
              ),
  );
}

Widget buildMapLoadingPlaceholder(BuildContext context) {
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
