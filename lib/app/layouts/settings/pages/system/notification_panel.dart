import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/notification_settings_dialog.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/reaction_type_picker.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as uh;

class NotificationPanel extends StatefulWidget {
  const NotificationPanel({super.key});

  @override
  State<StatefulWidget> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> with SingleTickerProviderStateMixin, ThemeHelpers {
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
            if (SettingsSvc.settings.skin.value != Skins.Samsung)
              Container(
                  height: 50,
                  alignment: Alignment.bottomLeft,
                  color: headerColor,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0, left: iOS ? 30 : 15),
                    child: Text("Notifications".psCapitalize, style: iOS ? iosSubtitle : materialSubtitle),
                  )),
            Obx(() => SettingsSection(backgroundColor: tileColor, children: [
              if (!kIsWeb && !kIsDesktop)
                SettingsSwitch(
                  onChanged: (bool val) async {
                    SettingsSvc.settings.dndFavoritesOverride.value = val;
                    await SettingsSvc.settings.saveOneAsync('dndFavoritesOverride');
                  },
                  initialVal: SettingsSvc.settings.dndFavoritesOverride.value,
                  title: "Override DND for Favorites",
                  subtitle: "Override Do Not Disturb (DND) for Favorite (starred) contacts",
                  isThreeLine: true,
                  backgroundColor: tileColor,
                ),
              if (!kIsWeb && !kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
              // On desktop this toggle has no effect: notifications there fire
              // regardless of the chat list, so only show it on mobile.
              if (!kIsWeb && !kIsDesktop)
                SettingsSwitch(
                  onChanged: (bool val) async {
                    SettingsSvc.settings.notifyOnChatList.value = val;
                    await SettingsSvc.settings.saveOneAsync('notifyOnChatList');
                  },
                  initialVal: SettingsSvc.settings.notifyOnChatList.value,
                  title: "Send Notifications on Chat List",
                  subtitle: "Sends notifications for new messages while in the chat list or chat creator",
                  isThreeLine: true,
                  backgroundColor: tileColor,
                ),
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
              // Matches the chat-list toggle above: no leading divider on desktop where that toggle is hidden.
              if (!kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
              SettingsSwitch(
                onChanged: (bool val) async {
                  SettingsSvc.settings.notifyReactions.value = val;
                  await SettingsSvc.settings.saveOneAsync('notifyReactions');
                },
                initialVal: SettingsSvc.settings.notifyReactions.value,
                title: "Notify for Reactions",
                subtitle: "Sends notifications for incoming reactions",
                backgroundColor: tileColor,
              ),
              const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
              SettingsSwitch(
                title: "Text Detection",
                subtitle: "Mute all chats except when your choice of text is found in a message",
                initialVal: SettingsSvc.settings.globalTextDetection.value.isNotEmpty,
                onChanged: (bool val) async {
                  if (!val) {
                    SettingsSvc.settings.globalTextDetection.value = "";
                    await SettingsSvc.settings.saveOneAsync('globalTextDetection');
                    return;
                  }
                  final TextEditingController controller = TextEditingController();
                  controller.text = SettingsSvc.settings.globalTextDetection.value;
                  await showDialog(
                    context: context,
                    builder: (context) => TextDetectionDialog(controller),
                  );
                  SettingsSvc.settings.globalTextDetection.value = controller.text;
                  await SettingsSvc.settings.saveOneAsync('globalTextDetection');
                },
                backgroundColor: tileColor,
              ),
              if (SettingsSvc.settings.globalTextDetection.value.isNotEmpty)
                SettingsTile(
                  title: "Whitelisted Phrases",
                  subtitle: SettingsSvc.settings.globalTextDetection.value,
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.pencil,
                    materialIcon: Icons.edit_outlined,
                    containerColor: Colors.teal,
                  ),
                  onTap: () async {
                    final TextEditingController controller = TextEditingController();
                    controller.text = SettingsSvc.settings.globalTextDetection.value;
                    await showDialog(
                      context: context,
                      builder: (context) => TextDetectionDialog(controller),
                    );
                    SettingsSvc.settings.globalTextDetection.value = controller.text;
                    await SettingsSvc.settings.saveOneAsync('globalTextDetection');
                  },
                ),
            ])),
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Advanced"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Obx(() => SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.hideTextPreviews.value = val;
                        await SettingsSvc.settings.saveOneAsync('hideTextPreviews');
                      },
                      initialVal: SettingsSvc.settings.hideTextPreviews.value,
                      title: "Hide Message Text",
                      subtitle: "Replaces message text with 'iMessage' in notifications",
                      backgroundColor: tileColor,
                    )),
                const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                Obx(() => SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.showIncrementalSync.value = val;
                        await SettingsSvc.settings.saveOneAsync('showIncrementalSync');
                      },
                      initialVal: SettingsSvc.settings.showIncrementalSync.value,
                      title: "Notify When Incremental Sync Complete",
                      subtitle: "Show a toast whenever a message sync is completed",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
                if (!kIsWeb && !kIsDesktop) ...[
                  AnimatedSizeAndFade.showHide(
                    show: SettingsSvc.settings.enablePrivateAPI.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                        Obx(() => SettingsSwitch(
                              onChanged: (bool val) async {
                                SettingsSvc.settings.notificationReactionAction.value = val;
                                await SettingsSvc.settings.saveOneAsync('notificationReactionAction');
                              },
                              initialVal: SettingsSvc.settings.notificationReactionAction.value,
                              title: "Quick Reaction from Notifications",
                              subtitle: "Add a quick reaction button to your notifications (requires Private API)",
                              backgroundColor: tileColor,
                              isThreeLine: true,
                            )),
                      ],
                    ),
                  ),
                  AnimatedSizeAndFade.showHide(
                    show: SettingsSvc.settings.enablePrivateAPI.value &&
                        SettingsSvc.settings.notificationReactionAction.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Obx(() => ReactionTypePicker(
                            title: "Notification Reaction Type",
                            currentValue: SettingsSvc.settings.notificationReactionActionType.value,
                            reactions: [ReactionTypes.LOVE, ReactionTypes.LIKE],
                            onChanged: (val) async {
                              if (val == null) return;
                              SettingsSvc.settings.notificationReactionActionType.value = val;
                              await SettingsSvc.settings.saveOneAsync('notificationReactionActionType');
                            },
                            secondaryColor: headerColor,
                            useModernMenu: true,
                          )),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      )
    ];

    return Obx(() => BBScaffold(
          backgroundColor: headerColor,
          extendBodyBehindAppBar: false,
          appBar: samsung && index.value == 0
              ? null
              : BBAppBar(
                  titleText: "Notifications",
                  leading: buildBackButton(context),
                  toolbarHeight: 50,
                ),
          body: TabBarView(
            physics: ThemeSwitcher.getScrollPhysics(),
            controller: tabController,
            children: <Widget>[
              NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  if (SettingsSvc.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                  final scrollDistance = context.height / 3 - 57;

                  if (controller1.offset > 0 && controller1.offset < scrollDistance) {
                    final double snapOffset = controller1.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                    Future.microtask(() => controller1.animateTo(snapOffset,
                        duration: const Duration(milliseconds: 200), curve: Curves.linear));
                  }
                  return false;
                },
                child: ScrollbarWrapper(
                  controller: controller1,
                  child: Obx(
                    () => CustomScrollView(
                      controller: controller1,
                      physics: (kIsDesktop || kIsWeb)
                          ? const NeverScrollableScrollPhysics()
                          : ThemeSwitcher.getScrollPhysics(),
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
                                      child: Center(
                                          child: Text("Notifications",
                                              style: context.theme.textTheme.displaySmall!
                                                  .copyWith(color: context.theme.colorScheme.onSurface),
                                              textAlign: TextAlign.center)),
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
                                        child: SizedBox(
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
                        if (SettingsSvc.settings.skin.value != Skins.Samsung) ...bodySlivers,
                        if (SettingsSvc.settings.skin.value == Skins.Samsung)
                          SliverToBoxAdapter(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: context.height -
                                      50 -
                                      context.mediaQueryPadding.top -
                                      context.mediaQueryViewPadding.top),
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
              if (!kIsWeb) const ChatList(),
            ],
          ),
          bottomNavigationBar: kIsWeb
              ? null
              : NavigationBar(
                  selectedIndex: index.value,
                  backgroundColor: headerColor,
                  destinations: [
                    NavigationDestination(
                      icon: Icon(iOS ? CupertinoIcons.globe : Icons.public),
                      label: "GLOBAL OPTIONS",
                    ),
                    NavigationDestination(
                      icon: Icon(
                        iOS ? CupertinoIcons.conversation_bubble : Icons.chat_bubble_outline,
                      ),
                      label: "CHAT OPTIONS",
                    ),
                  ],
                  onDestinationSelected: (page) {
                    index.value = page;
                    tabController.animateTo(page);
                  },
                ),
        ));
  }
}

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  State<StatefulWidget> createState() => ChatListState();
}

class ChatListState extends State<ChatList> with ThemeHelpers {
  final ScrollController controller = ScrollController();

  String getSubtitle(Chat chat) {
    if (chat.muteType == null) {
      return "No settings set";
    } else {
      String muteArgsStr = "";
      if (chat.muteArgs != null) {
        if (chat.muteType == "mute_individuals") {
          final participants = chat.handles.where((element) => chat.muteArgs!.split(",").contains(element.address));
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
                      findChildIndexCallback: (key) => findChildIndexByKey(ChatsSvc.allChats, key, (item) => item.guid),
                      itemBuilder: (context, index) {
                        final chat = ChatsSvc.allChats[index];
                        return ConversationTile(
                          key: Key(chat.guid.toString()),
                          chat: chat,
                          controller: Get.put(
                              ConversationListController(showUnknownSenders: true, showArchivedChats: true),
                              tag: "notification-panel"),
                          inSelectMode: true,
                          subtitle: Text(
                            getSubtitle(chat),
                            style: context.theme.textTheme.bodySmall!
                                .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                          ),
                          onSelect: (_) async {
                            await showDialog(
                              context: context,
                              builder: (context) => NotificationSettingsDialog(chat, () {
                                setState(() {});
                              }),
                            );
                          },
                        );
                      },
                      itemCount: ChatsSvc.length,
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
