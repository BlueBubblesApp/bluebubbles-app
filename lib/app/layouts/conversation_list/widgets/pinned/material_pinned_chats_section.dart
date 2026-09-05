import 'dart:math';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// The Material skin's pinned chats: a paged grid of large, shape-masked
/// avatars above the conversation list.
///
/// Material's stock behaviour is Google Messages': pinned chats just sort to the
/// top of the same list, so a handful of pins is the entire first screen. This
/// lifts them out into their own fixed-height section — the layout the iOS skin
/// already uses — and swaps the circular avatar frame for an abstract shape from
/// the M3 Expressive shape library.
///
/// Grid geometry comes from the same `pinRows*` / `pinColumns*` settings the iOS
/// pinned section honours; overflow paginates horizontally.
class MaterialPinnedChatsSection extends StatefulWidget {
  const MaterialPinnedChatsSection({
    super.key,
    required this.controller,
    this.showArchived = false,
    this.showUnknown = false,
  });

  final ConversationListController controller;
  final bool showArchived;
  final bool showUnknown;

  /// Whether the expressive pinned section is showing.
  ///
  /// Reads observables, so call it inside an `Obx`. The conversation list calls
  /// this too — when the section is up, the list must stop rendering pinned
  /// chats as ordinary rows or every pin appears twice.
  ///
  /// Material only for now: Samsung's much taller header leaves too little room
  /// above the fold for a second fixed-height band.
  static bool get isEnabled =>
      SettingsSvc.settings.enhancedPinnedTiles.value && SettingsSvc.settings.skin.value == Skins.Material;

  @override
  State<MaterialPinnedChatsSection> createState() => _MaterialPinnedChatsSectionState();
}

class _MaterialPinnedChatsSectionState extends State<MaterialPinnedChatsSection> {
  final PageController _pageController = PageController();

  // Per-tile overhead baked into PinnedConversationTile, needed here to turn the
  // available width into an avatar diameter. Keep in sync with that widget's
  // margins/padding if they change.
  static const double _tileHOverhead = 42.0;
  static const double _tileVOverhead = 17.0;
  // Font metrics vary by device enough that an exact estimate can come in short
  // and let the bottom row bleed into the list below it.
  static const double _tileVSafetyBuffer = 4.0;
  static const double _pageHPadding = 20.0;
  static const double _maxAvatarSize = 120.0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!MaterialPinnedChatsSection.isEnabled) return const SizedBox.shrink();
      // Observed so the section rebuilds when a chat is pinned, unpinned or reordered.
      // ignore: unused_local_variable
      final version = ChatsSvc.chatListVersion.value;
      if (!ChatsSvc.loadedFirstChatBatch.value) return const SizedBox.shrink();

      final chats = ChatsSvc.getFilteredChats(
        showArchived: widget.showArchived,
        showUnknown: widget.showUnknown,
        pinnedOnly: true,
        filters: ChatsSvc.chatListFilters.value,
      );
      if (chats.isEmpty) return const SizedBox.shrink();

      final rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
          ? SettingsSvc.settings.pinRowsPortrait.value
          : SettingsSvc.settings.pinRowsLandscape.value;
      final colCount = kIsDesktop
          ? SettingsSvc.settings.pinColumnsLandscape.value
          : SettingsSvc.settings.pinColumnsPortrait.value;
      if (rowCount < 1 || colCount < 1) return const SizedBox.shrink();

      final pinCount = chats.length;
      final maxOnPage = rowCount * colCount;
      final usedRowCount = min((pinCount / colCount).ceil(), rowCount);
      final pageCount = (pinCount / maxOnPage).ceil();
      final singleRow = usedRowCount == 1;

      return LayoutBuilder(
        builder: (context, constraints) {
          final rawAvatarSize = (constraints.maxWidth - _pageHPadding - colCount * _tileHOverhead) / colCount;
          final avatarSize = min(rawAvatarSize, _maxAvatarSize);
          // A very narrow window with a high column count can drive this negative.
          if (avatarSize <= 0) return const SizedBox.shrink();
          final tileWidth = avatarSize + _tileHOverhead;

          final style = context.theme.textTheme.bodyMedium!;
          final textHeight = (style.height ?? 1.2) * (style.fontSize ?? 14);
          final tileHeight = avatarSize + textHeight + _tileVOverhead + _tileVSafetyBuffer;

          return Padding(
            padding: const EdgeInsets.only(top: M3ESpacing.sm, bottom: M3ESpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: usedRowCount * tileHeight,
                  child: PageView.builder(
                    clipBehavior: Clip.none,
                    physics: const AlwaysScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    controller: _pageController,
                    itemCount: pageCount,
                    itemBuilder: (context, pageIndex) {
                      final start = pageIndex * maxOnPage;
                      final pageChats = chats.sublist(start, min(start + maxOnPage, pinCount));

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: M3ESpacing.sm + 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: List.generate(usedRowCount, (rowIndex) {
                            final rowChats = pageChats.skip(rowIndex * colCount).take(colCount).toList();

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: singleRow ? MainAxisAlignment.center : MainAxisAlignment.start,
                              children: [
                                for (final Chat chat in rowChats)
                                  SizedBox(
                                    width: tileWidth,
                                    child: PinnedConversationTile(
                                      key: Key("${chat.guid}-material-pinned"),
                                      chat: chat,
                                      avatarSize: avatarSize,
                                      controller: widget.controller,
                                      expressive: true,
                                    ),
                                  ),
                                // Keep multi-row pages left-aligned against each other.
                                if (!singleRow)
                                  for (int i = rowChats.length; i < colCount; i++) SizedBox(width: tileWidth),
                              ],
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),
                if (pageCount > 1)
                  MouseRegion(
                    cursor: MouseCursor.defer,
                    hitTestBehavior: HitTestBehavior.deferToChild,
                    child: Padding(
                      padding: const EdgeInsets.only(top: M3ESpacing.xs, bottom: M3ESpacing.xs),
                      child: SmoothPageIndicator(
                        count: pageCount,
                        controller: _pageController,
                        onDotClicked: kIsDesktop || kIsWeb
                            ? (page) => _pageController.animateToPage(
                                page,
                                curve: M3EMotion.spatialDefault.curve,
                                duration: M3EMotion.spatialDefault.duration,
                              )
                            : null,
                        effect: ColorTransitionEffect(
                          activeDotColor: context.theme.colorScheme.primary,
                          dotColor: context.theme.colorScheme.outlineVariant,
                          dotWidth: 6,
                          dotHeight: 6,
                          spacing: 5,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: M3ESpacing.lg),
                  child: Divider(
                    color: context.theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    thickness: 1,
                    height: M3ESpacing.md,
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
