import 'package:auto_size_text/auto_size_text.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_page.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class HeaderText extends StatelessWidget {
  const HeaderText({Key? key, required this.controller, this.fontSize});

  final ConversationListController controller;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: AutoSizeText(
        controller.showArchivedChats
            ? "Archive"
            : controller.showUnknownSenders
            ? "Unknown Senders"
            : "Messages",
        style: context.textTheme.headlineLarge!.copyWith(
          color: context.theme.colorScheme.onBackground,
          fontWeight: FontWeight.w500,
          fontSize: fontSize,
        ),
        maxLines: 1,
      ),
    );
  }
}

class SyncIndicator extends StatelessWidget {
  final double size;

  SyncIndicator({this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ss.settings.showSyncIndicator.value
          || !sync.isIncrementalSyncing.value) {
        return const SizedBox.shrink();
      }
      return buildProgressIndicator(context, size: size);
    });
  }
}

class OverflowMenu extends StatelessWidget {
  final bool extraItems;
  final ConversationListController? controller;
  const OverflowMenu({this.extraItems = false, this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => PopupMenuButton<int>(
      color: context.theme.colorScheme.properSurface.lightenOrDarken(ss.settings.skin.value == Skins.Samsung ? 20 : 0)
          .withOpacity(ss.settings.windowEffect.value != WindowEffect.disabled ? 0.9 : 1),
      shape: ss.settings.skin.value != Skins.Material ? const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(20.0),
        ),
      ) : null,
      onSelected: (int value) async {
        if (value == 0) {
          chats.markAllAsRead();
        } else if (value == 1) {
          ns.pushLeft(
            context,
            ConversationList(
              showArchivedChats: true,
              showUnknownSenders: false,
            )
          );
        } else if (value == 2) {
          final currentChat = cm.activeChat?.chat;
          ns.closeAllConversationView(context);
          await cm.setAllInactive();
          await Navigator.of(Get.context!).push(
            ThemeSwitcher.buildPageRoute(
              builder: (BuildContext context) {
                return SettingsPage();
              },
            ),
          );
          if (currentChat != null) {
            await cm.setActiveChat(currentChat);
            if (ss.settings.tabletMode.value) {
                ns.pushAndRemoveUntil(
                  context,
                  ConversationView(
                    chat: currentChat,
                  ),
                      (route) => route.isFirst,
                ).onError((error, stackTrace) => cm.setAllInactiveSync());
            } else {
              cvc(currentChat).close();
            }
          }
        } else if (value == 3) {
          ns.pushLeft(
            context,
            ConversationList(
              showArchivedChats: false,
              showUnknownSenders: true,
            )
          );
        } else if (value == 4) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  "Are you sure?",
                  style: context.theme.textTheme.titleLarge,
                ),
                backgroundColor: context.theme.colorScheme.properSurface,
                actions: <Widget>[
                  TextButton(
                    child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () async {
                      fs.deleteDB();
                      socket.forgetConnection();
                      ss.settings = Settings();
                      ss.fcmData = FCMData();
                      await ss.prefs.clear();
                      await ss.prefs.setString("selected-dark", "OLED Dark");
                      await ss.prefs.setString("selected-light", "Bright White");
                      Get.offAll(() => WillPopScope(
                        onWillPop: () async => false,
                        child: TitleBarWrapper(child: SetupView()),
                      ), duration: Duration.zero, transition: Transition.noTransition);
                    },
                  ),
                ],
              );
            },
          );
        } else if (value == 5) {
          final currentChat = cm.activeChat?.chat;
          ns.closeAllConversationView(context);
          await cm.setAllInactive();
          await Navigator.of(Get.context!).push(
            ThemeSwitcher.buildPageRoute(
              builder: (BuildContext context) {
                return const FindMyPage();
              },
            ),
          );
          if (currentChat != null) {
            await cm.setActiveChat(currentChat);
            if (ss.settings.tabletMode.value) {
              ns.pushAndRemoveUntil(
                context,
                ConversationView(
                  chat: currentChat,
                ),
                    (route) => route.isFirst,
              );
            } else {
              cvc(currentChat).close();
            }
          }
        } else if (value == 6) {
          final current = ns.ratio(context);
          eventDispatcher.emit("override-split", 0.3);
          await ns.pushLeft(context, SearchView());
          eventDispatcher.emit("override-split", current);
        } else if (value == 7) {
          controller?.openNewChatCreator(context);
        }
      },
      itemBuilder: (context) {
        return <PopupMenuItem<int>>[
          PopupMenuItem(
            value: 0,
            child: Text(
              'Mark All As Read',
              style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
            ),
          ),
          PopupMenuItem(
            value: 1,
            child: Text(
              'Archived',
              style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
            ),
          ),
          if (ss.settings.filterUnknownSenders.value)
            PopupMenuItem(
              value: 3,
              child: Text(
                'Unknown Senders',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          if (ss.isMinCatalinaSync)
            PopupMenuItem(
              value: 5,
              child: Text(
                'FindMy',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          PopupMenuItem(
            value: 2,
            child: Text(
              'Settings',
              style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
            ),
          ),
          if (kIsWeb)
            PopupMenuItem(
              value: 4,
              child: Text(
                'Logout',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          if (extraItems)
            PopupMenuItem(
              value: 6,
              child: Text(
                'Search',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          if (extraItems && ss.settings.moveChatCreatorToHeader.value)
            PopupMenuItem(
              value: 7,
              child: Text(
                'New Chat',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
        ];
      },
      icon: ss.settings.skin.value == Skins.Material ? Icon(
        Icons.more_vert,
        color: context.theme.colorScheme.onBackground,
        size: 25,
      ) : null,
      child: ss.settings.skin.value == Skins.Material
        ? null
        : ThemeSwitcher(
            iOSSkin: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: context.theme.colorScheme.properSurface,
              ),
              child: Icon(
                Icons.more_horiz,
                color: context.theme.colorScheme.properOnSurface,
                size: 20,
              ),
            ),
            materialSkin: const SizedBox.shrink(),
            samsungSkin: Icon(
              Icons.more_vert,
              color: context.theme.colorScheme.onBackground,
              size: 25,
            ),
          ),
    ));
  }
}
