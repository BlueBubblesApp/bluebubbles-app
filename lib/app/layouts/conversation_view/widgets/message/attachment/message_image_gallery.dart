import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum GalleryFanDirection {
  left,
  right,
}

class MessageImageGallery extends StatefulWidget {
  const MessageImageGallery({
    super.key,
    required this.attachments,
    required this.partIndex,
    required this.isInReply,
    required this.fanDirection,
    this.attachmentPartIndices,
    this.infiniteScroll = false,
    this.currentIndexNotifier,
    this.reactionsByAttachmentKey,
  });

  final List<Attachment> attachments;

  /// Collapsed gallery message-part id
  final int partIndex;

  /// Original message-part id for each attachment index when the gallery is
  /// collapsed from multiple parts. Null when all attachments share [partIndex].
  final List<int>? attachmentPartIndices;

  final bool isInReply;
  final GalleryFanDirection fanDirection;
  final bool infiniteScroll;
  final ValueNotifier<int>? currentIndexNotifier;

  /// Tapback reactions keyed by attachment (guid, falling back to
  /// transferName) so each card in the fan can show the reaction that was
  /// actually left on that specific image/video, rather than one reaction
  /// shared across the whole gallery.
  final Map<String, List<Message>>? reactionsByAttachmentKey;

  @override
  State<MessageImageGallery> createState() => _MessageImageGalleryState();
}

class _MessageImageGalleryState extends State<MessageImageGallery> with ThemeHelpers {
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
  bool _labelHovered = false;
  int? _activeDragPointer;
  VelocityTracker? _velocityTracker;
  ConversationViewController? _cvController;

  List<Attachment> get _attachments => widget.attachments;

  @override
  void initState() {
    super.initState();
    _cvController = MessageStateScope.readStateOnce(context).cvController;
  }

  @override
  void didUpdateWidget(covariant MessageImageGallery oldWidget) {
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
    widget.currentIndexNotifier?.value = _currentIndex;
  }

  int _indexAtOffset(int offset) {
    var index = (_currentIndex + offset) % _attachments.length;
    if (index < 0) index += _attachments.length;
    return index;
  }

  int _partIdForAttachment(int attachmentIndex) =>
      widget.attachmentPartIndices?[attachmentIndex] ?? widget.partIndex;

  MessagePart _partForAttachment(Attachment attachment, int attachmentIndex) {
    return MessagePart(
      part: _partIdForAttachment(attachmentIndex),
      attachments: [attachment],
      shouldRedact: false,
      text: null,
      subject: null,
      mentions: const [],
      edits: const [],
      isUnsent: false,
    );
  }

  double _computeBaseCardHeight(double baseCardWidth) {
    return (baseCardWidth / _portraitAspect).clamp(100.0, 500.0);
  }

  void _showGalleryPopup(BuildContext context, String title) {
    showBBDialog(
      useRootNavigator: false,
      context: context,
      title: title,
      content: SizedBox(
        width: 500,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _attachments.length,
          itemBuilder: (context, index) {
            return MediaGalleryCard(attachment: _attachments[index], showSenderAvatar: false);
          },
        ),
      ),
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
    final photoCount = _attachments.where((a) => a.mimeStart == 'image').length;
    final videoCount = _attachments.where((a) => a.mimeStart == 'video').length;
    final galleryLabel = photoCount > 0 && videoCount > 0
        ? '${photoCount + videoCount} Photos & Videos'
        : videoCount > 0
            ? '$videoCount ${videoCount == 1 ? 'Video' : 'Videos'}'
            : '$photoCount ${photoCount == 1 ? 'Photo' : 'Photos'}';

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

    return Listener(
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
        _velocityTracker = VelocityTracker.withKind(event.kind);
        _velocityTracker!.addPosition(event.timeStamp, event.position);
        // Claim the drag so the list-wide timestamp-reveal swipe (a distinct
        // GestureDetector ancestor in MessagesView) doesn't also react to the
        // same pointer — see conversation_view_controller.dart's field doc.
        _cvController?.isGalleryDragging = true;
      },
      onPointerMove: (event) {
        if (_attachments.length <= 1 || _activeDragPointer != event.pointer) return;
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
            setState(() {
              _dragDx += event.delta.dx * 0.3;
              if (blockedPositive) _dragDx = _dragDx.clamp(0.0, _maxWiggleDx);
              if (blockedNegative) _dragDx = _dragDx.clamp(-_maxWiggleDx, 0.0);
            });
            return;
          } else {
            _hapticGivenForCurrentEnd = false;
          }
        }
        setState(() {
          _dragDx += event.delta.dx;
          _dragDx = _dragDx.clamp(-_maxDragDx, _maxDragDx);
        });
      },
      onPointerUp: (event) {
        if (_activeDragPointer != event.pointer) return;
        _activeDragPointer = null;
        _hapticGivenForCurrentEnd = false;
        _cvController?.isGalleryDragging = false;
        final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
        _velocityTracker = null;
        if (_attachments.length <= 1) return;
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
      },
      onPointerCancel: (event) {
        if (_activeDragPointer != event.pointer) return;
        _activeDragPointer = null;
        _velocityTracker = null;
        _hapticGivenForCurrentEnd = false;
        _cvController?.isGalleryDragging = false;
        if (_attachments.length <= 1) return;
        setState(() {
          _dragDx = 0;
        });
      },
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              widget.fanDirection == GalleryFanDirection.left ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            MouseRegion(
              onEnter: kIsDesktop ? (_) => setState(() => _labelHovered = true) : null,
              onExit: kIsDesktop ? (_) => setState(() => _labelHovered = false) : null,
              child: GestureDetector(
                onTap: kIsDesktop ? () => _showGalleryPopup(context, galleryLabel) : null,
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
                          galleryLabel,
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
            const SizedBox(height: 4),
            SizedBox(
              width: fanCanvasWidth,
              height: fanCanvasHeight,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: stackChildren,
              ),
            ),
          ],
        ),
    );
  }

  List<Message> _reactionsFor(Attachment attachment) {
    final key = attachment.guid ?? attachment.transferName;
    if (key == null) return const [];
    return widget.reactionsByAttachmentKey?[key] ?? const [];
  }

  Widget _withReactionOverlay(Widget card, Attachment attachment) {
    final reactions = _reactionsFor(attachment);
    if (reactions.isEmpty) return card;
    final isFromMe = widget.fanDirection == GalleryFanDirection.left;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -14,
          left: isFromMe ? -14 : null,
          right: isFromMe ? null : -14,
          child: ReactionHolder(reactions: reactions),
        ),
      ],
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
          child: _withReactionOverlay(
            IgnorePointer(
              ignoring: !isCurrent,
              child: AttachmentHolder(
                message: _partForAttachment(attachment, attachmentIndex),
                transparentBackground: true,
                showCardShadow: true,
                fill: true,
                galleryAttachments: _attachments,
              ),
            ),
            attachment,
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
            child: _withReactionOverlay(
              IgnorePointer(
                ignoring: true,
                child: AttachmentHolder(
                  message: _partForAttachment(attachment, attachmentIndex),
                  transparentBackground: true,
                  showCardShadow: true,
                  fill: true,
                  galleryAttachments: _attachments,
                ),
              ),
              attachment,
            ),
          ),
        ),
      ),
    );
  }
}
