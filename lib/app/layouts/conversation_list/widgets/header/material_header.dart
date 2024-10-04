import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
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
        Obx(() => Container(
              height: controller.selectedChats.isEmpty ? 100 : null,
              width: ns.width(context),
              color: ss.settings.windowEffect.value == WindowEffect.disabled ? context.theme.colorScheme.properSurface : Colors.transparent,
            )),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: controller.selectedChats.isEmpty
              ? SafeArea(
                  child: Obx(() {
                      ns.listener.value;
                      return Container(
                        decoration: BoxDecoration(
                          color: !ns.isAvatarOnly(context) && !showArchived && !showUnknown ? context.theme.colorScheme.properSurface
                              .withOpacity(ss.settings.windowEffect.value == WindowEffect.disabled ? 1 : 0.7) : Colors.transparent,
                        ),
                        child: Padding(
                              padding: const EdgeInsets.only(left: 5.0, top: 5.0, bottom: 5.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (ns.isAvatarOnly(context))
                                    Material(
                                      color: Colors.transparent,
                                      shape: const CircleBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: OverflowMenu(extraItems: true, controller: controller),
                                    ),
                                  if (!ns.isAvatarOnly(context))
                                    Padding(
                                      padding: const EdgeInsets.only(left: 15, right: 20),
                                      child: (!showArchived && !showUnknown)
                                          ? Image.asset("assets/icon/icon.png", width: 34, fit: BoxFit.contain)
                                          : IconButton(
                                              onPressed: () async {
                                                Navigator.of(context).pop();
                                              },
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                Icons.arrow_back,
                                                color: context.theme.colorScheme.properOnSurface,
                                              ),
                                            ),
                                    ),
                                  if (!ns.isAvatarOnly(context)) HeaderText(controller: controller, fontSize: 20),
                                  if (!ns.isAvatarOnly(context) && !showArchived && !showUnknown)
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () async {
                                              controller.openCamera(context);
                                            },
                                            icon: Icon(
                                              Icons.camera_alt_outlined,
                                              color: context.theme.colorScheme.properOnSurface,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 2),
                                            child: IconButton(
                                            onPressed: () async {
                                              ns.pushLeft(
                                                context,
                                                SearchView(),
                                              );
                                            },
                                            icon: Icon(
                                              Icons.search_rounded,
                                              color: context.theme.colorScheme.properOnSurface,
                                            ),
                                          )),
                                          const OverflowMenu(),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                      );
                    }),
                )
              : SafeArea(
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
                              style: context.theme.textTheme.titleLarge!.copyWith(
                                color: context.theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Obx(() {
                          List<Chat> selectedChats = controller.selectedChats.map((e) => GlobalChatService.getChat(e)!).toList();
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (([0, selectedChats.length])
                                  .contains(selectedChats.where((element) => element.observables.isUnread.value).length))
                                IconButton(
                                  onPressed: () {
                                    for (Chat element in selectedChats) {
                                      element.toggleUnreadStatus(null);
                                    }
                                    controller.clearSelectedChats();
                                  },
                                  icon: Icon(
                                    selectedChats.first.observables.isUnread.value ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread_outlined,
                                    color: context.theme.colorScheme.primary,
                                  ),
                                ),
                              if (([0, selectedChats.length])
                                  .contains(selectedChats.where((element) => element.isChatMuted).length))
                                IconButton(
                                  onPressed: () {
                                    for (Chat element in selectedChats) {
                                      element.toggleMuteType(null);
                                    }

                                    controller.clearSelectedChats();
                                  },
                                  icon: Icon(
                                    selectedChats.first.isChatMuted
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_off_outlined,
                                    color: context.theme.colorScheme.primary,
                                  ),
                                ),
                              if (([0, selectedChats.length])
                                  .contains(selectedChats.where((element) => element.observables.isPinned.value).length))
                                IconButton(
                                  onPressed: () {
                                    for (Chat element in selectedChats) {
                                      element.toggleIsPinned(null);
                                    }
                                    controller.clearSelectedChats();
                                  },
                                  icon: Icon(
                                    selectedChats.first.observables.isPinned.value ? Icons.push_pin_outlined : Icons.push_pin,
                                    color: context.theme.colorScheme.primary,
                                  ),
                                ),
                              IconButton(
                                onPressed: () {
                                  for (Chat element in selectedChats) {
                                    element.toggleIsArchived(null);
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
                                  for (String element in controller.selectedChats) {
                                    GlobalChatService.removeChat(element);
                                  }

                                  controller.clearSelectedChats();
                                },
                                icon: Icon(
                                  Icons.delete_outlined,
                                  color: context.theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          );
                        })
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
