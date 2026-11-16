import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/filters/custom_group_filter_chip_row.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/cupertino_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pinned_chats_grid.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_source.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/unpin_drop_target.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

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
          UnpinDropTarget(drag: controller.pinDrag, child: ScrollbarWrapper(
            showScrollbar: true,
            controller: controller.iosScrollController,
            child: Obx(() => CustomScrollView(
                  controller: controller.iosScrollController,
                  physics: ThemeSvc.scrollPhysics,
                  slivers: <Widget>[
                    if (!showArchived && !showUnknown) CupertinoHeader(controller: controller),
                    if (!showArchived && !showUnknown)
                      const SliverToBoxAdapter(child: CustomGroupFilterChipRow()),
                    PinnedChatsGrid(controller: controller),
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
                      // With every chat pinned, the pins are the list.
                      final noChats = _chats.isEmpty &&
                          ChatsSvc.getFilteredChats(
                                  showArchived: showArchived,
                                  showUnknown: showUnknown,
                                  pinnedOnly: true,
                                  filters: ChatsSvc.chatListFilters.value)
                              .isEmpty;

                      if (!loaded || noChats) {
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

                      // Only the rows watch the drag, for the room a pin dragged over them makes, so a drag doesn't
                      // refilter the chats.
                      return Obx(() {
                        final rows = controller.pinDrag.withUnpinPreview(_chats);
                        return SliverPadding(
                          // Bottom padding is 20 to account for the bottom pill bar.
                          padding: const EdgeInsets.only(top: 10, bottom: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final chat = ChatsSvc.findChatByGuid(rows[index].guid)!;

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

                                // The dividers are inside the drag source so they collapse with the row when its chat
                                // is dragged to the pins, rather than stacking up where it was.
                                return PinDragSource(
                                  drag: controller.pinDrag,
                                  chat: chat,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      topDivider,
                                      child,
                                      separator,
                                    ],
                                  ),
                                );
                              },
                              childCount: rows.length,
                            ),
                          ),
                        );
                      });
                    }),
                  ],
                )),
          )),
          if (!showArchived && !showUnknown) CupertinoMiniHeader(controller: controller),
        ],
      ),
    );
  }
}
