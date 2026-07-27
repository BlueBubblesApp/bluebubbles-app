import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

typedef AttachmentFiltersChanged = void Function(AttachmentFiltersState filters);

/// Opens the shared attachment filters bottom sheet.
void showAttachmentFiltersSheet(
  BuildContext context, {
  required Chat chat,
  required Color tileColor,
  required AttachmentFiltersState filters,
  required AttachmentFiltersChanged onChanged,
  AttachmentFiltersTypeSection typeSection = AttachmentFiltersTypeSection.media,
  bool expressive = false,
}) {
  HapticFeedback.lightImpact();
  final chipRadius = expressive ? M3EShapes.radiusLg : null;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      var currentFilters = filters;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final labelStyle = TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          );
          final sectionLabelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              );
          final primaryColor = Theme.of(context).colorScheme.primary;

          void updateFilters({
            MediaFilter? type,
            FileTypeFilter? fileType,
            MediaSenderFilter? sender,
            DateTime? date,
            bool clearDate = false,
          }) {
            currentFilters = currentFilters.copyWith(
              mediaFilter: type,
              fileTypeFilter: fileType,
              senderFilter: sender,
              sinceDate: date,
              clearSinceDate: clearDate,
            );
            onChanged(currentFilters);
            setSheetState(() {});
          }

          final showFromYou = currentFilters.senderFilter.kind != MediaSenderFilterKind.fromOthers &&
              currentFilters.senderFilter.kind != MediaSenderFilterKind.participant;
          final showFromOthers = chat.isGroup &&
              currentFilters.senderFilter.kind != MediaSenderFilterKind.fromYou &&
              currentFilters.senderFilter.kind != MediaSenderFilterKind.participant;
          final showParticipants = currentFilters.senderFilter.kind != MediaSenderFilterKind.fromYou &&
              currentFilters.senderFilter.kind != MediaSenderFilterKind.fromOthers;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: tileColor,
            ),
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "Filters",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, left: 10),
                    child: Text("Sender", style: sectionLabelStyle),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                      child: _FilterChipWrap(
                        children: [
                          if (showFromYou)
                            BBChip(
                              borderRadius: chipRadius,
                              showCheckmark: true,
                              selected: currentFilters.senderFilter.kind == MediaSenderFilterKind.fromYou,
                              checkmarkColor: primaryColor,
                              avatar: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: const ContactAvatarWidget(
                                  handle: null,
                                  size: 24,
                                  editable: false,
                                  scaleSize: false,
                                  borderThickness: 0,
                                ),
                              ),
                              label: Text("From You", style: labelStyle),
                              onSelected: (selected) {
                                updateFilters(
                                  sender: selected ? const MediaSenderFilter.fromYou() : const MediaSenderFilter.any(),
                                );
                              },
                            ),
                          if (showFromOthers)
                            BBChip(
                              borderRadius: chipRadius,
                              showCheckmark: true,
                              selected: currentFilters.senderFilter.kind == MediaSenderFilterKind.fromOthers,
                              checkmarkColor: primaryColor,
                              label: Text("From Others", style: labelStyle),
                              onSelected: (selected) {
                                updateFilters(
                                  sender:
                                      selected ? const MediaSenderFilter.fromOthers() : const MediaSenderFilter.any(),
                                );
                              },
                            ),
                          if (showParticipants)
                            for (final handle in chat.handles)
                              if (currentFilters.senderFilter.kind != MediaSenderFilterKind.participant ||
                                  currentFilters.senderFilter.participant?.address == handle.address)
                                _ParticipantSenderChip(
                                  handle: handle,
                                  labelStyle: labelStyle,
                                  primaryColor: primaryColor,
                                  borderRadius: chipRadius,
                                  selected: currentFilters.senderFilter.kind == MediaSenderFilterKind.participant &&
                                      currentFilters.senderFilter.participant?.address == handle.address,
                                  onSelected: (selected) {
                                    updateFilters(
                                      sender: selected
                                          ? MediaSenderFilter.participant(handle)
                                          : const MediaSenderFilter.any(),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                  if (typeSection == AttachmentFiltersTypeSection.media) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 10),
                      child: Text("Type", style: sectionLabelStyle),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: [
                            if (currentFilters.mediaFilter != MediaFilter.videos)
                              BBChip(
                                borderRadius: chipRadius,
                                showCheckmark: true,
                                selected: currentFilters.mediaFilter == MediaFilter.images,
                                checkmarkColor: primaryColor,
                                label: Text(MediaFilter.images.label, style: labelStyle),
                                onSelected: (selected) {
                                  updateFilters(type: selected ? MediaFilter.images : MediaFilter.all);
                                },
                              ),
                            if (currentFilters.mediaFilter != MediaFilter.images)
                              BBChip(
                                borderRadius: chipRadius,
                                showCheckmark: true,
                                selected: currentFilters.mediaFilter == MediaFilter.videos,
                                checkmarkColor: primaryColor,
                                label: Text("Videos", style: labelStyle),
                                onSelected: (selected) {
                                  updateFilters(type: selected ? MediaFilter.videos : MediaFilter.all);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (typeSection == AttachmentFiltersTypeSection.files) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 10),
                      child: Text("Types", style: sectionLabelStyle),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: [
                            if (currentFilters.fileTypeFilter != FileTypeFilter.audio &&
                                currentFilters.fileTypeFilter != FileTypeFilter.other)
                              BBChip(
                                borderRadius: chipRadius,
                                showCheckmark: true,
                                selected: currentFilters.fileTypeFilter == FileTypeFilter.documents,
                                checkmarkColor: primaryColor,
                                label: Text("Documents", style: labelStyle),
                                onSelected: (selected) {
                                  updateFilters(fileType: selected ? FileTypeFilter.documents : FileTypeFilter.all);
                                },
                              ),
                            if (currentFilters.fileTypeFilter != FileTypeFilter.documents &&
                                currentFilters.fileTypeFilter != FileTypeFilter.other)
                              BBChip(
                                borderRadius: chipRadius,
                                showCheckmark: true,
                                selected: currentFilters.fileTypeFilter == FileTypeFilter.audio,
                                checkmarkColor: primaryColor,
                                label: Text("Audio", style: labelStyle),
                                onSelected: (selected) {
                                  updateFilters(fileType: selected ? FileTypeFilter.audio : FileTypeFilter.all);
                                },
                              ),
                            if (currentFilters.fileTypeFilter != FileTypeFilter.documents &&
                                currentFilters.fileTypeFilter != FileTypeFilter.audio)
                              BBChip(
                                borderRadius: chipRadius,
                                showCheckmark: true,
                                selected: currentFilters.fileTypeFilter == FileTypeFilter.other,
                                checkmarkColor: primaryColor,
                                label: Text("Other", style: labelStyle),
                                onSelected: (selected) {
                                  updateFilters(fileType: selected ? FileTypeFilter.other : FileTypeFilter.all);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 16, left: 10),
                    child: Text("Date", style: sectionLabelStyle),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 0,
                        children: [
                          BBChip(
                            borderRadius: chipRadius,
                            avatar: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.calendar_today_outlined,
                                color: primaryColor,
                                size: 12,
                              ),
                            ),
                            label: currentFilters.sinceDate != null
                                ? Text(
                                    "Since ${buildFullDate(currentFilters.sinceDate!, includeTime: currentFilters.sinceDate!.isToday(), useTodayYesterday: true)}",
                                    style: labelStyle,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text("Filter by Date", style: labelStyle),
                            onDeleted: currentFilters.sinceDate == null ? null : () => updateFilters(clearDate: true),
                            onPressed: () async {
                              final picked = await showTimeframePicker(
                                "Since When?",
                                context,
                                customTimeframes: {
                                  "1 Hour": 1,
                                  "1 Day": 24,
                                  "1 Week": 168,
                                  "1 Month": 720,
                                  "6 Months": 4320,
                                  "1 Year": 8760,
                                },
                                selectionSuffix: "Ago",
                                useTodayYesterday: true,
                              );
                              if (picked != null) {
                                updateFilters(date: picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Wraps filter chips with a max width of ~half the row so long sender labels
/// ellipsize instead of forcing one chip per line.
class _FilterChipWrap extends StatelessWidget {
  final List<Widget> children;

  const _FilterChipWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final chipMaxWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: chipMaxWidth),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _ParticipantSenderChip extends StatelessWidget {
  final Handle handle;
  final TextStyle labelStyle;
  final Color primaryColor;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final BorderRadius? borderRadius;

  const _ParticipantSenderChip({
    required this.handle,
    required this.labelStyle,
    required this.primaryColor,
    required this.selected,
    required this.onSelected,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final handleState = HandleSvc.getOrCreateHandleState(handle);

    return Obx(() {
      final displayName = handleState.displayName.value ?? handle.address;
      return BBChip(
        borderRadius: borderRadius,
        showCheckmark: true,
        selected: selected,
        checkmarkColor: primaryColor,
        avatar: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: ContactAvatarWidget(
            handle: handle,
            size: 24,
            editable: false,
            scaleSize: false,
            borderThickness: 0,
          ),
        ),
        label: Text("From $displayName", style: labelStyle, overflow: TextOverflow.ellipsis),
        onSelected: onSelected,
      );
    });
  }
}

/// Filter button with badge, matching the search filters trigger.
class AttachmentFiltersButton extends StatelessWidget {
  /// Trailing inset of the tune icon within the 48px [IconButton] touch target.
  static const double _iconTrailingInset = 12;

  final AttachmentFiltersState filters;
  final AttachmentFiltersTypeSection typeSection;
  final Color? iconColor;
  final VoidCallback onPressed;

  const AttachmentFiltersButton({
    super.key,
    required this.filters,
    required this.typeSection,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = filters.hasActiveFilter(typeSection);
    final color = iconColor ?? Theme.of(context).colorScheme.primary;

    return Obx(() {
      final horizontalPadding = attachmentSectionHorizontalPadding(
        fullPage: true,
        iOS: SettingsSvc.settings.skin.value == Skins.iOS,
      ).toDouble();
      final rightMargin = (horizontalPadding - _iconTrailingInset).clamp(0.0, double.infinity);

      return Padding(
        padding: EdgeInsets.only(right: rightMargin),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (hasActiveFilter)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onPressed();
                },
                icon: Icon(Icons.tune, color: color),
              ),
            ],
          ),
        ),
      );
    });
  }
}
