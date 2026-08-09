import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomAvatarPanel extends StatefulWidget {
  const CustomAvatarPanel({super.key});

  @override
  State<StatefulWidget> createState() => _CustomAvatarPanelState();
}

class _CustomAvatarPanelState extends State<CustomAvatarPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
        title: "Custom Avatars",
        initialHeader: null,
        iosSubtitle: null,
        materialSubtitle: null,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          Obx(() {
            if (!ChatsSvc.loadedFirstChatBatch.value) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Loading chats...",
                            style: context.theme.textTheme.labelLarge,
                          ),
                        ),
                        buildProgressIndicator(context, size: 15),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (ChatsSvc.loadedFirstChatBatch.value && ChatsSvc.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Text(
                      "You have no chats :(",
                      style: context.theme.textTheme.labelLarge,
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chat = ChatsSvc.allChats[index];
                  return ConversationTile(
                    key: Key(chat.guid.toString()),
                    chat: chat,
                    controller: Get.put(ConversationListController(showUnknownSenders: true, showArchivedChats: true),
                        tag: "custom-avatar-panel"),
                    inSelectMode: true,
                    onSelect: (_) {
                      if (chat.customAvatarPath != null) {
                        showBBDialog(
                          context: context,
                          title: "Custom Avatar",
                          body: "You have already set a custom avatar for this chat. What would you like to do?",
                          actions: [
                            BBDialogAction(
                              text: "Cancel",
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                            ),
                            BBDialogAction(
                              text: "Reset",
                              isDestructive: true,
                              onPressed: () async {
                                await ChatsSvc.setChatCustomAvatarPath(chat, null);
                                Navigator.of(context, rootNavigator: true).pop();
                              },
                            ),
                            BBDialogAction(
                              text: "Set New",
                              isDefault: true,
                              onPressed: () async {
                                Navigator.of(context, rootNavigator: true).pop();
                                final result = await NavigationSvc.pushSettings(
                                  context,
                                  AvatarCrop(chat: chat),
                                );
                                if (result is String) {
                                  await ChatsSvc.setChatCustomAvatarPath(chat, result);
                                }
                              },
                            ),
                          ],
                        );
                      } else {
                        NavigationSvc.pushSettings(
                          context,
                          AvatarCrop(chat: chat),
                        ).then((result) async {
                          if (result is! String) return;
                          await ChatsSvc.setChatCustomAvatarPath(chat, result);
                        });
                      }
                    },
                  );
                },
                childCount: ChatsSvc.length,
              ),
            );
          }),
        ]);
  }
}
