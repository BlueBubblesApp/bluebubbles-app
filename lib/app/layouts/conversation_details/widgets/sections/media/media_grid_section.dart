import 'dart:math';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachment_section_header.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/media/media_filter_selector.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Widget that handles media grid display with selection functionality
class MediaGridSection extends StatefulWidget {
  final Chat chat;
  final List<Attachment> media;
  final RxList<String> selected;
  final bool isLoading;
  final bool fullPage;
  final int? crossAxisCount;
  final MediaFilter mediaFilter;
  final MediaSenderFilter senderFilter;
  final DateTime? sinceDate;
  final ValueChanged<MediaFilter>? onMediaFilterChanged;
  final bool showSenderAvatar;

  /// Optional per-cell overlay (e.g. collection tapbacks); clips thumbnail only so overlays can overflow.
  final Widget Function(BuildContext context, int index, Attachment attachment)? cellOverlayBuilder;

  const MediaGridSection({
    super.key,
    required this.chat,
    required this.media,
    required this.selected,
    required this.isLoading,
    this.fullPage = false,
    this.crossAxisCount,
    this.mediaFilter = MediaFilter.all,
    this.senderFilter = const MediaSenderFilter.any(),
    this.sinceDate,
    this.onMediaFilterChanged,
    this.showSenderAvatar = true,
    this.cellOverlayBuilder,
  });

  @override
  State<MediaGridSection> createState() => _MediaGridSectionState();
}

class _MediaGridSectionState extends State<MediaGridSection> with ThemeHelpers {
  static const int _chunkSize = 24;
  late int _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
  bool _loadingMore = false;

  List<Attachment> get _filteredMedia => applyMediaFilters(
        widget.media,
        typeFilter: widget.mediaFilter,
        senderFilter: widget.senderFilter,
        sinceDate: widget.sinceDate,
      );

  @override
  void didUpdateWidget(MediaGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.length != widget.media.length) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.isLoading != widget.isLoading) {
      setState(() {});
    }
    if (oldWidget.fullPage != widget.fullPage) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.mediaFilter != widget.mediaFilter) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.senderFilter != widget.senderFilter) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.sinceDate != widget.sinceDate) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
  }

  int get _visibleCount {
    if (widget.fullPage) {
      return min(_displayCount, _filteredMedia.length);
    }
    return min(kAttachmentPreviewLimit, _filteredMedia.length);
  }

  int _gridCrossAxisCountFor(double width) {
    if (widget.crossAxisCount != null) return widget.crossAxisCount!;
    return expressiveMediaCrossAxisCount(width) + (widget.fullPage ? 1 : 0);
  }

  void _loadMore() {
    if (_loadingMore || _displayCount >= _filteredMedia.length) return;
    _loadingMore = true;
    setState(() => _displayCount = min(_displayCount + _chunkSize, _filteredMedia.length));
    _loadingMore = false;
  }

  Widget _buildGridItem(BuildContext context, int index) {
    final attachment = _filteredMedia[index];
    final hasOverlay = widget.cellOverlayBuilder != null;
    const tileRadius = BorderRadius.all(Radius.circular(20));

    Widget thumbnail = MediaGalleryCard(
      attachment: attachment,
      showSenderAvatar: widget.showSenderAvatar,
      chat: widget.chat,
      galleryAttachments: _filteredMedia,
    );
    if (hasOverlay) {
      thumbnail = ClipRRect(borderRadius: tileRadius, child: thumbnail);
    }

    return Obx(() {
      final isSelected = widget.selected.contains(attachment.guid);
      const motion = M3EMotion.spatialFast;
      return AnimatedContainer(
        duration: motion.duration,
        curve: motion.curve,
        margin: EdgeInsets.all(isSelected ? 10 : 0),
        decoration: hasOverlay
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(isSelected ? M3EShapes.md : 20),
              ),
        clipBehavior: hasOverlay ? Clip.none : Clip.antiAlias,
        child: GestureDetector(
          onTap: widget.selected.isNotEmpty
              ? () {
                  if (widget.selected.contains(attachment.guid)) {
                    widget.selected.remove(attachment.guid!);
                  } else {
                    widget.selected.add(attachment.guid!);
                  }
                }
              : null,
          onLongPress: () {
            if (widget.selected.contains(attachment.guid)) {
              widget.selected.remove(attachment.guid!);
            } else {
              widget.selected.add(attachment.guid!);
            }
          },
          child: AbsorbPointer(
            absorbing: widget.selected.isNotEmpty,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: hasOverlay ? Clip.none : Clip.hardEdge,
              children: [
                thumbnail,
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.theme.colorScheme.primary,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Icon(
                        iOS ? CupertinoIcons.check_mark : Icons.check,
                        color: context.theme.colorScheme.onPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                if (hasOverlay) widget.cellOverlayBuilder!(context, index, attachment),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final hideWhenEmpty = !widget.fullPage && !widget.isLoading && _filteredMedia.isEmpty;

    final slivers = <Widget>[
      if (!widget.fullPage)
        SliverToBoxAdapter(
          child: AttachmentSectionHeader(
            title: AttachmentSectionType.media.expressiveSectionLabel,
            onShowMore: () {
              widget.selected.clear();
              ConversationAttachments.open(
                context,
                chat: widget.chat,
                section: AttachmentSectionType.media,
                media: widget.media,
              );
            },
          ),
        ),
      if (widget.fullPage && !widget.isLoading && widget.onMediaFilterChanged != null)
        SliverToBoxAdapter(
          child: MediaFilterSelector(
            value: widget.mediaFilter,
            onChanged: widget.onMediaFilterChanged!,
          ),
        ),
      if (widget.isLoading)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Center(child: buildProgressIndicator(context, size: 24)),
          ),
        )
      else if (hideWhenEmpty)
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: M3EMotion.spatialFast.duration,
            curve: M3EMotion.spatialFast.curve,
            child: const SizedBox.shrink(),
          ),
        )
      else if (_filteredMedia.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Center(
              child: Text(
                widget.fullPage ? widget.mediaFilter.emptyMessage : "No photos or videos",
                style: context.theme.textTheme.bodyMedium!.copyWith(
                  color: context.theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        )
      else ...[
        SliverPadding(
          padding: attachmentSectionListPadding(
            top: widget.fullPage ? 10 : 0,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridCrossAxisCountFor(constraints.crossAxisExtent),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, int index) => _buildGridItem(context, index),
                  childCount: _visibleCount,
                ),
              );
            },
          ),
        ),
        if (widget.fullPage && _displayCount < _filteredMedia.length)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                if (!_loadingMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: buildProgressIndicator(context, size: 24)),
                );
              },
            ),
          ),
      ],
    ];

    return SliverMainAxisGroup(slivers: slivers);
  }
}
