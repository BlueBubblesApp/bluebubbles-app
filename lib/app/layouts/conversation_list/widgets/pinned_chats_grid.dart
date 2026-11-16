import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/drop_flight.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_grid_slot.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_placeholder.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// The paged grid of pinned chats at the top of the chat list, shared by every skin. A sliver.
///
/// Dragging (hold then drag on touch, click and drag with a mouse) reorders pins, pins a chat dragged in from
/// the list (`PinDragSource`), and unpins one dropped on the list (`UnpinDropTarget`). The grid previews the
/// order while a drag hovers its pins and saves it on drop; hovering a page edge turns the page. The drag's state
/// is the list's [ConversationListController.pinDrag].
class PinnedChatsGrid extends StatefulWidget {
  const PinnedChatsGrid({super.key, required this.controller});

  final ConversationListController controller;

  @override
  State<PinnedChatsGrid> createState() => _PinnedChatsGridState();
}

class _PinnedChatsGridState extends State<PinnedChatsGrid> {
  // PageView horizontal padding (8 each side)
  static const double _pageHPadding = 16.0;

  // Where a tile draws its avatar: AnimatedContainer margin (top: 1) + padding (top: 4)
  static const double _tileAvatarTop = 5.0;

  final PageController _pages = PageController();
  Timer? _pageFlipCooldown;

  ConversationListController get controller => widget.controller;

  PinDragController get drag => controller.pinDrag;

  @override
  void initState() {
    super.initState();
    drag.attachGrid(context);
  }

  @override
  void didUpdateWidget(PinnedChatsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.pinDrag.detachGrid(context);
      drag.attachGrid(context);
    }
  }

  @override
  void dispose() {
    drag.detachGrid(context);
    _pageFlipCooldown?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// A pin tile's avatar size and footprint for [colCount] columns across [maxWidth].
  static ({double avatar, double width, double height}) _tileSize(BuildContext context, double maxWidth, int colCount) {
    // Horizontal overhead per tile: margins (4+4) + padding (8+8) + extra gap
    const double tileHOverhead = 30.0;
    // Vertical overhead per tile: AnimatedContainer margins (top:1) + padding (4+2)
    //   + ChatTitle fixed padding (top:6 + bottom:4)
    const double tileVOverhead = 17.0;
    // Extra per-row safety margin so real-device font/DPI variance can't make the
    // estimate come in short and let the last row bleed into the space below it.
    const double tileVSafetyBuffer = 4.0;
    final double avatar = min((maxWidth - _pageHPadding - colCount * tileHOverhead) / colCount, 120.0);
    final TextStyle style = context.theme.textTheme.bodyMedium!;
    final double textHeight = (style.height ?? 1.2) * (style.fontSize ?? 14);
    return (
      avatar: avatar,
      width: avatar + tileHOverhead,
      height: avatar + textHeight + tileVOverhead + tileVSafetyBuffer,
    );
  }

  /// Keeps the drag's pin look the size of the pins, once this layout is done.
  void _reportAvatarSize(double avatar) {
    if (avatar == drag.pinAvatarSize) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => drag.reportPinAvatarSize(avatar));
  }

  void _flipPage(int direction, int pageCount) {
    if (_pageFlipCooldown?.isActive ?? false) return;
    final page = (_pages.page?.round() ?? 0) + direction;
    if (page < 0 || page >= pageCount) return;
    _pageFlipCooldown = Timer(const Duration(milliseconds: 700), () {});
    _pages.animateToPage(page, curve: Curves.easeOut, duration: const Duration(milliseconds: 250));
  }

  void _drop(DragTargetDetails<String> details, List<Chat> pinned) {
    if (!drag.moved) return;
    drag.markDropped(drag.commit(details.data, pinned));
    DropFlight.show(context, drag, details.data, details.offset, toPin: true);
  }

  /// Pins a drag at the end, or with [start] at the start: the room left of a centered row.
  Widget _dropZone(List<Chat> pinned, Widget child, {bool start = false}) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        drag.setOverPinArea(true);
        drag.hoverEdge(drag.ordered(pinned), details.data, start: start);
        return true;
      },
      // Entered while the pins were still sliding, so retried until it takes.
      onMove: (details) => drag.hoverEdge(drag.ordered(pinned), details.data, start: start),
      onAcceptWithDetails: (details) => _drop(details, pinned),
      builder: (context, _, _) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        // The pins themselves: only chat and settings changes refilter them.
        child: Obx(() {
          ChatsSvc.loadedFirstChatBatch.value;
          // Observe chatListVersion so pinned section rebuilds when a chat is pinned/unpinned
          ChatsSvc.chatListVersion.value;
          NavigationSvc.listener.value;
          final pinned = ChatsSvc.getFilteredChats(
            showArchived: controller.showArchivedChats,
            showUnknown: controller.showUnknownSenders,
            pinnedOnly: true,
            filters: ChatsSvc.chatListFilters.value,
          );
          final int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
              ? SettingsSvc.settings.pinRowsPortrait.value
              : SettingsSvc.settings.pinRowsLandscape.value;
          final int colCount = kIsDesktop
              ? SettingsSvc.settings.pinColumnsLandscape.value
              : SettingsSvc.settings.pinColumnsPortrait.value;
          // How a drag shows them: its previewed order, without a pin dragged off them.
          return Obx(() => _buildPins(context, pinned, rowCount: rowCount, colCount: colCount));
        }),
      ),
    );
  }

  Widget _buildPins(BuildContext context, List<Chat> pinned, {required int rowCount, required int colCount}) {
    final left = drag.leftPinsGuid;
    final ordered = drag.ordered(pinned);
    final chats = left == null ? ordered : ordered.where((c) => c.guid != left).toList();

    if (chats.isEmpty) {
      // With no pins there is no grid to drop on, so a list drag gets a zone of its own.
      if (!drag.showsPlaceholder) return const SizedBox(width: double.infinity);
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: LayoutBuilder(builder: (context, constraints) {
          final tile = _tileSize(context, constraints.maxWidth, colCount);
          return _dropZone(
            pinned,
            PinPlaceholder(avatarSize: tile.avatar, avatarTop: _tileAvatarTop, height: tile.height),
          );
        }),
      );
    }

    return Padding(
      // Bottom padding guarantees visible separation from the regular chat list even if
      // totalHeight below slightly underestimates the tiles' real rendered height on a
      // given device (font metrics can vary enough to make the estimate come in short).
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: LayoutBuilder(builder: (context, constraints) {
        final tile = _tileSize(context, constraints.maxWidth, colCount);
        _reportAvatarSize(tile.avatar);
        if (NavigationSvc.isAvatarOnly(context)) return _buildAvatarOnly(context, chats);

        final int pinCount = chats.length;
        final int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
        final int maxOnPage = rowCount * colCount;
        final int pageCount = (pinCount / maxOnPage).ceil();
        return _dropZone(
          pinned,
          Column(
            children: <Widget>[
              SizedBox(
                height: usedRowCount * tile.height,
                child: Stack(
                  children: [
                    PageView.builder(
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      scrollDirection: Axis.horizontal,
                      controller: _pages,
                      itemCount: pageCount,
                      itemBuilder: (context, pageIndex) => _buildPage(
                        pinned: pinned,
                        chats: chats,
                        pageIndex: pageIndex,
                        maxOnPage: maxOnPage,
                        colCount: colCount,
                        singleRow: usedRowCount == 1,
                        pageWidth: constraints.maxWidth - _pageHPadding,
                        tile: tile,
                      ),
                    ),
                    if (pageCount > 1)
                      for (final direction in [-1, 1])
                        Positioned(
                          top: 0,
                          bottom: 0,
                          width: 24,
                          left: direction < 0 ? 0 : null,
                          right: direction > 0 ? 0 : null,
                          child: DragTarget<String>(
                            onWillAcceptWithDetails: (_) => false,
                            onMove: (_) => _flipPage(direction, pageCount),
                            builder: (context, _, _) => const SizedBox.expand(),
                          ),
                        ),
                  ],
                ),
              ),
              if (pageCount > 1) _buildPageIndicator(context, pageCount, tile.avatar),
            ],
          ),
        );
      }),
    );
  }

  /// One page of pins. Each sits at its slot in a stack, keyed by chat, so a reorder slides it there rather than
  /// rebuilding the rows in the new order.
  Widget _buildPage({
    required List<Chat> pinned,
    required List<Chat> chats,
    required int pageIndex,
    required int maxOnPage,
    required int colCount,
    required bool singleRow,
    required double pageWidth,
    required ({double avatar, double width, double height}) tile,
  }) {
    final int start = pageIndex * maxOnPage;
    final List<Chat> pageChats = chats.sublist(start, min(start + maxOnPage, chats.length));
    final double rowInset = singleRow ? max(0, (pageWidth - pageChats.length * tile.width) / 2) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pageHPadding / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (pageIndex == 0 && rowInset > 0)
            Positioned(
              left: 0,
              top: 0,
              width: rowInset,
              height: tile.height,
              child: _dropZone(pinned, const SizedBox.expand(), start: true),
            ),
          for (final (slot, chat) in pageChats.indexed)
            AnimatedPositioned(
              key: ValueKey(chat.guid),
              duration: PinDragController.slide,
              curve: Curves.easeOutCubic,
              left: rowInset + (slot % colCount) * tile.width,
              top: (slot ~/ colCount) * tile.height,
              width: tile.width,
              child: PinGridSlot(
                chat: chat,
                listController: controller,
                avatarSize: tile.avatar,
                onHover: (dragged) => drag.hover(chats, dragged, chat.guid),
                onDrop: (details) => _drop(details, pinned),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarOnly(BuildContext context, List<Chat> chats) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.builder(
          shrinkWrap: true,
          itemCount: chats.length,
          findChildIndexCallback: (key) => findChildIndexByKey(chats, key, (item) => item.guid),
          itemBuilder: (context, index) {
            final chat = chats[index];
            return Center(
              heightFactor: 1,
              child: ConversationTile(key: Key(chat.guid), chat: chat, controller: controller),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            color: context.theme.colorScheme.outline.withValues(alpha: 0.5),
            thickness: 2,
            height: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(BuildContext context, int pageCount, double avatarSize) {
    return MouseRegion(
      cursor: MouseCursor.defer,
      hitTestBehavior: HitTestBehavior.deferToChild,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SmoothPageIndicator(
          count: pageCount,
          controller: _pages,
          onDotClicked: kIsDesktop || kIsWeb
              ? (page) => _pages.animateToPage(
                    page,
                    curve: Curves.linear,
                    duration: const Duration(milliseconds: 150),
                  )
              : null,
          effect: ColorTransitionEffect(
            activeDotColor: context.theme.colorScheme.primary,
            dotColor: context.theme.colorScheme.outline,
            dotWidth: avatarSize * 0.1,
            dotHeight: avatarSize * 0.1,
            spacing: avatarSize * 0.07,
          ),
        ),
      ),
    );
  }
}
