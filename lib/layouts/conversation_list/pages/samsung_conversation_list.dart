import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/footer/samsung_footer.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/header/samsung_header.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/list_item.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class SamsungConversationList extends StatefulWidget {
  const SamsungConversationList({Key? key, required this.parentController});

  final ConversationListController parentController;

  @override
  State<SamsungConversationList> createState() => _SamsungConversationListState();
}

class _SamsungConversationListState extends OptimizedState<SamsungConversationList> with ThemeHelpers {
  bool get showArchived => widget.parentController.showArchivedChats;
  bool get showUnknown => widget.parentController.showUnknownSenders;
  Color get backgroundColor => SettingsManager().settings.windowEffect.value == WindowEffect.disabled
      ? headerColor
      : Colors.transparent;
  Color get _tileColor => SettingsManager().settings.windowEffect.value == WindowEffect.disabled
      ? tileColor
      : Colors.transparent;
  ConversationListController get controller => widget.parentController;

  @override
  void initState() {
    super.initState();
    SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: WillPopScope(
        onWillPop: () async {
          if (controller.selectedChats.isNotEmpty) {
            controller.selectedChats.clear();
            controller.updateSelectedChats();
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          floatingActionButton: !SettingsManager().settings.moveChatCreatorToHeader.value
              && !showArchived && !showUnknown
              ? ConversationListFAB(parentController: controller)
              : null,
          body: SafeArea(
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                final scrollDistance = context.height / 3 - 57;
                if (controller.scrollController.offset > 0
                    && controller.scrollController.offset < scrollDistance
                    && controller.scrollController.offset != controller.scrollController.position.maxScrollExtent) {
                  final double snapOffset = controller.scrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                  Future.microtask(
                          () => controller.scrollController.animateTo(snapOffset, duration: Duration(milliseconds: 200), curve: Curves.linear));
                }
                return false;
              },
              child: ScrollbarWrapper(
                showScrollbar: true,
                controller: controller.scrollController,
                  child: Obx(() {
                    final chats = ChatBloc().chats
                        .archivedHelper(controller.showArchivedChats)
                        .unknownSendersHelper(controller.showUnknownSenders);
                    return CustomScrollView(
                      physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                          ? NeverScrollableScrollPhysics()
                          : ThemeSwitcher.getScrollPhysics(),
                      controller: controller.scrollController,
                      slivers: [
                        SamsungHeader(parentController: controller),
                        SliverToBoxAdapter(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: context.height - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                            child: CustomScrollView(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              slivers: [
                                if (chats.bigPinHelper(true).isNotEmpty)
                                  SliverList(
                                    delegate: SliverChildListDelegate([
                                      SingleChildScrollView(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(25),
                                              color: _tileColor,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              physics: NeverScrollableScrollPhysics(),
                                              itemBuilder: (context, index) {
                                                final chat = chats.bigPinHelper(true)[index];
                                                return ListItem(chat: chat, controller: controller);
                                              },
                                              itemCount: chats.bigPinHelper(true).length,
                                            ),
                                          )
                                      )
                                    ])
                                  ),
                                if (chats.bigPinHelper(true).isNotEmpty)
                                  const SliverToBoxAdapter(child: SizedBox(height: 15)),

                                SliverList(
                                  delegate: SliverChildListDelegate([
                                    SingleChildScrollView(
                                      child: Obx(() {
                                        if (!ChatBloc().loadedChatBatch.value || chats.bigPinHelper(false).isEmpty) {
                                          return Center(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 50),
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

                                        return Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(25),
                                            color: _tileColor,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            physics: NeverScrollableScrollPhysics(),
                                            itemBuilder: (context, index) {
                                              final chat = chats.bigPinHelper(false)[index];
                                              return ListItem(chat: chat, controller: controller);
                                            },
                                            itemCount: chats.bigPinHelper(false).length,
                                          ),
                                        );
                                      }),
                                    )
                                  ]),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
