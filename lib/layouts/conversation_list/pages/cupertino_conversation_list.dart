import 'dart:math';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class CupertinoConversationList extends StatefulWidget {
  const CupertinoConversationList({Key? key, required this.parentController});

  final ConversationListController parentController;

  @override
  State<StatefulWidget> createState() => CupertinoConversationListState();
}

class CupertinoConversationListState extends OptimizedState<CupertinoConversationList> with ThemeHelpers {
  final PageController _controller = PageController();

  bool get showArchived => widget.parentController.showArchivedChats;
  bool get showUnknown => widget.parentController.showUnknownSenders;
  Color get backgroundColor => SettingsManager().settings.windowEffect.value == WindowEffect.disabled
      ? context.theme.colorScheme.background
      : Colors.transparent;
  ConversationListController get controller => widget.parentController;

  @override
  void initState() {
    super.initState();
    // update widget when background color changes
    SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: !showArchived && !showUnknown,
      floatingActionButton: !SettingsManager().settings.moveChatCreatorToHeader.value
          && !showArchived
          && !showUnknown
          ? ConversationListFAB(parentController: controller)
          : null,
      appBar: showArchived || showUnknown ? AppBar(
        leading: buildBackButton(context),
        elevation: 0,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        centerTitle: true,
        backgroundColor: context.theme.colorScheme.background,
        title: Text(
          showArchived ? "Archive" : "Unknown Senders",
          style: context.theme.textTheme.titleLarge
        ),
      ) : null,
      body: Stack(
        children: [
          ScrollbarWrapper(
            showScrollbar: true,
            controller: controller.scrollController,
            child: Obx(() => CustomScrollView(
              controller: controller.scrollController,
              physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                  ? NeverScrollableScrollPhysics()
                  : ThemeManager().scrollPhysics,
              slivers: <Widget>[
                if (!showArchived && !showUnknown)
                  CupertinoHeader(controller: controller),
                Obx(() {
                  final chats = ChatBloc().chats
                      .archivedHelper(showArchived)
                      .unknownSendersHelper(showUnknown)
                      .bigPinHelper(true);

                  if (chats.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
                      ? SettingsManager().settings.pinRowsPortrait.value
                      : SettingsManager().settings.pinRowsLandscape.value;
                  int colCount = kIsDesktop
                      ? SettingsManager().settings.pinColumnsLandscape.value
                      : SettingsManager().settings.pinColumnsPortrait.value;
                  int pinCount = chats.length;
                  int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
                  int maxOnPage = rowCount * colCount;
                  int _pageCount = (pinCount / maxOnPage).ceil();
                  int _filledPageCount = (pinCount / maxOnPage).floor();
                  double spaceBetween = (colCount - 1) * 30;
                  double maxWidth = ((CustomNavigator.width(context) - 50 - spaceBetween) / colCount).floorToDouble();
                  TextStyle style = context.theme.textTheme.bodyMedium!;
                  double height =
                      usedRowCount * (maxWidth * 1.15 + 10 + style.height! * style.fontSize! * 2);

                  return SliverPadding(
                    padding: const EdgeInsets.only(top: 10),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: height,
                            child: PageView.builder(
                              clipBehavior: Clip.none,
                              physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              scrollDirection: Axis.horizontal,
                              controller: _controller,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: _pageCount > 1
                                        ? WrapAlignment.start : WrapAlignment.center,
                                    children: List.generate(
                                      index < _filledPageCount
                                          ? maxOnPage : chats.length % maxOnPage,
                                      (_index) {
                                        return PinnedConversationTile(
                                          key: Key(chats[index * maxOnPage + _index].guid.toString()),
                                          chat: chats[index * maxOnPage + _index],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              itemCount: _pageCount,
                            ),
                          ),
                          if (_pageCount > 1)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              hitTestBehavior: HitTestBehavior.deferToChild,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SmoothPageIndicator(
                                  count: _pageCount,
                                  controller: _controller,
                                  onDotClicked: kIsDesktop || kIsWeb ? (page) => _controller.animateToPage(
                                    page,
                                    curve: Curves.linear,
                                    duration: Duration(milliseconds: 150),
                                  ) : null,
                                  effect: ColorTransitionEffect(
                                    activeDotColor: context.theme.colorScheme.primary,
                                    dotColor: context.theme.colorScheme.outline,
                                    dotWidth: maxWidth * 0.1,
                                    dotHeight: maxWidth * 0.1,
                                    spacing: maxWidth * 0.07,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                Obx(() {
                  final chats = ChatBloc().chats
                      .archivedHelper(showArchived)
                      .unknownSendersHelper(showUnknown)
                      .bigPinHelper(false);

                  if (!ChatBloc().loadedChatBatch.value || chats.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50.0),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  !ChatBloc().loadedChatBatch.value
                                    ? "Loading chats..."
                                    : showArchived
                                    ? "You have no archived chats"
                                    : showUnknown
                                    ? "You have no messages from unknown senders :)"
                                    : "You have no chats :(",
                                  style: context.textTheme.labelLarge,
                                ),
                              ),
                              buildProgressIndicator(context, size: 15),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ConversationTile(
                          key: Key(chats[index].guid.toString()),
                          chat: chats[index],
                        );
                      },
                      childCount: chats.length,
                    ),
                  );
                }),
              ],
            )),
          ),
          if (!showArchived && !showUnknown)
            CupertinoMiniHeader(controller: controller),
        ],
      ),
    );
  }
}
