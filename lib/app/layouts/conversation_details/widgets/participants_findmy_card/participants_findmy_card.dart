import 'dart:async';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
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
  /// Tag → owning card State's token. Prevents a stale sheet-close callback from
  /// deleting a controller after a remount has claimed the same tag.
  static final Map<String, Object> _owners = <String, Object>{};

  /// Tags with an expanded sheet currently open (survives card remount).
  static final Set<String> _sheetOpenTags = <String>{};

  /// Sheet-close handler for the current owner of each tag.
  static final Map<String, VoidCallback> _sheetCloseHandlers = <String, VoidCallback>{};

  late final FindMyController _controller;
  final Object _ownerToken = Object();
  StreamSubscription? _participantsSub;
  bool _sheetOpen = false;

  ChatState? get _chatState => ChatsSvc.chatStates[widget.chat.guid];

  String get _controllerTag => FindMyParticipantPrefetch.controllerTag(widget.chat.guid);

  List<Handle> get _currentParticipants {
    final state = _chatState;
    if (state != null) return state.participants.map((hs) => hs.handle).toList();
    return widget.chat.handles.toList();
  }

  bool _owns(String tag) => identical(_owners[tag], _ownerToken);

  @override
  void initState() {
    super.initState();
    _initController();
    _participantsSub = _chatState?.participants.listen((_) {
      if (!mounted) return;
      _controller.updateParticipantFilter(_currentParticipants);
      setState(() {});
    });
  }

  void _initController() {
    final tag = _controllerTag;
    if (Get.isRegistered<FindMyController>(tag: tag)) {
      _controller = Get.find<FindMyController>(tag: tag);
      _controller.updateParticipantFilter(_currentParticipants);
    } else {
      _controller = Get.put(
        FindMyController(participantFilter: _currentParticipants, showSelf: true),
        tag: tag,
      );
    }
    _claimOwnership(tag);
  }

  void _claimOwnership(String tag) {
    _owners[tag] = _ownerToken;
    _sheetCloseHandlers[tag] = _handleSheetClosed;
    // Remount while a sheet is still open: inherit the flag so dispose skips delete.
    if (_sheetOpenTags.contains(tag)) {
      _sheetOpen = true;
    }
  }

  void _clearOwnership(String tag) {
    if (!_owns(tag)) return;
    _owners.remove(tag);
    _sheetCloseHandlers.remove(tag);
  }

  void _deleteControllerIfRegistered(String tag) {
    if (Get.isRegistered<FindMyController>(tag: tag)) {
      Get.delete<FindMyController>(tag: tag);
    }
  }

  /// Invoked via [_sheetCloseHandlers] so a remounted card receives the close.
  void _handleSheetClosed() {
    final tag = _controllerTag;
    if (!_owns(tag)) return;

    if (mounted) {
      setState(() => _sheetOpen = false);
    } else {
      _deleteControllerIfRegistered(tag);
      _clearOwnership(tag);
    }
  }

  Future<void> _openExpandedMap() async {
    if (_sheetOpen) return;

    final tag = _controllerTag;
    setState(() => _sheetOpen = true);
    _sheetOpenTags.add(tag);
    await showParticipantsFindMyMap(
      context,
      controller: _controller,
      chat: widget.chat,
      onSheetClosed: () {
        _sheetOpenTags.remove(tag);
        _sheetCloseHandlers[tag]?.call();
      },
    );
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    final tag = _controllerTag;
    // Skip delete while the sheet still holds the controller; sheet close will
    // clean up if this card (or a remounted owner) is already gone.
    if (_owns(tag) && !_sheetOpen) {
      _deleteControllerIfRegistered(tag);
      _clearOwnership(tag);
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

      return SliverToBoxAdapter(
        child: _ParticipantsFindMyCardContent(
          controller: _controller,
          visibleParticipants: visibleParticipants,
          isGroup: widget.chat.isGroup,
          groupTitle: _chatState?.title.value ?? widget.chat.getTitle(),
          locationTitle: widget.chat.isGroup
              ? null
              : (loading ? 'Location' : _singleChatLocationTitle(visibleParticipants.first)),
          loading: loading,
          sheetOpen: _sheetOpen,
          openExpandedMap: _openExpandedMap,
        ),
      );
    });
  }
}

class _ParticipantsFindMyCardContent extends StatelessWidget {
  final FindMyController controller;
  final List<FindMyFriend> visibleParticipants;
  final bool isGroup;
  final String groupTitle;
  final String? locationTitle;
  final bool loading;
  final bool sheetOpen;
  final VoidCallback openExpandedMap;

  const _ParticipantsFindMyCardContent({
    required this.controller,
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
    final card = Column(
      children: [
        _buildMapPreview(context),
        _buildFooter(context),
      ],
    );

    if (context.iOS) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, isGroup ? 4 : 12, 20, isGroup ? 12 : 4),
        child: Material(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: card,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const M3ESectionHeader(label: "Location"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: M3ESpacing.lg, vertical: M3ESpacing.xs),
          child: Material(
            color: context.tileColor,
            borderRadius: BorderRadius.circular(M3EShapes.xl),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: card,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mapAspectRatio,
      child: loading
          ? _buildMapSkeleton(context)
          : IgnorePointer(
              child: FindMyMapWidget(
                controller: controller,
                mapController: controller.mapController,
                interactive: false,
                onMapReady: controller.onParticipantMapReady,
              ),
            ),
    );
  }

  Widget _buildMapSkeleton(BuildContext context) {
    final color = context.iOS
        ? context.theme.colorScheme.surfaceContainerHighest
        : context.tileColor.themeLightenOrDarken(context, 6);
    return ColoredBox(
      color: color,
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
    return _buildExpressiveFooter(context);
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

  Widget _buildExpressiveFooter(BuildContext context) {
    final title = isGroup ? groupTitle : locationTitle!;
    final subtitle = _footerSubtitle();
    final subtitleStyle =
        context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.onSurfaceVariant);

    return SizedBox(
      height: _footerHeight,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: M3ESpacing.lg),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: context.theme.colorScheme.primary),
            const SizedBox(width: M3ESpacing.md),
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
            if (!loading) Icon(Icons.open_in_full, size: 18, color: context.theme.colorScheme.onSurfaceVariant),
          ],
        ),
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
