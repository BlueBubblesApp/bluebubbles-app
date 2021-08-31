import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class NotificationPanelController extends GetxController with SingleGetTickerProviderMixin {
  late final TabController tabController;

  @override
  void onInit() {
    tabController = TabController(vsync: this, length: 2);
    super.onInit();
  }
}

class NotificationPanel extends StatelessWidget {
  final NotificationPanelController controller = Get.put(NotificationPanelController());

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
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness: headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(context.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Notification Settings",
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
            CustomScrollView(
              physics: ThemeSwitcher.getScrollPhysics(),
              slivers: <Widget>[
                SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
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
                      Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
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
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                      SettingsTile(
                        title: "Text Detection",
                        onTap: () async {
                          final TextEditingController controller = TextEditingController();
                          controller.text = SettingsManager().settings.globalTextDetection.value;
                          Get.defaultDialog(
                            title: "Text detection",
                            backgroundColor: Theme.of(context).backgroundColor,
                            buttonColor: Theme.of(context).primaryColor,
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("Enter any text separated by commas to whitelist notifications for. These are case insensitive.\n\nE.g. 'John,hey guys,homework'\n"),
                                  ),
                                  TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      labelText: "Enter text to whitelist...",
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey,)),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor,)),
                                    ),
                                  ),
                                ]
                            ),
                            onConfirm: () async {
                              if (controller.text.isEmpty) {
                                showSnackbar("Error", "Please enter text!");
                                return;
                              }
                              SettingsManager().settings.globalTextDetection.value = controller.text;
                              Get.back();
                            },
                          );
                        },
                        backgroundColor: tileColor,
                        subtitle: "Mute all chats except when your choice of text is found in a message",
                      ),
                      Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                      Container(
                        height: 30,
                        decoration: SettingsManager().settings.skin.value == Skins.iOS
                            ? BoxDecoration(
                          color: headerColor,
                          border: Border(
                              top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
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
            ChatList(),
          ],
        ),
        bottomSheet: Container(
          color: tileColor,
          child: TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            indicator: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.blue,
                  width: 3.0,
                ),
              ),
            ),
            tabs: [
              Tab(
                  icon: Icon(
                    Icons.public,
                    color: Theme.of(context).textTheme.bodyText1!.color,
                  ),
                  text: "GLOBAL OPTIONS"
              ),
              Tab(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: Theme.of(context).textTheme.bodyText1!.color,
                ),
                text: "CHAT-SPECIFIC OPTIONS"
              ),
            ],
            controller: controller.tabController,
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
  @override
  State<StatefulWidget> createState() => ChatListState();
}

class ChatListState extends State<ChatList> {

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
    return CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(
        parent: CustomBouncingScrollPhysics(),
      ),
      slivers: <Widget>[
        Obx(() {
          if (!ChatBloc().hasChats.value) {
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
          if (ChatBloc().hasChats.value && ChatBloc().chats.isEmpty) {
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
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                      content: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            ListTile(
                                title: Text(chat.muteType == "mute" ? "Unmute" : "Mute", style: Theme.of(context).textTheme.bodyText1),
                                subtitle: Text("Completely ${chat.muteType == "mute" ? "unmute" : "mute"} this chat", style: Theme.of(context).textTheme.subtitle1),
                                onTap: () async {
                                  Get.back();
                                  await chat.toggleMute(chat.muteType != "mute");
                                  await chat.update();
                                  if (this.mounted) setState(() {});
                                  EventDispatcher().emit("refresh", null);
                                },
                            ),
                            ListTile(
                                title: Text("Mute Individuals", style: Theme.of(context).textTheme.bodyText1),
                                subtitle: Text("Mute certain individuals in this chat", style: Theme.of(context).textTheme.subtitle1),
                                onTap: () async {
                                  Get.back();
                                  List<Future<String?>> names = chat.participants.map((e) async =>
                                  await ContactManager().getContactTitle(e)).toList();
                                  Future<List<String?>> futureList = Future.wait(names);
                                  List<String?> result = await futureList;
                                  List<String> existing = chat.muteArgs?.split(",") ?? [];
                                  Get.defaultDialog(
                                      title: "Mute Individuals",
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
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text("Select the individuals you would like to mute"),
                                                    ),
                                                    ListView.builder(
                                                      shrinkWrap: true,
                                                      itemCount: chat.participants.length,
                                                      itemBuilder: (context, index) {
                                                        return CheckboxListTile(
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
                                                            title: Text(result[index] ?? chat.participants[index].address, style: Theme.of(context).textTheme.headline1),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                );
                                              }
                                            ),
                                          ),
                                        ),
                                      ),
                                      onConfirm: () async {
                                        if (existing.isEmpty) {
                                          showSnackbar("Error", "Please select at least one person!");
                                          return;
                                        }
                                        await chat.toggleMute(false);
                                        chat.muteType = "mute_individuals";
                                        chat.muteArgs = existing.join(",");
                                        Get.back();
                                        await chat.update();
                                        if (this.mounted) setState(() {});
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
                                        await chat.toggleMute(false);
                                        chat.muteType = "temporary_mute";
                                        chat.muteArgs = finalDate.toIso8601String();
                                        await chat.update();
                                        if (this.mounted) setState(() {});
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
                                    backgroundColor: Theme.of(context).backgroundColor,
                                    buttonColor: Theme.of(context).primaryColor,
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text("Enter any text separated by commas to whitelist notifications for. These are case insensitive.\n\nE.g. 'John,hey guys,homework'\n"),
                                        ),
                                        TextField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            labelText: "Enter text to whitelist...",
                                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey,)),
                                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor,)),
                                          ),
                                        ),
                                      ]
                                    ),
                                    onConfirm: () async {
                                      if (controller.text.isEmpty) {
                                        showSnackbar("Error", "Please enter text!");
                                        return;
                                      }
                                      await chat.toggleMute(false);
                                      chat.muteType = "text_detection";
                                      chat.muteArgs = controller.text;
                                      Get.back();
                                      await chat.update();
                                      if (this.mounted) setState(() {});
                                      EventDispatcher().emit("refresh", null);
                                    },
                                  );
                                },
                            ),
                            ListTile(
                              title: Text("Remove chat-specific settings", style: Theme.of(context).textTheme.bodyText1),
                              subtitle: Text("Delete your custom settings", style: Theme.of(context).textTheme.subtitle1),
                              onTap: () async {
                                Get.back();
                                await chat.toggleMute(false);
                                chat.muteType = null;
                                chat.muteArgs = null;
                                await chat.update();
                                if (this.mounted) setState(() {});
                                EventDispatcher().emit("refresh", null);
                              },
                            ),
                          ]
                      ),
                      barrierDismissible: true,
                      backgroundColor: Theme.of(context).backgroundColor,
                    );
                  },
                );
              },
              childCount: ChatBloc().chats.length,
            ),
          );
        }),
        SliverPadding(
          padding: EdgeInsets.all(40),
        ),
      ],
    );
  }
}