import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/conversation_list/pinned_order_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatListPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _ChatListPanelState();
}

class _ChatListPanelState extends OptimizedState<ChatListPanel> {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
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
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.showConnectionIndicator.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.showConnectionIndicator.value,
                          title: "Show Connection Indicator",
                          subtitle: "Show a visual status indicator when the app is not connected to the server",
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
                            ss.settings.showSyncIndicator.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.showSyncIndicator.value,
                          title: "Show Sync Indicator in Chat List",
                          subtitle:
                              "Enables a small indicator at the top left to show when the app is syncing messages",
                          backgroundColor: tileColor,
                          isThreeLine: true,
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
                            ss.settings.statusIndicatorsOnChats.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.statusIndicatorsOnChats.value,
                          title: "Message Status Indicators",
                          subtitle:
                              "Adds status indicators to the chat list for the sent / delivered / read status of your most recent message",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                  ],
                ),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Filtering"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.filteredChatList.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.filteredChatList.value,
                          title: "Filtered Chat List",
                          subtitle:
                              "Filters the chat list based on parameters set in iMessage (usually this removes old, inactive chats)",
                          backgroundColor: tileColor,
                          isThreeLine: true,
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
                            ss.settings.filterUnknownSenders.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.filterUnknownSenders.value,
                          title: "Filter Unknown Senders",
                          subtitle:
                              "Turn off notifications for senders who aren't in your contacts and sort them into a separate chat list",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              ss.settings.unarchiveOnNewMessage.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.unarchiveOnNewMessage.value,
                            title: "Unarchive Chats On New Message",
                            subtitle: "Automatically unarchive chats when a new message is received",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                  ],
                ),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Appearance"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideDividers.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideDividers.value,
                          title: "Hide Dividers",
                          backgroundColor: tileColor,
                          subtitle: "Hides dividers between tiles",
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
                            ss.settings.denseChatTiles.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.denseChatTiles.value,
                          title: "Dense Conversation Tiles",
                          backgroundColor: tileColor,
                          subtitle: "Compresses chat tile size on the conversation list page",
                          isThreeLine: true,
                        )),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    if (!kIsDesktop && !kIsWeb)
                      Obx(() {
                        if (iOS) {
                          return const SettingsTile(
                            title: "Pin Configuration",
                            subtitle: "The row and column count of the pin grid. ",
                            isThreeLine: true,
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (!kIsDesktop && !kIsWeb)
                      Obx(() {
                        if (iOS) {
                          return Row(
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
                                  onChanged: (int? val) {
                                    if (val == null) return;
                                    ss.settings.pinRowsPortrait.value = val.toInt();
                                    saveSettings();
                                  },
                                  options: List.generate(4, (index) => index + 1),
                                  initial: ss.settings.pinRowsPortrait.value,
                                  title: '',
                                  secondaryColor: context.theme.colorScheme.secondary,
                                  textProcessing: (val) => val.toString(),
                                ),
                              ),
                              const SizedBox(width: 20),
                            ],
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (!kIsDesktop && !kIsWeb)
                      Obx(() {
                        if (iOS) {
                          return Row(
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
                                  onChanged: (int? val) {
                                    if (val == null) return;
                                    ss.settings.pinRowsLandscape.value = val.toInt();
                                    saveSettings();
                                  },
                                  options: List.generate(4, (index) => index + 1),
                                  initial: ss.settings.pinRowsLandscape.value,
                                  title: '',
                                  secondaryColor: context.theme.colorScheme.secondary,
                                  textProcessing: (val) => val.toString(),
                                ),
                              ),
                              const SizedBox(width: 20),
                            ],
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (!kIsDesktop && !kIsWeb)
                      Obx(() {
                        if (iOS) {
                          return Row(
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
                                  onChanged: (int? val) {
                                    if (val == null) return;
                                    ss.settings.pinColumnsPortrait.value = val.toInt();
                                    saveSettings();
                                  },
                                  options: List.generate(4, (index) => index + 1),
                                  initial: ss.settings.pinColumnsPortrait.value,
                                  title: '',
                                  secondaryColor: context.theme.colorScheme.secondary,
                                  textProcessing: (val) => val.toString(),
                                ),
                              ),
                              const SizedBox(width: 20),
                            ],
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (!kIsWeb) const SettingsDivider(),
                    if (kIsDesktop)
                      Obx(() {
                        if (iOS) {
                          return SettingsTile(
                            title:
                                "Pinned Chat Configuration (${ss.settings.pinRowsPortrait.value} row${ss.settings.pinRowsPortrait.value > 1 ? "s" : ""} of ${ss.settings.pinColumnsLandscape})",
                            subtitle:
                                "Pinned chats will overflow onto multiple pages if they do not fit in this configuration.",
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (kIsDesktop)
                      Obx(() {
                        if (iOS) {
                          return Row(
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
                                            initial: ss.settings.pinRowsPortrait.value,
                                            options: List.generate(4, (index) => index + 1),
                                            onChanged: (int? val) {
                                              if (val == null) return;
                                              ss.settings.pinRowsPortrait.value = val;
                                              saveSettings();
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
                                            initial: ss.settings.pinColumnsLandscape.value,
                                            options: List.generate(5, (index) => index + 2),
                                            onChanged: (int? val) {
                                              if (val == null) return;
                                              ss.settings.pinColumnsLandscape.value = val;
                                              saveSettings();
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
                                ns.listener.value;
                                double width = 108 * context.width / context.height;
                                if (ns.width(context) != context.width) {
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
                                                        flex: ss.settings.pinRowsPortrait.value *
                                                            (width - ns.width(context) / context.width * width) ~/
                                                            ss.settings.pinColumnsLandscape.value,
                                                        child: GridView.custom(
                                                          shrinkWrap: true,
                                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                            crossAxisCount: ss.settings.pinColumnsLandscape.value,
                                                          ),
                                                          physics: const NeverScrollableScrollPhysics(),
                                                          childrenDelegate: SliverChildBuilderDelegate(
                                                            (context, index) => Container(
                                                              margin: EdgeInsets.all(2 /
                                                                  max(ss.settings.pinRowsPortrait.value,
                                                                      ss.settings.pinColumnsLandscape.value)),
                                                              decoration: BoxDecoration(
                                                                  borderRadius: BorderRadius.circular(50 /
                                                                      max(ss.settings.pinRowsPortrait.value,
                                                                          ss.settings.pinColumnsLandscape.value)),
                                                                  color: context.theme.colorScheme.secondary
                                                                      .lightenOrDarken(10)),
                                                            ),
                                                            childCount: ss.settings.pinColumnsLandscape.value *
                                                                ss.settings.pinRowsPortrait.value,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (ss.settings.pinRowsPortrait.value *
                                                            (width - ns.width(context) / context.width * width) /
                                                            ss.settings.pinColumnsLandscape.value <
                                                        96)
                                                      Expanded(
                                                        flex: 96 -
                                                            ss.settings.pinRowsPortrait.value *
                                                                (width - ns.width(context) / context.width * width) ~/
                                                                ss.settings.pinColumnsLandscape.value,
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
                                                            itemCount: 8),
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
                                            width: ns.width(context) / context.width * width - 1,
                                            height: 108,
                                            color: context.theme.colorScheme.secondary),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                            ],
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (kIsDesktop && iOS) const SizedBox(height: 24),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Pinned Order",
                        subtitle: "Set the order for your pinned chats",
                        onTap: () {
                          ns.pushSettings(
                            context,
                            PinnedOrderPanel(),
                          );
                        },
                        trailing: Icon(
                          iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
                          color: context.theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                if (!kIsWeb && !kIsDesktop && !iOS)
                  SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Swipe Actions"),
                if (!kIsWeb && !kIsDesktop && !iOS)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              ss.settings.swipableConversationTiles.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.swipableConversationTiles.value,
                            title: "Swipe Actions for Conversation Tiles",
                            subtitle: "Enables swipe actions for conversation tiles when using Material theme",
                            backgroundColor: tileColor,
                          )),
                      Obx(() {
                        if (ss.settings.swipableConversationTiles.value) {
                          return Container(
                            color: tileColor,
                            child: Column(
                              children: [
                                SettingsOptions<MaterialSwipeAction>(
                                  initial: ss.settings.materialRightAction.value,
                                  onChanged: (val) {
                                    if (val != null) {
                                      ss.settings.materialRightAction.value = val;
                                      saveSettings();
                                    }
                                  },
                                  options: MaterialSwipeAction.values,
                                  textProcessing: (val) =>
                                      val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                                  title: "Swipe Right Action",
                                  secondaryColor: headerColor,
                                ),
                                SettingsOptions<MaterialSwipeAction>(
                                  initial: ss.settings.materialLeftAction.value,
                                  onChanged: (val) {
                                    if (val != null) {
                                      ss.settings.materialLeftAction.value = val;
                                      saveSettings();
                                    }
                                  },
                                  options: MaterialSwipeAction.values,
                                  textProcessing: (val) =>
                                      val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                                  title: "Swipe Left Action",
                                  secondaryColor: headerColor,
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Misc"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.moveChatCreatorToHeader.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.moveChatCreatorToHeader.value,
                          title: "Move Chat Creator Button to Header",
                          subtitle: "Replaces the floating button at the bottom to a fixed button at the top",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              ss.settings.cameraFAB.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.cameraFAB.value,
                            title: ss.settings.skin.value != Skins.iOS ? "Long Press for Camera" : "Add Camera Button",
                            subtitle: ss.settings.skin.value != Skins.iOS
                                ? "Long press the start chat button to easily send a picture to a chat"
                                : "Adds a dedicated camera button near the new chat creator button to easily send pictures",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                  ],
                ),
              ],
            ),
          ),
        ]);
  }

  void saveSettings() {
    ss.saveSettings(ss.settings);
  }
}
