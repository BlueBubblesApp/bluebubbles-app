import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class SamsungHeader extends CustomStateful<ConversationListController> {
  const SamsungHeader({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungHeaderState();
}

class _SamsungHeaderState extends CustomState<SamsungHeader, void, ConversationListController> {
  Color get backgroundColor =>
      SettingsSvc.settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent;
  bool get showArchived => controller.showArchivedChats;
  bool get showUnknown => controller.showUnknownSenders;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      NavigationSvc.listener.value;
      if (NavigationSvc.isAvatarOnly(context)) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(10.0).add(const EdgeInsets.only(top: 30)),
            child: Material(
              color: Colors.transparent,
              child: OverflowMenu(extraItems: true, controller: controller),
            ),
          ),
        );
      }
      return SliverAppBar(
        backgroundColor: backgroundColor,
        shadowColor: Colors.black,
        pinned: true,
        stretch: true,
        expandedHeight: context.height / 3,
        toolbarHeight: kToolbarHeight + (kIsDesktop ? 20 : 0),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: LayoutBuilder(
          builder: (context, constraints) {
            final double expandRatio = ((constraints.maxHeight - (kToolbarHeight + (kIsDesktop ? 20 : 0))) /
                    (context.height / 3 - (kToolbarHeight + (kIsDesktop ? 20 : 0))))
                .clamp(0, 1);
            final animation = AlwaysStoppedAnimation(expandRatio);

            return Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
                  )),
                  child: Center(child: ExpandedHeaderText(parentController: controller)),
                ),
                FadeTransition(
                  opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                  )),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: EdgeInsets.only(left: showArchived || showUnknown ? 60 : 16),
                      height: (kToolbarHeight + (kIsDesktop ? 20 : 0)),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            HeaderText(controller: controller, fontSize: 20),
                            const SyncIndicator(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    height: (kToolbarHeight + (kIsDesktop ? 20 : 0)),
                    child: Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (controller.selectedChats.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                controller.clearSelectedChats();
                              },
                              icon: Icon(
                                Icons.close,
                                color: context.theme.colorScheme.primary,
                              ),
                            )
                          else if (showArchived || showUnknown)
                            IconButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                },
                                padding: EdgeInsets.zero,
                                icon: buildBackButton(context))
                          else
                            const SizedBox.shrink(),
                          if (controller.selectedChats.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (([0, controller.selectedChats.length]).contains(
                                    controller.selectedChats.where((element) => element.hasUnreadMessage!).length))
                                  IconButton(
                                    onPressed: () {
                                      for (Chat element in controller.selectedChats) {
                                        final chatState = ChatsSvc.getChatState(element.guid);
                                        if (chatState != null) {
                                          ChatsSvc.setChatHasUnread(chatState.chat, !element.hasUnreadMessage!);
                                        } else {
                                          element.toggleHasUnreadAsync(!element.hasUnreadMessage!);
                                        }
                                      }
                                      controller.clearSelectedChats();
                                    },
                                    icon: Icon(
                                      controller.selectedChats[0].hasUnreadMessage!
                                          ? Icons.mark_chat_read_outlined
                                          : Icons.mark_chat_unread_outlined,
                                      color: context.theme.colorScheme.primary,
                                    ),
                                  ),
                                if (([0, controller.selectedChats.length]).contains(
                                    controller.selectedChats.where((element) => element.muteType == "mute").length))
                                  IconButton(
                                    onPressed: () {
                                      for (Chat element in controller.selectedChats) {
                                        final chatState = ChatsSvc.getChatState(element.guid);
                                        if (chatState != null) {
                                          ChatsSvc.setChatMuted(chatState.chat, element.muteType != "mute");
                                        } else {
                                          element.toggleMuteAsync(element.muteType != "mute");
                                        }
                                      }
                                      controller.clearSelectedChats();
                                    },
                                    icon: Icon(
                                      controller.selectedChats[0].muteType == "mute"
                                          ? Icons.notifications_active_outlined
                                          : Icons.notifications_off_outlined,
                                      color: context.theme.colorScheme.primary,
                                    ),
                                  ),
                                if (([0, controller.selectedChats.length])
                                    .contains(controller.selectedChats.where((element) => element.isPinned!).length))
                                  IconButton(
                                    onPressed: () {
                                      for (Chat element in controller.selectedChats) {
                                        final chatState = ChatsSvc.getChatState(element.guid);
                                        if (chatState != null) {
                                          ChatsSvc.setChatPinned(chatState.chat, !element.isPinned!);
                                        } else {
                                          ChatsSvc.toggleChatPin(element, !element.isPinned!);
                                        }
                                      }
                                      controller.clearSelectedChats();
                                    },
                                    icon: Icon(
                                      controller.selectedChats[0].isPinned! ? Icons.push_pin_outlined : Icons.push_pin,
                                      color: context.theme.colorScheme.primary,
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    for (Chat element in controller.selectedChats) {
                                      final chatState = ChatsSvc.getChatState(element.guid);
                                      if (chatState != null) {
                                        ChatsSvc.setChatArchived(chatState.chat, !element.isArchived!);
                                      } else {
                                        ChatsSvc.toggleChatArchive(element, !element.isArchived!);
                                      }
                                    }
                                    controller.clearSelectedChats();
                                  },
                                  icon: Icon(
                                    showArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                                    color: context.theme.colorScheme.primary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    for (Chat element in controller.selectedChats) {
                                      ChatsSvc.removeChat(element);
                                      ChatsSvc.softDeleteChat(element);
                                    }
                                    controller.clearSelectedChats();
                                  },
                                  icon: Icon(
                                    Icons.delete_outlined,
                                    color: context.theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!showArchived && !showUnknown)
                                  Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: IconButton(
                                        onPressed: () async {
                                          controller.openCamera(context);
                                        },
                                        icon: Icon(
                                          Icons.camera_alt_outlined,
                                          color: context.theme.colorScheme.onSurfaceVariant,
                                        ),
                                      )),
                                if (!showArchived && !showUnknown)
                                  IconButton(
                                      onPressed: () async {
                                        NavigationSvc.pushLeft(
                                          context,
                                          const SearchView(),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.search,
                                        color: context.theme.colorScheme.onSurfaceVariant,
                                      )),
                                if (!showArchived && !showUnknown)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: OverflowMenu(),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

class ExpandedHeaderText extends CustomStateful<ConversationListController> {
  const ExpandedHeaderText({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _ExpandedHeaderTextState();
}

class _ExpandedHeaderTextState extends CustomState<ExpandedHeaderText, void, ConversationListController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unreadChats = ChatsSvc.unreadCount.value;
      return Text(
        controller.selectedChats.isNotEmpty
            ? "${controller.selectedChats.length} selected"
            : controller.showArchivedChats
                ? "Archived"
                : controller.showUnknownSenders
                    ? "Unknown Senders"
                    : unreadChats > 0
                        ? "$unreadChats unread message${unreadChats > 1 ? "s" : ""}"
                        : "Messages",
        style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onSurface),
        textAlign: TextAlign.center,
      );
    });
  }
}
