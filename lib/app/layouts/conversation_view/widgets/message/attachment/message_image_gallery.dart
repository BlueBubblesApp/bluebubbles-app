import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supercharged/supercharged.dart';

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
    this.infiniteScroll = false,
    this.currentIndexNotifier,
    this.reactionsByAttachmentKey,
  });

  final List<Attachment> attachments;
  final int partIndex;
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

  static const _fanSlotDx = <double>[0, 10, 17, 23, 28];
  static const _fanSlotDy = <double>[0, 4, 9, 14, 20];
  static const _fanSlotAngle = <double>[0, 0.05, 0.125, 0.2, 0.35];
  static const _fanSlotScale = <double>[1.0, 0.9, 0.8, 0.7, 0.6];

  static const _pastSlotDx = <double>[14, 20, 25];
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
  final Map<String, Size> _imageSizes = {};
  int? _activeDragPointer;
  VelocityTracker? _velocityTracker;
  ConversationViewController? _cvController;
  late final MessageState _ms;
  final List<Worker> _sizeWorkers = [];

  List<Attachment> get _attachments => widget.attachments;

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
    _cvController = _ms.cvController;
    _watchAttachmentSizes();
    _loadImageSizes();
  }

  @override
  void dispose() {
    for (final w in _sizeWorkers) {
      w.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessageImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKeys = oldWidget.attachments.map((a) => a.guid ?? a.transferName).toList();
    final newKeys = widget.attachments.map((a) => a.guid ?? a.transferName).toList();
    if (!listEquals(oldKeys, newKeys)) {
      _currentIndex = 0;
      _imageSizes.clear();
      _watchAttachmentSizes();
      _loadImageSizes();
    } else {
      final diff = widget.attachments.filter((a) => _sizeFor(a) == null).toList();
      if (diff.isNotEmpty) {
        _loadImageSizes();
      }
    }
  }

  /// The fan's card height is derived from its tallest image, so it has to
  /// re-measure when an attachment finishes downloading or when local dimension
  /// extraction lands. Neither rebuilds this widget on its own — the download
  /// progress UI updates inside `AttachmentHolder`'s own `Obx`, well below here,
  /// so without these workers the fan keeps the square fallback height it
  /// picked while the file was still missing.
  void _watchAttachmentSizes() {
    for (final w in _sizeWorkers) {
      w.dispose();
    }
    _sizeWorkers.clear();

    for (final a in _attachments) {
      final guid = a.guid;
      if (guid == null) continue;
      final state = _ms.getOrCreateAttachmentState(guid, attachment: a);
      _sizeWorkers.add(
        everAll([state.width, state.height, state.resolvedFile], (_) {
          _runOutsideBuild(() {
            if (!mounted) return;
            // Dimensions may already be on the attachment (the state write and
            // the entity write happen together), so rebuild regardless; the
            // probe below only does work when they aren't.
            unawaited(_loadOneImageSize(a, force: true));
            setState(() {});
          });
        }),
      );
    }
  }

  /// Runs [fn] once the framework is out of its build/layout phase.
  ///
  /// GetX workers fire synchronously from whoever wrote the value, and
  /// `AttachmentHolder.initState` resolves an already-downloaded file while this
  /// widget is still building its own subtree — so calling `setState` straight
  /// from a worker throws "setState() called during build".
  void _runOutsideBuild(VoidCallback fn) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final midFrame = phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks;
    if (!midFrame) {
      fn();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => fn());
  }

  void _loadImageSizes() {
    for (final a in _attachments) {
      if (a.mimeStart == 'image') {
        _loadOneImageSize(a);
      }
    }
  }

  /// The size to lay [attachment] out at, preferring the dimensions already
  /// tracked on the attachment over decoding the file to find out. Falls back to
  /// the probed size for attachments whose dimensions were never extracted.
  Size? _sizeFor(Attachment attachment) {
    final w = attachment.displayWidth;
    final h = attachment.displayHeight;
    if (w != null && h != null && w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
    final key = attachment.guid ?? attachment.transferName;
    return key != null ? _imageSizes[key] : null;
  }

  Future<void> _loadOneImageSize(Attachment attachment, {bool force = false}) async {
    final key = attachment.guid ?? attachment.transferName;
    if (key == null) return;
    if (!force && _imageSizes.containsKey(key)) return;
    // Stored dimensions already answer this — no reason to decode the file.
    if (attachment.hasValidSize) return;
    try {
      // Prefer a converted path (exists for HEIC/TIFF), fall back to original.
      // legacyConvertedPath covers HEIC converted before it moved to JPEG.
      File? imageFile;
      for (final candidate in {attachment.convertedPath, attachment.legacyConvertedPath, attachment.path}) {
        final f = File(candidate);
        if (f.existsSync()) {
          imageFile = f;
          break;
        }
      }
      if (imageFile == null) return;

      final completer = Completer<Size?>();
      final provider = FileImage(imageFile);
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
          }
          stream.removeListener(listener);
        },
        onError: (dynamic _, StackTrace? __) {
          if (!completer.isCompleted) completer.complete(null);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);

      final size = await completer.future;
      if (size == null) return;
      // A cached image resolves its listener synchronously, so this can land
      // mid-frame just like the workers above.
      _runOutsideBuild(() {
        if (!mounted) return;
        setState(() {
          _imageSizes[key] = size;
        });
      });
    } catch (_) {}
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

  Attachment _attachmentAtOffset(int offset) {
    final index = (_currentIndex + offset) % _attachments.length;
    return _attachments[index];
  }

  MessagePart _partForAttachment(Attachment attachment) {
    return MessagePart(
      part: widget.partIndex,
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
    if (widget.isInReply) return 120.0;

    const double maxHeight = 500.0;
    const double minHeight = 100.0;

    final tallest = _attachments.fold<double>(
      minHeight,
      (current, a) {
        final size = _sizeFor(a);
        if (size == null || size.width <= 0 || size.height <= 0) {
          return max(current, baseCardWidth);
        }
        return max(current, (size.height / size.width) * baseCardWidth);
      },
    );
    return tallest.clamp(minHeight, maxHeight);
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
    final baseCardWidth = min((NavigationSvc.width(context) * 0.5), 260.0);
    final baseHeight = _computeBaseCardHeight(baseCardWidth);
    final baseCardHeight = baseHeight.clamp(100.0, 500.0);

    final fanCanvasWidth = baseCardWidth + 56;
    final fanCanvasHeight = baseCardHeight;
    final baseOffset =
        ((fanCanvasWidth - baseCardWidth) / 2) + (widget.fanDirection == GalleryFanDirection.left ? 36 : -50);
    final fanDirectionSign = widget.fanDirection == GalleryFanDirection.left ? -1.0 : 1.0;
    final textOffset = (baseOffset + 25 + fanDirectionSign * 10.0).clamp(0.0, double.infinity);
    final direction = widget.fanDirection == GalleryFanDirection.left ? -1.0 : 1.0;
    final mirroredBias = direction * 10.0;
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
        final attachment = _attachmentAtOffset(i);
        return _buildFanCard(
          attachment: attachment,
          slotIndex: i,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          baseOffset: baseOffset,
          direction: direction,
          mirroredBias: mirroredBias,
          isCurrent: i == 0,
        );
      }).reversed);
    } else {
      final futureCount = _attachments.length - _currentIndex - 1;
      final pastCount = _currentIndex;
      final visiblePast = min(pastCount, _maxPastCards);
      final visibleFuture = min(futureCount, _visibleFanSlots - 1);

      for (int p = visiblePast; p >= 1; p--) {
        final attachment = _attachments[_currentIndex - p];
        final slot = (p - 1).clamp(0, _maxPastCards - 1);
        stackChildren.add(_buildPastCard(
          attachment: attachment,
          slotIndex: slot,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          baseOffset: baseOffset,
          direction: direction,
        ));
      }

      for (int f = visibleFuture; f >= 1; f--) {
        final attachment = _attachments[_currentIndex + f];
        stackChildren.add(_buildFanCard(
          attachment: attachment,
          slotIndex: f,
          baseCardWidth: baseCardWidth,
          baseCardHeight: baseCardHeight,
          baseOffset: baseOffset,
          direction: direction,
          mirroredBias: mirroredBias,
          isCurrent: false,
        ));
      }

      stackChildren.add(_buildFanCard(
        attachment: _attachments[_currentIndex],
        slotIndex: 0,
        baseCardWidth: baseCardWidth,
        baseCardHeight: baseCardHeight,
        baseOffset: baseOffset,
        direction: direction,
        mirroredBias: mirroredBias,
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
          final fanFlip = widget.fanDirection == GalleryFanDirection.left ? -1 : 1;
          final atStart = _currentIndex == 0;
          final atEnd = _currentIndex == _attachments.length - 1;
          final blockedPositive = (atStart && fanFlip > 0) || (atEnd && fanFlip < 0);
          final blockedNegative = (atStart && fanFlip < 0) || (atEnd && fanFlip > 0);

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

        final rawSign = (_dragDx != 0 ? _dragDx : velocity) < 0 ? 1 : -1;
        final fanFlip = widget.fanDirection == GalleryFanDirection.left ? -1 : 1;
        setState(() {
          _advance(rawSign * fanFlip);
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
            Padding(
              padding: (widget.fanDirection == GalleryFanDirection.left
                  ? const EdgeInsets.only(right: 20)
                  : EdgeInsets.only(left: textOffset)),
              child: MouseRegion(
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
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
    required double baseOffset,
    required double direction,
    required double mirroredBias,
    required bool isCurrent,
  }) {
    final slot = slotIndex < _visibleFanSlots ? slotIndex : (_visibleFanSlots - 1);
    final overflowDepth =
        slotIndex >= _visibleFanSlots ? ((slotIndex - (_visibleFanSlots - 1)).clamp(0, 6) * 0.7) : 0.0;
    final angle = slot == 0 ? 0.0 : direction * _fanSlotAngle[slot];
    final dy = _fanSlotDy[slot] + overflowDepth;
    final dx = direction * _fanSlotDx[slot];
    final scale = _fanSlotScale[slot];
    final cardWidth = baseCardWidth * scale;
    final cardHeight = baseCardHeight * scale;
    final centeredLeft = baseOffset + ((baseCardWidth - cardWidth) / 2);
    final dragOffset = isCurrent ? _dragDx : 0.0;
    final dragRotate = isCurrent ? (_dragDx / 700) : 0.0;

    return AnimatedPositioned(
      key: ValueKey(attachment.guid ?? attachment.id ?? '${attachment.transferName}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 1 + dy,
      left: centeredLeft + mirroredBias + dx + dragOffset,
      child: Transform.translate(
        offset: Offset.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardWidth, minHeight: cardHeight, maxHeight: cardHeight),
          child: Transform.rotate(
            angle: angle.toDouble() + dragRotate,
            alignment: widget.fanDirection == GalleryFanDirection.left ? Alignment.bottomRight : Alignment.bottomLeft,
            child: _withReactionOverlay(
              IgnorePointer(
                ignoring: !isCurrent,
                child: AttachmentHolder(
                  message: _partForAttachment(attachment),
                  transparentBackground: true,
                  showCardShadow: true,
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

  Widget _buildPastCard({
    required Attachment attachment,
    required int slotIndex,
    required double baseCardWidth,
    required double baseCardHeight,
    required double baseOffset,
    required double direction,
  }) {
    final slot = slotIndex.clamp(0, _maxPastCards - 1);
    final angle = -direction * _pastSlotAngle[slot];
    final dx = -direction * _pastSlotDx[slot];
    final scale = _pastSlotScale[slot];
    final dy = _pastSlotDy[slot];
    final opacity = _pastSlotOpacity[slot];
    final cardWidth = baseCardWidth * scale;
    final cardHeight = baseCardHeight * scale;
    final centeredLeft = baseOffset + ((baseCardWidth - cardWidth) / 2);
    final pastBias = -direction * 10.0;

    return AnimatedPositioned(
      key: ValueKey(attachment.guid ?? attachment.id ?? '${attachment.transferName}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 1 + dy,
      left: centeredLeft + pastBias + dx,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: opacity,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Transform.rotate(
            angle: angle.toDouble(),
            alignment: widget.fanDirection == GalleryFanDirection.left ? Alignment.bottomLeft : Alignment.bottomRight,
            child: _withReactionOverlay(
              IgnorePointer(
                ignoring: true,
                child: AttachmentHolder(
                  message: _partForAttachment(attachment),
                  transparentBackground: true,
                  showCardShadow: true,
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
