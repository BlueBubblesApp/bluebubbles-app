import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/notification_settings_dialog.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as uh;

class NotificationPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends OptimizedState<NotificationPanel> with SingleTickerProviderStateMixin {
  final ScrollController controller1 = ScrollController();
  late final TabController tabController;
  final RxInt index = 0.obs;

  @override
  void initState() {
    super.initState();
    tabController = TabController(vsync: this, length: kIsWeb ? 1 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final bodySlivers = [
      SliverList(
        delegate: SliverChildListDelegate(
          <Widget>[
            if (ss.settings.skin.value != Skins.Samsung)
              Container(
                  height: 50,
                  alignment: Alignment.bottomLeft,
                  color: iOS ? headerColor : tileColor,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0, left: iOS ? 30 : 15),
                    child: Text("Notifications".psCapitalize,
                        style: iOS
                            ? iosSubtitle
                            : materialSubtitle),
                  )),
            SettingsSection(backgroundColor: tileColor, children: [
              if (!kIsWeb)
                Obx(() => SettingsSwitch(
                  onChanged: (bool val) {
                    ss.settings.notifyOnChatList.value = val;
                    saveSettings();
                  },
                  initialVal: ss.settings.notifyOnChatList.value,
                  title: "Send Notifications on Chat List",
                  subtitle:
                  "Sends notifications for new messages while in the chat list or chat creator",
                  isThreeLine: true,
                  backgroundColor: tileColor,
                )),
              if (kIsWeb)
                SettingsTile(
                  onTap: () async {
                    String res = await uh.Notification.requestPermission();
                    setState(() {});
                    showSnackbar("Notice", "Notification permission $res");
                  },
                  title: uh.Notification.permission == "granted"
                      ? "Notifications enabled"
                      : uh.Notification.permission == "denied"
                      ? "Notifications denied, please update your browser settings to re-enable notifications"
                      : "Click to enable notifications",
                  backgroundColor: tileColor,
                ),
              Container(
                color: tileColor,
                child: Padding(
                  padding: const EdgeInsets.only(left: 15.0),
                  child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                ),
              ),
              Obx(() => SettingsSwitch(
                onChanged: (bool val) {
                  ss.settings.notifyReactions.value = val;
                  saveSettings();
                },
                initialVal: ss.settings.notifyReactions.value,
                title: "Notify for Reactions",
                subtitle: "Sends notifications for incoming reactions",
                backgroundColor: tileColor,
              )),
              Container(
                color: tileColor,
                child: Padding(
                  padding: const EdgeInsets.only(left: 15.0),
                  child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                ),
              ),
              /*if (!kIsWeb)
                                    Obx(() {
                                      if (iOS)
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: tileColor,
                                          ),
                                          padding: EdgeInsets.only(left: 15),
                                          child: Text("Select Notification Sound"),
                                        );
                                      else return SizedBox.shrink();
                                    }),
                                  if (!kIsWeb)
                                    Obx(() => SettingsOptions<String>(
                                      initial: settings.settings.notificationSound.value,
                                      onChanged: (val) {
                                        if (val == null) return;
                                        settings.settings.notificationSound.value = val;
                                        saveSettings();
                                      },
                                      options: ["default", "twig.wav", "walrus.wav", "sugarfree.wav", "raspberry.wav"],
                                      textProcessing: (val) => val.toString().split(".").first.capitalizeFirst!,
                                      capitalize: false,
                                      title: "Notification Sound",
                                      subtitle: "Set a custom notification sound for the app",
                                      backgroundColor: tileColor,
                                      secondaryColor: headerColor,
                                    )),
                                  if (!kIsWeb)
                                    Container(
                                      color: tileColor,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 15.0),
                                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                      ),
                                    ),*/
              SettingsTile(
                title: "Text Detection",
                onTap: () async {
                  final TextEditingController controller = TextEditingController();
                  controller.text = ss.settings.globalTextDetection.value;
                  showDialog(
                    context: context,
                    builder: (context) => TextDetectionDialog(controller),
                  );
                  ss.settings.globalTextDetection.value = controller.text;
                  saveSettings();
                },
                backgroundColor: tileColor,
                subtitle: "Mute all chats except when your choice of text is found in a message",
              ),
            ]),
            SettingsHeader(
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Advanced"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Obx(() => SettingsSwitch(
                  onChanged: (bool val) {
                    ss.settings.hideTextPreviews.value = val;
                    saveSettings();
                  },
                  initialVal: ss.settings.hideTextPreviews.value,
                  title: "Hide Message Text",
                  subtitle: "Replaces message text with 'iMessage' in notifications",
                  backgroundColor: tileColor,
                )),
                Container(
                  color: tileColor,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                  ),
                ),
                Obx(() => SettingsSwitch(
                  onChanged: (bool val) {
                    ss.settings.showIncrementalSync.value = val;
                    saveSettings();
                  },
                  initialVal: ss.settings.showIncrementalSync.value,
                  title: "Notify When Incremental Sync Complete",
                  subtitle: "Show a snackbar whenever a message sync is completed",
                  backgroundColor: tileColor,
                  isThreeLine: true,
                )),
              ],
            ),
          ],
        ),
      )
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(() => Scaffold(
        backgroundColor: material ? tileColor : headerColor,
        appBar: samsung && index.value == 0
            ? null
            : PreferredSize(
          preferredSize: Size(ns.width(context), 50),
          child: AppBar(
            systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            toolbarHeight: 50,
            elevation: 0,
            scrolledUnderElevation: 3,
            surfaceTintColor: context.theme.colorScheme.primary,
            leading: buildBackButton(context),
            backgroundColor: headerColor,
            centerTitle: iOS,
            title: Text(
              "Notifications",
              style: context.theme.textTheme.titleLarge,
            ),
          ),
        ),
        body: TabBarView(
          physics: ThemeSwitcher.getScrollPhysics(),
          controller: tabController,
          children: <Widget>[
            NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                final scrollDistance = context.height / 3 - 57;

                if (controller1.offset > 0 && controller1.offset < scrollDistance) {
                  final double snapOffset = controller1.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                  Future.microtask(() =>
                      controller1.animateTo(snapOffset, duration: const Duration(milliseconds: 200), curve: Curves.linear));
                }
                return false;
              },
              child: ScrollbarWrapper(
                controller: controller1,
                child: Obx(() => CustomScrollView(
                    controller: controller1,
                    physics:
                    (kIsDesktop || kIsWeb) ? const NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics(),
                    slivers: <Widget>[
                      if (samsung)
                        SliverAppBar(
                          backgroundColor: headerColor,
                          pinned: true,
                          stretch: true,
                          expandedHeight: context.height / 3,
                          elevation: 0,
                          automaticallyImplyLeading: false,
                          flexibleSpace: LayoutBuilder(
                            builder: (context, constraints) {
                              var expandRatio = (constraints.maxHeight - 100) / (context.height / 3 - 50);

                              if (expandRatio > 1.0) expandRatio = 1.0;
                              if (expandRatio < 0.0) expandRatio = 0.0;
                              final animation = AlwaysStoppedAnimation<double>(expandRatio);

                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  FadeTransition(
                                    opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
                                    )),
                                    child: Center(child: Text("Notifications", style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
                                  ),
                                  FadeTransition(
                                    opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                                    )),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Container(
                                        padding: const EdgeInsets.only(left: 40),
                                        height: 50,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Notifications",
                                            style: context.theme.textTheme.titleLarge,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Container(
                                        height: 50,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: buildBackButton(context),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      if (ss.settings.skin.value != Skins.Samsung)
                        ...bodySlivers,
                      if (ss.settings.skin.value == Skins.Samsung)
                        SliverToBoxAdapter(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                            child: CustomScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              slivers: bodySlivers,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!kIsWeb) ChatList(),
          ],
        ),
        bottomNavigationBar: kIsWeb ? null : NavigationBar(
          selectedIndex: index.value,
          backgroundColor: headerColor,
          destinations: [
            NavigationDestination(
              icon: Icon(iOS ? CupertinoIcons.globe : Icons.public),
              label: "GLOBAL OPTIONS",
            ),
            NavigationDestination(
              icon: Icon(
                iOS
                    ? CupertinoIcons.conversation_bubble
                    : Icons.chat_bubble_outline,
              ),
              label: "CHAT OPTIONS",
            ),
          ],
          onDestinationSelected: (page) {
            index.value = page;
            tabController.animateTo(page);
          },
        ),
      )
    ));
  }

  void saveSettings() {
    ss.saveSettings();
  }
}

class ChatList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ChatListState();
}

class ChatListState extends OptimizedState<ChatList> {
  final ScrollController controller = ScrollController();

  String getSubtitle(Chat chat) {
    if (chat.muteType == null) {
      return "No settings set";
    } else {
      String muteArgsStr = "";
      if (chat.muteArgs != null) {
        if (chat.muteType == "mute_individuals") {
          final participants =
              chat.participants.where((element) => chat.muteArgs!.split(",").contains(element.address));
          muteArgsStr = " - ${participants.length > 1 ? "${participants.length} people" : "1 person"}";
        } else if (chat.muteType == "temporary_mute") {
          final DateTime time = DateTime.parse(chat.muteArgs!).toLocal();
          muteArgsStr = " until ${buildDate(time)}";
        } else if (chat.muteType == "text_detection") {
          muteArgsStr = " for words ${chat.muteArgs!.split(",").join(", ")}";
        }
      }
      return "Mute type: ${chat.muteType!.split("_").join(" ").capitalizeFirst}$muteArgsStr";
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: ThemeSwitcher.getScrollPhysics(),
      slivers: <Widget>[
        Obx(() {
          if (!chats.loadedChatBatch.value) {
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
          if (chats.loadedChatBatch.value && chats.chats.isEmpty) {
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

          final _controller = ScrollController();

          return SliverToBoxAdapter(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: context.height - 175,
                  color: tileColor,
                  child: ScrollbarWrapper(
                    controller: _controller,
                    child: ListView.builder(
                      physics: ThemeSwitcher.getScrollPhysics(),
                      shrinkWrap: true,
                      controller: _controller,
                      findChildIndexCallback: (key) => findChildIndexByKey(chats.chats, key, (item) => item.guid),
                      itemBuilder: (context, index) {
                        return ConversationTile(
                          key: Key(chats.chats[index].guid.toString()),
                          chat: chats.chats[index],
                          controller: Get.put(
                            ConversationListController(showUnknownSenders: true, showArchivedChats: true),
                            tag: "notification-panel"
                          ),
                          inSelectMode: true,
                          subtitle: Text(getSubtitle(chats.chats[index]),
                              style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                          onSelect: (_) async {
                            final chat = chats.chats[index];
                            await showDialog(
                              context: context,
                              builder: (context) => NotificationSettingsDialog(chat, () {
                                setState(() {});
                              }),
                            );
                          },
                        );
                      },
                      itemCount: chats.chats.length,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SliverPadding(
          padding: EdgeInsets.all(40),
        ),
      ],
    );
  }
}
