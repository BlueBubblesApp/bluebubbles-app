
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A library sticker being dragged onto a message ([StickerDropTarget]), with the scale and rotation a second finger
/// has given it on the way.
class StickerDrag {
  StickerDrag(this.sticker);

  final LibrarySticker sticker;
  final ValueNotifier<({double scale, double rotation})> transform = ValueNotifier((scale: 1, rotation: 0));
}

/// One sticker from the Mac's library, drawn from the on-disk thumbnail cache ([StickerLibrarySvc]), with a
/// placeholder until it's there. Right-click, or on mobile a long press released without moving, offers to remove it
/// ([AttachmentActions.confirmRemoveSticker]) where that's possible.
class StickerLibraryTile extends StatefulWidget {
  const StickerLibraryTile({
    super.key,
    required this.sticker,
    this.onTap,
    this.draggable = false,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final LibrarySticker sticker;
  final VoidCallback? onTap;

  /// Lets it be dragged onto a message ([StickerDropTarget]), centered on the pointer: at once with a mouse, and after
  /// a long press on mobile, where a second finger scales and rotates it.
  final bool draggable;
  final DragUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;

  /// The dragged sticker's size, about as large as one placed at scale 1
  static const double dragSize = 96;

  @override
  State<StickerLibraryTile> createState() => _StickerLibraryTileState();
}

class _StickerLibraryTileState extends State<StickerLibraryTile> {
  late StickerDrag _drag = StickerDrag(sticker);

  /// How far the current drag has gone, to tell a long press released in place (remove) from a drag
  double _dragDistance = 0;

  // The two fingers of a pinch during a mobile drag: the one dragging, and the one that came down after it
  int? _dragPointer;
  Offset _dragPosition = Offset.zero;
  int? _pinchPointer;
  Offset _pinchPosition = Offset.zero;

  /// The pinch's start: the fingers' distance and angle, and the sticker's transform then
  ({double distance, double angle, double scale, double rotation})? _pinchStart;

  LibrarySticker get sticker => widget.sticker;

  @override
  void didUpdateWidget(StickerLibraryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker.identifier != sticker.identifier) _drag = StickerDrag(sticker);
  }

  @override
  void dispose() {
    _stopPinching();
    super.dispose();
  }

  bool _pinching = false;

  void _startPinching() {
    if (_pinching) return;
    _pinching = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _stopPinching() {
    if (_pinching) GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _pinching = false;
    _pinchPointer = null;
    _pinchStart = null;
  }

  // No larger than placed stickers draw, so it lands as it looked, on every device
  void _setTransform(double scale, double rotation) => _drag.transform.value =
      (scale: scale.clamp(0.4, StickerHolder.maxPoints / StickerLibraryTile.dragSize), rotation: rotation);

  // Sees every pointer on screen while dragging, so a second finger anywhere can pinch the sticker
  void _onPointer(PointerEvent event) {
    final t = _drag.transform.value;
    if (event.pointer == _dragPointer) {
      if (event is PointerMoveEvent) _dragPosition = event.position;
    } else if (event is PointerDownEvent && _pinchPointer == null) {
      _pinchPointer = event.pointer;
      _pinchPosition = event.position;
      final span = _pinchPosition - _dragPosition;
      _pinchStart = (distance: span.distance, angle: span.direction, scale: t.scale, rotation: t.rotation);
    } else if (event.pointer == _pinchPointer) {
      if (event is PointerMoveEvent) {
        _pinchPosition = event.position;
      } else if (event is PointerUpEvent || event is PointerCancelEvent) {
        _pinchPointer = null;
        _pinchStart = null;
        return;
      }
    } else {
      return;
    }
    final start = _pinchStart;
    if (start == null || start.distance < 1) return;
    final span = _pinchPosition - _dragPosition;
    _setTransform(start.scale * span.distance / start.distance, start.rotation + span.direction - start.angle);
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile(context);
    if (!widget.draggable) return tile;
    final feedback = FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: ValueListenableBuilder(
        valueListenable: _drag.transform,
        builder: (_, t, child) => Transform.rotate(
          angle: t.rotation,
          child: Transform.scale(scale: t.scale, child: child),
        ),
        child: Image.file(
          StickerLibrarySvc.thumbnailFile(sticker.identifier),
          width: StickerLibraryTile.dragSize,
          height: StickerLibraryTile.dragSize,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.square(dimension: StickerLibraryTile.dragSize),
        ),
      ),
    );
    void onStarted() {
      _dragDistance = 0;
      _drag.transform.value = (scale: 1, rotation: 0);
    }

    void onUpdate(DragUpdateDetails details) {
      _dragDistance += details.delta.distance;
      _dragPosition = details.globalPosition;
      widget.onDragUpdate?.call(details);
    }

    if (kIsDesktop) {
      return Draggable<StickerDrag>(
        data: _drag,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: onStarted,
        onDragUpdate: onUpdate,
        onDragEnd: (_) => widget.onDragEnd?.call(),
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.4, child: tile),
        child: tile,
      );
    }
    return Listener(
      onPointerDown: (event) {
        _dragPointer = event.pointer;
        _dragPosition = event.position;
      },
      child: LongPressDraggable<StickerDrag>(
        data: _drag,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () {
          onStarted();
          _startPinching();
        },
        onDragUpdate: onUpdate,
        onDragEnd: (_) {
          _stopPinching();
          widget.onDragEnd?.call();
        },
        onDraggableCanceled: (_, _) {
          final t = _drag.transform.value;
          final untouched = _dragDistance < 12 && t.scale == 1 && t.rotation == 0;
          if (untouched && AttachmentActions.canRemoveFromLibrary && mounted) {
            AttachmentActions.confirmRemoveSticker(context, sticker);
          }
        },
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.4, child: tile),
        child: tile,
      ),
    );
  }

  Widget _tile(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final placeholder = Center(
      child: Icon(Icons.sticky_note_2_outlined, size: 28, color: scheme.outline.withValues(alpha: 0.4)),
    );
    return Semantics(
      button: widget.onTap != null,
      label: sticker.label ?? "Sticker",
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          // A draggable tile's long press starts the drag, and offers removal when released in place
          onLongPress: AttachmentActions.canRemoveFromLibrary && !kIsDesktop && !widget.draggable
              ? () => AttachmentActions.confirmRemoveSticker(context, sticker)
              : null,
          onSecondaryTap: AttachmentActions.canRemoveFromLibrary
              ? () => AttachmentActions.confirmRemoveSticker(context, sticker)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Obx(
              () => StickerLibrarySvc.cachedThumbnails.contains(sticker.identifier)
                  ? Image.file(
                      StickerLibrarySvc.thumbnailFile(sticker.identifier),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => placeholder,
                    )
                  : placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

class StickerAddTile extends StatelessWidget {
  const StickerAddTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Semantics(
      button: true,
      label: "Add a sticker from this device",
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
          ),
          child: Obx(() {
            final adding = StickerLibrarySvc.adding.value;
            return InkWell(
              onTap: adding ? null : AttachmentActions.pickAndAddSticker,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  adding
                      ? CupertinoActivityIndicator(color: scheme.onPrimary)
                      : Icon(Icons.add_photo_alternate_rounded, color: scheme.onPrimary, size: 30),
                  const SizedBox(height: 6),
                  Text("Add", style: context.theme.textTheme.labelLarge!.copyWith(color: scheme.onPrimary)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
