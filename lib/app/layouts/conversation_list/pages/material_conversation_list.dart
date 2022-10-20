import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/list_item.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class MaterialConversationList extends StatefulWidget {
  const MaterialConversationList({Key? key, required this.parentController});

  final ConversationListController parentController;

  @override
  State<MaterialConversationList> createState() => _MaterialConversationListState();
}

class _MaterialConversationListState extends OptimizedState<MaterialConversationList> with ThemeHelpers {
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
    return WillPopScope(
      onWillPop: () async {
        if (controller.selectedChats.isNotEmpty) {
          controller.clearSelectedChats();
          return false;
        }
        return true;
      },
      child: Container(
        color: backgroundColor,
        padding: EdgeInsets.only(top: kIsDesktop ? 30 : 0),
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: MaterialHeader(parentController: controller),
          ),
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: true,
          floatingActionButton: !ss.settings.moveChatCreatorToHeader.value
              && !showArchived && !showUnknown
              ? ConversationListFAB(parentController: controller)
              : null,
          body: Obx(() {
            final chats = ChatBloc().chats
                .archivedHelper(showArchived)
                .unknownSendersHelper(showUnknown);

            if (!ChatBloc().loadedChatBatch.value || chats.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
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
                          style: context.theme.textTheme.labelLarge,
                        ),
                      ),
                      if (!ChatBloc().loadedChatBatch.value)
                        buildProgressIndicator(context, size: 15),
                    ],
                  ),
                ),
              );
            }

            return NotificationListener(
              onNotification: (notif) {
                if (notif is ScrollStartNotification) {
                  controller.materialScrollStartPosition = controller.materialScrollController.offset;
                }
                return true;
              },
              child: ScrollbarWrapper(
                showScrollbar: true,
                controller: controller.materialScrollController,
                child: Obx(() => ListView.builder(
                  controller: controller.materialScrollController,
                  physics: (ss.settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                      ? NeverScrollableScrollPhysics()
                      : ThemeSwitcher.getScrollPhysics(),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final child = ListItem(chat: chat, controller: controller);
                    final separator = Obx(() => !ss.settings.hideDividers.value ? Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Divider(
                        color: context.theme.colorScheme.outline.withOpacity(0.5),
                        thickness: 0.5,
                        height: 0.5,
                      ),
                    ) : const SizedBox.shrink());

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        child,
                        separator,
                      ],
                    );
                  },
                  itemCount: chats.length,
                )),
              ),
            );
          }),
        ),
      ),
    );
  }
}
