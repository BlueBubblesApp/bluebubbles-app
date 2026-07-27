import 'dart:math';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachment_section_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget that handles locations section display
class LocationsSection extends StatefulWidget {
  final Chat chat;
  final List<Attachment> locations;
  final bool isLoading;
  final bool fullPage;
  final bool expressive;
  final AttachmentFiltersState filters;

  const LocationsSection({
    super.key,
    required this.chat,
    required this.locations,
    this.isLoading = false,
    this.fullPage = false,
    this.expressive = false,
    this.filters = const AttachmentFiltersState(),
  });

  @override
  State<LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<LocationsSection> {
  static const int _chunkSize = 10;
  late int _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
  bool _loadingMore = false;

  List<Attachment> get _displayedLocations {
    if (!widget.fullPage) return widget.locations;
    return applyFileFilters(
      widget.locations,
      typeFilter: FileTypeFilter.all,
      senderFilter: widget.filters.senderFilter,
      sinceDate: widget.filters.sinceDate,
    );
  }

  @override
  void didUpdateWidget(LocationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations.length != widget.locations.length) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.fullPage != widget.fullPage || oldWidget.filters != widget.filters) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
  }

  int get _visibleCount {
    if (widget.fullPage) return min(_displayCount, _displayedLocations.length);
    return min(kAttachmentPreviewLimit, _displayedLocations.length);
  }

  void _loadMore() {
    if (_loadingMore || _displayCount >= _displayedLocations.length) return;
    _loadingMore = true;
    setState(() => _displayCount = min(_displayCount + _chunkSize, _displayedLocations.length));
    _loadingMore = false;
  }

  Widget _buildLocationTile(BuildContext context, int index) {
    if (AttachmentsSvc.getContent(_displayedLocations[index]) is! PlatformFile) {
      return const Text("Failed to load location!");
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
          final attachment = _displayedLocations[index];
          if (attachment.mimeType?.contains("location") ?? false) {
            final location = attachment.transferName;
            if (location != null) {
              final uri = Uri.parse("https://maps.google.com/?q=$location");
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        child: Center(
          child: UrlPreview(
            data: UrlPreviewData(
              title:
                  "Location from ${DateFormat.yMd().format(_displayedLocations[index].message.target!.dateCreated!)}",
              siteName: "Tap to open",
            ),
            file: AttachmentsSvc.getContent(_displayedLocations[index]),
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

    final hideWhenEmpty = widget.expressive && !widget.fullPage && !widget.isLoading && _displayedLocations.isEmpty;

    return SliverMainAxisGroup(
      slivers: [
        if (!widget.fullPage)
          SliverToBoxAdapter(
            child: AttachmentSectionHeader(
              title: widget.expressive
                  ? AttachmentSectionType.locations.expressiveSectionLabel
                  : AttachmentSectionType.locations.sectionLabel,
              expressive: widget.expressive,
              onShowMore: () => ConversationAttachments.open(
                context,
                chat: widget.chat,
                section: AttachmentSectionType.locations,
                locations: widget.locations,
              ),
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
        else if (_displayedLocations.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Center(
                child: Text(
                  widget.locations.isEmpty ? "No locations" : "No matching locations",
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
                    itemBuilder: (context, index) => _buildLocationTile(context, index),
                    itemCount: _visibleCount,
                  ),
                ),
              )),
          if (widget.fullPage && _displayCount < _displayedLocations.length)
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
