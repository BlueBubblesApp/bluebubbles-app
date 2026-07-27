import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/material/chat_detail_theme.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachments_loader.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/filters/media_filters_sheet.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/documents/documents_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/links/links_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/locations/locations_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/media/media_grid_section.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConversationAttachments extends StatefulWidget {
  final Chat chat;
  final AttachmentSectionType section;
  final List<Attachment>? media;
  final List<Attachment>? docs;
  final List<Attachment>? locations;

  const ConversationAttachments({
    super.key,
    required this.chat,
    required this.section,
    this.media,
    this.docs,
    this.locations,
  });

  static void open(
    BuildContext context, {
    required Chat chat,
    required AttachmentSectionType section,
    List<Attachment>? media,
    List<Attachment>? docs,
    List<Attachment>? locations,
  }) {
    NavigationSvc.push(
      context,
      ConversationAttachments(
        chat: chat,
        section: section,
        media: media,
        docs: docs,
        locations: locations,
      ),
    );
  }

  @override
  State<ConversationAttachments> createState() => _ConversationAttachmentsState();
}

class _ConversationAttachmentsState extends State<ConversationAttachments> with ThemeHelpers {
  List<Attachment> media = <Attachment>[];
  List<Attachment> docs = <Attachment>[];
  List<Attachment> locations = <Attachment>[];
  bool isLoadingAttachments = false;
  final RxList<String> selected = <String>[].obs;
  AttachmentFiltersState _filters = const AttachmentFiltersState();

  void _onFiltersChanged(AttachmentFiltersState filters) {
    if (_filters == filters) return;
    setState(() {
      _filters = filters;
      if (widget.section == AttachmentSectionType.media) {
        final filtered = applyMediaFilters(
          media,
          typeFilter: filters.mediaFilter,
          senderFilter: filters.senderFilter,
          sinceDate: filters.sinceDate,
        );
        selected.removeWhere((guid) => !filtered.any((e) => e.guid != null && e.guid == guid));
      }
    });
  }

  void _onMediaFilterChanged(MediaFilter filter) => _onFiltersChanged(_filters.copyWith(mediaFilter: filter));

  @override
  void initState() {
    super.initState();
    if (widget.media != null) media = widget.media!;
    if (widget.docs != null) docs = widget.docs!;
    if (widget.locations != null) locations = widget.locations!;
    if (_needsLoadForCurrentSection()) {
      isLoadingAttachments = true;
    }
  }

  bool _needsLoadForCurrentSection() {
    switch (widget.section) {
      case AttachmentSectionType.media:
        return widget.media == null;
      case AttachmentSectionType.documents:
        return widget.docs == null;
      case AttachmentSectionType.locations:
        return widget.locations == null;
      case AttachmentSectionType.links:
        return false;
    }
  }

  void onAttachmentsLoaded(
      List<Attachment> loadedMedia, List<Attachment> loadedDocs, List<Attachment> loadedLocations) {
    if (mounted) {
      setState(() {
        media = loadedMedia;
        docs = loadedDocs;
        locations = loadedLocations;
        isLoadingAttachments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getOrCreateChatState(widget.chat);
    return ChatStateScope(
      chatState: chatState,
      child: Obx(() {
        final chatDetailTheme = ChatDetailTheme.resolve(context, widget.chat);

        return Theme(
          data: chatDetailTheme.theme,
          child: Obx(() => SettingsScaffold(
                headerColor: chatDetailTheme.headerColor,
                title: widget.section.pageTitle,
                tileColor: chatDetailTheme.tileColor,
                initialHeader: null,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                actions: _buildAppBarActions(context, chatDetailTheme.tileColor),
                bodySlivers: [
                  if (isLoadingAttachments)
                    SliverToBoxAdapter(
                      child: AttachmentsLoader(
                        chat: widget.chat,
                        onAttachmentsLoaded: onAttachmentsLoaded,
                      ),
                    ),
                  ..._buildSectionSlivers(),
                  const SliverPadding(padding: EdgeInsets.only(top: 50)),
                ],
              )),
        );
      }),
    );
  }

  List<Widget> _buildSectionSlivers() {
    switch (widget.section) {
      case AttachmentSectionType.media:
        return [
          MediaGridSection(
            chat: widget.chat,
            media: media,
            selected: selected,
            isLoading: isLoadingAttachments,
            fullPage: true,
            crossAxisCount: 3,
            mediaFilter: _filters.mediaFilter,
            senderFilter: _filters.senderFilter,
            sinceDate: _filters.sinceDate,
            onMediaFilterChanged: _onMediaFilterChanged,
          ),
        ];
      case AttachmentSectionType.links:
        return [
          LinksSection(
            chat: widget.chat,
            fullPage: true,
            senderFilter: _filters.senderFilter,
            sinceDate: _filters.sinceDate,
          ),
        ];
      case AttachmentSectionType.locations:
        return [
          LocationsSection(
            chat: widget.chat,
            locations: locations,
            isLoading: isLoadingAttachments,
            fullPage: true,
            filters: _filters,
          ),
        ];
      case AttachmentSectionType.documents:
        return [
          DocumentsSection(
            chat: widget.chat,
            docs: docs,
            isLoading: isLoadingAttachments,
            fullPage: true,
            filters: _filters,
          ),
        ];
    }
  }

  List<Widget> _buildAppBarActions(BuildContext context, Color scaffoldTileColor) {
    switch (widget.section) {
      case AttachmentSectionType.media:
        return [
          AttachmentFiltersButton(
            filters: _filters,
            typeSection: AttachmentFiltersTypeSection.media,
            onPressed: () => showAttachmentFiltersSheet(
              context,
              chat: widget.chat,
              tileColor: scaffoldTileColor,
              filters: _filters,
              onChanged: _onFiltersChanged,
              typeSection: AttachmentFiltersTypeSection.media,
            ),
          ),
          Obx(() {
            if (selected.isNotEmpty) {
              return IconButton(
                icon: Icon(iOS ? CupertinoIcons.xmark : Icons.close, color: context.theme.colorScheme.onSurface),
                onPressed: () => selected.clear(),
              );
            }
            return const SizedBox.shrink();
          }),
          Obx(() {
            if (selected.isNotEmpty) {
              return IconButton(
                icon: Icon(iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                    color: context.theme.colorScheme.onSurface),
                onPressed: () {
                  final attachments = media.where((e) => selected.contains(e.guid!));
                  for (final a in attachments) {
                    final file = AttachmentsSvc.getContent(a, autoDownload: false);
                    if (file is PlatformFile) {
                      AttachmentsSvc.saveToDisk(file);
                    }
                  }
                },
              );
            }
            return const SizedBox.shrink();
          }),
        ];
      case AttachmentSectionType.links:
        return [
          AttachmentFiltersButton(
            filters: _filters,
            typeSection: AttachmentFiltersTypeSection.none,
            onPressed: () => showAttachmentFiltersSheet(
              context,
              chat: widget.chat,
              tileColor: scaffoldTileColor,
              filters: _filters,
              onChanged: _onFiltersChanged,
              typeSection: AttachmentFiltersTypeSection.none,
            ),
          ),
        ];
      case AttachmentSectionType.documents:
        return [
          AttachmentFiltersButton(
            filters: _filters,
            typeSection: AttachmentFiltersTypeSection.files,
            onPressed: () => showAttachmentFiltersSheet(
              context,
              chat: widget.chat,
              tileColor: scaffoldTileColor,
              filters: _filters,
              onChanged: _onFiltersChanged,
              typeSection: AttachmentFiltersTypeSection.files,
            ),
          ),
        ];
      case AttachmentSectionType.locations:
        return [
          AttachmentFiltersButton(
            filters: _filters,
            typeSection: AttachmentFiltersTypeSection.none,
            onPressed: () => showAttachmentFiltersSheet(
              context,
              chat: widget.chat,
              tileColor: scaffoldTileColor,
              filters: _filters,
              onChanged: _onFiltersChanged,
              typeSection: AttachmentFiltersTypeSection.none,
            ),
          ),
        ];
    }
  }
}
