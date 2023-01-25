import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MaterialHeader extends CustomStateful<ConversationListController> {
  const MaterialHeader({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _MaterialHeaderState();
}

class _MaterialHeaderState extends CustomState<MaterialHeader, void, ConversationListController> {
  bool get showArchived => controller.showArchivedChats;
  bool get showUnknown => controller.showUnknownSenders;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: controller.selectedChats.isEmpty ? 80 : null,
          width: ns.width(context),
          color: context.theme.colorScheme.background,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: controller.selectedChats.isEmpty ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: context.theme.colorScheme.properSurface,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!showArchived && !showUnknown) {
                        ns.pushLeft(
                          context,
                          SearchView(),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5.0, top: 5.0, bottom: 5.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                (!showArchived && !showUnknown) ? IconButton(
                                  onPressed: () async {
                                    ns.pushLeft(
                                      context,
                                      SearchView(),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.search,
                                    color: context.theme.colorScheme.properOnSurface,
                                  ),
                                ) : IconButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                  },
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.arrow_back,
                                    color: context.theme.colorScheme.properOnSurface,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    SyncIndicator(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          HeaderText(controller: controller, fontSize: 23),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Obx(() => ss.settings.moveChatCreatorToHeader.value
                                    && !showArchived
                                    && !showUnknown ? GestureDetector(
                                  onLongPress: ss.settings.cameraFAB.value
                                      ? () => controller.openCamera(context) : null,
                                  child: IconButton(
                                    onPressed: () => controller.openNewChatCreator(context),
                                    icon: Icon(
                                      Icons.create_outlined,
                                      color: context.theme.colorScheme.properOnSurface,
                                    ),
                                  ),
                                ) : const SizedBox.shrink()),
                                if (!showArchived && !showUnknown)
                                  const OverflowMenu(),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ) : SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                right: 20.0,
                left: 20.0,
                top: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          controller.clearSelectedChats();
                        },
                        icon: Icon(
                          Icons.close,
                          color: context.theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        controller.selectedChats.length.toString(),
                        style: context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.primary,),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (([0, controller.selectedChats.length])
                          .contains(controller.selectedChats.where((element) => element.hasUnreadMessage!).length))
                        IconButton(
                          onPressed: () {
                            for (Chat element in controller.selectedChats) {
                              element.toggleHasUnread(!element.hasUnreadMessage!);
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
                      if (([0, controller.selectedChats.length])
                          .contains(controller.selectedChats.where((element) => element.muteType == "mute").length))
                        IconButton(
                          onPressed: () {
                            for (Chat element in controller.selectedChats) {
                              element.toggleMute(element.muteType != "mute");
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
                              element.togglePin(!element.isPinned!);
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
                            element.toggleArchived(!element.isArchived!);
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
                            chats.removeChat(element);
                            Chat.softDelete(element);
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}