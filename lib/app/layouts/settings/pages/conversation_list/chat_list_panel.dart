import 'dart:math';

import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/conversation_list/pinned_order_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatListPanel extends StatefulWidget {
  const ChatListPanel({super.key});

  @override
  State<StatefulWidget> createState() => _ChatListPanelState();
}

class _ChatListPanelState extends State<ChatListPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(expressive: true, 
        title: "Chat List",
        initialHeader: "Indicators",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                SettingsSection(expressive: true, 
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.showSyncIndicator.value = val;
                            await SettingsSvc.settings.saveOneAsync('showSyncIndicator');
                          },
                          initialVal: SettingsSvc.settings.showSyncIndicator.value,
                          title: "Show Sync Indicator in Chat List",
                          subtitle:
                              "Enables a small indicator at the top left to show when the app is syncing messages",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.statusIndicatorsOnChats.value = val;
                            await SettingsSvc.settings.saveOneAsync('statusIndicatorsOnChats');
                          },
                          initialVal: SettingsSvc.settings.statusIndicatorsOnChats.value,
                          title: "Message Status Indicators",
                          subtitle:
                              "Adds status indicators to the chat list for the sent / delivered / read status of your most recent message",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                  ],
                ),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Filtering"),
                SettingsSection(expressive: true, 
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.filteredChatList.value = val;
                            await SettingsSvc.settings.saveOneAsync('filteredChatList');
                          },
                          initialVal: SettingsSvc.settings.filteredChatList.value,
                          title: "Filtered Chat List",
                          subtitle:
                              "Filters the chat list based on parameters set in iMessage (usually this removes old, inactive chats)",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.filterUnknownSenders.value = val;
                            await SettingsSvc.settings.saveOneAsync('filterUnknownSenders');
                          },
                          initialVal: SettingsSvc.settings.filterUnknownSenders.value,
                          title: "Filter Unknown Senders",
                          subtitle:
                              "Turn off notifications for senders who aren't in your contacts and sort them into a separate chat list",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    if (!kIsWeb) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.unarchiveOnNewMessage.value = val;
                              await SettingsSvc.settings.saveOneAsync('unarchiveOnNewMessage');
                            },
                            initialVal: SettingsSvc.settings.unarchiveOnNewMessage.value,
                            title: "Unarchive Chats On New Message",
                            subtitle: "Automatically unarchive chats when a new message is received",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                  ],
                ),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Appearance"),
                Obx(() => SettingsSection(expressive: true,
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.hideDividers.value = val;
                            await SettingsSvc.settings.saveOneAsync('hideDividers');
                          },
                          initialVal: SettingsSvc.settings.hideDividers.value,
                          title: "Hide Dividers",
                          backgroundColor: tileColor,
                          subtitle: "Hides dividers between tiles",
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.denseChatTiles.value = val;
                            await SettingsSvc.settings.saveOneAsync('denseChatTiles');
                          },
                          initialVal: SettingsSvc.settings.denseChatTiles.value,
                          title: "Dense Conversation Tiles",
                          backgroundColor: tileColor,
                          subtitle: "Compresses chat tile size on the conversation list page",
                          isThreeLine: true,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsDesktop && !kIsWeb && iOS)
                      const SettingsTile(
                        title: "Pin Configuration",
                        subtitle: "The row and column count of the pin grid. ",
                        isThreeLine: true,
                      ),
                    if (!kIsDesktop && !kIsWeb && iOS)
                      Row(
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(left: 48),
                            child: SizedBox(
                              width: 100,
                              child: Text("Row Count in Portrait"),
                            ),
                          ),
                          Flexible(
                            child: SettingsOptions<int>(
                              onChanged: (int? val) async {
                                if (val == null) return;
                                SettingsSvc.settings.pinRowsPortrait.value = val.toInt();
                                await SettingsSvc.settings.saveOneAsync('pinRowsPortrait');
                              },
                              options: List.generate(4, (index) => index + 1),
                              initial: SettingsSvc.settings.pinRowsPortrait.value,
                              title: '',
                              secondaryColor: context.theme.colorScheme.secondary,
                              textProcessing: (val) => val.toString(),
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    if (!kIsDesktop && !kIsWeb && iOS)
                      Row(
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(left: 48),
                            child: SizedBox(
                              width: 100,
                              child: Text("Row Count in Landscape"),
                            ),
                          ),
                          Flexible(
                            child: SettingsOptions<int>(
                              onChanged: (int? val) async {
                                if (val == null) return;
                                SettingsSvc.settings.pinRowsLandscape.value = val.toInt();
                                await SettingsSvc.settings.saveOneAsync('pinRowsLandscape');
                              },
                              options: List.generate(4, (index) => index + 1),
                              initial: SettingsSvc.settings.pinRowsLandscape.value,
                              title: '',
                              secondaryColor: context.theme.colorScheme.secondary,
                              textProcessing: (val) => val.toString(),
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    if (!kIsDesktop && !kIsWeb && iOS)
                      Row(
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(left: 48),
                            child: SizedBox(
                              width: 100,
                              child: Text("Column Count"),
                            ),
                          ),
                          Flexible(
                            child: SettingsOptions<int>(
                              onChanged: (int? val) async {
                                if (val == null) return;
                                SettingsSvc.settings.pinColumnsPortrait.value = val.toInt();
                                await SettingsSvc.settings.saveOneAsync('pinColumnsPortrait');
                              },
                              options: List.generate(4, (index) => index + 1),
                              initial: SettingsSvc.settings.pinColumnsPortrait.value,
                              title: '',
                              secondaryColor: context.theme.colorScheme.secondary,
                              textProcessing: (val) => val.toString(),
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    if (!kIsWeb) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (kIsDesktop && iOS)
                      SettingsTile(
                        title:
                            "Pinned Chat Configuration (${SettingsSvc.settings.pinRowsPortrait.value} row${SettingsSvc.settings.pinRowsPortrait.value > 1 ? "s" : ""} of ${SettingsSvc.settings.pinColumnsLandscape})",
                        subtitle:
                            "Pinned chats will overflow onto multiple pages if they do not fit in this configuration.",
                      ),
                    if (kIsDesktop && iOS)
                      Row(
                            children: <Widget>[
                              Flexible(
                                child: Column(
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        const Padding(
                                          padding: EdgeInsets.only(left: 48),
                                          child: SizedBox(
                                            width: 100,
                                            child: Text("Row Count"),
                                          ),
                                        ),
                                        Flexible(
                                          child: SettingsOptions<int>(
                                            initial: SettingsSvc.settings.pinRowsPortrait.value,
                                            options: List.generate(4, (index) => index + 1),
                                            onChanged: (int? val) async {
                                              if (val == null) return;
                                              SettingsSvc.settings.pinRowsPortrait.value = val;
                                              await SettingsSvc.settings.saveOneAsync('pinRowsPortrait');
                                            },
                                            title: "Pin Rows",
                                            secondaryColor: context.theme.colorScheme.secondary,
                                            textProcessing: (val) => val.toString(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: <Widget>[
                                        const Padding(
                                          padding: EdgeInsets.only(left: 48),
                                          child: SizedBox(
                                            width: 100,
                                            child: Text("Column Count"),
                                          ),
                                        ),
                                        Flexible(
                                          child: SettingsOptions<int>(
                                            initial: SettingsSvc.settings.pinColumnsLandscape.value,
                                            options: List.generate(5, (index) => index + 2),
                                            onChanged: (int? val) async {
                                              if (val == null) return;
                                              SettingsSvc.settings.pinColumnsLandscape.value = val;
                                              await SettingsSvc.settings.saveOneAsync('pinColumnsLandscape');
                                            },
                                            title: "Pins Per Row",
                                            secondaryColor: context.theme.colorScheme.secondary,
                                            textProcessing: (val) => val.toString(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Obx(() {
                                NavigationSvc.listener.value;
                                double width = 108 * context.width / context.height;
                                if (NavigationSvc.width(context) != context.width) {
                                  return Container(
                                    width: width,
                                    height: 108,
                                    margin: const EdgeInsets.only(left: 24, right: 48),
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Flexible(
                                          child: Container(
                                            color: context.theme.colorScheme.secondary,
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: AbsorbPointer(
                                              child: Obx(
                                                () => Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Container(
                                                        height: 12,
                                                        padding: const EdgeInsets.only(left: 2, top: 3),
                                                        child: Text(
                                                          "Messages",
                                                          style: context.textTheme.labelLarge!.copyWith(fontSize: 4),
                                                          textAlign: TextAlign.left,
                                                        )),
                                                    Obx(
                                                      () => Expanded(
                                                        flex: SettingsSvc.settings.pinRowsPortrait.value *
                                                            (width -
                                                                NavigationSvc.width(context) / context.width * width) ~/
                                                            SettingsSvc.settings.pinColumnsLandscape.value,
                                                        child: GridView.custom(
                                                          shrinkWrap: true,
                                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                            crossAxisCount:
                                                                SettingsSvc.settings.pinColumnsLandscape.value,
                                                          ),
                                                          physics: const NeverScrollableScrollPhysics(),
                                                          childrenDelegate: SliverChildBuilderDelegate(
                                                            (context, index) => Container(
                                                              margin: EdgeInsets.all(2 /
                                                                  max(SettingsSvc.settings.pinRowsPortrait.value,
                                                                      SettingsSvc.settings.pinColumnsLandscape.value)),
                                                              decoration: BoxDecoration(
                                                                  borderRadius: BorderRadius.circular(50 /
                                                                      max(
                                                                          SettingsSvc.settings.pinRowsPortrait.value,
                                                                          SettingsSvc
                                                                              .settings.pinColumnsLandscape.value)),
                                                                  color: context.theme.colorScheme.secondary
                                                                      .lightenOrDarken(10)),
                                                            ),
                                                            childCount: SettingsSvc.settings.pinColumnsLandscape.value *
                                                                SettingsSvc.settings.pinRowsPortrait.value,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (SettingsSvc.settings.pinRowsPortrait.value *
                                                            (width -
                                                                NavigationSvc.width(context) / context.width * width) /
                                                            SettingsSvc.settings.pinColumnsLandscape.value <
                                                        96)
                                                      Expanded(
                                                        flex: 96 -
                                                            SettingsSvc.settings.pinRowsPortrait.value *
                                                                (width -
                                                                    NavigationSvc.width(context) /
                                                                        context.width *
                                                                        width) ~/
                                                                SettingsSvc.settings.pinColumnsLandscape.value,
                                                        child: ListView.builder(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          physics: const NeverScrollableScrollPhysics(),
                                                          shrinkWrap: true,
                                                          itemBuilder: (context, index) => Container(
                                                              height: 12,
                                                              margin: const EdgeInsets.symmetric(vertical: 1),
                                                              decoration: BoxDecoration(
                                                                  color: context.theme.colorScheme.secondary
                                                                      .lightenOrDarken(10),
                                                                  borderRadius: BorderRadius.circular(3))),
                                                          itemCount: 8,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                            width: 1,
                                            height: 108,
                                            color: context.theme.colorScheme.secondary.oppositeLightenOrDarken(40)),
                                        Container(
                                            width: NavigationSvc.width(context) / context.width * width - 1,
                                            height: 108,
                                            color: context.theme.colorScheme.secondary),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                            ],
                          ),
                    if (kIsDesktop && iOS) const SizedBox(height: 24),
                    if (!kIsWeb) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Pinned Order",
                        subtitle: "Set the order for your pinned chats",
                        onTap: () {
                          NavigationSvc.pushSettings(
                            context,
                            const PinnedOrderPanel(),
                          );
                        },
                        trailing: const NextButton(),
                      ),
                  ],
                )),
                if (!kIsWeb && !kIsDesktop && !iOS)
                  SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Swipe Actions"),
                if (!kIsWeb && !kIsDesktop && !iOS)
                  Obx(() => SettingsSection(expressive: true,
                    backgroundColor: tileColor,
                    children: [
                      SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.swipableConversationTiles.value = val;
                          await SettingsSvc.settings.saveOneAsync('swipableConversationTiles');
                        },
                        initialVal: SettingsSvc.settings.swipableConversationTiles.value,
                        title: "Swipe Actions for Conversation Tiles",
                        subtitle: "Enables swipe actions for conversation tiles when using Material theme",
                        backgroundColor: tileColor,
                      ),
                      if (SettingsSvc.settings.swipableConversationTiles.value)
                        Container(
                          color: tileColor,
                          child: Column(
                            children: [
                              SettingsOptions<MaterialSwipeAction>(
                                initial: SettingsSvc.settings.materialRightAction.value,
                                onChanged: (val) async {
                                  if (val != null) {
                                    SettingsSvc.settings.materialRightAction.value = val;
                                    await SettingsSvc.settings.saveOneAsync('materialRightAction');
                                  }
                                },
                                options: MaterialSwipeAction.values,
                                textProcessing: (val) =>
                                    val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                                title: "Swipe Right Action",
                                secondaryColor: headerColor,
                                useModernMenu: true,
                              ),
                              SettingsOptions<MaterialSwipeAction>(
                                initial: SettingsSvc.settings.materialLeftAction.value,
                                onChanged: (val) async {
                                  if (val != null) {
                                    SettingsSvc.settings.materialLeftAction.value = val;
                                    await SettingsSvc.settings.saveOneAsync('materialLeftAction');
                                  }
                                },
                                options: MaterialSwipeAction.values,
                                textProcessing: (val) =>
                                    val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                                title: "Swipe Left Action",
                                secondaryColor: headerColor,
                                useModernMenu: true,
                              ),
                            ],
                          ),
                        ),
                    ],
                  )),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Misc"),
                Obx(() => SettingsSection(expressive: true, 
                      backgroundColor: tileColor,
                      children: [
                        if (SettingsSvc.settings.skin.value == Skins.iOS)
                          SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.moveChatCreatorToHeader.value = val;
                              await SettingsSvc.settings.saveOneAsync('moveChatCreatorToHeader');
                            },
                            initialVal: SettingsSvc.settings.moveChatCreatorToHeader.value,
                            title: "Move Chat Creator Button to Header",
                            subtitle: "Replaces the floating button at the bottom to a fixed button at the top",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          ),
                        if (SettingsSvc.settings.skin.value == Skins.iOS)
                          const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                        SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.showFiltersInHeader.value = val;
                            await SettingsSvc.settings.saveOneAsync('showFiltersInHeader');
                          },
                          initialVal: SettingsSvc.settings.showFiltersInHeader.value,
                          title: "Show Filters in Header",
                          subtitle:
                              "Adds a shortcut button next to search to quickly open the chat list filters, highlighted when a filter is active",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        ),
                        const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                        SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.showCustomGroupFilterChips.value = val;
                            await SettingsSvc.settings.saveOneAsync('showCustomGroupFilterChips');
                          },
                          initialVal: SettingsSvc.settings.showCustomGroupFilterChips.value,
                          title: "Show Custom Group Filters",
                          subtitle: "Adds quick-filter chips for your custom groups above the chat list",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        ),
                        if (!kIsWeb && !kIsDesktop)
                          const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                        if (!kIsWeb && !kIsDesktop)
                          SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.cameraFAB.value = val;
                              await SettingsSvc.settings.saveOneAsync('cameraFAB');
                            },
                            initialVal: SettingsSvc.settings.cameraFAB.value,
                            title: SettingsSvc.settings.skin.value != Skins.iOS
                                ? "Long Press for Camera"
                                : "Add Camera Button",
                            subtitle: SettingsSvc.settings.skin.value != Skins.iOS
                                ? "Long press the start chat button to easily send a picture to a chat"
                                : "Adds a dedicated camera button near the new chat creator button to easily send pictures",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          ),
                      ],
                    )),
              ],
            ),
          ),
        ]);
  }
}
