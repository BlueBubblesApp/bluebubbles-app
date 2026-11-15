import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// True while any chat is being dragged, so the grid can show itself as a drop zone.
final RxBool _listDragActive = false.obs;

/// Whether the chat being dragged is over the pin area, so its drag preview can look like a pin or a list tile.
final RxBool _overPinArea = false.obs;

/// The paged grid of pinned chats at the top of the chat list, shared by every skin. A sliver.
///
/// Dragging (hold then drag on touch, click and drag with a mouse) reorders pins, pins a chat dragged in from
/// the list ([PinDragSource]), and unpins one dropped on the list ([UnpinDropTarget]). The grid previews the
/// order while a drag hovers its pins and saves it on drop; hovering a page edge turns the page.
class PinnedChatsGrid extends StatefulWidget {
  const PinnedChatsGrid({super.key, required this.controller});

  final ConversationListController controller;

  @override
  State<PinnedChatsGrid> createState() => _PinnedChatsGridState();
}

class _PinnedChatsGridState extends State<PinnedChatsGrid> {
  final PageController _controller = PageController();

  /// Guids in their previewed order while a drag hovers the pins, otherwise null.
  List<String>? _dragOrder;
  Timer? _pageFlipCooldown;
  late final Worker _listDragWorker;

  @override
  void initState() {
    super.initState();
    _listDragWorker = ever(_listDragActive, (bool active) {
      if (!active) _cancelPreview();
    });
  }

  ConversationListController get controller => widget.controller;

  bool get showArchived => controller.showArchivedChats;

  bool get showUnknown => controller.showUnknownSenders;

  @override
  void dispose() {
    _pageFlipCooldown?.cancel();
    _listDragWorker.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<Chat> _ordered(List<Chat> chats) {
    final order = _dragOrder;
    if (order == null) return chats;
    final byGuid = {for (final c in chats) c.guid: c};
    // A chat dragged in from the list isn't a pin yet; a pin added or removed mid-drag shows up (or drops out)
    // instead of breaking the preview.
    return [
      ...order.map((g) => byGuid[g] ?? ChatsSvc.findChatByGuid(g)).whereType<Chat>(),
      ...chats.where((c) => !order.contains(c.guid)),
    ];
  }

  void _hover(List<Chat> shown, String dragged, String target) {
    if (dragged == target) return;
    final order = shown.map((c) => c.guid).toList();
    order.remove(dragged);
    final to = order.indexOf(target);
    if (to < 0) return;
    order.insert(to, dragged);
    setState(() => _dragOrder = order);
  }

  void _cancelPreview() {
    if (_dragOrder != null && mounted) setState(() => _dragOrder = null);
  }

  /// A drop anywhere on the grid: pins a chat from the list (where the preview put it, else at the end) and
  /// saves the previewed order.
  Future<void> _accept(String guid, List<Chat> pinned) async {
    final order = _ordered(pinned);
    setState(() => _dragOrder = null);
    final chat = ChatsSvc.findChatByGuid(guid);
    if (chat == null) return;
    if (!(chat.isPinned ?? false)) {
      await ChatsSvc.setChatPinned(chat, true);
      if (!order.any((c) => c.guid == guid)) return;
    }
    if (!listEquals(order.map((c) => c.guid).toList(), pinned.map((c) => c.guid).toList())) {
      await ChatsSvc.reorderPins(order);
    }
  }

  Widget _dropZone(List<Chat> pinned, Widget child) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => _overPinArea.value = true,
      onAcceptWithDetails: (details) => _accept(details.data, pinned),
      builder: (context, _, _) => Obx(
        () => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _listDragActive.value
                ? context.theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ),
    );
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
        // With no pins there is no grid to drop on, so a list drag gets a zone of its own.
        if (!_listDragActive.value) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          sliver: SliverToBoxAdapter(
            child: _dropZone(
              pinned,
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    "Drop here to pin",
                    style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.primary),
                  ),
                ),
              ),
            ),
          ),
        );
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

              return _dropZone(
                pinned,
                Column(
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
                                                _overPinArea.value = true;
                                                _hover(_chats, details.data, chat.guid);
                                                return true;
                                              },
                                              onAcceptWithDetails: (details) => _accept(details.data, pinned),
                                              builder: (context, _, _) => PinnedConversationTile(
                                                chat: chat,
                                                avatarSize: avatarSize,
                                                controller: controller,
                                                draggable: true,
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
                                  builder: (context, _, _) => const SizedBox.expand(),
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
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

/// Makes a chat list tile draggable into [PinnedChatsGrid] to pin it: hold then drag on touch, click and drag with
/// a mouse. A hold that doesn't move does what the tile's long press does: peek on iOS, select otherwise.
class PinDragSource extends StatelessWidget {
  const PinDragSource({super.key, required this.chat, required this.child});

  final Chat chat;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChatDragSource(
      chat: chat,
      startsInPinArea: false,
      onHold: (position) {
        if (SettingsSvc.settings.skin.value == Skins.iOS) {
          peekChat(context, chat, position);
          return closeChatPeek;
        }
        if (!Get.isRegistered<ConversationTileController>(tag: chat.guid)) return null;
        final tile = Get.find<ConversationTileController>(tag: chat.guid)..onSelected();
        return tile.onSelected;
      },
      child: child,
    );
  }
}

/// Drags a chat (a pin or a list tile) for [PinnedChatsGrid] and [UnpinDropTarget].
///
/// On touch the drag starts on the hold, so [onHold] runs right then (opening the peek, say) and returns how to
/// undo it; the undo runs once the finger moves, which is what turns the hold into a drag. With a mouse a plain
/// click and drag starts it and there is no hold.
class ChatDragSource extends StatefulWidget {
  const ChatDragSource({
    super.key,
    required this.chat,
    required this.startsInPinArea,
    required this.onHold,
    required this.child,
  });

  final Chat chat;
  final bool startsInPinArea;
  final VoidCallback? Function(Offset position) onHold;
  final Widget child;

  @override
  State<ChatDragSource> createState() => _ChatDragSourceState();
}

class _ChatDragSourceState extends State<ChatDragSource> {
  /// How far the finger moves before a hold becomes a drag.
  static const double _holdSlop = 12;

  Offset _downPosition = Offset.zero;
  VoidCallback? _undoHold;
  bool _moved = false;

  void _onStart() {
    _listDragActive.value = true;
    _overPinArea.value = widget.startsInPinArea;
    _moved = false;
    if (kIsDesktop || kIsWeb) return;
    // The iOS peek buzzes on its own.
    if (SettingsSvc.settings.skin.value != Skins.iOS) HapticFeedback.mediumImpact();
    _undoHold = widget.onHold(_downPosition);
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_moved || (details.globalPosition - _downPosition).distance < _holdSlop) return;
    _moved = true;
    _undoHold?.call();
    _undoHold = null;
  }

  void _onEnd() {
    _listDragActive.value = false;
    _undoHold = null;
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _ChatDragFeedback(chat: widget.chat, listWidth: min(MediaQuery.sizeOf(context).width - 24, 480));
    final whileDragging = Opacity(opacity: 0.3, child: widget.child);
    final data = widget.chat.guid;
    final Widget draggable = kIsDesktop || kIsWeb
        ? Draggable<String>(
            data: data,
            feedback: feedback,
            childWhenDragging: whileDragging,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: _onStart,
            onDragEnd: (_) => _onEnd(),
            child: widget.child,
          )
        : LongPressDraggable<String>(
            data: data,
            feedback: feedback,
            childWhenDragging: whileDragging,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            // Beats the tile's own long press to the gesture; the hold action runs from here instead.
            delay: kLongPressTimeout - const Duration(milliseconds: 100),
            hapticFeedbackOnStart: false,
            onDragStarted: _onStart,
            onDragUpdate: _onUpdate,
            onDragEnd: (_) => _onEnd(),
            child: widget.child,
          );
    return Listener(onPointerDown: (event) => _downPosition = event.position, child: draggable);
  }
}

/// What follows the finger: a pin over the pin area, a list tile anywhere else.
class _ChatDragFeedback extends StatelessWidget {
  const _ChatDragFeedback({required this.chat, required this.listWidth});

  final Chat chat;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    final title = ChatsSvc.getChatState(chat.guid)?.title.value ?? chat.getTitle();
    final textTheme = context.theme.textTheme;
    // A zero-size box at the pointer with the content centered on it, so whichever look is showing (and both,
    // mid-switch) sits under the finger.
    return SizedBox.shrink(
      child: OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: Material(
        type: MaterialType.transparency,
        child: Obx(() => AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _overPinArea.value
                  ? SizedBox(
                      key: const ValueKey('pin'),
                      width: 88,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ContactAvatarGroupWidget(chat: chat, size: 72, editable: false),
                          const SizedBox(height: 6),
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                        ],
                      ),
                    )
                  : Material(
                      key: const ValueKey('list'),
                      elevation: 6,
                      color: context.theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: listWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              ContactAvatarGroupWidget(chat: chat, size: 44, editable: false),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            )),
      ),
    ));
  }
}

/// Unpins a pin dropped on [child], the chat list below the pinned grid. Drops on the grid itself never reach it.
class UnpinDropTarget extends StatelessWidget {
  const UnpinDropTarget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        _overPinArea.value = false;
        return ChatsSvc.findChatByGuid(details.data)?.isPinned ?? false;
      },
      onAcceptWithDetails: (details) {
        final chat = ChatsSvc.findChatByGuid(details.data);
        if (chat != null) ChatsSvc.setChatPinned(chat, false);
      },
      builder: (context, _, _) => child,
    );
  }
}
