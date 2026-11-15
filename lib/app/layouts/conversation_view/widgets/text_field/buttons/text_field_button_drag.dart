import 'dart:ui' as ui;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/desktop_attachment_menu.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

const String _tag = 'TextFieldButtons';
const String _snapshotFailed = "Couldn't snapshot the menu item a button was dropped on";

/// A desktop composer button being dragged between the row ([TextFieldIconBar]) and the `+` menu
/// ([DesktopAttachmentMenu]), as the pins do: the row makes room where a drop would put it, and hovering `+` opens
/// the menu with the button faded in place. A drop flies it there, turning into a menu tile when it lands in the menu.
/// Released anywhere else, it flies back.
abstract final class TextFieldButtonDrag {
  static const Duration slide = Duration(milliseconds: 240);

  static final Rxn<TextFieldButton> dragged = Rxn();

  /// Where in the row it would land: before the button at this index of the saved row. Null when it wouldn't.
  static final RxnInt rowIndex = RxnInt();

  /// Over `+` or the menu
  static final RxBool overMenu = false.obs;

  /// Its landing place stays hidden while a flight carries it there
  static final RxBool flying = false.obs;

  /// The drop's commit, which lands in one frame instead of sliding
  static final RxBool snap = false.obs;

  /// The room made in the row, and the faded preview in the menu, for a flight to aim at
  static final GlobalKey rowSlot = GlobalKey();
  static final GlobalKey menuSlot = GlobalKey();

  /// Its row index when the drag started, or null when it came from the menu
  static int? _origin;

  static bool get fromRow => _origin != null;

  /// [child], sliding between sizes, except while [snapping] (the caller's read of [snap]): an AnimatedSize, however
  /// short, spends a frame at the old size, which flashes the landed button out
  static Widget slides(Widget child, {required bool snapping, Key? key, Alignment alignment = Alignment.center}) =>
      snapping
      ? KeyedSubtree(key: key, child: child)
      : AnimatedSize(key: key, duration: slide, curve: Curves.easeOutCubic, alignment: alignment, child: child);

  static void start(TextFieldButton b, {int? from}) {
    _origin = from;
    dragged.value = b;
    rowIndex.value = from;
    overMenu.value = false;
    flying.value = false;
  }

  static void enterRow(int index) {
    overMenu.value = false;
    rowIndex.value = index;
  }

  static void leaveRow(int index) {
    if (rowIndex.value == index) rowIndex.value = _origin;
  }

  static void enterMenu() {
    rowIndex.value = null;
    overMenu.value = true;
  }

  static void leaveMenu() {
    if (!overMenu.value) return;
    overMenu.value = false;
    rowIndex.value = _origin;
  }

  static void dropOnRow(BuildContext context, int index, Offset at) {
    final b = dragged.value;
    if (b == null) return;
    enterRow(index);
    _fly(context, b, at, toMenu: false, then: () => moveTextFieldButton(b, index));
  }

  static void dropOnMenu(BuildContext context, Offset at) {
    final b = dragged.value;
    if (b == null) return;
    if (!fromRow) return cancel(context, at);
    enterMenu();
    _fly(context, b, at, toMenu: true, then: () => removeTextFieldButton(b));
  }

  /// Released off every target: back where it came from
  static void cancel(BuildContext context, Offset at) {
    final b = dragged.value;
    if (b == null) return;
    overMenu.value = false;
    rowIndex.value = _origin;
    _fly(context, b, at, toMenu: !fromRow);
  }

  static void _fly(BuildContext context, TextFieldButton b, Offset at, {required bool toMenu, VoidCallback? then}) {
    // Taken before the landing place hides: the flight turns into exactly what it lands as, as the pins do
    Future<ui.Image>? tile;
    final boundary = toMenu ? menuSlot.currentContext?.findRenderObject() : null;
    // It may not have painted yet (dropped the instant the menu opened), which fails differently in debug (an assert)
    // and release (its missing layer), hence catching everything. Without a snapshot the flight draws the tile itself
    if (boundary is RenderRepaintBoundary && boundary.hasSize && !boundary.size.isEmpty) {
      try {
        tile = boundary.toImage(pixelRatio: View.of(context).devicePixelRatio);
      } catch (e, s) {
        Logger.warn(_snapshotFailed, error: e, trace: s, tag: _tag);
      }
    }
    flying.value = true;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    // The root overlay doesn't carry the conversation's theme, so the flight would land in a different color
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    late final OverlayEntry entry;
    var finished = false;
    // Runs once, when the flight lands or, failing that, when it's torn down, so the drag never stays stuck
    void finish() {
      if (finished) return;
      finished = true;
      if (entry.mounted) entry.remove();
      // One frame: the saved layout replaces the preview without sliding, right where the flight landed
      snap.value = true;
      then?.call();
      _end();
      WidgetsBinding.instance.addPostFrameCallback((_) => snap.value = false);
    }

    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: themes.wrap(
          _Flight(
            button: b,
            toMenu: toMenu,
            tile: tile,
            from: overlayBox.globalToLocal(at),
            overlayBox: overlayBox,
            onDone: finish,
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  static void _end() {
    _origin = null;
    dragged.value = null;
    rowIndex.value = null;
    overMenu.value = false;
    flying.value = false;
  }
}

/// A dropped button flying from where it was dropped to its landing place, as the row's icon or the menu's tile
class _Flight extends StatefulWidget {
  const _Flight({
    required this.button,
    required this.toMenu,
    required this.tile,
    required this.from,
    required this.overlayBox,
    required this.onDone,
  });

  final TextFieldButton button;
  final bool toMenu;

  /// The menu item it lands as
  final Future<ui.Image>? tile;
  final Offset from;
  final RenderBox overlayBox;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
  bool _landing = false;
  Offset? _lastTo;
  double? _slotWidth;

  RenderBox? get _slot {
    final box = (widget.toMenu ? TextFieldButtonDrag.menuSlot : TextFieldButtonDrag.rowSlot).currentContext
        ?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  // Followed every frame: the landing place can still be sliding open. Without one, it lands where it was dropped
  Offset get _to {
    final slot = _slot;
    if (slot != null) {
      _lastTo = widget.overlayBox.globalToLocal(slot.localToGlobal(slot.size.center(Offset.zero)));
      _slotWidth = slot.size.width;
    }
    return _lastTo ?? widget.from;
  }

  ui.Image? _tile;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.tile?.then(
      (image) => mounted ? setState(() => _tile = image) : image.dispose(),
      onError: (Object e, StackTrace s) => Logger.warn(_snapshotFailed, error: e, trace: s, tag: _tag),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _landing = true);
      await _move.forward();
      if (!mounted) return;
      _done = true;
      widget.onDone();
    });
  }

  @override
  void dispose() {
    // Torn down before landing: still finish the drag, after this frame since it changes other widgets' state
    if (!_done) Future.microtask(widget.onDone);
    _tile?.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.button;
    final icon = Icon(b.icon, size: 28, color: context.theme.colorScheme.outline, key: const ValueKey('icon'));
    final dpr = View.of(context).devicePixelRatio;
    final tile = _tile;
    final look = Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        // Landing in the menu, the tile grows out of the dragged icon's center
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: _landing && widget.toMenu
            ? KeyedSubtree(
                key: const ValueKey('menu'),
                child: tile != null
                    ? RawImage(image: tile, width: tile.width / dpr, height: tile.height / dpr)
                    : desktopMenuTileLook(context, b, width: _slotWidth),
              )
            : icon,
      ),
    );
    return AnimatedBuilder(
      animation: _move,
      builder: (context, child) {
        final at = Offset.lerp(widget.from, _to, Curves.easeOutCubic.transform(_move.value))!;
        return Stack(
          children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
            ),
          ],
        );
      },
      child: look,
    );
  }
}
