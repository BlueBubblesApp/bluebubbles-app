import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/footer/samsung_footer.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/samsung_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/list_item.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class SamsungConversationList extends StatefulWidget {
  const SamsungConversationList({Key? key, required this.parentController});

  final ConversationListController parentController;

  @override
  State<SamsungConversationList> createState() => _SamsungConversationListState();
}

class _SamsungConversationListState extends OptimizedState<SamsungConversationList> {
  bool get showArchived => widget.parentController.showArchivedChats;
  bool get showUnknown => widget.parentController.showUnknownSenders;
  Color get backgroundColor => ss.settings.windowEffect.value == WindowEffect.disabled
      ? headerColor
      : Colors.transparent;
  Color get _tileColor => ss.settings.windowEffect.value == WindowEffect.disabled
      ? tileColor
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
    return WillPopScope(
      onWillPop: () async {
        if (controller.selectedChats.isNotEmpty) {
          controller.clearSelectedChats();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: backgroundColor,
            floatingActionButton: Obx(() => !ss.settings.moveChatCreatorToHeader.value
                && !showArchived && !showUnknown
                ? ConversationListFAB(parentController: controller)
                : const SizedBox.shrink()),
            body: SafeArea(
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  if (kIsWeb || kIsDesktop) return false;
                  final scrollDistance = context.height / 3 - 57;
                  if (controller.samsungScrollController.offset > 0
                      && controller.samsungScrollController.offset < scrollDistance
                      && controller.samsungScrollController.offset != controller.samsungScrollController.position.maxScrollExtent) {
                    final double snapOffset = controller.samsungScrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                    Future.microtask(
                            () => controller.samsungScrollController.animateTo(snapOffset, duration: const Duration(milliseconds: 200), curve: Curves.linear));
                  }
                  return false;
                },
                child: ScrollbarWrapper(
                  showScrollbar: true,
                  controller: controller.samsungScrollController,
                    child: Obx(() {
                      final _chats = chats.chats
                          .archivedHelper(controller.showArchivedChats)
                          .unknownSendersHelper(controller.showUnknownSenders);

                      return CustomScrollView(
                        physics: (ss.settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                            ? const NeverScrollableScrollPhysics()
                            : ThemeSwitcher.getScrollPhysics(),
                        controller: controller.samsungScrollController,
                        slivers: [
                          SamsungHeader(parentController: controller),

                          if (!chats.loadedChatBatch.value || _chats.bigPinHelper(false).isEmpty)
                            SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 50),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          !chats.loadedChatBatch.value
                                              ? "Loading chats..."
                                              : showArchived
                                              ? "You have no archived chats"
                                              : showUnknown
                                              ? "You have no messages from unknown senders :)"
                                              : "You have no chats :(",
                                          style: context.theme.textTheme.labelLarge,
                                        ),
                                      ),
                                      if (!chats.loadedChatBatch.value)
                                        buildProgressIndicator(context, size: 15),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          if (_chats.bigPinHelper(true).isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.only(bottom: 15),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final chat = _chats.bigPinHelper(true)[index];
                                    final item = ListItem(chat: chat, controller: controller, update: () {
                                      setState(() {});
                                    });
                                    // give the list rounded corners at top and bottom
                                    if (_chats.bigPinHelper(true).length == 1) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(25),
                                            topRight: Radius.circular(25),
                                            bottomLeft: Radius.circular(25),
                                            bottomRight: Radius.circular(25),
                                          ),
                                          color: _tileColor,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: item,
                                      );
                                    } else if (index == 0 || index == _chats.bigPinHelper(true).length - 1) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: index == 0 ? const BorderRadius.only(
                                            topLeft: Radius.circular(25),
                                            topRight: Radius.circular(25),
                                          ) : const BorderRadius.only(
                                            bottomLeft: Radius.circular(25),
                                            bottomRight: Radius.circular(25),
                                          ),
                                          color: _tileColor,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: item,
                                      );
                                    } else {
                                      return Container(
                                        color: _tileColor,
                                        child: item,
                                      );
                                    }
                                  },
                                  childCount: _chats.bigPinHelper(true).length,
                                )
                              ),
                            ),

                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 15),
                            sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                    final chat = _chats.bigPinHelper(false)[index];
                                    final item = ListItem(chat: chat, controller: controller, update: () {
                                      setState(() {});
                                    });
                                    // give the list rounded corners at top and bottom
                                    if (_chats.bigPinHelper(false).length == 1) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(25),
                                            topRight: Radius.circular(25),
                                            bottomLeft: Radius.circular(25),
                                            bottomRight: Radius.circular(25),
                                          ),
                                          color: _tileColor,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: item,
                                      );
                                    } else if (index == 0 || index == _chats.bigPinHelper(false).length - 1) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: index == 0 ? const BorderRadius.only(
                                            topLeft: Radius.circular(25),
                                            topRight: Radius.circular(25),
                                          ) : const BorderRadius.only(
                                            bottomLeft: Radius.circular(25),
                                            bottomRight: Radius.circular(25),
                                          ),
                                          color: _tileColor,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: item,
                                      );
                                    } else {
                                      return Container(
                                        color: _tileColor,
                                        child: item,
                                      );
                                    }
                                  },
                                  childCount: _chats.bigPinHelper(false).length,
                                )
                            ),
                          ),
                        ],
                      );
                  }),
                ),
              ),
            ),
            bottomNavigationBar: SamsungFooter(parentController: controller),
          ),
          if (ss.settings.showConnectionIndicator.value)
            const ConnectionIndicator(),
        ],
      ),
    );
  }
}
