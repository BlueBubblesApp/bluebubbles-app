import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/participants_findmy_sheet/participants_findmy_sheet.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_participant_prefetch.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

class ParticipantsFindMyMapCard extends StatefulWidget {
  final Chat chat;

  const ParticipantsFindMyMapCard({super.key, required this.chat});

  /// Same capability gate as the Find My nav entry (plus web exclusion).
  static bool get isSupported => FindMyParticipantPrefetch.isSupported;

  @override
  State<ParticipantsFindMyMapCard> createState() => _ParticipantsFindMyMapCardState();
}

class _ParticipantsFindMyMapCardState extends State<ParticipantsFindMyMapCard> {
  late final FindMyController _controller;
  late final MapController _mapController;
  StreamSubscription? _participantsSub;
  bool _sheetOpen = false;

  ChatState? get _chatState => ChatsSvc.chatStates[widget.chat.guid];

  List<Handle> get _currentParticipants {
    final state = _chatState;
    if (state != null) return state.participants.map((hs) => hs.handle).toList();
    return widget.chat.handles.toList();
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initController();
    _participantsSub = _chatState?.participants.listen((_) {
      if (!mounted) return;
      _controller.updateParticipantFilter(_currentParticipants);
      setState(() {});
    });
  }

  void _initController() {
    final tag = FindMyParticipantPrefetch.controllerTag(widget.chat.guid);
    if (Get.isRegistered<FindMyController>(tag: tag)) {
      _controller = Get.find<FindMyController>(tag: tag);
      _controller.updateParticipantFilter(_currentParticipants);
    } else {
      _controller = Get.put(
        FindMyController(participantFilter: _currentParticipants),
        tag: tag,
      );
    }
    _controller.attachParticipantMapController(_mapController);
  }

  Future<void> _openExpandedMap() async {
    if (_sheetOpen) return;

    setState(() => _sheetOpen = true);
    await showParticipantsFindMyMap(
      context,
      controller: _controller,
      chat: widget.chat,
      onSheetClosed: () {
        if (mounted) setState(() => _sheetOpen = false);
      },
    );
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    _controller.detachParticipantMapController();
    _mapController.dispose();
    final tag = FindMyParticipantPrefetch.controllerTag(widget.chat.guid);
    if (Get.isRegistered<FindMyController>(tag: tag)) {
      Get.delete<FindMyController>(tag: tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _controller.friendsWithLocation.length;
      final visibleParticipants = _controller.participantFriendsWithLocation;
      final loading = visibleParticipants.isEmpty;

      // Show the card when we have real locations, or when prefetch already
      // knows a participant is sharing (map area stays in a loading state).
      // Otherwise render nothing so we never leave an empty gap.
      if (loading && !FindMyParticipantPrefetch.hasParticipantSharing(widget.chat)) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      return _ParticipantsFindMyCardContent(
        controller: _controller,
        mapController: _mapController,
        visibleParticipants: visibleParticipants,
        isGroup: widget.chat.isGroup,
        groupTitle: _chatState?.title.value ?? widget.chat.getTitle(),
        locationTitle: widget.chat.isGroup
            ? null
            : (loading ? 'Location' : _singleChatLocationTitle(visibleParticipants.first)),
        loading: loading,
        sheetOpen: _sheetOpen,
        openExpandedMap: _openExpandedMap,
      );
    });
  }
}

class _ParticipantsFindMyCardContent extends StatelessWidget {
  final FindMyController controller;
  final MapController mapController;
  final List<FindMyFriend> visibleParticipants;
  final bool isGroup;
  final String groupTitle;
  final String? locationTitle;
  final bool loading;
  final bool sheetOpen;
  final VoidCallback openExpandedMap;

  const _ParticipantsFindMyCardContent({
    required this.controller,
    required this.mapController,
    required this.visibleParticipants,
    required this.isGroup,
    required this.groupTitle,
    required this.locationTitle,
    required this.loading,
    required this.sheetOpen,
    required this.openExpandedMap,
  });

  static const double _mapAspectRatio = _kFindMyMapAspectRatio;
  static const double _footerHeight = _kFindMyFooterHeight;

  @override
  Widget build(BuildContext context) {
    final onTap = loading || sheetOpen ? null : openExpandedMap;
    return _buildFindMySkinCard(
      context,
      onTap: onTap,
      child: Column(
        children: [
          _buildMapPreview(context),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mapAspectRatio,
      child: loading
          ? _buildMapSkeleton(context)
          : sheetOpen
              ? const ColoredBox(color: Colors.transparent)
              : IgnorePointer(
                  child: FindMyMapWidget(
                    controller: controller,
                    mapController: mapController,
                    interactive: false,
                    onMapReady: () => controller.onParticipantMapReady(mapController),
                  ),
                ),
    );
  }

  Widget _buildMapSkeleton(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: context.iOS
            ? CupertinoActivityIndicator(
                radius: 12,
                color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              )
            : SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (context.iOS) return _buildIosFooter(context);
    if (context.samsung) return _buildSamsungFooter(context);
    return _buildMaterialFooter(context);
  }

  Widget _buildIosFooter(BuildContext context) {
    final title = isGroup ? groupTitle : locationTitle!;
    final subtitle = _footerSubtitle();

    return Container(
      height: _footerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: context.tileColor,
      child: Row(
        children: [
          Icon(Icons.location_on, size: 18, color: context.theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.textTheme.titleSmall),
                if (subtitle != null)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialFooter(BuildContext context) {
    final title = isGroup ? groupTitle : locationTitle!;
    final subtitle = _footerSubtitle();
    final subtitleStyle =
        context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.onSurfaceVariant);

    return Container(
      height: _footerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: context.tileColor,
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: context.theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.textTheme.titleSmall),
                if (subtitle != null)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle),
              ],
            ),
          ),
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Icon(Icons.open_in_full, size: 18, color: context.theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _buildSamsungFooter(BuildContext context) {
    final title = isGroup ? groupTitle : locationTitle!;
    final subtitle = _footerSubtitle();
    final subtitleStyle =
        context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurfaceVariant);

    return Container(
      height: _footerHeight + 4,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: context.tileColor,
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 20, color: context.theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle),
              ],
            ),
          ),
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Icon(Icons.keyboard_arrow_up_rounded, size: 22, color: context.theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  String? _footerSubtitle() {
    if (loading) return null;
    if (isGroup) return _groupParticipantLabel(visibleParticipants.length);
    return _locationStateLabel(visibleParticipants.first);
  }
}

const double _kFindMyMapAspectRatio = 2.2;
const double _kFindMyFooterHeight = 56;

/// Card chrome (padding, radius, colors) shared across skins.
Widget _buildFindMySkinCard(BuildContext context, {required VoidCallback? onTap, required Widget child}) {
  if (context.iOS) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Material(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: child,
          ),
        ),
      ),
    );
  }

  if (context.samsung) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Material(
          color: context.headerColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }

  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Material(
        color: context.headerColor,
        child: InkWell(onTap: onTap, child: child),
      ),
    ),
  );
}

String _singleChatLocationTitle(FindMyFriend friend) {
  if (shouldRedactFindMyContactInfo()) return 'Location';
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
