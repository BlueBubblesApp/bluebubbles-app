import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/services/services.dart';
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

class CupertinoConversationListState extends OptimizedState<CupertinoConversationList> {
  bool get showArchived => widget.parentController.showArchivedChats;

  bool get showUnknown => widget.parentController.showUnknownSenders;

  Color get backgroundColor => ss.settings.windowEffect.value == WindowEffect.disabled ? context.theme.colorScheme.background : Colors.transparent;

  ConversationListController get controller => widget.parentController;

  @override
  void initState() {
    super.initState();
    // update widget when background color changes
    if (kIsDesktop) {
      ss.settings.windowEffect.listen((WindowEffect effect) {
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ss.settings.windowEffect.value != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background,
      extendBodyBehindAppBar: !showArchived && !showUnknown,
      floatingActionButton: Obx(() => !ss.settings.moveChatCreatorToHeader.value && !showArchived && !showUnknown
          ? ConversationListFAB(parentController: controller)
          : const SizedBox.shrink()),
      appBar: showArchived || showUnknown
          ? AppBar(
              leading: buildBackButton(context),
              elevation: 0,
              systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              centerTitle: true,
              backgroundColor: Colors.transparent,
              title: Text(showArchived ? "Archive" : "Unknown Senders", style: context.theme.textTheme.titleLarge),
            )
          : null,
      body: Stack(
        children: [
          ScrollbarWrapper(
            showScrollbar: true,
            controller: controller.iosScrollController,
            child: Obx(() => CustomScrollView(
                  controller: controller.iosScrollController,
                  physics: ts.scrollPhysics,
                  slivers: <Widget>[
                    if (!showArchived && !showUnknown) CupertinoHeader(controller: controller),
                    Obx(() {
                      ns.listener.value;
                      final _chats = GlobalChatService.chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).bigPinHelper(true);

                      if (_chats.isEmpty) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }

                      int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
                          ? ss.settings.pinRowsPortrait.value
                          : ss.settings.pinRowsLandscape.value;
                      int colCount = kIsDesktop ? ss.settings.pinColumnsLandscape.value : ss.settings.pinColumnsPortrait.value;
                      int pinCount = _chats.length;
                      int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
                      int maxOnPage = rowCount * colCount;
                      PageController _controller = PageController();
                      int _pageCount = (pinCount / maxOnPage).ceil();
                      int _filledPageCount = (pinCount / maxOnPage).floor();

                      return SliverPadding(
                        padding: const EdgeInsets.only(top: 10),
                        sliver: SliverToBoxAdapter(
                          child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                            double availableWidth = constraints.maxWidth - 50;
                            double spaceBetween = (colCount - 1) * 30;
                            double maxWidth = ((availableWidth - spaceBetween) / colCount).floorToDouble();
                            TextStyle style = context.theme.textTheme.bodyMedium!;
                            double height = usedRowCount * (maxWidth * 1.15 + 10 + style.height! * style.fontSize! * 2);
                            // avatar only
                            if (ns.isAvatarOnly(context)) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _chats.length,
                                    findChildIndexCallback: (key) => findChildIndexByKey(_chats, key, (item) => item.guid),
                                    itemBuilder: (context, index) {
                                      final chat = _chats[index];
                                      return Center(
                                        heightFactor: 1,
                                        child: ConversationTile(
                                          key: Key(chat.guid),
                                          chatGuid: chat.guid,
                                          controller: controller,
                                        ),
                                      );
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Divider(
                                      color: context.theme.colorScheme.outline.withOpacity(0.5),
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
                                  height: height,
                                  child: PageView.builder(
                                    clipBehavior: Clip.none,
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    scrollDirection: Axis.horizontal,
                                    controller: _controller,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          alignment: _pageCount > 1 ? WrapAlignment.start : WrapAlignment.center,
                                          children: List.generate(
                                            index < _filledPageCount ? maxOnPage : _chats.length % maxOnPage,
                                            (_index) {
                                              return PinnedConversationTile(
                                                key: Key(_chats[index * maxOnPage + _index].guid.toString()),
                                                chatGuid: _chats[index * maxOnPage + _index].guid,
                                                controller: controller,
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
                                          dotWidth: maxWidth * 0.1,
                                          dotHeight: maxWidth * 0.1,
                                          spacing: maxWidth * 0.07,
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
                    FutureBuilder(
                      future: GlobalChatService.chatsLoadedFuture.future,
                      builder: (context, snapshot) {
                        return Obx(() {
                          final _chats = GlobalChatService.chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).bigPinHelper(false);

                          if (!GlobalChatService.chatsLoaded || _chats.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 50.0),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          !GlobalChatService.chatsLoaded
                                              ? "Loading chats..."
                                              : showArchived
                                                  ? "You have no archived chats"
                                                  : showUnknown
                                                      ? "You have no messages from unknown senders :)"
                                                      : "You have no chats :(",
                                          style: context.textTheme.labelLarge,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (!GlobalChatService.chatsLoaded) buildProgressIndicator(context, size: 15),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final chat = GlobalChatService.chats.firstWhere((e) => e.guid == _chats[index].guid);
                                final child = ConversationTile(
                                  key: Key(chat.guid.toString()),
                                  chatGuid: chat.guid,
                                  controller: controller,
                                );
                                final separator = Obx(() => !ss.settings.hideDividers.value
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 20),
                                        child: Divider(
                                          color: context.theme.colorScheme.outline.withOpacity(0.5),
                                          thickness: 0.5,
                                          height: 0.5,
                                        ),
                                      )
                                    : const SizedBox.shrink());

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    child,
                                    separator,
                                  ],
                                );
                              },
                              childCount: _chats.length,
                            ),
                          );
                        });
                      }
                    )
                  ],
                )),
          ),
          if (!showArchived && !showUnknown) CupertinoMiniHeader(controller: controller),
        ],
      ),
    );
  }
}
