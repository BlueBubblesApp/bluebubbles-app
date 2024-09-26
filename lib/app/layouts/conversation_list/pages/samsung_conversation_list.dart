import 'package:bluebubbles/app/components/sliver_decoration.dart';
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
  Color get backgroundColor =>
      ss.settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent;
  Color get _tileColor => ss.settings.windowEffect.value == WindowEffect.disabled ? tileColor : Colors.transparent;
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
    return PopScope(
      canPop: false,
      onPopInvoked: (_) async {
        if (controller.selectedChats.isNotEmpty) {
          controller.clearSelectedChats();
          return;
        } else if (controller.showArchivedChats || controller.showUnknownSenders) {
          // Pop the current page
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        floatingActionButton: !showArchived && !showUnknown
            ? ConversationListFAB(parentController: controller)
            : const SizedBox.shrink(),
        body: SafeArea(
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              if (kIsWeb || kIsDesktop) return false;
              final scrollDistance = context.height / 3 - 57;
              if (controller.samsungScrollController.offset > 0 &&
                  controller.samsungScrollController.offset < scrollDistance &&
                  controller.samsungScrollController.offset !=
                      controller.samsungScrollController.position.maxScrollExtent) {
                final double snapOffset =
                    controller.samsungScrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                Future.microtask(() => controller.samsungScrollController
                    .animateTo(snapOffset, duration: const Duration(milliseconds: 200), curve: Curves.linear));
              }
              return false;
            },
            child: ScrollbarWrapper(
              showScrollbar: true,
              controller: controller.samsungScrollController,
              // Convert the below Obx to a Future Builder
              child: FutureBuilder(
                future: GlobalChatService.chatsLoadedFuture.future,
                builder: (context, snapshot) {
                  final _chats = GlobalChatService.chats
                    .archivedHelper(controller.showArchivedChats)
                    .unknownSendersHelper(controller.showUnknownSenders);

                  return CustomScrollView(
                    physics: ThemeSwitcher.getScrollPhysics(),
                    controller: controller.samsungScrollController,
                    slivers: [
                      SamsungHeader(parentController: controller),
                      if (snapshot.connectionState != ConnectionState.done || _chats.bigPinHelper(false).isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 50),
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
                                      style: context.theme.textTheme.labelLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (!GlobalChatService.chatsLoaded) buildProgressIndicator(context, size: 15),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_chats.bigPinHelper(true).isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 15),
                          sliver: SliverDecoration(
                            color: _tileColor,
                            borderRadius: BorderRadius.circular(25),
                            sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final chat = _chats.bigPinHelper(true)[index];
                                return ListItem(
                                    chat: chat,
                                    controller: controller,
                                    update: () {
                                      setState(() {});
                                    });
                              },
                              childCount: _chats.bigPinHelper(true).length,
                            )),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 15),
                        sliver: SliverDecoration(
                          color: _tileColor,
                          borderRadius: BorderRadius.circular(25),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final chat = _chats.bigPinHelper(false)[index];
                                return ListItem(
                                    chat: chat,
                                    controller: controller,
                                    update: () {
                                      setState(() {});
                                    });
                              },
                              childCount: _chats.bigPinHelper(false).length,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              )
            ),
          ),
        ),
        bottomNavigationBar: SamsungFooter(parentController: controller),
      ),
    );
  }
}
