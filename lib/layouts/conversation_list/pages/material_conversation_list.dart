import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Color get backgroundColor => SettingsManager().settings.windowEffect.value == WindowEffect.disabled
      ? context.theme.colorScheme.background
      : Colors.transparent;
  ConversationListController get controller => widget.parentController;
  MaterialSwipeAction get leftAction => SettingsManager().settings.materialLeftAction.value;
  MaterialSwipeAction get rightAction => SettingsManager().settings.materialRightAction.value;

  @override
  void initState() {
    super.initState();
    // update widget when background color changes
    SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
      setState(() {});
    });
  }


  Widget slideBackground(Chat chat, bool left) {
    MaterialSwipeAction action;
    if (left) {
      action = leftAction;
    } else {
      action = rightAction;
    }

    return Container(
      color: action == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : action == MaterialSwipeAction.alerts
              ? Colors.purple
              : action == MaterialSwipeAction.delete
                  ? Colors.red
                  : action == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: left ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            Icon(
              action == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : action == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                      : action == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : action == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              action == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : action == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? ' Show Alerts' : ' Hide Alerts')
                      : action == MaterialSwipeAction.delete
                          ? " Delete"
                          : action == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: left ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: left ? Alignment.centerRight : Alignment.centerLeft,
      ),
    );
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
              floatingActionButton: !SettingsManager().settings.moveChatCreatorToHeader.value
                  ? ConversationListFAB(parentController: controller)
                  : null,
              body: Obx(() {
                final chats = ChatBloc().chats
                    .archivedHelper(showArchived)
                    .unknownSendersHelper(showUnknown);

                if (!ChatBloc().loadedChatBatch.value || chats.isEmpty) {
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
                          buildProgressIndicator(context, size: 15),
                        ],
                      ),
                    ),
                  );
                }

                return NotificationListener(
                    onNotification: (notif) {
                      if (notif is ScrollStartNotification) {
                        controller.materialScrollStartPosition = controller.scrollController.offset;
                      }
                      return true;
                    },
                    child: ScrollbarWrapper(
                      showScrollbar: true,
                      controller: controller.scrollController,
                      child: Obx(() => ListView.builder(
                          controller: controller.scrollController,
                          physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                              ? NeverScrollableScrollPhysics()
                              : ThemeSwitcher.getScrollPhysics(),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            final tile = ConversationTile(
                              key: Key(chat.guid),
                              chat: chat,
                              inSelectMode: controller.selectedChats.isNotEmpty,
                              selected: controller.selectedChats,
                              onSelect: (bool isSelected) {
                                if (isSelected) {
                                  controller.selectedChats.add(chat);
                                  controller.updateSelectedChats();
                                } else {
                                  controller.selectedChats.removeWhere((element) => element.guid == chat.guid);
                                  controller.updateSelectedChats();
                                }
                              },
                            );
                            
                            return Obx(() {
                              if (SettingsManager().settings.swipableConversationTiles.value) {
                                return Dismissible(
                                  background: (kIsDesktop || kIsWeb)
                                      ? null
                                      : Obx(() => slideBackground(chat, false)),
                                  secondaryBackground: (kIsDesktop || kIsWeb)
                                      ? null
                                      : Obx(() => slideBackground(chat, true)),
                                  key: UniqueKey(),
                                  onDismissed: (direction) async {
                                    MaterialSwipeAction action;
                                    if (direction == DismissDirection.endToStart) {
                                      action = leftAction;
                                    } else {
                                      action = rightAction;
                                    }

                                    if (action == MaterialSwipeAction.pin) {
                                      chat.togglePin(!chat.isPinned!);
                                      setState(() {});
                                    } else if (action == MaterialSwipeAction.alerts) {
                                      chat.toggleMute(chat.muteType != "mute");
                                      setState(() {});
                                    } else if (action == MaterialSwipeAction.delete) {
                                      ChatBloc().deleteChat(chat);
                                      Chat.deleteChat(chat);
                                    } else if (action == MaterialSwipeAction.mark_read) {
                                      ChatBloc().toggleChatUnread(chat, !chat.hasUnreadMessage!);
                                    } else if (action == MaterialSwipeAction.archive) {
                                      if (chat.isArchived!) {
                                        ChatBloc().unArchiveChat(chat);
                                      } else {
                                        ChatBloc().archiveChat(chat);
                                      }
                                    }
                                  },
                                  child: tile,
                                );
                              } else {
                                return tile;
                              }
                            });
                          },
                          itemCount: chats.length,
                        ),
                      ),
                    ),
                  );
              }),
          ),
        ),
      ),
    );
  }
}
