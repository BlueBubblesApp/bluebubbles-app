import 'dart:math';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/filters/custom_group_filter_chip_row.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:universal_io/io.dart';

class CupertinoConversationList extends StatefulWidget {
  const CupertinoConversationList({super.key, required this.parentController});

  final ConversationListController parentController;

  @override
  State<StatefulWidget> createState() => CupertinoConversationListState();
}

class CupertinoConversationListState extends State<CupertinoConversationList> with ThemeHelpers {
  bool get showArchived => widget.parentController.showArchivedChats;

  bool get showUnknown => widget.parentController.showUnknownSenders;

  Color get backgroundColor => SettingsSvc.settings.windowEffect.value == WindowEffect.disabled
      ? context.theme.colorScheme.surface
      : Colors.transparent;

  ConversationListController get controller => widget.parentController;

  @override
  void initState() {
    super.initState();

    // update widget when background color changes
    if (kIsDesktop) {
      SettingsSvc.settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
          ? Colors.transparent
          : context.theme.colorScheme.surface,
      extendBodyBehindAppBar: !showArchived && !showUnknown,
      floatingActionButton: Obx(() =>
          !SettingsSvc.settings.moveChatCreatorToHeader.value && !showArchived && !showUnknown
              ? ConversationListFAB(parentController: controller)
              : const SizedBox.shrink()),
      appBar: showArchived || showUnknown
          ? BBAppBar(
              titleText: showArchived ? "Archive" : "Unknown Senders",
              leading: buildBackButton(context),
              centerTitle: true,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: Stack(
        children: [
          ScrollbarWrapper(
            showScrollbar: true,
            controller: controller.iosScrollController,
            child: Obx(() => CustomScrollView(
                  controller: controller.iosScrollController,
                  physics: ThemeSvc.scrollPhysics,
                  slivers: <Widget>[
                    if (!showArchived && !showUnknown) CupertinoHeader(controller: controller),
                    if (!showArchived && !showUnknown)
                      const SliverToBoxAdapter(child: CustomGroupFilterChipRow()),
                    Obx(() {
                      // Force reactivity by accessing observable values first
                      // ignore: unused_local_variable
                      final loaded = ChatsSvc.loadedFirstChatBatch.value;
                      // Observe chatListVersion so pinned section rebuilds when a chat is pinned/unpinned
                      // ignore: unused_local_variable
                      final _version = ChatsSvc.chatListVersion.value;
                      NavigationSvc.listener.value;
                      final _chats = ChatsSvc.getFilteredChats(
                          showArchived: showArchived,
                          showUnknown: showUnknown,
                          pinnedOnly: true,
                          filters: ChatsSvc.chatListFilters.value);

                      if (_chats.isEmpty) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }

                      int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
                          ? SettingsSvc.settings.pinRowsPortrait.value
                          : SettingsSvc.settings.pinRowsLandscape.value;
                      int colCount = kIsDesktop
                          ? SettingsSvc.settings.pinColumnsLandscape.value
                          : SettingsSvc.settings.pinColumnsPortrait.value;
                      int pinCount = _chats.length;
                      int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
                      int maxOnPage = rowCount * colCount;
                      PageController _controller = PageController();
                      int _pageCount = (pinCount / maxOnPage).ceil();

                      return SliverPadding(
                        padding: const EdgeInsets.only(top: 10),
                        sliver: SliverToBoxAdapter(
                          child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                            // Horizontal overhead per tile: margins (4+4) + padding (11+11) + extra gap
                            const double tileHOverhead = 42.0;
                            // Vertical overhead per tile: AnimatedContainer margins (top:1) + padding (4+2)
                            //   + ChatTitle fixed padding (top:6 + bottom:4)
                            const double tileVOverhead = 17.0;
                            // PageView horizontal padding (10 each side)
                            const double pageHPadding = 20.0;

                            // Derive a clean, capped avatar size from the actual available width
                            final double rawAvatarSize =
                                (constraints.maxWidth - pageHPadding - colCount * tileHOverhead) / colCount;
                            final double avatarSize =
                                clampDouble(rawAvatarSize, 70.0, Platform.isAndroid ? 120.0 : 140.0);
                            final double tileWidth = avatarSize + tileHOverhead;

                            final TextStyle style = context.theme.textTheme.bodyMedium!;
                            final double textHeight = (style.height ?? 1.2) * (style.fontSize ?? 14);
                            final double tileHeight = avatarSize + textHeight + tileVOverhead;
                            final double totalHeight = usedRowCount * tileHeight;

                            // avatar only
                            if (NavigationSvc.isAvatarOnly(context)) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _chats.length,
                                    findChildIndexCallback: (key) =>
                                        findChildIndexByKey(_chats, key, (item) => item.guid),
                                    itemBuilder: (context, index) {
                                      final chat = _chats[index];
                                      return Center(
                                        heightFactor: 1,
                                        child: ConversationTile(
                                          key: Key(chat.guid),
                                          chat: chat,
                                          controller: controller,
                                        ),
                                      );
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Divider(
                                      color: context.theme.colorScheme.outline.withValues(alpha: 0.5),
                                      thickness: 2,
                                      height: 2,
                                    ),
                                  )
                                ],
                              );
                            }

                            return Column(
                              children: <Widget>[
                                SizedBox(
                                  height: totalHeight,
                                  child: PageView.builder(
                                    clipBehavior: Clip.none,
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    scrollDirection: Axis.horizontal,
                                    controller: _controller,
                                    itemCount: _pageCount,
                                    itemBuilder: (context, pageIndex) {
                                      final int start = pageIndex * maxOnPage;
                                      final List<Chat> pageChats =
                                          _chats.sublist(start, min(start + maxOnPage, pinCount));

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(usedRowCount, (rowIndex) {
                                            final int rowStart = rowIndex * colCount;
                                            final List<Chat> rowChats =
                                                pageChats.skip(rowStart).take(colCount).toList();
                                            final bool singleRow = usedRowCount == 1;

                                            return Row(
                                              mainAxisAlignment:
                                                  singleRow ? MainAxisAlignment.center : MainAxisAlignment.start,
                                              children: [
                                                for (final chat in rowChats)
                                                  SizedBox(
                                                    width: tileWidth,
                                                    child: PinnedConversationTile(
                                                      key: Key(chat.guid),
                                                      chat: chat,
                                                      avatarSize: avatarSize,
                                                      controller: controller,
                                                    ),
                                                  ),
                                                // Fill empty slots in multi-row mode so rows align
                                                if (!singleRow)
                                                  for (int i = rowChats.length; i < colCount; i++)
                                                    SizedBox(width: tileWidth),
                                              ],
                                            );
                                          }),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_pageCount > 1)
                                  MouseRegion(
                                    cursor: MouseCursor.defer,
                                    hitTestBehavior: HitTestBehavior.deferToChild,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: SmoothPageIndicator(
                                        count: _pageCount,
                                        controller: _controller,
                                        onDotClicked: kIsDesktop || kIsWeb
                                            ? (page) => _controller.animateToPage(
                                                  page,
                                                  curve: Curves.linear,
                                                  duration: const Duration(milliseconds: 150),
                                                )
                                            : null,
                                        effect: ColorTransitionEffect(
                                          activeDotColor: context.theme.colorScheme.primary,
                                          dotColor: context.theme.colorScheme.outline,
                                          dotWidth: avatarSize * 0.1,
                                          dotHeight: avatarSize * 0.1,
                                          spacing: avatarSize * 0.07,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ),
                      );
                    }),
                    Obx(() {
                      // Force reactivity by accessing observable values first
                      final loaded = ChatsSvc.loadedFirstChatBatch.value;
                      // Observe chat list version to trigger rebuild when order changes
                      final _ = ChatsSvc.chatListVersion.value;
                      final _chats = ChatsSvc.getFilteredChats(
                          showArchived: showArchived,
                          showUnknown: showUnknown,
                          excludePinned: true,
                          filters: ChatsSvc.chatListFilters.value);

                      if (!loaded || _chats.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 50.0),
                              child: loaded
                                  ? buildEmptyChatListState(context,
                                      showArchived: showArchived,
                                      showUnknown: showUnknown,
                                      filters: ChatsSvc.chatListFilters.value)
                                  : Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Loading chats...",
                                            style: context.textTheme.labelLarge,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        buildProgressIndicator(context, size: 15),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        // Bottom padding is 20 to account for the bottom pill bar.
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final chat = ChatsSvc.findChatByGuid(_chats[index].guid)!;

                              // No need for Obx here - ConversationTile handles its own reactivity
                              final child = ConversationTile(
                                key: Key(chat.guid),
                                chat: chat,
                                controller: controller,
                              );

                              final separator = Obx(() => !SettingsSvc.settings.hideDividers.value
                                  ? Padding(
                                      padding:
                                          EdgeInsets.only(left: SettingsSvc.settings.denseChatTiles.value ? 70 : 82),
                                      child: Divider(
                                        color: context.theme.colorScheme.outline.withValues(alpha: 0.4),
                                        thickness: 0.5,
                                        height: 0.5,
                                      ),
                                    )
                                  : const SizedBox.shrink());

                              final topDivider = index == 0
                                  ? const SizedBox.shrink()
                                  : Obx(() => !SettingsSvc.settings.hideDividers.value
                                      ? Padding(
                                          padding: EdgeInsets.only(
                                              left: SettingsSvc.settings.denseChatTiles.value ? 70 : 82),
                                          child: Divider(
                                            color: context.theme.colorScheme.outline.withValues(alpha: 0.4),
                                            thickness: 0.5,
                                            height: 0.5,
                                          ),
                                        )
                                      : const SizedBox.shrink());

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  topDivider,
                                  child,
                                  separator,
                                ],
                              );
                            },
                            childCount: _chats.length,
                          ),
                        ),
                      );
                    }),
                  ],
                )),
          ),
          if (!showArchived && !showUnknown) CupertinoMiniHeader(controller: controller),
        ],
      ),
    );
  }
}
