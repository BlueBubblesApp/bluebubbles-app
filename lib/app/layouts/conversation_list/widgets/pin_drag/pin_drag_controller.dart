import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// The state of a chat being dragged onto, around, or off the pins of one chat list.
///
/// One per [ConversationListController] (`pinDrag`), created and disposed with it, so a list pushed over another
/// (Archived, Unknown Senders) has a drag of its own. Widgets read it inside `Obx` through its getters and change it
/// only through its methods, which keep the derived values ([unpinPreviewGuid], [leftPinsGuid], [movedGuid],
/// [showsPlaceholder]) in step, so a widget can watch just the one value it shows.
class PinDragController {
  /// How long pins take to slide to a new order.
  static const Duration slide = Duration(milliseconds: 220);

  /// True while a chat is being dragged (past a hold), so the grid can show itself as a drop zone.
  final RxBool _active = false.obs;

  /// Whether the dragged chat is over the pin area, so its drag preview can look like a pin or a list tile.
  final RxBool _overPinArea = false.obs;

  /// Whether the drag has moved past a hold. Until it has, nothing looks dragged: a hold is a peek or a select.
  final RxBool _moved = false.obs;

  /// The chat being dragged, so it shows faded only where a drop would put it.
  final RxnString _draggedGuid = RxnString();

  /// Whether the dragged chat is a pin, so the list can make room where unpinning would put it.
  final RxBool _fromPins = false.obs;

  /// Set from the drop until the drag finishes: the empty pin closes at once, so a drop's flight lands where the
  /// list ends up.
  final RxBool _dropped = false.obs;

  /// The chat a drop's flight is carrying: its landing tile stays hidden until it arrives, so it looks like it went
  /// there.
  final RxnString _flyingGuid = RxnString();

  /// Pin guids in their previewed order while a drag hovers the pins, otherwise null.
  final Rxn<List<String>> _previewOrder = Rxn<List<String>>();

  // Derived from the values above by [_sync], so each changes only when what it shows does.
  final RxnString _movedGuid = RxnString();
  final RxnString _leftPinsGuid = RxnString();
  final RxnString _unpinPreviewGuid = RxnString();
  final RxBool _showsPlaceholder = false.obs;

  /// The row the list makes for an unpin, for a drop's flight to snapshot and turn into.
  final GlobalKey unpinRowBoundary = GlobalKey();

  /// Bumped by every drag, so a drag that ends after the next one has started leaves that one's state alone.
  int _generation = 0;

  /// The save a drop started. The drag's look holds until it lands, so the chat doesn't flash back where it was.
  Future<void>? _pendingDrop;

  /// The drop's flight. The drag's look holds until it lands too: its landing place only exists while the drag
  /// does, and the flight follows that place as the list moves.
  Future<void>? _pendingFlight;

  /// The grid, for a pin's cancelled drag to fly back from once the pin itself has left it.
  BuildContext? _gridContext;

  /// Where a drop lands, for its flight to aim at: the dragged chat's slot among the pins, or the room the list made.
  BuildContext? _pinSlotContext;
  BuildContext? _unpinSlotContext;

  /// The pins' avatar size as last laid out, so a dragged pin matches them.
  double _pinAvatarSize = 72;

  /// A reorder slides pins under a still finger, which reads as entering them and would reorder again, back and
  /// forth, so entries are ignored while the pins slide.
  DateTime _lastReorder = DateTime(0);

  /// A drop being saved: its preview stays up until the saved order replaces it, so the grid doesn't show the old
  /// order in between. The drag ending right after the drop would otherwise clear it.
  bool _committing = false;

  bool _closed = false;

  bool get active => _active.value;

  bool get overPinArea => _overPinArea.value;

  bool get moved => _moved.value;

  bool get fromPins => _fromPins.value;

  String? get draggedGuid => _draggedGuid.value;

  String? get flyingGuid => _flyingGuid.value;

  /// The dragged chat once the drag has moved past a hold.
  String? get movedGuid => _movedGuid.value;

  /// The dragged chat once it has moved off the pins, so the grid closes its place.
  String? get leftPinsGuid => _leftPinsGuid.value;

  /// A pin dragged over the list, which makes room for it where unpinning would put it.
  String? get unpinPreviewGuid => _unpinPreviewGuid.value;

  /// Whether a grid with no pins shows an empty pin to drop on.
  bool get showsPlaceholder => _showsPlaceholder.value;

  BuildContext? get gridContext => _gridContext;

  double get pinAvatarSize => _pinAvatarSize;

  /// Where a drop's flight lands: the dragged pin's slot, or the room the list made for an unpin.
  BuildContext? slotContext({required bool pin}) => pin ? _pinSlotContext : _unpinSlotContext;

  void _sync() {
    final moved = _moved.value ? _draggedGuid.value : null;
    final left = _overPinArea.value ? null : moved;
    _movedGuid.value = moved;
    _leftPinsGuid.value = left;
    _unpinPreviewGuid.value = _fromPins.value ? left : null;
    _showsPlaceholder.value = _active.value && !_dropped.value;
  }

  /// Starts a drag of [guid] and returns its generation, for [finish]. [moved] starts it past the hold already.
  int start(String guid, {required bool fromPins, required bool moved}) {
    if (_closed) return _generation;
    _dropped.value = false;
    _draggedGuid.value = guid;
    _fromPins.value = fromPins;
    _overPinArea.value = fromPins;
    _moved.value = moved;
    _active.value = moved;
    _sync();
    return ++_generation;
  }

  void markMoved() {
    if (_closed) return;
    _moved.value = true;
    _active.value = true;
    _sync();
  }

  /// Hovering through the pins previews where the drag would land; leaving them puts everything back.
  void setOverPinArea(bool over) {
    if (_closed) return;
    _overPinArea.value = over;
    if (!over) cancelPreview();
    _sync();
  }

  /// A drop that saves [save]: the drag's look holds until it is saved.
  void markDropped(Future<void> save) {
    if (_closed) return;
    _dropped.value = true;
    _pendingDrop = save;
    _sync();
  }

  /// A drop's flight carrying [guid], which is done once [landed] completes.
  void startFlight(String guid, Future<void> landed) {
    if (_closed) return;
    _flyingGuid.value = guid;
    _pendingFlight = landed;
  }

  /// The flight carrying [guid] has landed, so its tile shows again.
  void endFlight(String guid) {
    if (_closed) return;
    if (_flyingGuid.value == guid) _flyingGuid.value = null;
  }

  /// Ends the drag of [generation] once its drop is saved and its flight has landed. A later drag that has started
  /// meanwhile keeps its state.
  Future<void> finish(int generation) async {
    final pending = _pendingDrop;
    final flight = _pendingFlight;
    _pendingDrop = null;
    _pendingFlight = null;
    if (pending != null) {
      await pending.catchError((e, s) => Logger.error('Failed to save a pin drop', error: e, trace: s, tag: 'Pins'));
    }
    if (flight != null) await flight;
    if (_closed || generation != _generation) return;
    _active.value = false;
    _draggedGuid.value = null;
    _moved.value = false;
    _fromPins.value = false;
    _dropped.value = false;
    cancelPreview();
    _sync();
  }

  /// The list's [chats] with room made for a pin being dragged over it, where unpinning would put it. Read it in an
  /// `Obx` around the list's rows so the room opens and closes with the drag.
  List<Chat> withUnpinPreview(List<Chat> chats) {
    final guid = unpinPreviewGuid;
    if (guid == null || chats.any((c) => c.guid == guid)) return chats;
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

  /// [chats] with the order previewed while a drag hovers the pins, if one is.
  List<Chat> ordered(List<Chat> chats) {
    final order = _previewOrder.value;
    if (order == null) return chats;
    final byGuid = {for (final c in chats) c.guid: c};
    // A chat dragged in from the list isn't a pin yet; a pin added or removed mid-drag shows up (or drops out)
    // instead of breaking the preview.
    return [
      ...order.map((g) => byGuid[g] ?? ChatsSvc.findChatByGuid(g)).whereType<Chat>(),
      ...chats.where((c) => !order.contains(c.guid)),
    ];
  }

  /// Previews [dragged] in [target]'s place among the [shown] pins.
  void hover(List<Chat> shown, String dragged, String target) {
    // A hold that selects resizes the header, sliding the pins under a still finger: only a real drag reorders.
    if (_closed || dragged == target || !_moved.value) return;
    if (DateTime.now().difference(_lastReorder) < slide) return;
    _lastReorder = DateTime.now();
    final order = shown.map((c) => c.guid).toList();
    final to = order.indexOf(target);
    if (to < 0) return;
    // Taken out first, so a pin moving forward lands after the target and one moving back lands before it.
    order.remove(dragged);
    order.insert(to, dragged);
    _previewOrder.value = order;
  }

  /// Previews [dragged] at the end of the [shown] pins, or with [start] at the start.
  void hoverEdge(List<Chat> shown, String dragged, {required bool start}) {
    if (_closed || !_moved.value) return;
    final order = shown.map((c) => c.guid).toList();
    if (order.isNotEmpty && (start ? order.first : order.last) == dragged) return;
    if (DateTime.now().difference(_lastReorder) < slide) return;
    _lastReorder = DateTime.now();
    order.remove(dragged);
    start ? order.insert(0, dragged) : order.add(dragged);
    _previewOrder.value = order;
  }

  void cancelPreview() {
    if (_closed || _committing) return;
    _previewOrder.value = null;
  }

  /// Saves a drop of [guid] on the grid: pins a chat from the list (where the preview put it, else at the end) and
  /// saves the previewed order of the [pinned] chats.
  Future<void> commit(String guid, List<Chat> pinned) async {
    final order = ordered(pinned);
    final chat = ChatsSvc.findChatByGuid(guid);
    if (chat == null) return cancelPreview();
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
      cancelPreview();
    }
  }

  void attachGrid(BuildContext context) => _gridContext = context;

  void detachGrid(BuildContext context) {
    if (_gridContext == context) _gridContext = null;
  }

  void attachSlot(BuildContext context, {required bool pin}) =>
      pin ? _pinSlotContext = context : _unpinSlotContext = context;

  void detachSlot(BuildContext context) {
    if (_pinSlotContext == context) _pinSlotContext = null;
    if (_unpinSlotContext == context) _unpinSlotContext = null;
  }

  void reportPinAvatarSize(double size) => _pinAvatarSize = size;

  void dispose() {
    _closed = true;
    _gridContext = null;
    _pinSlotContext = null;
    _unpinSlotContext = null;
    for (final rx in <RxInterface>[
      _active,
      _overPinArea,
      _moved,
      _draggedGuid,
      _fromPins,
      _dropped,
      _flyingGuid,
      _previewOrder,
      _movedGuid,
      _leftPinsGuid,
      _unpinPreviewGuid,
      _showsPlaceholder,
    ]) {
      rx.close();
    }
  }
}
