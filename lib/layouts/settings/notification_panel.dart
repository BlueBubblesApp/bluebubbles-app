import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as uh;

class NotificationPanelController extends GetxController with SingleGetTickerProviderMixin {
  late final TabController tabController;
  final List<Widget> tabs = [];

  @override
  void onInit() {
    tabController = TabController(vsync: this, length: kIsWeb ? 1 : 2);
    tabs.add(Tab(
        icon: Icon(
          SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.globe : Icons.public,
          color: Theme.of(Get.context!).textTheme.bodyText1!.color,
        ),
        text: "GLOBAL OPTIONS"
    ));
    if (!kIsWeb) {
      tabs.add(Tab(
          icon: Icon(
            SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.conversation_bubble : Icons.chat_bubble_outline,
            color: Theme.of(Get.context!).textTheme.bodyText1!.color,
          ),
          text: "CHAT-SPECIFIC OPTIONS"
      ));
    }
    super.onInit();
  }
}

class NotificationPanel extends StatelessWidget {
  final ScrollController controller1 = ScrollController();

  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness: headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: GetBuilder<NotificationPanelController>(
        init: NotificationPanelController(),
        builder: (controller) => Scaffold(
          backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? tileColor : headerColor,
          appBar: SettingsManager().settings.skin.value == Skins.Samsung ? null : PreferredSize(
            preferredSize: Size(CustomNavigator.width(context), 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  systemOverlayStyle: ThemeData.estimateBrightnessForColor(headerColor) == Brightness.dark
                      ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                  toolbarHeight: 100.0,
                  elevation: 0,
                  leading: buildBackButton(context),
                  backgroundColor: headerColor.withOpacity(0.5),
                  title: Text(
                    "Notifications",
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                    final double snapOffset =
                    controller1.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                    Future.microtask(() => controller1.animateTo(snapOffset,
                        duration: Duration(milliseconds: 200), curve: Curves.linear));
                  }
                  return false;
                },
                child: ImprovedScrolling(
                  enableMMBScrolling: true,
                  mmbScrollConfig: MMBScrollConfig(
                    customScrollCursor: DefaultCustomScrollCursor(
                      cursorColor: context.textTheme.subtitle1!.color!,
                      backgroundColor: Colors.white,
                      borderColor: context.textTheme.headline1!.color!,
                    ),
                  ),
                  scrollController: controller1,
                  child: CustomScrollView(
                    controller: controller1,
                    physics: ThemeSwitcher.getScrollPhysics(),
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
                              var expandRatio = (constraints.maxHeight - 100)
                                  / (context.height / 3 - 50);

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
                                    child: Center(
                                        child: Text("Notifications", textScaleFactor: 2.5, textAlign: TextAlign.center)
                                    ),
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
                                            style: Theme.of(context).textTheme.headline1,
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
                                  height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                                  alignment: Alignment.bottomLeft,
                                  decoration: SettingsManager().settings.skin.value == Skins.iOS
                                      ? BoxDecoration(
                                    color: headerColor,
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                                  )
                                      : BoxDecoration(
                                    color: tileColor,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                                    child: Text("Notifications".psCapitalize,
                                        style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                                  )),
                            SettingsSection(
                              backgroundColor: tileColor,
                              children: [
                                Container(
                                    color: SettingsManager().settings.skin.value == Skins.Samsung ? null : tileColor,
                                    padding: EdgeInsets.only(top: 5.0)
                                ),
                                if (!kIsWeb)
                                  Obx(() => SettingsSwitch(
                                    onChanged: (bool val) {
                                      SettingsManager().settings.notifyOnChatList.value = val;
                                      saveSettings();
                                    },
                                    initialVal: SettingsManager().settings.notifyOnChatList.value,
                                    title: "Send Notifications on Chat List",
                                    subtitle: "Sends notifications for new messages while in the chat list or chat creator",
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
                                        ? "Notifications enabled" : uh.Notification.permission == "denied"
                                        ? "Notifications denied, please update your browser settings to re-enable notifications"
                                        : "Click to enable notifications",
                                    backgroundColor: tileColor,
                                  ),
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: headerColor),
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
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: headerColor),
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
                                      padding: const EdgeInsets.only(left: 65.0),
                                      child: SettingsDivider(color: headerColor),
                                    ),
                                  ),*/
                                SettingsTile(
                                  title: "Text Detection",
                                  onTap: () async {
                                    final TextEditingController controller = TextEditingController();
                                    controller.text = SettingsManager().settings.globalTextDetection.value;
                                    Get.defaultDialog(
                                      title: "Text detection",
                                      titleStyle: Theme.of(context).textTheme.headline1,
                                      backgroundColor: Theme.of(context).backgroundColor,
                                      buttonColor: Theme.of(context).primaryColor,
                                      content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text("Enter any text separated by commas to whitelist notifications for. These are case insensitive.\n\nE.g. 'John,hey guys,homework'\n"),
                                            ),
                                            Theme(
                                              data: Theme.of(context).copyWith(
                                                  inputDecorationTheme: const InputDecorationTheme(
                                                    labelStyle: TextStyle(color: Colors.grey),
                                                  )
                                              ),
                                              child: TextField(
                                                controller: controller,
                                                decoration: InputDecoration(
                                                  labelText: "Enter text to whitelist...",
                                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey,)),
                                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor,)),
                                                ),
                                              ),
                                            ),
                                          ]
                                      ),
                                      onConfirm: () async {
                                        SettingsManager().settings.globalTextDetection.value = controller.text;
                                        saveSettings();
                                        Get.back();
                                      },
                                    );
                                  },
                                  backgroundColor: tileColor,
                                  subtitle: "Mute all chats except when your choice of text is found in a message",
                                ),
                              ]
                            ),
                            Container(
                                color: SettingsManager().settings.skin.value == Skins.Samsung ? null : tileColor,
                                padding: EdgeInsets.only(top: SettingsManager().settings.skin.value == Skins.Samsung ? 30 : 5.0)
                            ),
                            if (SettingsManager().settings.skin.value != Skins.Samsung)
                              Container(
                                  height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                                  alignment: Alignment.bottomLeft,
                                  decoration: SettingsManager().settings.skin.value == Skins.iOS
                                      ? BoxDecoration(
                                    color: headerColor,
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                                  )
                                      : BoxDecoration(
                                    color: tileColor,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                                    child: Text("Advanced".psCapitalize,
                                        style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                                  )),
                            SettingsSection(
                              backgroundColor: tileColor,
                              children: [Obx(() =>
                                  SettingsSwitch(
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
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: headerColor),
                                  ),
                                ),
                                Obx(() =>
                                    SettingsSwitch(
                                      onChanged: (bool val) {
                                        SettingsManager().settings.showIncrementalSync.value = val;
                                        saveSettings();
                                      },
                                      initialVal: SettingsManager().settings.showIncrementalSync.value,
                                      title: "Notify when incremental sync complete",
                                      subtitle: "Show a snackbar whenever a message sync is completed",
                                      backgroundColor: tileColor,
                                    )),],
                            ),
                            if (SettingsManager().settings.skin.value != Skins.Samsung)
                              Container(
                                height: 30,
                                decoration: SettingsManager().settings.skin.value == Skins.iOS
                                    ? BoxDecoration(
                                  color: headerColor,
                                  border: Border(
                                      top: BorderSide(
                                          color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                                )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.all(40),
                      ),
                    ],
                  ),
                ),
              ),
              if (!kIsWeb)
                ChatList(headerColor: headerColor, tileColor: tileColor),
            ],
          ),
          bottomSheet: Container(
            color: tileColor,
            child: TabBar(
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(Get.context!).textTheme.bodyText1!.color,
              indicator: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.blue,
                    width: 3.0,
                  ),
                ),
              ),
              tabs: controller.tabs,
              controller: controller.tabController,
            ),
          ),
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
          final participants = chat.participants.where((element) => chat.muteArgs!.split(",").contains(element.address));
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
          final double snapOffset =
          controller.offset / scrollDistance > 0.5 ? scrollDistance : 0;

          Future.microtask(() => controller.animateTo(snapOffset,
              duration: Duration(milliseconds: 200), curve: Curves.linear));
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
                  var expandRatio = (constraints.maxHeight - 100)
                      / (context.height / 3 - 50);

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
                        child: Center(
                            child: Text("Notifications", textScaleFactor: 2.5, textAlign: TextAlign.center)
                        ),
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
                                style: Theme.of(context).textTheme.headline1,
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
                            style: Theme.of(context).textTheme.subtitle1,
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
                      style: Theme.of(context).textTheme.subtitle1,
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildListDelegate([
                SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      color: widget.tileColor,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return ConversationTile(
                            key: Key(
                                ChatBloc().chats[index].guid.toString()),
                            chat: ChatBloc().chats[index],
                            inSelectMode: true,
                            subtitle: Text(getSubtitle(ChatBloc().chats[index]), style: Theme.of(context).textTheme.subtitle1),
                            onSelect: (_) async {
                              final chat = ChatBloc().chats[index];
                              await Get.defaultDialog(
                                title: "Chat-Specific Settings",
                                titleStyle: Theme.of(context).textTheme.headline1,
                                confirm: Container(height: 0, width: 0),
                                cancel: Container(height: 0, width: 0),
                                content: Container(
                                  height: context.height - 200,
                                  child: SingleChildScrollView(
                                    child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          ListTile(
                                            title: Text(chat.muteType == "mute" ? "Unmute" : "Mute", style: Theme.of(context).textTheme.bodyText1),
                                            subtitle: Text("Completely ${chat.muteType == "mute" ? "unmute" : "mute"} this chat", style: Theme.of(context).textTheme.subtitle1),
                                            onTap: () async {
                                              Get.back();
                                              chat.toggleMute(chat.muteType != "mute");
                                              chat.save();
                                              if (mounted) setState(() {});
                                              EventDispatcher().emit("refresh", null);
                                            },
                                          ),
                                          ListTile(
                                            title: Text("Mute Individuals", style: Theme.of(context).textTheme.bodyText1),
                                            subtitle: Text("Mute certain individuals in this chat", style: Theme.of(context).textTheme.subtitle1),
                                            onTap: () async {
                                              Get.back();
                                              List<String?> names = chat.participants.map((e) => ContactManager().getContactTitle(e)).toList();
                                              List<String> existing = chat.muteArgs?.split(",") ?? [];
                                              Get.defaultDialog(
                                                title: "Mute Individuals",
                                                titleStyle: Theme.of(context).textTheme.headline1,
                                                backgroundColor: Theme.of(context).backgroundColor,
                                                buttonColor: Theme.of(context).primaryColor,

                                                content: Container(
                                                  constraints: BoxConstraints(
                                                    maxHeight: 300,
                                                  ),
                                                  child: Center(
                                                    child: Container(
                                                      width: 300,
                                                      height: 200,
                                                      constraints: BoxConstraints(
                                                        maxHeight: Get.height - 300,
                                                      ),
                                                      child: StatefulBuilder(
                                                          builder: (context, setState) {
                                                            return SingleChildScrollView(
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Padding(
                                                                    padding: const EdgeInsets.all(8.0),
                                                                    child: Text("Select the individuals you would like to mute"),
                                                                  ),
                                                                  ListView.builder(
                                                                    shrinkWrap: true,
                                                                    itemCount: chat.participants.length,
                                                                    physics: NeverScrollableScrollPhysics(),
                                                                    itemBuilder: (context, index) {
                                                                      return Theme(
                                                                        data: Theme.of(context).copyWith(unselectedWidgetColor: Theme.of(context).textTheme.headline1!.color),
                                                                        child: CheckboxListTile(
                                                                          value: existing.contains(chat.participants[index].address),
                                                                          onChanged: (val) {
                                                                            setState(() {
                                                                              if (val!) {
                                                                                existing.add(chat.participants[index].address);
                                                                              } else {
                                                                                existing.removeWhere((element) => element == chat.participants[index].address);
                                                                              }
                                                                            });
                                                                          },
                                                                          activeColor: Theme.of(context).primaryColor,
                                                                          title: Text(names[index] ?? chat.participants[index].address, style: Theme.of(context).textTheme.headline1),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                onConfirm: () {
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
                                                },
                                              );
                                            },
                                          ),
                                          ListTile(
                                            title: Text(chat.muteType == "temporary_mute" && shouldMuteDateTime(chat.muteArgs) ? "Delete Temporary Mute" : "Temporary Mute", style: Theme.of(context).textTheme.bodyText1),
                                            subtitle: Text(chat.muteType == "temporary_mute" && shouldMuteDateTime(chat.muteArgs) ? "" : "Mute this chat temporarily", style: Theme.of(context).textTheme.subtitle1),
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
                                                  final messageTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                                  if (messageTime != null) {
                                                    final finalDate = DateTime(messageDate.year, messageDate.month, messageDate.day, messageTime.hour, messageTime.minute);
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
                                            title: Text("Text Detection", style: Theme.of(context).textTheme.bodyText1),
                                            subtitle: Text("Completely mute this chat, except when a message contains certain text", style: Theme.of(context).textTheme.subtitle1),
                                            onTap: () async {
                                              Get.back();
                                              final TextEditingController controller = TextEditingController();
                                              if (chat.muteType == "text_detection") {
                                                controller.text = chat.muteArgs!;
                                              }
                                              Get.defaultDialog(
                                                title: "Text detection",
                                                titleStyle: Theme.of(context).textTheme.headline1,
                                                backgroundColor: Theme.of(context).backgroundColor,
                                                buttonColor: Theme.of(context).primaryColor,
                                                content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Text("Enter any text separated by commas to whitelist notifications for. These are case insensitive.\n\nE.g. 'John,hey guys,homework'\n"),
                                                      ),
                                                      Theme(
                                                        data: Theme.of(context).copyWith(
                                                            inputDecorationTheme: const InputDecorationTheme(
                                                              labelStyle: TextStyle(color: Colors.grey),
                                                            )
                                                        ),
                                                        child: TextField(
                                                          controller: controller,
                                                          decoration: InputDecoration(
                                                            labelText: "Enter text to whitelist...",
                                                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey,)),
                                                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor,)),
                                                          ),
                                                        ),
                                                      ),
                                                    ]
                                                ),
                                                onConfirm: () async {
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
                                                },
                                              );
                                            },
                                          ),
                                          ListTile(
                                            title: Text("Reset chat-specific settings", style: Theme.of(context).textTheme.bodyText1),
                                            subtitle: Text("Delete your custom settings", style: Theme.of(context).textTheme.subtitle1),
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
                                        ]
                                    ),
                                  ),
                                ),
                                barrierDismissible: true,
                                backgroundColor: Theme.of(context).backgroundColor,
                              );
                            },
                          );
                        },
                        itemCount: ChatBloc().chats.length,
                      )
                    )
                  )
                )
              ]),
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