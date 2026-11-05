import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/media_collection.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_style.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_title.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_holder_reactions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// iOS fan stack for multi-attachment media collections.
class CollectionGroupStack extends StatefulWidget {
  const CollectionGroupStack({
    super.key,
    required this.messagePart,
    required this.cvController,
    required this.isEditing,
    this.infiniteScroll = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;
  final bool infiniteScroll;

  @override
  State<CollectionGroupStack> createState() => _CollectionGroupStackState();
}

class _CollectionGroupStackState extends State<CollectionGroupStack> with ThemeHelpers {
  static const int _visibleFanSlots = 5;
  static const int _maxPastCards = 3;
  static const double _swipeCommitThreshold = 70;
  static const double _maxDragDx = 140;
  static const double _maxWiggleDx = 20.0;

  /// Portrait card aspect (width:height = 3:4).
  static const double _portraitAspect = 3 / 4;

  static const _fanSlotDx = <double>[0, 7, 12, 16, 20];
  static const _fanSlotDy = <double>[0, 4, 9, 14, 20];
  static const _fanSlotAngle = <double>[0, 0.06, 0.13, 0.225, 0.32];
  static const _fanSlotScale = <double>[1.0, 0.9, 0.8, 0.7, 0.6];
  static const _pastSlotOpacity = <double>[0.80, 0.60, 0.40];

  static const double _scrollAdvanceThreshold = 50.0;

  int _currentIndex = 0;
  double _dragDx = 0;
  double _scrollAccumulator = 0;
  bool _hapticGivenForCurrentEnd = false;
  int? _activeDragPointer;
  Offset? _dragStartPosition;
  bool? _panHorizontal;
  VelocityTracker? _velocityTracker;

  List<Attachment> get _attachments => widget.messagePart.attachments;

  bool get _isFromMe => MessageStateScope.of(context).isFromMe.value;

  @override
  void initState() {
    super.initState();
    _setCurrentIndex(0);
  }

  @override
  void dispose() {
    _activeDragPointer = null;
    _dragStartPosition = null;
    _velocityTracker = null;
    _hapticGivenForCurrentEnd = false;
    widget.cvController.isCollectionDragging = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CollectionGroupStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKeys = oldWidget.messagePart.attachments.map((a) => a.guid ?? a.transferName).toList();
    final newKeys = widget.messagePart.attachments.map((a) => a.guid ?? a.transferName).toList();
    if (!listEquals(oldKeys, newKeys)) {
      _setCurrentIndex(0);
    } else if (_currentIndex >= widget.messagePart.attachments.length) {
      _setCurrentIndex(_currentIndex);
    }
  }

  void _setCurrentIndex(int index, {bool resetDrag = false}) {
    if (_attachments.isEmpty) return;
    int clamped;
    if (widget.infiniteScroll) {
      clamped = index % _attachments.length;
      if (clamped < 0) clamped += _attachments.length;
    } else {
      clamped = index.clamp(0, _attachments.length - 1);
    }
    if (clamped < 0) return;
    if (clamped == _currentIndex && !resetDrag) return;
    _currentIndex = clamped;
    if (resetDrag) _dragDx = 0;
  }

  void _advance(int direction) {
    if (_attachments.length <= 1) return;
    _setCurrentIndex(_currentIndex + direction);
  }

  void _jumpTo(int index) {
    if (_attachments.length <= 1) return;
    HapticFeedback.lightImpact();
    setState(() {
      _setCurrentIndex(index, resetDrag: true);
    });
  }

  /// Applies a horizontal drag delta to the fan, with end-of-stack wiggle + haptic when not infinite.
  void _dragBy(double dx) {
    if (!mounted) return;
    if (!widget.infiniteScroll) {
      // Left advances / right goes back for both sides.
      final blockedPositive = _currentIndex == 0;
      final blockedNegative = _currentIndex == _attachments.length - 1;

      final draggingIntoBlockedEnd = (blockedPositive && dx > 0) || (blockedNegative && dx < 0);
      if (draggingIntoBlockedEnd) {
        if (!_hapticGivenForCurrentEnd) {
          HapticFeedback.lightImpact();
          _hapticGivenForCurrentEnd = true;
        }
        setState(() {
          _dragDx += dx * 0.3;
          if (blockedPositive) _dragDx = _dragDx.clamp(0.0, _maxWiggleDx);
          if (blockedNegative) _dragDx = _dragDx.clamp(-_maxWiggleDx, 0.0);
        });
        return;
      } else {
        _hapticGivenForCurrentEnd = false;
      }
    }
    setState(() {
      _dragDx += dx;
      _dragDx = _dragDx.clamp(-_maxDragDx, _maxDragDx);
    });
  }

  /// Commits or springs back the fan drag at the end of a swipe.
  void _endDrag(double velocity) {
    if (!mounted) return;
    final bool commit = _dragDx.abs() >= _swipeCommitThreshold || velocity.abs() > 700;
    if (!commit) {
      setState(() {
        _dragDx = 0;
      });
      return;
    }

    // Negative drag (left) advances; positive (right) goes back — same for both sides.
    final rawSign = (_dragDx != 0 ? _dragDx : velocity) < 0 ? 1 : -1;
    setState(() {
      _advance(rawSign);
      _dragDx = 0;
    });
  }

  int _indexAtOffset(int offset) {
    var index = (_currentIndex + offset) % _attachments.length;
    if (index < 0) index += _attachments.length;
    return index;
  }

  double _computeBaseCardHeight(double baseCardWidth) {
    return (baseCardWidth / _portraitAspect).clamp(100.0, 500.0);
  }

  @override
  Widget build(BuildContext context) {
    final collection = MediaCollection.forPart(
      context,
      collectionPart: widget.messagePart,
      cvController: widget.cvController,
    );
    // Obx: the layout reads isFromMe (fan alignment, title side, download button side).
    return MediaCollectionScope(collection: collection, child: Obx(() => _buildStack(context, collection)));
  }

  Widget _buildStack(BuildContext context, MediaCollection collection) {
    // Calculated against screen width; maxStackWidth caps size on larger screens.
    final baseCardWidth = min(
      NavigationSvc.width(context) * CollectionStyle.cardWidthFactor,
      CollectionStyle.maxCardWidth,
    );
    final baseCardHeight = _computeBaseCardHeight(baseCardWidth);

    // Horizontal spread of fanned cards behind the front card; sizes the canvas.
    final double maxFanDx;
    if (widget.infiniteScroll) {
      maxFanDx = _fanSlotDx.last;
    } else {
      final layoutFuture = min(_attachments.length - 1, _visibleFanSlots - 1);
      maxFanDx = layoutFuture > 0 ? _fanSlotDx[layoutFuture] : 0.0;
    }
    // Left-anchor for both sides so from-me front card is inset from the end-aligned
    // canvas by maxFanDx (future fan stays on-canvas). Tapbacks may overhang the
    // author edge — no extra reaction gutter.
    final fanCanvasWidth = baseCardWidth + maxFanDx;
    final fanCanvasHeight = baseCardHeight;

    final stackChildren = <Widget>[];

    if (_attachments.length > 1 && (widget.infiniteScroll || _currentIndex < _attachments.length - 1)) {
      stackChildren.add(
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _advance(1);
                _dragDx = 0;
              });
            },
          ),
        ),
      );
    }

    if (widget.infiniteScroll) {
      stackChildren.addAll(List.generate(_attachments.length, (i) {
        final attachmentIndex = _indexAtOffset(i);
        return _buildFanCard(
          attachment: _attachments[attachmentIndex],
          attachmentIndex: attachmentIndex,
          slotIndex: i,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          isCurrent: i == 0,
        );
      }).reversed);
    } else {
      final futureCount = _attachments.length - _currentIndex - 1;
      final pastCount = _currentIndex;
      final visiblePast = min(pastCount, _maxPastCards);
      final visibleFuture = min(futureCount, _visibleFanSlots - 1);

      for (int p = visiblePast; p >= 1; p--) {
        final attachmentIndex = _currentIndex - p;
        stackChildren.add(_buildPastCard(
          attachment: _attachments[attachmentIndex],
          attachmentIndex: attachmentIndex,
          slotIndex: p.clamp(1, _visibleFanSlots - 1),
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
        ));
      }

      for (int f = visibleFuture; f >= 1; f--) {
        final attachmentIndex = _currentIndex + f;
        stackChildren.add(_buildFanCard(
          attachment: _attachments[attachmentIndex],
          attachmentIndex: attachmentIndex,
          slotIndex: f,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          isCurrent: false,
        ));
      }

      stackChildren.add(_buildFanCard(
        attachment: _attachments[_currentIndex],
        attachmentIndex: _currentIndex,
        slotIndex: 0,
        baseCardWidth: baseCardWidth,
        baseCardHeight: baseCardHeight,
        isCurrent: true,
      ));
    }

    // Listener wraps only the card canvas so pointer-down on the label does not
    // set isCollectionDragging or claim the horizontal swipe for fan navigation.
    final fanBody = CollectionDownloadButton.wrap(
      isFromMe: _isFromMe,
      contentWidth: fanCanvasWidth,
      contentHeight: fanCanvasHeight,
      attachments: _attachments,
      child: Listener(
            // Raw pointer tracking (instead of GestureDetector.onHorizontalDragUpdate/End) so this
            // swipe never has to win a gesture-arena contest against a card's own recognizers — e.g.
            // VideoPlayer registers onTap/onDoubleTap on the current card, and a DoubleTapGestureRecognizer
            // holding the arena open was swallowing fast horizontal swipes over video attachments while
            // images (which register no onDoubleTap) were unaffected. Listener never enters the arena, so
            // it always sees the drag regardless of what the card underneath does with the same pointer.
            behavior: HitTestBehavior.translucent,
            onPointerSignal: (event) {
              if (event is PointerScrollEvent && _attachments.length > 1) {
                GestureBinding.instance.pointerSignalResolver.register(event, (event) {
                  if (!mounted) return;
                  final scrollEvent = event as PointerScrollEvent;
                  final delta = scrollEvent.scrollDelta;
                  _scrollAccumulator += delta.dx.abs() > delta.dy.abs() ? delta.dx : delta.dy;
                  if (_scrollAccumulator.abs() >= _scrollAdvanceThreshold) {
                    final scrollDir = _scrollAccumulator > 0 ? 1 : -1;
                    _scrollAccumulator = 0;
                    final oldIndex = _currentIndex;
                    setState(() {
                      _advance(scrollDir);
                      _dragDx = 0;
                    });
                    if (_currentIndex == oldIndex && !widget.infiniteScroll) {
                      HapticFeedback.lightImpact();
                    }
                  }
                });
              }
            },
            onPointerDown: (event) {
              if (_attachments.length <= 1) return;
              _activeDragPointer = event.pointer;
              _dragStartPosition = event.position;
              _velocityTracker = VelocityTracker.withKind(event.kind);
              _velocityTracker!.addPosition(event.timeStamp, event.position);
              // Claim the drag so the list-wide timestamp-reveal swipe (a distinct
              // GestureDetector ancestor in MessagesView) doesn't also react to the
              // same pointer — see conversation_view_controller.dart's field doc.
              widget.cvController.isCollectionDragging = true;
            },
            onPointerMove: (event) {
              if (_attachments.length <= 1 || _activeDragPointer != event.pointer) return;
              // Bail out of fan drag when the pointer is clearly vertical so the
              // conversation list can scroll and isCollectionDragging does not stick.
              final start = _dragStartPosition;
              if (start != null) {
                final total = event.position - start;
                if (total.dy.abs() >= total.dx.abs() && total.distance >= 8.0) {
                  _activeDragPointer = null;
                  _dragStartPosition = null;
                  _velocityTracker = null;
                  _hapticGivenForCurrentEnd = false;
                  widget.cvController.isCollectionDragging = false;
                  if (mounted && _dragDx != 0) {
                    setState(() {
                      _dragDx = 0;
                    });
                  }
                  return;
                }
              }
              _velocityTracker?.addPosition(event.timeStamp, event.position);
              _dragBy(event.delta.dx);
            },
            onPointerUp: (event) {
              if (_activeDragPointer != event.pointer) return;
              _activeDragPointer = null;
              _dragStartPosition = null;
              _hapticGivenForCurrentEnd = false;
              widget.cvController.isCollectionDragging = false;
              final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
              _velocityTracker = null;
              if (_attachments.length <= 1) return;
              _endDrag(velocity);
            },
            onPointerCancel: (event) {
              if (_activeDragPointer != event.pointer) return;
              _activeDragPointer = null;
              _dragStartPosition = null;
              _velocityTracker = null;
              _hapticGivenForCurrentEnd = false;
              widget.cvController.isCollectionDragging = false;
              if (_attachments.length <= 1) return;
              if (mounted) {
                setState(() {
                  _dragDx = 0;
                });
              }
            },
            // Two-finger trackpad swipes (Windows/Linux). Same horizontal commit as touch so vertical
            // swipes keep scrolling the chat.
            onPointerPanZoomStart: (event) {
              if (_attachments.length <= 1) return;
              _panHorizontal = null;
              _velocityTracker = VelocityTracker.withKind(PointerDeviceKind.trackpad);
            },
            onPointerPanZoomUpdate: (event) {
              if (_attachments.length <= 1 || _velocityTracker == null) return;
              _velocityTracker!.addPosition(event.timeStamp, event.pan);
              if (_panHorizontal == null) {
                if (event.pan.distance < kTouchSlop) return;
                _panHorizontal = event.pan.dx.abs() > event.pan.dy.abs();
              }
              if (_panHorizontal!) _dragBy(event.panDelta.dx);
            },
            onPointerPanZoomEnd: (event) {
              final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
              _velocityTracker = null;
              _hapticGivenForCurrentEnd = false;
              if (_attachments.length <= 1 || _panHorizontal != true) return;
              _panHorizontal = null;
              _endDrag(velocity);
            },
            child: SizedBox(
              width: fanCanvasWidth,
              height: fanCanvasHeight,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: stackChildren,
              ),
            ),
          ),
    );

    // Title is iOS chrome only (same as grid). Material/Samsung forced stack stays cards-only.
    return CollectionTitledLayout(
      collection: collection,
      isFromMe: _isFromMe,
      // From-me: reserve room for per-card tapbacks (top: -14) so they don't cover
      // the end-aligned label. From-other: tapbacks sit on the trailing edge, away
      // from the start-aligned label — no reservation (avoids a large title gap).
      // Empty messageParts: only this collection's own tapbacks count, never whole-message reactions.
      spacing: _isFromMe
          ? ReactionSpacing(
              messageParts: const [],
              part: widget.messagePart,
              minHeightWhenNoReactions: 4,
            )
          : const SizedBox(height: 4),
      child: fanBody,
    );
  }

  Widget _buildCardContent({
    required Attachment attachment,
    required int attachmentIndex,
    required bool isCurrent,
    required bool ignorePointer,
  }) {
    return CollectionAttachmentCard(
      attachment: attachment,
      attachmentIndex: attachmentIndex,
      messagePart: widget.messagePart,
      ignorePointer: ignorePointer,
      cvController: widget.cvController,
      isEditing: widget.isEditing,
      enableGestures: isCurrent,
      reactionTailType: ReactionTailType.inside,
    );
  }

  Widget _buildFanCard({
    required Attachment attachment,
    required int attachmentIndex,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
    required bool isCurrent,
  }) {
    final slot = slotIndex < _visibleFanSlots ? slotIndex : (_visibleFanSlots - 1);
    final overflowDepth =
        slotIndex >= _visibleFanSlots ? ((slotIndex - (_visibleFanSlots - 1)).clamp(0, 6) * 0.7) : 0.0;
    // One-sided fan: left grows with slot, positive angle, pivot bottom-left.
    final angle = slot == 0 ? 0.0 : _fanSlotAngle[slot];
    final dy = _fanSlotDy[slot] + overflowDepth;
    final scale = _fanSlotScale[slot];
    final cardWidth = baseCardWidth * scale;
    final cardHeight = baseCardHeight * scale;
    // Scale-center so smaller cards don't poke out past the fan spread.
    final slotDx = slot < _fanSlotDx.length ? _fanSlotDx[slot] : _fanSlotDx.last;
    final fromLeft = slotDx + ((baseCardWidth - cardWidth) / 2);
    final dragOffset = isCurrent ? _dragDx : 0.0;
    final dragRotate = isCurrent ? (_dragDx / 700) : 0.0;

    final card = _buildCardContent(
      attachment: attachment,
      attachmentIndex: attachmentIndex,
      isCurrent: isCurrent,
      ignorePointer: !isCurrent,
    );

    return AnimatedPositioned(
      key: ValueKey(attachment.guid ?? attachment.id ?? '${attachment.transferName}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 1 + dy,
      left: fromLeft + dragOffset,
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Transform.rotate(
          angle: angle.toDouble() + dragRotate,
          alignment: Alignment.bottomLeft,
          child: isCurrent
              ? card
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jumpTo(attachmentIndex),
                  child: card,
                ),
        ),
      ),
    );
  }

  Widget _buildPastCard({
    required Attachment attachment,
    required int attachmentIndex,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
  }) {
    // Mirror of the one-sided fan (negative dx/angle, opposite pivot); opacity only is past-specific.
    final slot = slotIndex.clamp(1, _visibleFanSlots - 1);
    final angle = -_fanSlotAngle[slot];
    final scale = _fanSlotScale[slot];
    final dy = _fanSlotDy[slot];
    final opacity = _pastSlotOpacity[(slot - 1).clamp(0, _pastSlotOpacity.length - 1)];
    final cardWidth = baseCardWidth * scale;
    final cardHeight = baseCardHeight * scale;
    final slotDx = _fanSlotDx[slot];
    final fromLeft = -slotDx + ((baseCardWidth - cardWidth) / 2);

    return AnimatedPositioned(
      key: ValueKey(attachment.guid ?? attachment.id ?? '${attachment.transferName}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 1 + dy,
      left: fromLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: opacity,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Transform.rotate(
            angle: angle.toDouble(),
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _jumpTo(attachmentIndex),
              child: _buildCardContent(
                attachment: attachment,
                attachmentIndex: attachmentIndex,
                isCurrent: false,
                ignorePointer: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
