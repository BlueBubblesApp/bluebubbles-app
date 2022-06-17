import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as uh;

class NotificationPanelController extends GetxController with SingleGetTickerProviderMixin {
  late final TabController tabController;
  final RxInt index = 0.obs;

  @override
  void onInit() {
    tabController = TabController(vsync: this, length: kIsWeb ? 1 : 2);
    super.onInit();
  }
}

class NotificationPanel extends StatelessWidget {
  final ScrollController controller1 = ScrollController();

  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness,
      ),
      child: GetBuilder<NotificationPanelController>(
        init: NotificationPanelController(),
        builder: (controller) => Scaffold(
          backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? tileColor : headerColor,
          appBar: SettingsManager().settings.skin.value == Skins.Samsung
              ? null
              : PreferredSize(
            preferredSize: Size(CustomNavigator.width(context), 50),
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
              centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
              title: Text(
                "Notifications",
                style: context.theme.textTheme.titleLarge,
              ),
            ),
          ),
          body: TabBarView(
            physics: ThemeSwitcher.getScrollPhysics(),
            controller: controller.tabController,
            children: <Widget>[
              NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  if (SettingsManager().settings.skin.value != Skins.Samsung) return false;
                  final scrollDistance = context.height / 3 - 57;

                  if (controller1.offset > 0 && controller1.offset < scrollDistance) {
                    final double snapOffset = controller1.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                    Future.microtask(() =>
                        controller1.animateTo(snapOffset, duration: Duration(milliseconds: 200), curve: Curves.linear));
                  }
                  return false;
                },
                child: ScrollbarWrapper(
                  controller: controller1,
                  child: Obx(
                    () => CustomScrollView(
                      controller: controller1,
                      physics:
                          (kIsDesktop || kIsWeb) ? NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics(),
                      slivers: <Widget>[
                        if (SettingsManager().settings.skin.value == Skins.Samsung)
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
                                        curve: Interval(0.3, 1.0, curve: Curves.easeIn),
                                      )),
                                      child: Center(child: Text("Notifications", style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
                                    ),
                                    FadeTransition(
                                      opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
                                      )),
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Container(
                                          padding: EdgeInsets.only(left: 40),
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
                        SliverList(
                          delegate: SliverChildListDelegate(
                            <Widget>[
                              if (SettingsManager().settings.skin.value != Skins.Samsung)
                                Container(
                                    height: 50,
                                    alignment: Alignment.bottomLeft,
                                    color: SettingsManager().settings.skin.value == Skins.iOS ? headerColor : tileColor,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 8.0, left: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 15),
                                      child: Text("Notifications".psCapitalize,
                                          style: SettingsManager().settings.skin.value == Skins.iOS
                                              ? iosSubtitle
                                              : materialSubtitle),
                                    )),
                              SettingsSection(backgroundColor: tileColor, children: [
                                if (!kIsWeb)
                                  Obx(() => SettingsSwitch(
                                        onChanged: (bool val) {
                                          SettingsManager().settings.notifyOnChatList.value = val;
                                          saveSettings();
                                        },
                                        initialVal: SettingsManager().settings.notifyOnChatList.value,
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
                                      controller.update();
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
                                        SettingsManager().settings.notifyReactions.value = val;
                                        saveSettings();
                                      },
                                      initialVal: SettingsManager().settings.notifyReactions.value,
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
                                    if (SettingsManager().settings.skin.value == Skins.iOS)
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
                                    initial: SettingsManager().settings.notificationSound.value,
                                    onChanged: (val) {
                                      if (val == null) return;
                                      SettingsManager().settings.notificationSound.value = val;
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
                                    controller.text = SettingsManager().settings.globalTextDetection.value;
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text("Text detection", style: context.theme.textTheme.titleLarge),
                                        backgroundColor: context.theme.colorScheme.properSurface,
                                        content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                    "Enter any text separated by commas to whitelist notifications for. These are case insensitive.\n\nE.g. 'John,hey guys,homework'\n", style: context.theme.textTheme.bodyLarge,),
                                              ),
                                              TextField(
                                                controller: controller,
                                                decoration: InputDecoration(
                                                  labelText: "Enter text to whitelist...",
                                                  enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: context.theme.colorScheme.outline,
                                                      )),
                                                  focusedBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: context.theme.colorScheme.primary,
                                                      )),
                                                ),
                                              ),
                                        ]),
                                        actions: [
                                          TextButton(
                                              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                              onPressed: () {
                                                SettingsManager().settings.globalTextDetection.value = controller.text;
                                                saveSettings();
                                                Get.back();
                                              }
                                          ),
                                        ],
                                      )
                                    );
                                  },
                                  backgroundColor: tileColor,
                                  subtitle: "Mute all chats except when your choice of text is found in a message",
                                ),
                              ]),
                              SettingsHeader(
                                  headerColor: headerColor,
                                  tileColor: tileColor,
                                  iosSubtitle: iosSubtitle,
                                  materialSubtitle: materialSubtitle,
                                  text: "Advanced"),
                              SettingsSection(
                                backgroundColor: tileColor,
                                children: [
                                  Obx(() => SettingsSwitch(
                                        onChanged: (bool val) {
                                          SettingsManager().settings.hideTextPreviews.value = val;
                                          saveSettings();
                                        },
                                        initialVal: SettingsManager().settings.hideTextPreviews.value,
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
                                          SettingsManager().settings.showIncrementalSync.value = val;
                                          saveSettings();
                                        },
                                        initialVal: SettingsManager().settings.showIncrementalSync.value,
                                        title: "Notify When Incremental Sync Complete",
                                        subtitle: "Show a snackbar whenever a message sync is completed",
                                        backgroundColor: tileColor,
                                        isThreeLine: true,
                                      )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!kIsWeb) ChatList(headerColor: headerColor, tileColor: tileColor),
            ],
          ),
          bottomNavigationBar: kIsWeb ? null : Obx(() => NavigationBar(
            selectedIndex: controller.index.value,
            backgroundColor: headerColor,
            destinations: [
              NavigationDestination(
                icon: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.globe : Icons.public),
                label: "GLOBAL OPTIONS",
              ),
              NavigationDestination(
                icon: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS
                      ? CupertinoIcons.conversation_bubble
                      : Icons.chat_bubble_outline,
                ),
                label: "CHAT OPTIONS",
              ),
            ],
            onDestinationSelected: (page) {
              controller.index.value = page;
              controller.tabController.animateTo(page);
            },
          )),
        ),
      ),
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}

class ChatList extends StatefulWidget {
  final Color headerColor;
  final Color tileColor;

  ChatList({required this.headerColor, required this.tileColor});

  @override
  State<StatefulWidget> createState() => ChatListState();
}

class ChatListState extends State<ChatList> {
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

  bool shouldMuteDateTime(String? muteArgs) {
    if (muteArgs == null) return false;
    DateTime? time = DateTime.tryParse(muteArgs);
    if (time == null) return false;
    return DateTime.now().toLocal().difference(time).inSeconds.isNegative;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        if (SettingsManager().settings.skin.value != Skins.Samsung) return false;
        final scrollDistance = context.height / 3 - 57;

        if (controller.offset > 0 && controller.offset < scrollDistance) {
          final double snapOffset = controller.offset / scrollDistance > 0.5 ? scrollDistance : 0;

          Future.microtask(
              () => controller.animateTo(snapOffset, duration: Duration(milliseconds: 200), curve: Curves.linear));
        }
        return false;
      },
      child: CustomScrollView(
        controller: controller,
        physics: ThemeSwitcher.getScrollPhysics(),
        slivers: <Widget>[
          if (SettingsManager().settings.skin.value == Skins.Samsung)
            SliverAppBar(
              backgroundColor: widget.headerColor,
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
                          curve: Interval(0.3, 1.0, curve: Curves.easeIn),
                        )),
                        child: Center(child: Text("Notifications", style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
                      ),
                      FadeTransition(
                        opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                          parent: animation,
                          curve: Interval(0.0, 0.7, curve: Curves.easeOut),
                        )),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: EdgeInsets.only(left: 40),
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
          Obx(() {
            if (!ChatBloc().loadedChatBatch.value) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
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
            if (ChatBloc().loadedChatBatch.value && ChatBloc().chats.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
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
                physics: NeverScrollableScrollPhysics(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    height: context.height - 175,
                    color: widget.tileColor,
                    child: ScrollbarWrapper(
                      controller: _controller,
                      child: ListView.builder(
                        physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                            ? NeverScrollableScrollPhysics()
                            : ThemeSwitcher.getScrollPhysics(),
                        shrinkWrap: true,
                        controller: _controller,
                        itemBuilder: (context, index) {
                          return ConversationTile(
                            key: Key(ChatBloc().chats[index].guid.toString()),
                            chat: ChatBloc().chats[index],
                            inSelectMode: true,
                            subtitle: Text(getSubtitle(ChatBloc().chats[index]),
                                style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                            onSelect: (_) async {
                              final chat = ChatBloc().chats[index];
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Chat-Specific Settings", style: context.theme.textTheme.titleLarge),
                                  content: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                    ListTile(
                                      title: Text(chat.muteType == "mute" ? "Unmute" : "Mute",
                                          style: context.theme.textTheme.bodyLarge),
                                      subtitle: Text(
                                          "Completely ${chat.muteType == "mute" ? "unmute" : "mute"} this chat",
                                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                                      onTap: () async {
                                        Get.back();
                                        chat.toggleMute(chat.muteType != "mute");
                                        chat.save();
                                        if (mounted) setState(() {});
                                        EventDispatcher().emit("refresh", null);
                                      },
                                    ),
                                    if (chat.isGroup())
                                    ListTile(
                                      title: Text("Mute Individuals", style: context.theme.textTheme.bodyLarge),
                                      subtitle: Text("Mute certain individuals in this chat",
                                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                                      onTap: () async {
                                        Get.back();
                                        List<String?> names = chat.participants
                                            .map((e) => ContactManager().getContactTitle(e))
                                            .toList();
                                        List<String> existing = chat.muteArgs?.split(",") ?? [];
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text("Mute Individuals", style: context.theme.textTheme.titleLarge),
                                            backgroundColor: context.theme.colorScheme.properSurface,
                                            content: SingleChildScrollView(
                                              child: Container(
                                                width: double.maxFinite,
                                                child: StatefulBuilder(builder: (context, setState) {
                                                  return Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child:
                                                        Text("Select the individuals you would like to mute"),
                                                      ),
                                                      ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          maxHeight: context.mediaQuery.size.height * 0.4,
                                                        ),
                                                        child: ListView.builder(
                                                          shrinkWrap: true,
                                                          itemCount: chat.participants.length,
                                                          itemBuilder: (context, index) {
                                                            return CheckboxListTile(
                                                              value: existing
                                                                  .contains(chat.participants[index].address),
                                                              onChanged: (val) {
                                                                setState(() {
                                                                  if (val!) {
                                                                    existing.add(chat.participants[index].address);
                                                                  } else {
                                                                    existing.removeWhere((element) =>
                                                                    element ==
                                                                        chat.participants[index].address);
                                                                  }
                                                                });
                                                              },
                                                              activeColor: context.theme.colorScheme.primary,
                                                              title: Text(
                                                                  names[index] ?? chat.participants[index].address,
                                                                  style: context.theme.textTheme.bodyLarge),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                  child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                  onPressed: () {
                                                    if (existing.isEmpty) {
                                                      showSnackbar("Error", "Please select at least one person!");
                                                      return;
                                                    }
                                                    chat.toggleMute(false);
                                                    chat.muteType = "mute_individuals";
                                                    chat.muteArgs = existing.join(",");
                                                    Get.back();
                                                    chat.save(updateMuteType: true, updateMuteArgs: true);
                                                    if (mounted) setState(() {});
                                                    EventDispatcher().emit("refresh", null);
                                                  }
                                              ),
                                            ],
                                          )
                                        );
                                      },
                                    ),
                                    ListTile(
                                      title: Text(
                                          chat.muteType == "temporary_mute" && shouldMuteDateTime(chat.muteArgs)
                                              ? "Delete Temporary Mute"
                                              : "Temporary Mute",
                                          style: context.theme.textTheme.bodyLarge),
                                      subtitle: Text(
                                          chat.muteType == "temporary_mute" && shouldMuteDateTime(chat.muteArgs)
                                              ? ""
                                              : "Mute this chat temporarily",
                                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                                      onTap: () async {
                                        Get.back();
                                        if (shouldMuteDateTime(chat.muteArgs)) {
                                          chat.muteType = null;
                                          chat.muteArgs = null;
                                          chat.save(updateMuteType: true, updateMuteArgs: true);
                                        } else {
                                          final messageDate = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now().toLocal(),
                                              firstDate: DateTime.now().toLocal(),
                                              lastDate: DateTime.now().toLocal().add(Duration(days: 365)));
                                          if (messageDate != null) {
                                            final messageTime =
                                            await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                            if (messageTime != null) {
                                              final finalDate = DateTime(messageDate.year, messageDate.month,
                                                  messageDate.day, messageTime.hour, messageTime.minute);
                                              chat.toggleMute(false);
                                              chat.muteType = "temporary_mute";
                                              chat.muteArgs = finalDate.toIso8601String();
                                              chat.save(updateMuteType: true, updateMuteArgs: true);
                                              if (mounted) setState(() {});
                                              EventDispatcher().emit("refresh", null);
                                            }
                                          }
                                        }
                                      },
                                    ),
                                    ListTile(
                                      title: Text("Text Detection", style: context.theme.textTheme.bodyLarge),
                                      subtitle: Text(
                                          "Completely mute this chat, except when a message contains certain text",
                                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                                      onTap: () async {
                                        Get.back();
                                        final TextEditingController controller = TextEditingController();
                                        if (chat.muteType == "text_detection") {
                                          controller.text = chat.muteArgs!;
                                        }
                                        showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text("Text detection", style: context.theme.textTheme.titleLarge),
                                              backgroundColor: context.theme.colorScheme.properSurface,
                                              content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text(
                                                        "Enter any text separated by commas to whitelist notifications for. These are case insensitive.\n\nE.g. 'John,hey guys,homework'\n", style: context.theme.textTheme.bodyLarge,),
                                                    ),
                                                    TextField(
                                                      controller: controller,
                                                      decoration: InputDecoration(
                                                        labelText: "Enter text to whitelist...",
                                                        enabledBorder: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color: context.theme.colorScheme.outline,
                                                            )),
                                                        focusedBorder: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color: context.theme.colorScheme.primary,
                                                            )),
                                                      ),
                                                    ),
                                                  ]),
                                              actions: [
                                                TextButton(
                                                    child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                    onPressed: () {
                                                      if (controller.text.isEmpty) {
                                                        showSnackbar("Error", "Please enter text!");
                                                        return;
                                                      }
                                                      chat.toggleMute(false);
                                                      chat.muteType = "text_detection";
                                                      chat.muteArgs = controller.text;
                                                      Get.back();
                                                      chat.save(updateMuteType: true, updateMuteArgs: true);
                                                      if (mounted) setState(() {});
                                                      EventDispatcher().emit("refresh", null);
                                                    }
                                                ),
                                              ],
                                            )
                                        );
                                      },
                                    ),
                                    ListTile(
                                      title: Text("Reset chat-specific settings",
                                          style: context.theme.textTheme.bodyLarge),
                                      subtitle: Text("Delete your custom settings",
                                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),),
                                      onTap: () async {
                                        Get.back();
                                        chat.toggleMute(false);
                                        chat.muteType = null;
                                        chat.muteArgs = null;
                                        chat.save(updateMuteType: true, updateMuteArgs: true);
                                        if (mounted) setState(() {});
                                        EventDispatcher().emit("refresh", null);
                                      },
                                    ),
                                  ]),
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                )
                              );
                            },
                          );
                        },
                        itemCount: ChatBloc().chats.length,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          SliverPadding(
            padding: EdgeInsets.all(40),
          ),
        ],
      ),
    );
  }
}
