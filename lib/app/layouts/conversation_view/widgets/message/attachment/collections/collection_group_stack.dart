import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_layout_metrics.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_holder_reactions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollectionGroupStack extends StatefulWidget {
  const CollectionGroupStack({
    super.key,
    required this.messagePart,
    required this.cvController,
    this.isEditing = false,
    this.infiniteScroll = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;
  final bool infiniteScroll;

  List<Attachment> get attachments => messagePart.attachments;

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
  bool _labelHovered = false;
  int? _activeDragPointer;
  Offset? _dragStartPosition;
  VelocityTracker? _velocityTracker;

  List<Attachment> get _attachments => widget.attachments;

  @override
  void dispose() {
    _activeDragPointer = null;
    _dragStartPosition = null;
    _velocityTracker = null;
    _hapticGivenForCurrentEnd = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CollectionGroupStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKeys = oldWidget.attachments.map((a) => a.guid ?? a.transferName).toList();
    final newKeys = widget.attachments.map((a) => a.guid ?? a.transferName).toList();
    if (!listEquals(oldKeys, newKeys)) {
      _currentIndex = 0;
    }
  }

  void _advance(int direction) {
    if (_attachments.length <= 1) return;
    if (widget.infiniteScroll) {
      _currentIndex = (_currentIndex + direction) % _attachments.length;
      if (_currentIndex < 0) _currentIndex += _attachments.length;
    } else {
      _currentIndex = (_currentIndex + direction).clamp(0, _attachments.length - 1);
    }
  }

  void _jumpTo(int index) {
    if (_attachments.length <= 1) return;
    final next = widget.infiniteScroll
        ? index % _attachments.length
        : index.clamp(0, _attachments.length - 1);
    if (next == _currentIndex) return;
    _currentIndex = next;
  }

  double _computeBaseCardHeight(double baseCardWidth) {
    return (baseCardWidth / _portraitAspect).clamp(100.0, 500.0);
  }

  void _openCollectionGrid(BuildContext context, String title) {
    _collectionController(context).openGrid(context, title: title);
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
    final baseCardWidth = collectionCardWidth(context);
    final baseCardHeight = _computeBaseCardHeight(baseCardWidth);
    final collectionController = _collectionController(context);

    final isFromMe = MessageStateScope.of(context).isFromMe.value;
    final stackLabel = collectionController.title;

    // Stable fan room for this collection (not remaining future at the current index).
    final double maxFanDx;
    if (widget.infiniteScroll) {
      maxFanDx = _fanSlotDx.last;
    } else {
      final layoutFuture = min(_attachments.length - 1, _visibleFanSlots - 1);
      maxFanDx = layoutFuture > 0 ? _fanSlotDx[layoutFuture] : 0.0;
    }
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
              if (mounted) {
                setState(() {
                  _advance(1);
                  _dragDx = 0;
                });
              }
            },
          ),
        ),
      );
    }

    if (widget.infiniteScroll) {
      stackChildren.addAll(List.generate(_attachments.length, (i) {
        final attachmentIndex = (_currentIndex + i) % _attachments.length;
        return _buildFanCard(
          attachmentIndex: attachmentIndex,
          attachment: _attachments[attachmentIndex],
          messageState: MessageStateScope.of(context),
          collectionController: collectionController,
          slotIndex: i,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          isCurrent: i == 0,
        );
      }).reversed);
    } else {
      final pastCount = _currentIndex;
      final visiblePast = min(pastCount, _maxPastCards);
      final futureCount = _attachments.length - _currentIndex - 1;
      final visibleFuture = min(futureCount, _visibleFanSlots - 1);

      for (int p = visiblePast; p >= 1; p--) {
        final attachmentIndex = _currentIndex - p;
        stackChildren.add(_buildPastCard(
          attachmentIndex: attachmentIndex,
          attachment: _attachments[attachmentIndex],
          messageState: MessageStateScope.of(context),
          collectionController: collectionController,
          slotIndex: p.clamp(1, _visibleFanSlots - 1),
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
        ));
      }

      for (int f = visibleFuture; f >= 1; f--) {
        final attachmentIndex = _currentIndex + f;
        stackChildren.add(_buildFanCard(
          attachmentIndex: attachmentIndex,
          attachment: _attachments[attachmentIndex],
          messageState: MessageStateScope.of(context),
          collectionController: collectionController,
          slotIndex: f,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          isCurrent: false,
        ));
      }

      stackChildren.add(_buildFanCard(
        attachmentIndex: _currentIndex,
        attachment: _attachments[_currentIndex],
        messageState: MessageStateScope.of(context),
        collectionController: collectionController,
        slotIndex: 0,
        baseCardWidth: baseCardWidth,
        baseCardHeight: baseCardHeight,
        isCurrent: true,
      ));
    }

    final stackColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: kIsDesktop ? (_) => setState(() => _labelHovered = true) : null,
          onExit: kIsDesktop ? (_) => setState(() => _labelHovered = false) : null,
          child: GestureDetector(
            onTap: () => _openCollectionGrid(context, stackLabel),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -6,
                  right: -6,
                  top: -2,
                  bottom: -2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _labelHovered
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      stackLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Empty messageParts: key off reactionsForPart only (not whole-message reactions).
        // minHeight reserves room for per-card tapbacks (top: -14) above the label.
        ReactionSpacing(
          messageParts: const [],
          part: widget.messagePart,
          reactionsForPart: (part, reactions) =>
              reactions.where((s) => part.includesAssociatedPart(s.associatedMessagePart)),
          minHeightWhenNoReactions: 4,
        ),
        SizedBox(
          width: fanCanvasWidth,
          height: fanCanvasHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: stackChildren,
          ),
        ),
      ],
    );

    final stackBody = CollectionDownloadButton.wrap(
      isFromMe: isFromMe,
      contentWidth: fanCanvasWidth,
      attachments: _attachments,
      child: stackColumn,
    );

    // Fan motion uses Listener (never enters the gesture arena) so it isn't
    // swallowed by card recognizers (e.g. VideoPlayer onDoubleTap). RawGestureDetector
    // + [_EagerHorizontalDragRecognizer] still claims clear horizontal drags so
    // MessagesView's timestamp swipe doesn't win instead. Vertical motion is ignored
    // so conversation list scroll wins.
    final listener = Listener(
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
      },
      onPointerMove: (event) {
        if (_attachments.length <= 1 || _activeDragPointer != event.pointer) return;
        final start = _dragStartPosition;
        if (start != null) {
          final total = event.position - start;
          if (total.dy.abs() >= total.dx.abs() && total.distance >= 8.0) {
            _activeDragPointer = null;
            _dragStartPosition = null;
            _velocityTracker = null;
            _hapticGivenForCurrentEnd = false;
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

        // Left drag / velocity → forward; right → back (same for sent and received).
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
        if (_attachments.length <= 1) return;
        if (mounted) {
          setState(() {
            _dragDx = 0;
          });
        }
      },
      child: stackBody,
    );

    if (_attachments.length <= 1) return listener;

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _EagerHorizontalDragRecognizer: GestureRecognizerFactoryWithHandlers<_EagerHorizontalDragRecognizer>(
          () => _EagerHorizontalDragRecognizer(debugOwner: this),
          (_EagerHorizontalDragRecognizer instance) {
            // Non-null callbacks register the recognizer; fan motion stays on Listener.
            instance
              ..onStart = (_) {}
              ..onUpdate = (_) {}
              ..onEnd = (_) {}
              ..onCancel = () {};
          },
        ),
      },
      child: listener,
    );
  }

  Widget _buildFanCard({
    required int attachmentIndex,
    required Attachment attachment,
    required MessageState messageState,
    required CollectionMediaController collectionController,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
    required bool isCurrent,
  }) {
    final slot = slotIndex < _visibleFanSlots ? slotIndex : (_visibleFanSlots - 1);
    final overflowDepth =
        slotIndex >= _visibleFanSlots ? ((slotIndex - (_visibleFanSlots - 1)).clamp(0, 6) * 0.7) : 0.0;
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

    final card = CollectionAttachmentCard(
      controller: messageState,
      cvController: widget.cvController,
      collectionPart: widget.messagePart,
      attachmentIndex: attachmentIndex,
      collectionAttachments: _attachments,
      collectionController: collectionController,
      isEditing: widget.isEditing,
      enableGestures: isCurrent,
      frameMode: AttachmentFrameMode.fixedCard,
      reactionTailType: ReactionTailType.inside,
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (mounted) {
                      setState(() {
                        _jumpTo(attachmentIndex);
                        _dragDx = 0;
                      });
                    }
                  },
                  child: card,
                ),
        ),
      ),
    );
  }

  Widget _buildPastCard({
    required int attachmentIndex,
    required Attachment attachment,
    required MessageState messageState,
    required CollectionMediaController collectionController,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
  }) {
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
              onTap: () {
                HapticFeedback.lightImpact();
                if (mounted) {
                  setState(() {
                    _jumpTo(attachmentIndex);
                    _dragDx = 0;
                  });
                }
              },
              child: CollectionAttachmentCard(
                controller: messageState,
                cvController: widget.cvController,
                collectionPart: widget.messagePart,
                attachmentIndex: attachmentIndex,
                collectionAttachments: _attachments,
                collectionController: collectionController,
                isEditing: widget.isEditing,
                enableGestures: false,
                frameMode: AttachmentFrameMode.fixedCard,
                reactionTailType: ReactionTailType.inside,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Claims clear horizontal drags so MessagesView's timestamp swipe loses, without
/// owning fan motion. Accepts earlier than default touch-slop; rejects vertical early
/// so conversation scroll wins; leaves pure taps alone.
class _EagerHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _EagerHorizontalDragRecognizer({super.debugOwner});

  static const double _eagerAcceptDistance = 8.0;

  Offset? _initialPosition;
  bool _claimed = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _initialPosition = event.position;
    _claimed = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_claimed && event is PointerMoveEvent && _initialPosition != null) {
      final delta = event.position - _initialPosition!;
      if (delta.dy.abs() > delta.dx.abs() && delta.dy.abs() >= _eagerAcceptDistance) {
        _claimed = true;
        resolve(GestureDisposition.rejected);
      } else if (delta.dx.abs() > delta.dy.abs() && delta.dx.abs() >= _eagerAcceptDistance) {
        _claimed = true;
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _initialPosition = null;
    _claimed = false;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void dispose() {
    _initialPosition = null;
    _claimed = false;
    super.dispose();
  }
}
