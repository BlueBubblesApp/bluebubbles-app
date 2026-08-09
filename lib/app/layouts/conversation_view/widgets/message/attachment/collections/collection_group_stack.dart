import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
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
  static const double _maxStackSizeFactor = 0.42;
  static const double _maxStackWidth = 220.0;

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
  VelocityTracker? _velocityTracker;

  List<Attachment> get _attachments => widget.messagePart.attachments;

  bool get _isFromMe => MessageStateScope.messageOf(context).isFromMe == true;

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
    widget.cvController.isGalleryDragging = false;
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

  int _indexAtOffset(int offset) {
    var index = (_currentIndex + offset) % _attachments.length;
    if (index < 0) index += _attachments.length;
    return index;
  }

  double _computeBaseCardHeight(double baseCardWidth) {
    return (baseCardWidth / _portraitAspect).clamp(100.0, 500.0);
  }

  CollectionMediaController _collectionController(BuildContext context) {
    return CollectionMediaController(
      chat: widget.cvController.chat,
      media: _attachments,
      messageState: MessageStateScope.of(context),
      collectionPart: widget.messagePart,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculated against screen width; maxStackWidth caps size on larger screens.
    final baseCardWidth = min(
      NavigationSvc.width(context) * _maxStackSizeFactor,
      _maxStackWidth,
    );
    final baseCardHeight = _computeBaseCardHeight(baseCardWidth);
    final collectionController = _collectionController(context);

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
          collectionController: collectionController,
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
          collectionController: collectionController,
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
          collectionController: collectionController,
          slotIndex: f,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          isCurrent: false,
        ));
      }

      stackChildren.add(_buildFanCard(
        attachment: _attachments[_currentIndex],
        attachmentIndex: _currentIndex,
        collectionController: collectionController,
        slotIndex: 0,
        baseCardWidth: baseCardWidth,
        baseCardHeight: baseCardHeight,
        isCurrent: true,
      ));
    }

    // Listener wraps only the card canvas so pointer-down on the label does not
    // set isGalleryDragging or claim the horizontal swipe for fan navigation.
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
                  _scrollAccumulator += scrollEvent.scrollDelta.dy;
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
              widget.cvController.isGalleryDragging = true;
            },
            onPointerMove: (event) {
              if (_attachments.length <= 1 || _activeDragPointer != event.pointer) return;
              // Bail out of fan drag when the pointer is clearly vertical so the
              // conversation list can scroll and isGalleryDragging does not stick.
              final start = _dragStartPosition;
              if (start != null) {
                final total = event.position - start;
                if (total.dy.abs() >= total.dx.abs() && total.distance >= 8.0) {
                  _activeDragPointer = null;
                  _dragStartPosition = null;
                  _velocityTracker = null;
                  _hapticGivenForCurrentEnd = false;
                  widget.cvController.isGalleryDragging = false;
                  if (mounted && _dragDx != 0) {
                    setState(() {
                      _dragDx = 0;
                    });
                  }
                  return;
                }
              }
              _velocityTracker?.addPosition(event.timeStamp, event.position);
              if (!widget.infiniteScroll) {
                // Left advances / right goes back for both sides.
                final atStart = _currentIndex == 0;
                final atEnd = _currentIndex == _attachments.length - 1;
                final blockedPositive = atStart;
                final blockedNegative = atEnd;

                final draggingIntoBlockedEnd =
                    (blockedPositive && event.delta.dx > 0) || (blockedNegative && event.delta.dx < 0);
                if (draggingIntoBlockedEnd) {
                  if (!_hapticGivenForCurrentEnd) {
                    HapticFeedback.lightImpact();
                    _hapticGivenForCurrentEnd = true;
                  }
                  if (mounted) {
                    setState(() {
                      _dragDx += event.delta.dx * 0.3;
                      if (blockedPositive) _dragDx = _dragDx.clamp(0.0, _maxWiggleDx);
                      if (blockedNegative) _dragDx = _dragDx.clamp(-_maxWiggleDx, 0.0);
                    });
                  }
                  return;
                } else {
                  _hapticGivenForCurrentEnd = false;
                }
              }
              if (mounted) {
                setState(() {
                  _dragDx += event.delta.dx;
                  _dragDx = _dragDx.clamp(-_maxDragDx, _maxDragDx);
                });
              }
            },
            onPointerUp: (event) {
              if (_activeDragPointer != event.pointer) return;
              _activeDragPointer = null;
              _dragStartPosition = null;
              _hapticGivenForCurrentEnd = false;
              widget.cvController.isGalleryDragging = false;
              final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
              _velocityTracker = null;
              if (_attachments.length <= 1) return;
              final bool commit = _dragDx.abs() >= _swipeCommitThreshold || velocity.abs() > 700;
              if (!commit) {
                if (mounted) {
                  setState(() {
                    _dragDx = 0;
                  });
                }
                return;
              }

              // Negative drag (left) advances; positive (right) goes back — same for both sides.
              final rawSign = (_dragDx != 0 ? _dragDx : velocity) < 0 ? 1 : -1;
              if (mounted) {
                setState(() {
                  _advance(rawSign);
                  _dragDx = 0;
                });
              }
            },
            onPointerCancel: (event) {
              if (_activeDragPointer != event.pointer) return;
              _activeDragPointer = null;
              _dragStartPosition = null;
              _velocityTracker = null;
              _hapticGivenForCurrentEnd = false;
              widget.cvController.isGalleryDragging = false;
              if (_attachments.length <= 1) return;
              if (mounted) {
                setState(() {
                  _dragDx = 0;
                });
              }
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
    if (SettingsSvc.settings.skin.value != Skins.iOS) return fanBody;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CollectionTitle(
          label: collectionController.title,
          onTap: () => collectionController.openGallery(context),
        ),
        // From-me: reserve room for per-card tapbacks (top: -14) so they don't cover
        // the end-aligned label. From-other: tapbacks sit on the trailing edge, away
        // from the start-aligned label — no reservation (avoids a large title gap).
        // Empty messageParts: key off reactionsForPart only (not whole-message reactions).
        if (_isFromMe)
          ReactionSpacing(
            messageParts: const [],
            part: widget.messagePart,
            reactionsForPart: (part, reactions) =>
                reactions.where((s) => part.coversPartId(s.associatedMessagePart ?? 0)),
            minHeightWhenNoReactions: 4,
          )
        else
          const SizedBox(height: 4),
        fanBody,
      ],
    );
  }

  Widget _buildCardContent({
    required Attachment attachment,
    required int attachmentIndex,
    required bool isCurrent,
    required bool ignorePointer,
    required CollectionMediaController collectionController,
  }) {
    return CollectionAttachmentCard(
      attachment: attachment,
      attachmentIndex: attachmentIndex,
      messagePart: widget.messagePart,
      collectionController: collectionController,
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
    required CollectionMediaController collectionController,
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
      collectionController: collectionController,
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
    required CollectionMediaController collectionController,
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
                collectionController: collectionController,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
