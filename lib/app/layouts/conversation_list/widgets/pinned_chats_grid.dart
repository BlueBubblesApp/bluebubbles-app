import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// True while any chat is being dragged (past a hold), so the grid can show itself as a drop zone.
final RxBool _listDragActive = false.obs;

/// Whether the chat being dragged is over the pin area, so its drag preview can look like a pin or a list tile.
final RxBool _overPinArea = false.obs;

/// Whether the drag has moved past a hold. Until it has, nothing looks dragged: a hold is a peek or a select.
final RxBool _dragMoved = false.obs;

/// The chat being dragged, so it shows faded only where a drop would put it.
final RxnString _draggedGuid = RxnString();

/// Whether the chat being dragged is a pin, so the list can make room where unpinning would put it.
final RxBool _dragFromPins = false.obs;

/// Set from the drop until the drag finishes: the empty pin closes at once, so a drop's flight lands where the list
/// ends up.
final RxBool _dropped = false.obs;

/// The chats for the list, with room made for a pin being dragged over it, where unpinning would put it. Read it in
/// the list's Obx so the room opens and closes with the drag.
List<Chat> chatsWithUnpinPreview(List<Chat> chats) {
  final fromPins = _dragFromPins.value;
  final moved = _dragMoved.value;
  final overPins = _overPinArea.value;
  final guid = _draggedGuid.value;
  if (!fromPins || !moved || overPins || guid == null || chats.any((c) => c.guid == guid)) return chats;
  final chat = ChatsSvc.findChatByGuid(guid);
  if (chat == null) return chats;
  DateTime latest(Chat c) =>
      ChatsSvc.getChatState(c.guid)?.latestMessage.value?.dateCreated ??
      c.dbOnlyLatestMessageDate ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final date = latest(chat);
  final at = chats.indexWhere((c) => latest(c).isBefore(date));
  return [...chats]..insert(at < 0 ? chats.length : at, chat);
}

bool _isUnpinPreview(Chat chat) =>
    _dragFromPins.value && _dragMoved.value && !_overPinArea.value && _draggedGuid.value == chat.guid;

/// The save a drop started. The drag's look holds until it lands, so the chat doesn't flash back where it was.
Future<void>? _pendingDrop;

/// The drop's flight. The drag's look holds until it lands too: its landing place only exists while the drag does, and
/// the flight follows that place as the list moves.
Future<void>? _pendingFlight;

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
  static const Duration _slide = Duration(milliseconds: 220);

  final PageController _controller = PageController();

  /// Guids in their previewed order while a drag hovers the pins, otherwise null.
  List<String>? _dragOrder;
  Timer? _pageFlipCooldown;
  late final Worker _listDragWorker;
  late final Worker _leftPinAreaWorker;

  @override
  void initState() {
    super.initState();
    _listDragWorker = ever(_listDragActive, (bool active) {
      if (!active) _cancelPreview();
    });
    // Hovering through the pins previews where the drag would land; leaving them puts everything back.
    _leftPinAreaWorker = ever(_overPinArea, (bool over) {
      if (!over) _cancelPreview();
    });
  }

  ConversationListController get controller => widget.controller;

  bool get showArchived => controller.showArchivedChats;

  bool get showUnknown => controller.showUnknownSenders;

  @override
  void dispose() {
    _pageFlipCooldown?.cancel();
    _listDragWorker.dispose();
    _leftPinAreaWorker.dispose();
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

  /// A reorder slides pins under a still finger, which reads as entering them and would reorder again, back and
  /// forth, so entries are ignored while the pins slide. A pin entered meanwhile stays entered, so it doesn't fire
  /// once they settle.
  DateTime _lastReorder = DateTime(0);

  void _hover(List<Chat> shown, String dragged, String target) {
    // A hold that selects resizes the header, sliding the pins under a still finger: only a real drag reorders.
    if (dragged == target || !_dragMoved.value) return;
    if (DateTime.now().difference(_lastReorder) < _slide) return;
    _lastReorder = DateTime.now();
    final order = shown.map((c) => c.guid).toList();
    final to = order.indexOf(target);
    if (to < 0) return;
    // Taken out first, so a pin moving forward lands after the target and one moving back lands before it.
    order.remove(dragged);
    order.insert(to, dragged);
    setState(() => _dragOrder = order);
  }

  void _hoverEnd(List<Chat> shown, String dragged) {
    if (!_dragMoved.value) return;
    final order = shown.map((c) => c.guid).toList();
    if (order.isNotEmpty && order.last == dragged) return;
    if (DateTime.now().difference(_lastReorder) < _slide) return;
    _lastReorder = DateTime.now();
    order
      ..remove(dragged)
      ..add(dragged);
    setState(() => _dragOrder = order);
  }

  /// A drop being saved: its preview stays up until the saved order replaces it, so the grid doesn't show the old
  /// order in between. The drag ending right after the drop would otherwise clear it.
  bool _committing = false;

  void _cancelPreview() {
    if (_committing) return;
    if (_dragOrder != null && mounted) setState(() => _dragOrder = null);
  }

  /// A drop anywhere on the grid: pins a chat from the list (where the preview put it, else at the end) and
  /// saves the previewed order.
  Future<void> _accept(String guid, List<Chat> pinned) async {
    final order = _ordered(pinned);
    final chat = ChatsSvc.findChatByGuid(guid);
    if (chat == null) return _cancelPreview();
    _committing = true;
    try {
      if (!(chat.isPinned ?? false)) {
        await ChatsSvc.setChatPinned(chat, true);
      }
      if (order.any((c) => c.guid == guid) &&
          !listEquals(order.map((c) => c.guid).toList(), pinned.map((c) => c.guid).toList())) {
        await ChatsSvc.reorderPins(order);
      }
    } finally {
      _committing = false;
      _cancelPreview();
    }
  }

  void _drop(DragTargetDetails<String> details, List<Chat> pinned) {
    if (!_dragMoved.value) return;
    _dropped.value = true;
    _pendingDrop = _accept(details.data, pinned);
    _DropFlight.show(context, details.data, details.offset, toPin: true);
  }

  Widget _dropZone(List<Chat> pinned, Widget child) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        _overPinArea.value = true;
        _hoverEnd(_ordered(pinned), details.data);
        return true;
      },
      // Entered while the pins were still sliding, so retried until it takes.
      onMove: (details) => _hoverEnd(_ordered(pinned), details.data),
      onAcceptWithDetails: (details) => _drop(details, pinned),
      builder: (context, _, _) => child,
    );
  }

  // PageView horizontal padding (8 each side)
  static const double _pageHPadding = 16.0;

  // Where a tile draws its avatar: AnimatedContainer margin (top: 1) + padding (top: 4)
  static const double _tileAvatarTop = 5.0;

  /// A pin tile's avatar size and footprint for [colCount] columns across [maxWidth].
  static ({double avatar, double width, double height}) _tileSize(BuildContext context, double maxWidth, int colCount) {
    // Horizontal overhead per tile: margins (4+4) + padding (6+6)
    const double tileHOverhead = 20.0;
    // Vertical overhead per tile: AnimatedContainer margins (top:1) + padding (4+2)
    //   + ChatTitle fixed padding (top:6 + bottom:4)
    const double tileVOverhead = 17.0;
    // Extra per-row safety margin so real-device font/DPI variance can't make the
    // estimate come in short and let the last row bleed into the space below it.
    const double tileVSafetyBuffer = 4.0;
    // Derive a clean, capped avatar size from the actual available width
    final double avatar = min((maxWidth - _pageHPadding - colCount * tileHOverhead) / colCount, 120.0);
    final TextStyle style = context.theme.textTheme.bodyMedium!;
    final double textHeight = (style.height ?? 1.2) * (style.fontSize ?? 14);
    return (
      avatar: avatar,
      width: avatar + tileHOverhead,
      height: avatar + textHeight + tileVOverhead + tileVSafetyBuffer,
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
    return SliverToBoxAdapter(
        child: AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Obx(() {
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
      final dragged = _dragMoved.value ? _draggedGuid.value : null;
      final flying = _flyingGuid.value;
      final unpinning = dragged != null && !_overPinArea.value;
      final _chats = unpinning ? _ordered(pinned).where((c) => c.guid != dragged).toList() : _ordered(pinned);

      int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
          ? SettingsSvc.settings.pinRowsPortrait.value
          : SettingsSvc.settings.pinRowsLandscape.value;
      int colCount = kIsDesktop
          ? SettingsSvc.settings.pinColumnsLandscape.value
          : SettingsSvc.settings.pinColumnsPortrait.value;

      if (_chats.isEmpty) {
        // With no pins there is no grid to drop on, so a list drag gets a zone of its own.
        final dragging = _listDragActive.value && !_dropped.value;
        if (!dragging) return const SizedBox(width: double.infinity);
        // An empty pin where the first one goes, taking exactly the room that pin will so dropping it doesn't resize
        // anything: the grid's padding, a tile's height, and the circle where a tile draws its avatar.
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: LayoutBuilder(builder: (context, constraints) {
            final tile = _tileSize(context, constraints.maxWidth, colCount);
            return _dropZone(
              pinned,
              SizedBox(
                height: tile.height,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _tileAvatarTop),
                    child: CustomPaint(
                      painter: _DashedCircle(context.theme.colorScheme.outline),
                      child: SizedBox.square(
                        dimension: tile.avatar,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              "Drag here to pin",
                              textAlign: TextAlign.center,
                              style: context.theme.textTheme.labelSmall!
                                  .copyWith(color: context.theme.colorScheme.outline),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }

      int pinCount = _chats.length;
      int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
      int maxOnPage = rowCount * colCount;
      int _pageCount = (pinCount / maxOnPage).ceil();
      bool singleRow = usedRowCount == 1;

      return Padding(
        // Bottom padding guarantees visible separation from the regular chat list even if
        // totalHeight below slightly underestimates the tiles' real rendered height on a
        // given device (font metrics can vary enough to make the estimate come in short).
        padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final tile = _tileSize(context, constraints.maxWidth, colCount);
              final double avatarSize = tile.avatar;
              _pinAvatarSize = avatarSize;
              final double tileWidth = tile.width;
              final double tileHeight = tile.height;
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

                              // Each pin sits at its slot in a stack, keyed by chat, so a reorder slides it there
                              // rather than rebuilding the rows in the new order.
                              final double pageWidth = constraints.maxWidth - _pageHPadding;
                              final double rowInset =
                                  singleRow ? max(0, (pageWidth - pageChats.length * tileWidth) / 2) : 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: _pageHPadding / 2),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (final (slot, chat) in pageChats.indexed)
                                      AnimatedPositioned(
                                        key: ValueKey(chat.guid),
                                        duration: _slide,
                                        curve: Curves.easeOutCubic,
                                        left: rowInset + (slot % colCount) * tileWidth,
                                        top: (slot ~/ colCount) * tileHeight,
                                        width: tileWidth,
                                        child: DragTarget<String>(
                                          onWillAcceptWithDetails: (details) {
                                            _overPinArea.value = true;
                                            _hover(_chats, details.data, chat.guid);
                                            return true;
                                          },
                                          onAcceptWithDetails: (details) => _drop(details, pinned),
                                          builder: (context, _, _) {
                                            final tile = Opacity(
                                              opacity: chat.guid == flying ? 0 : (chat.guid == dragged ? 0.3 : 1),
                                              child: PinnedConversationTile(
                                                chat: chat,
                                                avatarSize: avatarSize,
                                                controller: controller,
                                                draggable: true,
                                              ),
                                            );
                                            return chat.guid == dragged ? _DropSlot(pin: true, child: tile) : tile;
                                          },
                                        ),
                                      ),
                                  ],
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
      );
    }),
    ));
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
    // The room made for a pin being dragged over the list, which stays until its own row takes over.
    if (_isUnpinPreview(chat)) {
      return _DropSlot(
        pin: false,
        child: _GrowIn(
          child: IgnorePointer(
            // Faded while the drag hovers; hidden once dropped, while the flight carries the pin into it.
            child: Obx(() => Opacity(
                  opacity: _flyingGuid.value == chat.guid ? 0 : 0.3,
                  child: RepaintBoundary(key: _unpinRowBoundary, child: child),
                )),
          ),
        ),
      );
    }
    // Keyed by chat: the lists build rows by index, so after a drop the row a chat left would otherwise hand its
    // drag state (a collapsed size, mid-animation) to whichever chat moves into it.
    return ChatDragSource(
      key: ValueKey(chat.guid),
      chat: chat,
      startsInPinArea: false,
      onHold: (position) {
        if (SettingsSvc.settings.skin.value == Skins.iOS) {
          if (NavigationSvc.isTabletMode(context)) return null;
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
    _draggedGuid.value = widget.chat.guid;
    _dragFromPins.value = widget.startsInPinArea;
    _overPinArea.value = widget.startsInPinArea;
    _moved = false;
    // A mouse drag only starts once it has moved.
    _dragMoved.value = kIsDesktop || kIsWeb;
    if (kIsDesktop || kIsWeb) {
      _listDragActive.value = true;
      return;
    }
    _undoHold = widget.onHold(_downPosition);
    final peeking = _undoHold == closeChatPeek;
    // The peek buzzes on its own.
    if (!peeking) HapticFeedback.mediumImpact();
    // A hold with nothing of its own to do (no peek in tablet mode) is the drag already.
    if (_undoHold == null) {
      _moved = true;
      _dragMoved.value = true;
      _listDragActive.value = true;
    }
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_moved || (details.globalPosition - _downPosition).distance < _holdSlop) return;
    _moved = true;
    _dragMoved.value = true;
    _listDragActive.value = true;
    _undoHold?.call();
    _undoHold = null;
  }

  Future<void> _onEnd() async {
    _undoHold = null;
    final pending = _pendingDrop;
    final flight = _pendingFlight;
    _pendingDrop = null;
    _pendingFlight = null;
    if (pending != null) await pending.catchError((_) {});
    if (flight != null) await flight;
    _listDragActive.value = false;
    _draggedGuid.value = null;
    _dragMoved.value = false;
    _dragFromPins.value = false;
    _dropped.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _ChatDragFeedback(
      chat: widget.chat,
      listWidth: min(MediaQuery.sizeOf(context).width - 24, 480),
      alwaysPin: true,
    );
    Widget listLook({required bool dragging}) => Obx(() {
          if (_flyingGuid.value == widget.chat.guid) return Opacity(opacity: 0, child: widget.child);
          final mine = _draggedGuid.value == widget.chat.guid;
          if (mine && _overPinArea.value) return const SizedBox.shrink();
          return mine && dragging && _dragMoved.value ? Opacity(opacity: 0.3, child: widget.child) : widget.child;
        });
    final Widget child = widget.startsInPinArea ? widget.child : listLook(dragging: false);
    final Widget whileDragging = widget.startsInPinArea ? widget.child : listLook(dragging: true);
    final data = widget.chat.guid;
    final Widget draggable = kIsDesktop || kIsWeb
        ? Draggable<String>(
            data: data,
            feedback: feedback,
            childWhenDragging: whileDragging,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: _onStart,
            // Not onDragEnd: Flutter skips it once the source is unmounted, which a pin is as soon as hovering the
            // list takes it out of the grid. These two always run.
            onDragCompleted: _onEnd,
            onDraggableCanceled: (_, _) => _onEnd(),
            child: child,
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
            onDragCompleted: _onEnd,
            onDraggableCanceled: (_, _) => _onEnd(),
            child: child,
          );
    return Listener(
      onPointerDown: (event) => _downPosition = event.position,
      child: widget.startsInPinArea
          ? draggable
          : AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: draggable,
            ),
    );
  }
}

/// What follows the finger: a pin over the pin area, a list tile anywhere else.
class _ChatDragFeedback extends StatelessWidget {
  const _ChatDragFeedback({
    required this.chat,
    required this.listWidth,
    required this.alwaysPin,
    this.look,
    this.listLook,
  });

  final Chat chat;
  final double listWidth;

  /// A drag is always a pin; only a drop's flight into the list turns it into a row.
  final bool alwaysPin;

  /// Whether it looks like a pin, when set: the drag's own state no longer applies once it's dropped.
  final RxBool? look;

  /// Shown in place of the built tile look: a drop's flight shows the row it lands as.
  final Widget? listLook;

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getChatState(chat.guid);
    // Like the tiles, which go transparent under a desktop window effect.
    final opaque = SettingsSvc.settings.windowEffect.value == WindowEffect.disabled;
    final title = chatState?.title.value ?? chat.getTitle();
    final subtitle = chatState?.subtitle.value ?? chat.dbLatestMessage.target?.getNotificationText();
    final textTheme = context.theme.textTheme;
    // A zero-size box at the pointer with the content centered on it, so whichever look is showing (and both,
    // mid-switch) sits under the finger.
    return Obx(() {
      final moved = _dragMoved.value;
      return look == null && !moved
        ? const SizedBox.shrink()
        : SizedBox.shrink(
      child: OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: Material(
        type: MaterialType.transparency,
        child: Obx(() => AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              // The new look grows out of the old one's center rather than appearing at full size.
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.3, end: 1.0)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: look?.value ?? (_overPinArea.value || alwaysPin)
                  ? SizedBox(
                      key: const ValueKey('pin'),
                      width: _pinAvatarSize + 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ContactAvatarGroupWidget(chat: chat, size: _pinAvatarSize, editable: false),
                          const SizedBox(height: 6),
                          Text(pinnedChatTitle(chat),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                        ],
                      ),
                    )
                  : listLook != null
                      ? KeyedSubtree(key: const ValueKey('list'), child: listLook!)
                      : Material(
                      key: const ValueKey('list'),
                      elevation: opaque ? 6 : 0,
                      color: opaque ? context.theme.colorScheme.surface : Colors.transparent,
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium),
                                    if (!isNullOrEmpty(subtitle))
                                      Text(subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodySmall!
                                              .copyWith(color: context.theme.colorScheme.outline)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            )),
      ),
    ));
    });
  }
}

final GlobalKey _unpinRowBoundary = GlobalKey();

/// The pins' avatar size as last laid out, so a dragged pin matches them.
double _pinAvatarSize = 72;

/// The chat a drop's flight is carrying: its landing tile stays hidden until it arrives, so it looks like it went
/// there.
final RxnString _flyingGuid = RxnString();

/// Where a drop lands, for its flight to aim at: the dragged chat's slot among the pins, or the room the list made.
BuildContext? _pinSlotContext;
BuildContext? _unpinSlotContext;

class _DropSlot extends StatefulWidget {
  const _DropSlot({required this.pin, required this.child});

  final bool pin;
  final Widget child;

  @override
  State<_DropSlot> createState() => _DropSlotState();
}

class _DropSlotState extends State<_DropSlot> {
  @override
  void initState() {
    super.initState();
    widget.pin ? _pinSlotContext = context : _unpinSlotContext = context;
  }

  @override
  void dispose() {
    if (_pinSlotContext == context) _pinSlotContext = null;
    if (_unpinSlotContext == context) _unpinSlotContext = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A dropped chat flying from [from] to where it lands, as a pin among the pins or turning into a tile for the list,
/// then fading as its own tile takes over. Without the landing place in view it changes where it was dropped.
class _DropFlight extends StatefulWidget {
  const _DropFlight({
    required this.chat,
    required this.toPin,
    required this.from,
    required this.overlayBox,
    required this.slot,
    this.width,
    this.row,
    required this.landed,
    required this.onDone,
  });

  /// Completed on landing, or if the flight is torn down first, so the drag never waits on it forever.
  final Completer<void> landed;

  final Chat chat;
  final bool toPin;

  /// The landing row as it looks, for the flight to the list to turn into.
  final Future<ui.Image>? row;
  final Offset from;
  final RenderBox overlayBox;
  final RenderBox? Function() slot;
  final double? width;
  final VoidCallback onDone;

  static void show(BuildContext context, String guid, Offset position, {required bool toPin}) {
    final chat = ChatsSvc.findChatByGuid(guid);
    if (chat == null) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final slot = (toPin ? _pinSlotContext : _unpinSlotContext)?.findRenderObject() as RenderBox?;
    final hasSlot = slot != null && slot.attached && slot.hasSize;
    final boundary = toPin ? null : _unpinRowBoundary.currentContext?.findRenderObject();
    final row = boundary is RenderRepaintBoundary && boundary.hasSize
        ? boundary.toImage(pixelRatio: View.of(context).devicePixelRatio)
        : null;
    _flyingGuid.value = guid;
    final landed = Completer<void>();
    _pendingFlight = landed.future;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _DropFlight(
          chat: chat,
          toPin: toPin,
          from: overlayBox.globalToLocal(position),
          overlayBox: overlayBox,
          slot: () => (toPin ? _pinSlotContext : _unpinSlotContext)?.findRenderObject() as RenderBox?,
          width: hasSlot ? slot.size.width : null,
          row: row,
          landed: landed,
          onDone: () {
            if (_flyingGuid.value == guid) _flyingGuid.value = null;
            if (!landed.isCompleted) landed.complete();
            entry.remove();
          },
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<_DropFlight> createState() => _DropFlightState();
}

class _DropFlightState extends State<_DropFlight> with TickerProviderStateMixin {
  final RxBool _asPin = true.obs;
  Offset? _lastTo;

  Offset get _to {
    final slot = widget.slot();
    if (slot != null && slot.attached && slot.hasSize) {
      _lastTo = widget.overlayBox.globalToLocal(slot.localToGlobal(slot.size.center(Offset.zero)));
    }
    return _lastTo ?? widget.from;
  }
  final Rxn<ui.Image> _row = Rxn<ui.Image>();
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void initState() {
    super.initState();
    widget.row?.then((image) => mounted ? _row.value = image : image.dispose());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _asPin.value = widget.toPin;
      await _move.forward();
      // Swapped for the landing tile in one frame, so it looks like it went there.
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    if (!widget.landed.isCompleted) widget.landed.complete();
    _row.value?.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = View.of(context).devicePixelRatio;
    final card = Obx(() {
        final row = _row.value;
        return _ChatDragFeedback(
          chat: widget.chat,
          listWidth: widget.width ?? min(MediaQuery.sizeOf(context).width - 24, 480),
          alwaysPin: false,
          look: _asPin,
          listLook: row == null ? null : RawImage(image: row, width: row.width / dpr, height: row.height / dpr),
        );
      });
    return AnimatedBuilder(
      animation: _move,
      builder: (context, child) {
        final at = Offset.lerp(widget.from, _to, Curves.easeOutCubic.transform(_move.value))!;
        return Stack(children: [Positioned(left: at.dx, top: at.dy, child: child!)]);
      },
      child: card,
    );
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
        // Released from a hold that never moved, after a select slid the list under it.
        if (!_dragMoved.value) return;
        final chat = ChatsSvc.findChatByGuid(details.data);
        if (chat == null) return;
        _dropped.value = true;
        _pendingDrop = ChatsSvc.setChatPinned(chat, false);
        // With pointerDragAnchorStrategy the drop offset is the finger, where the pin was drawn.
        _DropFlight.show(context, details.data, details.offset, toPin: false);
      },
      // Tiles don't light up under a mouse while it's carrying a chat.
      builder: (context, _, _) => Obx(() {
        final dragging = _listDragActive.value;
        final theme = context.theme;
        return Theme(data: dragging ? theme.copyWith(hoverColor: Colors.transparent) : theme, child: child);
      }),
    );
  }
}

/// Opens from nothing to its child's height.
class _GrowIn extends StatefulWidget {
  const _GrowIn({required this.child});

  final Widget child;

  @override
  State<_GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<_GrowIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
        sizeFactor: CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        alignment: Alignment.topCenter,
        child: widget.child,
      );
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashes = 24;
    const sweep = 2 * pi / dashes;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}
