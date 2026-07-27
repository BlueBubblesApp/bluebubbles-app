import 'dart:math';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachment_section_header.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/links/links_search_helper.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/conversation_search_field.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget that handles links section display with loading state
class LinksSection extends StatefulWidget {
  final Chat chat;
  final bool fullPage;
  final bool expressive;
  final MediaSenderFilter senderFilter;
  final DateTime? sinceDate;

  const LinksSection({
    super.key,
    required this.chat,
    this.fullPage = false,
    this.expressive = false,
    this.senderFilter = const MediaSenderFilter.any(),
    this.sinceDate,
  });

  @override
  State<LinksSection> createState() => _LinksSectionState();
}

class _LinksSectionState extends State<LinksSection> with ThemeHelpers {
  static const int _chunkSize = 20;
  late int _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
  List<Message> links = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  String _searchQuery = '';

  List<Message> get _filteredLinks {
    if (!widget.fullPage) return links;
    return applyMessageFilters(
      links,
      senderFilter: widget.senderFilter,
      sinceDate: widget.sinceDate,
    );
  }

  List<Message> get _displayedLinks {
    final filtered = _filteredLinks;
    if (!widget.fullPage || _searchQuery.isEmpty) return filtered;
    return filterAndSortLinks(filtered, _searchQuery);
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
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _fetchLinks();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(LinksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullPage != widget.fullPage ||
        oldWidget.senderFilter != widget.senderFilter ||
        oldWidget.sinceDate != widget.sinceDate) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
  }

  Future<void> _fetchLinks() async {
    if (kIsWeb || widget.chat.id == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final query = (Database.messages.query(Message_.dateDeleted.isNull() &
              Message_.dbPayloadData.notNull() &
              Message_.balloonBundleId.contains("URLBalloonProvider"))
            ..link(Message_.chat, Chat_.id.equals(widget.chat.id!))
            ..order(Message_.dateCreated, flags: Order.descending))
          .build();
      final fetchedLinks = await query.findAsync();
      query.close();

      if (mounted) {
        setState(() {
          links = fetchedLinks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _visibleCount {
    if (widget.fullPage) return min(_displayCount, _displayedLinks.length);
    return min(kAttachmentPreviewLimit, _displayedLinks.length);
  }

  void _loadMore() {
    if (_loadingMore || _displayCount >= _displayedLinks.length) return;
    _loadingMore = true;
    setState(() => _displayCount = min(_displayCount + _chunkSize, _displayedLinks.length));
    _loadingMore = false;
  }

  Widget _buildLinkTile(BuildContext context, int index) {
    if (_displayedLinks[index].payloadData?.urlData?.firstOrNull == null) {
      return const Text("Failed to load link!");
    }
    final radius = widget.expressive ? M3EShapes.lg : 20.0;
    return Material(
      color: widget.expressive
          ? context.tileColor.themeLightenOrDarken(context, 6)
          : context.theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () async {
          final data = _displayedLinks[index].payloadData!.urlData!.first;
          if ((data.url ?? data.originalUrl) == null) return;
          await launchUrl(
            Uri.parse((data.url ?? data.originalUrl)!),
            mode: LaunchMode.externalApplication,
          );
        },
        child: Center(
          child: UrlPreview(
            data: _displayedLinks[index].payloadData!.urlData!.first,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final hideWhenEmpty = widget.expressive && !widget.fullPage && !_isLoading && _displayedLinks.isEmpty;

    return SliverMainAxisGroup(
      slivers: [
        if (!widget.fullPage)
          SliverToBoxAdapter(
            child: AttachmentSectionHeader(
              title: widget.expressive
                  ? AttachmentSectionType.links.expressiveSectionLabel
                  : AttachmentSectionType.links.sectionLabel,
              expressive: widget.expressive,
              onShowMore: () => ConversationAttachments.open(
                context,
                chat: widget.chat,
                section: AttachmentSectionType.links,
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
        if (_isLoading)
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
        else if (_displayedLinks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Center(
                child: Text(
                  links.isEmpty ? "No links" : "No matching links",
                  style: context.theme.textTheme.bodyMedium!.copyWith(
                    color: context.theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          )
        else ...[
          Obx(() => SliverPadding(
                padding: attachmentSectionListPadding(
                  fullPage: widget.fullPage,
                  iOS: SettingsSvc.settings.skin.value == Skins.iOS,
                  expressive: widget.expressive,
                  top: widget.fullPage ? 10 : 0,
                ),
                sliver: SliverToBoxAdapter(
                  child: MasonryGridView.count(
                    crossAxisCount: max(2, NavigationSvc.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) => _buildLinkTile(context, index),
                    itemCount: _visibleCount,
                  ),
                ),
              )),
          if (widget.fullPage && _displayCount < _displayedLinks.length)
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
