import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/chat_drag_feedback.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

/// A dropped chat flying from [from] to where it lands, as a pin among the pins or turning into a tile for the list.
/// On landing it is swapped for its own tile in one frame; there is no fade. Without the landing place in view it
/// changes where it was dropped.
class DropFlight extends StatefulWidget {
  const DropFlight({
    super.key,
    required this.drag,
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

  final PinDragController drag;

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

  /// Flies [guid] from [position] to its slot among the pins ([toPin]) or to the room [drag]'s list made for it.
  /// [rowKey] lands it on that row instead.
  static void show(
    BuildContext context,
    PinDragController drag,
    String guid,
    Offset position, {
    required bool toPin,
    GlobalKey? rowKey,
  }) {
    final chat = ChatsSvc.findChatByGuid(guid);
    if (chat == null) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    RenderBox? slotBox() =>
        (rowKey?.currentContext ?? drag.slotContext(pin: toPin))?.findRenderObject() as RenderBox?;
    final slot = slotBox();
    final hasSlot = slot != null && slot.attached && slot.hasSize;
    final boundary = toPin ? null : (rowKey ?? drag.unpinRowBoundary).currentContext?.findRenderObject();
    final row = boundary is RenderRepaintBoundary && boundary.hasSize && !boundary.size.isEmpty
        ? boundary.toImage(pixelRatio: View.of(context).devicePixelRatio)
        : null;
    final landed = Completer<void>();
    drag.startFlight(guid, landed.future);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: DropFlight(
          drag: drag,
          chat: chat,
          toPin: toPin,
          from: overlayBox.globalToLocal(position),
          overlayBox: overlayBox,
          slot: slotBox,
          width: hasSlot ? slot.size.width : null,
          row: row,
          landed: landed,
          onDone: () {
            drag.endFlight(guid);
            if (!landed.isCompleted) landed.complete();
            entry.remove();
          },
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<DropFlight> createState() => _DropFlightState();
}

class _DropFlightState extends State<DropFlight> with TickerProviderStateMixin {
  final RxBool _asPin = true.obs;
  final Rxn<ui.Image> _row = Rxn<ui.Image>();
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  Offset? _lastTo;

  Offset get _to {
    final slot = widget.slot();
    if (slot != null && slot.attached && slot.hasSize) {
      _lastTo = widget.overlayBox.globalToLocal(slot.localToGlobal(slot.size.center(Offset.zero)));
    }
    return _lastTo ?? widget.from;
  }

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
      return ChatDragFeedback(
        drag: widget.drag,
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
