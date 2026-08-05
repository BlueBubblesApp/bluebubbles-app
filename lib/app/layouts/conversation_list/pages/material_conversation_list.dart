import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/filters/custom_group_filter_chip_row.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/list_item.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class MaterialConversationList extends StatefulWidget {
  const MaterialConversationList({super.key, required this.parentController});

  final ConversationListController parentController;

  @override
  State<MaterialConversationList> createState() => _MaterialConversationListState();
}

class _MaterialConversationListState extends State<MaterialConversationList> {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: <T>(bool didPop, T? other) {
        if (didPop) return;
        if (controller.selectedChats.isNotEmpty) {
          controller.clearSelectedChats();
          return;
        } else if (controller.showArchivedChats || controller.showUnknownSenders) {
          // Pop the current page
          Navigator.of(context).pop();
        } else {
          // Pop the app to exit the app
          SystemNavigator.pop();
        }
      },
      child: Container(
        color: backgroundColor,
        padding: EdgeInsets.only(top: kIsDesktop ? 30 : 0),
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: MaterialHeader(parentController: controller),
          ),
          backgroundColor: SettingsSvc.settings.windowEffect.value == WindowEffect.disabled
              ? context.theme.colorScheme.surfaceContainerHighest
              : Colors.transparent,
          extendBodyBehindAppBar: false,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: !showArchived && !showUnknown
              ? ConversationListFAB(parentController: controller)
              : const SizedBox.shrink(),
          body: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
            child: Container(
              color: backgroundColor,
              child: Obx(() {
                // Force reactivity by accessing observable values first
                final loaded = ChatsSvc.loadedFirstChatBatch.value;
                // Observe chat list version to trigger rebuild when order changes
                final _ = ChatsSvc.chatListVersion.value;

                final _chats = ChatsSvc.getFilteredChats(
                  showArchived: showArchived,
                  showUnknown: showUnknown,
                  filters: ChatsSvc.chatListFilters.value,
                );

                final Widget content;
                if (!loaded || _chats.isEmpty) {
                  content = Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: loaded
                          ? buildEmptyChatListState(context,
                              showArchived: showArchived, showUnknown: showUnknown, filters: ChatsSvc.chatListFilters.value)
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Loading chats...",
                                    style: context.theme.textTheme.labelLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                buildProgressIndicator(context, size: 15),
                              ],
                            ),
                    ),
                  );
                } else {
                  content = NotificationListener(
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
                            physics: ThemeSwitcher.getScrollPhysics(),
                            padding: const EdgeInsets.only(top: 8),
                            findChildIndexCallback: (key) => findChildIndexByKey(_chats, key, (item) => item.guid),
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              return Container(
                                  key: ValueKey(chat.guid),
                                  child: ListItem(
                                      chat: chat,
                                      controller: controller,
                                      update: () {
                                        setState(() {});
                                      }));
                            },
                            itemCount: _chats.length,
                          )),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (!showArchived && !showUnknown)
                      const CustomGroupFilterChipRow(
                        padding: EdgeInsets.only(left: 12, right: 12, top: 16, bottom: 4),
                      ),
                    Expanded(child: content),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
