import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// The paged grid of pinned chats at the top of the chat list, shared by every skin. A sliver.
///
/// Pins reorder by dragging one onto another (hold then drag on touch, click and drag with a mouse). The grid
/// previews the new order while dragging and saves it on release; hovering a page edge turns the page.
class PinnedChatsGrid extends StatefulWidget {
  const PinnedChatsGrid({super.key, required this.controller});

  final ConversationListController controller;

  @override
  State<PinnedChatsGrid> createState() => _PinnedChatsGridState();
}

class _PinnedChatsGridState extends State<PinnedChatsGrid> {
  final PageController _controller = PageController();

  /// Guids in their previewed order while a drag is reordering, otherwise null.
  List<String>? _dragOrder;
  Timer? _pageFlipCooldown;

  ConversationListController get controller => widget.controller;

  bool get showArchived => controller.showArchivedChats;

  bool get showUnknown => controller.showUnknownSenders;

  @override
  void dispose() {
    _pageFlipCooldown?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<Chat> _ordered(List<Chat> chats) {
    final order = _dragOrder;
    if (order == null) return chats;
    final byGuid = {for (final c in chats) c.guid: c};
    // A pin added or removed mid-drag shows up (or drops out) instead of breaking the preview.
    return [...order.map((g) => byGuid[g]).whereType<Chat>(), ...chats.where((c) => !order.contains(c.guid))];
  }

  void _hover(List<Chat> shown, String dragged, String target) {
    if (dragged == target) return;
    final order = shown.map((c) => c.guid).toList();
    final to = order.indexOf(target);
    if (!order.remove(dragged) || to < 0) return;
    order.insert(to, dragged);
    setState(() => _dragOrder = order);
  }

  void _endDrag(List<Chat> chats) {
    final order = _dragOrder;
    if (order == null) return;
    final reordered = _ordered(chats);
    setState(() => _dragOrder = null);
    if (!listEquals(reordered.map((c) => c.guid).toList(), chats.map((c) => c.guid).toList())) {
      ChatsSvc.reorderPins(reordered);
    }
  }

  void _flipPage(int direction, int pageCount) {
    if (_pageFlipCooldown?.isActive ?? false) return;
    final page = (_controller.page?.round() ?? 0) + direction;
    if (page < 0 || page >= pageCount) return;
    _pageFlipCooldown = Timer(const Duration(milliseconds: 700), () {});
    _controller.animateToPage(page, curve: Curves.easeOut, duration: const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Force reactivity by accessing observable values first
      // ignore: unused_local_variable
      final loaded = ChatsSvc.loadedFirstChatBatch.value;
      // Observe chatListVersion so pinned section rebuilds when a chat is pinned/unpinned
      // ignore: unused_local_variable
      final _version = ChatsSvc.chatListVersion.value;
      NavigationSvc.listener.value;
      final pinned = ChatsSvc.getFilteredChats(
        showArchived: showArchived,
        showUnknown: showUnknown,
        pinnedOnly: true,
        filters: ChatsSvc.chatListFilters.value,
      );
      final _chats = _ordered(pinned);

      if (_chats.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
          ? SettingsSvc.settings.pinRowsPortrait.value
          : SettingsSvc.settings.pinRowsLandscape.value;
      int colCount = kIsDesktop
          ? SettingsSvc.settings.pinColumnsLandscape.value
          : SettingsSvc.settings.pinColumnsPortrait.value;
      int pinCount = _chats.length;
      int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
      int maxOnPage = rowCount * colCount;
      int _pageCount = (pinCount / maxOnPage).ceil();
      bool singleRow = usedRowCount == 1;

      return SliverPadding(
        // Bottom padding guarantees visible separation from the regular chat list even if
        // totalHeight below slightly underestimates the tiles' real rendered height on a
        // given device (font metrics can vary enough to make the estimate come in short).
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        sliver: SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Horizontal overhead per tile: margins (4+4) + padding (11+11) + extra gap
              const double tileHOverhead = 42.0;
              // Vertical overhead per tile: AnimatedContainer margins (top:1) + padding (4+2)
              //   + ChatTitle fixed padding (top:6 + bottom:4)
              const double tileVOverhead = 17.0;
              // Extra per-row safety margin so real-device font/DPI variance can't make the
              // estimate come in short and let the last row bleed into the space below it.
              const double tileVSafetyBuffer = 4.0;
              // PageView horizontal padding (10 each side)
              const double pageHPadding = 20.0;

              // Derive a clean, capped avatar size from the actual available width
              final double rawAvatarSize = (constraints.maxWidth - pageHPadding - colCount * tileHOverhead) / colCount;
              final double avatarSize = min(rawAvatarSize, 120.0);
              final double tileWidth = avatarSize + tileHOverhead;

              final TextStyle style = context.theme.textTheme.bodyMedium!;
              final double textHeight = (style.height ?? 1.2) * (style.fontSize ?? 14);
              final double tileHeight = avatarSize + textHeight + tileVOverhead + tileVSafetyBuffer;
              final double totalHeight = usedRowCount * tileHeight;

              // avatar only
              if (NavigationSvc.isAvatarOnly(context)) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _chats.length,
                      findChildIndexCallback: (key) => findChildIndexByKey(_chats, key, (item) => item.guid),
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
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

              return Column(
                children: <Widget>[
                  SizedBox(
                    height: totalHeight,
                    child: Stack(
                      children: [
                        PageView.builder(
                          clipBehavior: Clip.none,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          scrollDirection: Axis.horizontal,
                          controller: _controller,
                          itemCount: _pageCount,
                          itemBuilder: (context, pageIndex) {
                            final int start = pageIndex * maxOnPage;
                            final List<Chat> pageChats = _chats.sublist(start, min(start + maxOnPage, pinCount));

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: List.generate(usedRowCount, (rowIndex) {
                                  final int rowStart = rowIndex * colCount;
                                  final List<Chat> rowChats = pageChats.skip(rowStart).take(colCount).toList();

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: singleRow ? MainAxisAlignment.center : MainAxisAlignment.start,
                                    children: [
                                      for (final chat in rowChats)
                                        SizedBox(
                                          key: Key(chat.guid),
                                          width: tileWidth,
                                          child: DragTarget<String>(
                                            onWillAcceptWithDetails: (details) {
                                              _hover(_chats, details.data, chat.guid);
                                              return true;
                                            },
                                            builder: (context, _, __) => PinnedConversationTile(
                                              chat: chat,
                                              avatarSize: avatarSize,
                                              controller: controller,
                                              onReorderEnd: () => _endDrag(pinned),
                                            ),
                                          ),
                                        ),
                                      // Fill empty slots in multi-row mode so rows align
                                      if (!singleRow)
                                        for (int i = rowChats.length; i < colCount; i++) SizedBox(width: tileWidth),
                                    ],
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                        if (_pageCount > 1)
                          for (final direction in [-1, 1])
                            Positioned(
                              top: 0,
                              bottom: 0,
                              width: 24,
                              left: direction < 0 ? 0 : null,
                              right: direction > 0 ? 0 : null,
                              child: DragTarget<String>(
                                onWillAcceptWithDetails: (_) => false,
                                onMove: (_) => _flipPage(direction, _pageCount),
                                builder: (context, _, __) => const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
                  ),
                  if (_pageCount > 1)
                    MouseRegion(
                      cursor: MouseCursor.defer,
                      hitTestBehavior: HitTestBehavior.deferToChild,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SmoothPageIndicator(
                          count: _pageCount,
                          controller: _controller,
                          onDotClicked: kIsDesktop || kIsWeb
                              ? (page) => _controller.animateToPage(
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
                    ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}
