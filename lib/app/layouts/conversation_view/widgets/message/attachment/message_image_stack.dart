import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_media_grid_page.dart';
import 'package:bluebubbles/app/state/message_state.dart';
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

/// Shared width for iOS collage and stack collection cards.
double collectionCardWidth(BuildContext context) =>
    min(NavigationSvc.width(context) * 0.42, 220.0);

class MessageImageStack extends StatefulWidget {
  const MessageImageStack({
    super.key,
    required this.messagePart,
    required this.cvController,
    required this.isInReply,
    required this.fanDirection,
    this.isEditing = false,
    this.infiniteScroll = false,
    this.currentIndexNotifier,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isInReply;
  final GalleryFanDirection fanDirection;
  final bool isEditing;
  final bool infiniteScroll;
  final ValueNotifier<int>? currentIndexNotifier;

  List<Attachment> get attachments => messagePart.attachments;

  @override
  State<MessageImageStack> createState() => _MessageImageStackState();
}

class _MessageImageStackState extends State<MessageImageStack> with ThemeHelpers {
  static const int _visibleFanSlots = 5;
  static const int _maxPastCards = 3;
  static const double _swipeCommitThreshold = 70;
  static const double _maxDragDx = 140;
  static const double _maxWiggleDx = 20.0;
  /// Portrait card aspect (width:height = 3:4).
  static const double _portraitAspect = 3 / 4;

  static const _fanSlotDx = <double>[0, 7, 12, 16, 20];
  static const _fanSlotDy = <double>[0, 4, 9, 14, 20];
  static const _fanSlotAngle = <double>[0, 0.08, 0.175, 0.3, 0.425];
  static const _fanSlotScale = <double>[1.0, 0.9, 0.8, 0.7, 0.6];

  static const _pastSlotDx = <double>[10, 14, 18];
  static const _pastSlotDy = <double>[5, 11, 17];
  static const _pastSlotAngle = <double>[0.1, 0.19, 0.28];
  static const _pastSlotScale = <double>[0.82, 0.72, 0.62];
  static const _pastSlotOpacity = <double>[0.80, 0.60, 0.40];

  static const double _scrollAdvanceThreshold = 50.0;

  int _currentIndex = 0;
  double _dragDx = 0;
  double _scrollAccumulator = 0;
  bool _hapticGivenForCurrentEnd = false;
  bool _labelHovered = false;

  List<Attachment> get _attachments => widget.attachments;

  @override
  void didUpdateWidget(covariant MessageImageStack oldWidget) {
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

  double _computeBaseCardHeight(double baseCardWidth) {
    if (widget.isInReply) return 120.0;
    return (baseCardWidth / _portraitAspect).clamp(100.0, 500.0);
  }

  void _openCollectionGrid(BuildContext context, String title) {
    CollectionMediaGridPage.open(
      context,
      chat: widget.cvController.chat,
      media: _attachments,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseCardWidth = collectionCardWidth(context);
    final baseCardHeight = _computeBaseCardHeight(baseCardWidth);

    final fanCanvasWidth = baseCardWidth + 56;
    final fanCanvasHeight = baseCardHeight;
    // fanDirection.right = from-me: fan opens to the right behind the front card.
    // fanDirection.left = received: fan opens to the left (mirrored).
    // The deepest fan card stays inside the author-side edge (no bleed past the screen).
    final bool authorOnRight = widget.fanDirection == GalleryFanDirection.right;
    final direction = authorOnRight ? 1.0 : -1.0;
    final stackLabel = CollectionMediaGridPage.titleForAttachments(_attachments);

    final double maxFanDx;
    if (widget.infiniteScroll) {
      maxFanDx = _fanSlotDx.last;
    } else {
      final futureCount = _attachments.length - _currentIndex - 1;
      final visibleFuture = min(futureCount, _visibleFanSlots - 1);
      maxFanDx = visibleFuture > 0 ? _fanSlotDx[visibleFuture] : 0.0;
    }

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

    // Incoming iOS only: beside the front card, behind cards so swipes paint over it,
    // above the advance tap fill so it stays tappable when uncovered.
    if (!authorOnRight && CollectionDownloadButton.isSupported) {
      stackChildren.add(
        Positioned(
          right: (fanCanvasWidth - baseCardWidth - maxFanDx) -
              CollectionDownloadButton.size -
              CollectionDownloadButton.gap,
          top: 0,
          bottom: 0,
          child: Center(child: CollectionDownloadButton(attachments: _attachments)),
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
          slotIndex: i,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          authorOnRight: authorOnRight,
          direction: direction,
          maxFanDx: maxFanDx,
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
        final slot = (p - 1).clamp(0, _maxPastCards - 1);
        stackChildren.add(_buildPastCard(
          attachmentIndex: attachmentIndex,
          attachment: _attachments[attachmentIndex],
          messageState: MessageStateScope.of(context),
          slotIndex: slot,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          authorOnRight: authorOnRight,
          direction: direction,
        ));
      }

      for (int f = visibleFuture; f >= 1; f--) {
        final attachmentIndex = _currentIndex + f;
        stackChildren.add(_buildFanCard(
          attachmentIndex: attachmentIndex,
          attachment: _attachments[attachmentIndex],
          messageState: MessageStateScope.of(context),
          slotIndex: f,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          authorOnRight: authorOnRight,
          direction: direction,
          maxFanDx: maxFanDx,
          isCurrent: false,
        ));
      }

      stackChildren.add(_buildFanCard(
        attachmentIndex: _currentIndex,
        attachment: _attachments[_currentIndex],
        messageState: MessageStateScope.of(context),
        slotIndex: 0,
        baseCardWidth: baseCardWidth,
        baseCardHeight: baseCardHeight,
        authorOnRight: authorOnRight,
        direction: direction,
        maxFanDx: maxFanDx,
        isCurrent: true,
      ));
    }

    // Swipe: dragging toward the fan (author edge) advances forward.
    final fanFlip = authorOnRight ? 1 : -1;

    return Listener(
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
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (_attachments.length <= 1) return;
          if (!widget.infiniteScroll) {
            final atStart = _currentIndex == 0;
            final atEnd = _currentIndex == _attachments.length - 1;
            final blockedPositive = (atStart && fanFlip > 0) || (atEnd && fanFlip < 0);
            final blockedNegative = (atStart && fanFlip < 0) || (atEnd && fanFlip > 0);

            final draggingIntoBlockedEnd =
                (blockedPositive && details.delta.dx > 0) || (blockedNegative && details.delta.dx < 0);
            if (draggingIntoBlockedEnd) {
              if (!_hapticGivenForCurrentEnd) {
                HapticFeedback.lightImpact();
                _hapticGivenForCurrentEnd = true;
              }
              setState(() {
                _dragDx += details.delta.dx * 0.3;
                if (blockedPositive) _dragDx = _dragDx.clamp(0.0, _maxWiggleDx);
                if (blockedNegative) _dragDx = _dragDx.clamp(-_maxWiggleDx, 0.0);
              });
              return;
            } else {
              _hapticGivenForCurrentEnd = false;
            }
          }
          setState(() {
            _dragDx += details.delta.dx;
            _dragDx = _dragDx.clamp(-_maxDragDx, _maxDragDx);
          });
        },
        onHorizontalDragEnd: (details) {
          _hapticGivenForCurrentEnd = false;
          if (_attachments.length <= 1) return;
          final velocity = details.primaryVelocity ?? 0;
          final bool commit = _dragDx.abs() >= _swipeCommitThreshold || velocity.abs() > 700;
          if (!commit) {
            setState(() {
              _dragDx = 0;
            });
            return;
          }

          final rawSign = (_dragDx != 0 ? _dragDx : velocity) < 0 ? 1 : -1;
          setState(() {
            _advance(rawSign * fanFlip);
            _dragDx = 0;
          });
        },
        onHorizontalDragCancel: () {
          _hapticGivenForCurrentEnd = false;
          if (_attachments.length <= 1) return;
          setState(() {
            _dragDx = 0;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: authorOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              // Match the front card's inset from the author edge (maxFanDx).
              padding: authorOnRight ? EdgeInsets.only(right: maxFanDx) : EdgeInsets.only(left: maxFanDx),
              child: MouseRegion(
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
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: fanCanvasWidth,
              height: fanCanvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: stackChildren,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFanCard({
    required int attachmentIndex,
    required Attachment attachment,
    required MessageState messageState,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
    required bool authorOnRight,
    required double direction,
    required double maxFanDx,
    required bool isCurrent,
  }) {
    final slot = slotIndex < _visibleFanSlots ? slotIndex : (_visibleFanSlots - 1);
    final overflowDepth =
        slotIndex >= _visibleFanSlots ? ((slotIndex - (_visibleFanSlots - 1)).clamp(0, 6) * 0.7) : 0.0;
    final angle = slot == 0 ? 0.0 : direction * _fanSlotAngle[slot];
    final dy = _fanSlotDy[slot] + overflowDepth;
    final scale = _fanSlotScale[slot];
    final cardWidth = baseCardWidth * scale;
    final cardHeight = baseCardHeight * scale;
    // Anchor the deepest visible full-size slot flush with the author-side edge.
    // Scale-center each card on its slot so smaller cards don't poke out further
    // than the original fan spread.
    final slotDx = slot < _fanSlotDx.length ? _fanSlotDx[slot] : _fanSlotDx.last;
    final fromAuthorEdge = maxFanDx - slotDx + ((baseCardWidth - cardWidth) / 2);
    final dragOffset = isCurrent ? _dragDx : 0.0;
    final dragRotate = isCurrent ? (_dragDx / 700) : 0.0;

    return AnimatedPositioned(
      key: ValueKey(attachment.guid ?? attachment.id ?? '${attachment.transferName}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 1 + dy,
      left: authorOnRight ? null : fromAuthorEdge + dragOffset,
      right: authorOnRight ? fromAuthorEdge - dragOffset : null,
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Transform.rotate(
          angle: angle.toDouble() + dragRotate,
          alignment: authorOnRight ? Alignment.bottomLeft : Alignment.bottomRight,
          child: IgnorePointer(
            ignoring: !isCurrent,
            child: CollectionAttachmentCard(
              controller: messageState,
              cvController: widget.cvController,
              collectionPart: widget.messagePart,
              attachmentIndex: attachmentIndex,
              collectionAttachments: _attachments,
              isEditing: widget.isEditing,
              enableGestures: isCurrent,
              fillCard: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPastCard({
    required int attachmentIndex,
    required Attachment attachment,
    required MessageState messageState,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
    required bool authorOnRight,
    required double direction,
  }) {
    final slot = slotIndex.clamp(0, _maxPastCards - 1);
    final angle = -direction * _pastSlotAngle[slot];
    final scale = _pastSlotScale[slot];
    final dy = _pastSlotDy[slot];
    final opacity = _pastSlotOpacity[slot];
    final cardWidth = baseCardWidth * scale;
    final cardHeight = baseCardHeight * scale;
    // Past cards tip toward the center, opposite the fan.
    final fromCenterSide = _pastSlotDx[slot] + ((baseCardWidth - cardWidth) / 2);

    return AnimatedPositioned(
      key: ValueKey(attachment.guid ?? attachment.id ?? '${attachment.transferName}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 1 + dy,
      left: authorOnRight ? fromCenterSide : null,
      right: authorOnRight ? null : fromCenterSide,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: opacity,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Transform.rotate(
            angle: angle.toDouble(),
            alignment: authorOnRight ? Alignment.bottomRight : Alignment.bottomLeft,
            child: IgnorePointer(
              ignoring: true,
              child: CollectionAttachmentCard(
                controller: messageState,
                cvController: widget.cvController,
                collectionPart: widget.messagePart,
                attachmentIndex: attachmentIndex,
                collectionAttachments: _attachments,
                isEditing: widget.isEditing,
                enableGestures: false,
                fillCard: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
