import 'dart:math';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/helpers/ui_helpers.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  Color get backgroundColor => ss.settings.windowEffect.value == WindowEffect.disabled
      ? context.theme.colorScheme.background
      : Colors.transparent;
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
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: !showArchived && !showUnknown,
      floatingActionButton: !ss.settings.moveChatCreatorToHeader.value
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
            controller: controller.iosScrollController,
            child: Obx(() => CustomScrollView(
              controller: controller.iosScrollController,
              physics: (ss.settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                  ? NeverScrollableScrollPhysics()
                  : ts.scrollPhysics,
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
                      ? ss.settings.pinRowsPortrait.value
                      : ss.settings.pinRowsLandscape.value;
                  int colCount = kIsDesktop
                      ? ss.settings.pinColumnsLandscape.value
                      : ss.settings.pinColumnsPortrait.value;
                  int pinCount = chats.length;
                  int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
                  int maxOnPage = rowCount * colCount;
                  int _pageCount = (pinCount / maxOnPage).ceil();
                  int _filledPageCount = (pinCount / maxOnPage).floor();
                  double spaceBetween = (colCount - 1) * 30;
                  double maxWidth = ((ns.width(context) - 50 - spaceBetween) / colCount).floorToDouble();
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
                              if (!ChatBloc().loadedChatBatch.value)
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
                        final chat = chats[index];
                        final child = ConversationTile(
                          key: Key(chat.guid.toString()),
                          chat: chat,
                          controller: controller,
                        );
                        final separator = Obx(() => !ss.settings.hideDividers.value ? Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Divider(
                            color: context.theme.colorScheme.outline.withOpacity(0.5),
                            thickness: 0.5,
                            height: 0.5,
                          ),
                        ) : const SizedBox.shrink());
                        
                        if (kIsWeb || kIsDesktop) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              child,
                              separator,
                            ],
                          );
                        }
                        
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slidable(
                              startActionPane: ActionPane(
                                motion: StretchMotion(),
                                extentRatio: 0.2,
                                children: [
                                  if (ss.settings.iosShowPin.value)
                                    SlidableAction(
                                      label: chat.isPinned! ? 'Unpin' : 'Pin',
                                      backgroundColor: Colors.yellow[800]!,
                                      foregroundColor: Colors.white,
                                      icon: chat.isPinned! ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                                      onPressed: (context) {
                                        chat.togglePin(!chat.isPinned!);
                                      },
                                    ),
                                ],
                              ),
                              endActionPane: ActionPane(
                                motion: StretchMotion(),
                                extentRatio: 0.9,
                                children: [
                                  if (!chat.isArchived! && ss.settings.iosShowAlert.value)
                                    SlidableAction(
                                      label: chat.muteType == "mute" ? 'Unmute' : 'Mute',
                                      backgroundColor: Colors.purple[700]!,
                                      flex: 2,
                                      icon: chat.muteType == "mute" ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                                      onPressed: (context) {
                                        chat.toggleMute(chat.muteType != "mute");
                                      },
                                    ),
                                  if (ss.settings.iosShowDelete.value)
                                    SlidableAction(
                                      label: "Delete",
                                      backgroundColor: Colors.red,
                                      flex: 2,
                                      icon: CupertinoIcons.trash,
                                      onPressed: (context) {
                                        ChatBloc().deleteChat(chat);
                                        Chat.deleteChat(chat);
                                      },
                                    ),
                                  if (ss.settings.iosShowMarkRead.value)
                                    SlidableAction(
                                      label: chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                                      backgroundColor: Colors.blue,
                                      flex: 3,
                                      icon: chat.hasUnreadMessage!
                                          ? CupertinoIcons.person_crop_circle_badge_checkmark
                                          : CupertinoIcons.person_crop_circle_badge_exclam,
                                      onPressed: (context) {
                                        ChatBloc().toggleChatUnread(chat, !chat.hasUnreadMessage!);
                                      },
                                    ),
                                  if (ss.settings.iosShowArchive.value)
                                    SlidableAction(
                                      label: chat.isArchived! ? 'UnArchive' : 'Archive',
                                      backgroundColor: chat.isArchived! ? Colors.blue : Colors.red,
                                      flex: 2,
                                      icon: chat.isArchived! ? CupertinoIcons.tray_arrow_up : CupertinoIcons.tray_arrow_down,
                                      onPressed: (context) {
                                        if (chat.isArchived!) {
                                          ChatBloc().unArchiveChat(chat);
                                        } else {
                                          ChatBloc().archiveChat(chat);
                                        }
                                      },
                                    ),
                                ],
                              ),
                              child: child,
                            ),
                            separator,
                          ],
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
