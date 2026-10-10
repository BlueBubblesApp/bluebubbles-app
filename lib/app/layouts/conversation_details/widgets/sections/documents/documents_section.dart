import 'dart:math';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachment_section_header.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/documents/documents_search_helper.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/conversation_search_field.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Widget that handles documents/files section display
class DocumentsSection extends StatefulWidget {
  final Chat chat;
  final List<Attachment> docs;
  final bool isLoading;
  final bool fullPage;
  final int? crossAxisCount;
  final AttachmentFiltersState filters;

  const DocumentsSection({
    super.key,
    required this.chat,
    required this.docs,
    this.isLoading = false,
    this.fullPage = false,
    this.crossAxisCount,
    this.filters = const AttachmentFiltersState(),
  });

  @override
  State<DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends State<DocumentsSection> with ThemeHelpers {
  static const int _chunkSize = 24;
  late int _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
  bool _loadingMore = false;
  String _searchQuery = '';

  List<Attachment> get _filteredDocs {
    if (!widget.fullPage) return widget.docs;
    return applyFileFilters(
      widget.docs,
      typeFilter: widget.filters.fileTypeFilter,
      senderFilter: widget.filters.senderFilter,
      sinceDate: widget.filters.sinceDate,
    );
  }

  List<Attachment> get _displayedDocs {
    final filtered = _filteredDocs;
    if (!widget.fullPage || _searchQuery.isEmpty) return filtered;
    return filterAndSortFiles(filtered, _searchQuery);
  }

  void _applySearchQuery(String query) {
    final nextQuery = query.trim();
    if (nextQuery == _searchQuery) return;
    setState(() {
      _searchQuery = nextQuery;
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    });
  }

  @override
  void didUpdateWidget(DocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.docs.length != widget.docs.length) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.fullPage != widget.fullPage || oldWidget.filters != widget.filters) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
  }

  int get _visibleCount {
    if (widget.fullPage) return min(_displayCount, _displayedDocs.length);
    return min(kAttachmentPreviewLimit, _displayedDocs.length);
  }

  int get _gridCrossAxisCount {
    if (widget.crossAxisCount != null) return widget.crossAxisCount!;
    return max(2, NavigationSvc.width(context) ~/ 200);
  }

  void _loadMore() {
    if (_loadingMore || _displayCount >= _displayedDocs.length) return;
    _loadingMore = true;
    setState(() => _displayCount = min(_displayCount + _chunkSize, _displayedDocs.length));
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final hideWhenEmpty = !widget.fullPage && !widget.isLoading && _displayedDocs.isEmpty;

    return SliverMainAxisGroup(
      slivers: [
        if (!widget.fullPage)
          SliverToBoxAdapter(
            child: AttachmentSectionHeader(
              title: AttachmentSectionType.documents.expressiveSectionLabel,
              onShowMore: () => ConversationAttachments.open(
                context,
                chat: widget.chat,
                section: AttachmentSectionType.documents,
                docs: widget.docs,
              ),
            ),
          ),
        if (widget.fullPage)
          SliverToBoxAdapter(
            child: Obx(() {
              final submitOnly = SettingsSvc.settings.highPerfMode.value;
              return ConversationSearchField(
                onChanged: submitOnly ? null : _applySearchQuery,
                onSubmitted: _applySearchQuery,
              );
            }),
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
        else if (_displayedDocs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Center(
                child: Text(
                  widget.docs.isEmpty ? "No files" : "No matching files",
                  style: context.theme.textTheme.bodyMedium!.copyWith(
                    color: context.theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: attachmentSectionListPadding(),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridCrossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, int index) => MediaGalleryCard(
                  attachment: _displayedDocs[index],
                  showJumpToMessage: true,
                  galleryAttachments: _displayedDocs,
                ),
                childCount: _visibleCount,
              ),
            ),
          ),
          if (widget.fullPage && _displayCount < _displayedDocs.length)
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
      ],
    );
  }
}
