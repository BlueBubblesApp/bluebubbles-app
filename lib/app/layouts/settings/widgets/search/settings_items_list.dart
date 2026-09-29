import '../../pages/misc/misc_panel.dart';
import '../../pages/scheduling/message_reminders_panel.dart';
import '../../pages/scheduling/scheduled_messages_panel.dart';
import '../tiles/connection_server_tile.dart';
import '../tiles/private_api_tile.dart';
import '../tiles/redacted_mode_tile.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/version_dialog.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/notification_providers_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/redacted_mode_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/tasker_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/conversation_list/chat_list_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_groups_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/desktop_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/message_view/attachment_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/message_view/conversation_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/about_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/troubleshoot_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/profile/profile_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/system/notification_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theming_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_items_actions.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';
import 'searchable_setting_item.dart';

List<Widget> buildSettingItemList({
  required BuildContext context,
  required String searchQuery,
  required Color tileColor,
  required bool samsung,
  required bool iOS,
  required bool material,
  required TextStyle iosSubtitle,
  required TextStyle materialSubtitle,
  required NavigatorService ns,
}) {
  // return searchable items, headers, tiles, or sections
  return [
    SearchableSettingItem(
      title: "Profile",
      child: SettingsHeader(height: 40, iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Profile"),
    ),
    SearchableSettingItem(
      title: SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value
          ? "User Name"
          : SettingsSvc.settings.userName.value,
      child: SettingsSection(
        backgroundColor: tileColor,
        children: [
          SettingsTile(
            backgroundColor: tileColor,
            activePage: ProfilePanel,
            title: SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value
                ? "User Name"
                : SettingsSvc.settings.userName.value,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const ProfilePanel(), (Route route) => route.isFirst);
            },
            leading: const ContactAvatarWidget(
              handle: null,
              borderThickness: 0.1,
              editable: false,
              fontSize: 22,
              size: 50,
            ),
            trailing: const NextButton(),
            minVerticalPadding: 20,
          ),
        ],
      ),
    ),
    if (!kIsWeb)
      SearchableSettingItem(
        title: "Server & Message Management",
        child: SettingsHeader(
          height: 40,
          iosSubtitle: iosSubtitle,
          materialSubtitle: materialSubtitle,
          text: "Server & Message Management",
        ),
      ),
    SearchableSettingItem(
      title: "Connection & Server",
      searchTags: [
        "Re-configure with BlueBubbles Server",
        "Manually Sync Messages",
        "Configure Custom Headers",
        "Auto-Sync Contacts",
        "Sign in with Google",
        "Fetch Latest URL",
        "Detect Localhost Address",
        "Fetch & Share Server Logs",
        "Restart iMessage",
        "Restart Private API & Services",
        "Restart BlueBubbles Server",
        "Check for Server Updates",
      ],
      onTap: () {
        ns.pushAndRemoveSettingsUntil(context, ServerManagementPanel(), (Route route) => route.isFirst);
      },
      // Helps search
      child: SettingsSection(
        backgroundColor: tileColor,
        children: [
          // Optimized reactive tile for connection state
          ConnectionServerTile(tileColor: tileColor),

          if (SettingsSvc.serverDetails.supportsScheduledMessages) const SettingsDivider(),
          if (SettingsSvc.serverDetails.supportsScheduledMessages)
            SearchableSettingItem(
              title: "Scheduled Messages",
              searchTags: ["Scheduled Messages"],
              child: SettingsTile(
                backgroundColor: tileColor,
                title: "Scheduled Messages",
                activePage: ScheduledMessagesPanel,
                onTap: () {
                  ns.pushAndRemoveSettingsUntil(
                    context,
                    const ScheduledMessagesPanel(),
                    (Route route) => route.isFirst,
                  );
                },
                trailing: const NextButton(),
                leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.calendar,
                  materialIcon: Icons.schedule_send_outlined,
                  containerColor: Colors.teal,
                ),
              ),
            ),

          if (Platform.isAndroid) const SettingsDivider(),
          if (Platform.isAndroid)
            SearchableSettingItem(
              title: "Message Reminders",
              searchTags: ["Message Reminders"],
              child: SettingsTile(
                backgroundColor: tileColor,
                title: "Message Reminders",
                activePage: MessageRemindersPanel,
                onTap: () {
                  ns.pushAndRemoveSettingsUntil(context, const MessageRemindersPanel(), (Route route) => route.isFirst);
                },
                trailing: const NextButton(),
                leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.alarm_fill,
                  materialIcon: Icons.alarm,
                  containerColor: Colors.indigo,
                ),
              ),
            ),
        ],
      ),
    ),
    SearchableSettingItem(
      title: "Appearance",
      child: SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Appearance"),
    ),
    SearchableSettingItem(
      title: "Appearance Settings",
      searchTags: [
        "Dark Mode",
        "Light Mode",
        "Theme Studio",
        "Tablet Mode",
        "Immersive Mode",
        "Material You",
        "Colors for Media",
        "Colorful Avatars",
        "Colorful Bubbles",
        "Custom Avatar Colors",
        "Custom Avatars",
        "Download iOS Emoji font",
      ],
      onTap: () {
        ns.pushAndRemoveSettingsUntil(context, ThemingPanel(), (Route route) => route.isFirst);
      },
      child: SettingsSection(
        backgroundColor: tileColor,
        children: [
          SettingsTile(
            backgroundColor: tileColor,
            title: "Appearance Settings",
            activePage: ThemingPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, ThemingPanel(), (Route route) => route.isFirst);
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${SettingsSvc.settings.skin.value.toString().split(".").last}  |  ${AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst!}",
                  style: context.theme.textTheme.bodyMedium!.apply(
                    color: context.theme.colorScheme.outline.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 5),
                const NextButton(),
              ],
            ),
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.paintbrush_fill,
              materialIcon: Icons.palette,
              containerColor: Colors.purple,
            ),
          ),
        ],
      ),
    ),
    SearchableSettingItem(
      title: "Application Settings", // Title to search
      child: SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Application Settings"),
    ),
    SettingsSection(
      backgroundColor: tileColor,
      searchableSettingsItems: [
        // Media Settings Tile
        SearchableSettingItem(
          title: "Media Settings", // Title to search
          searchTags: [
            "Auto-download Attachments",
            "Only Auto-download Attachments on WiFi",
            "Auto-save Attachments",
            "Save Media Location",
            "Enter Relative Path",
            "Save Documents Location",
            "Ask Where to Save Attachments",
            "Mute in Attachment Preview",
            "Mute in Fullscreen Player",
            "Arrow key direction",
            "Swipe Direction",
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const AttachmentPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Media Settings",
            activePage: AttachmentPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const AttachmentPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.photo_fill,
              materialIcon: Icons.attachment,
              iconSize: 18,
              containerColor: Colors.deepPurple,
            ),
            trailing: const NextButton(),
          ),
        ),

        // Notification Settings Tile
        SearchableSettingItem(
          title: "Notification Settings", // Title to search
          searchTags: [
            "Override DND for Favorites",
            "Send Notifications on Chat List",
            "Notify for Reactions",
            "Notification Sound",
            "Text Detection",
            "Hide Message Text",
            "Notify When Incremental Sync Complete",
            "Global options",
            "Chat options",
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const NotificationPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Notification Settings",
            activePage: NotificationPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const NotificationPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.bell_fill,
              materialIcon: Icons.notifications_on,
              containerColor: Colors.deepOrange,
            ),
            trailing: const NextButton(),
          ),
        ),

        // Chat List Settings Tile
        SearchableSettingItem(
          title: "Chat List Settings", // Title to search
          searchTags: [
            "Show Sync Indicator in Chat List",
            "Message Status Indicators",
            "Filtered Chat List",
            "Filter Unknown Senders",
            "Unarchive Chats On New Message",
            "Hide Dividers",
            "Dense Conversation Tiles",
            "Pin Configuration",
            "Pin Rows",
            "Pins Per Row",
            "Pinned Order",
            "Swipe Actions for Conversation Tiles",
            "Swipe Right Action",
            "Swipe Left Action",
            "Move Chat Creator Button to Header",
            "Long Press for Camera",
            "Show Custom Group Filters",
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const ChatListPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Chat List Settings",
            activePage: ChatListPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const ChatListPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.square_list_fill,
              materialIcon: Icons.list,
              containerColor: Colors.blue,
            ),
            trailing: const NextButton(),
          ),
        ),

        // Conversation Settings Tile
        SearchableSettingItem(
          title: "Conversation Settings", // Title to search
          searchTags: [
            "Show Delivery Timestamps",
            "Show Chat Name as Placeholder",
            "Show Avatars in DM Chats",
            "Smart Suggestions",
            "Show Replies To Previous Message",
            "Message Options Order",
            "Sync Group Chat Icons",
            "Store Last Read Message",
            "Hide Names in Reaction Details",
            "Add Send/Receive Sound",
            "Send/Receive Sound Volume",
            "Auto-open Keyboard",
            "Swipe Message Box to Close Keyboard",
            "Swipe Message Box to Open Keyboard",
            "Hide Keyboard When Scrolling",
            "Open Keyboard After Tapping Scroll To Bottom",
            "Double-Tap Message",
            "Send Message with Enter",
            "Scroll to Bottom When Sending Messages",
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const ConversationPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Conversation Settings",
            activePage: ConversationPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const ConversationPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.chat_bubble_fill,
              materialIcon: Icons.sms,
              containerColor: Colors.green,
            ),
            trailing: const NextButton(),
          ),
        ),

        // Custom Groups Tile
        SearchableSettingItem(
          title: "Custom Groups",
          searchTags: ["Custom Groups", "Create Group", "Group Chats", "Chat Groups"],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const CustomGroupsPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Custom Groups",
            activePage: CustomGroupsPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const CustomGroupsPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.folder_fill,
              materialIcon: Icons.folder_outlined,
              containerColor: Colors.orange,
            ),
            trailing: const NextButton(),
          ),
        ),

        if (kIsDesktop)
          // Desktop Settings Tile
          SearchableSettingItem(
            title: "Desktop Settings", // Title to search,
            searchTags: [
              "Desktop Settings",
              "Launch on Startup",
              "Launch on Startup Minimized",
              "Use Custom TitleBar",
              "Minimize to Tray",
              "Close to Tray",
              "Desktop Notifications",
              "Notification Sound Volume",
              "Actions",
              "Show Reply Field",
            ],
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const DesktopPanel(), (Route route) => route.isFirst);
            },
            child: SettingsTile(
              backgroundColor: tileColor,
              title: "Desktop Settings",
              activePage: DesktopPanel,
              onTap: () {
                ns.pushAndRemoveSettingsUntil(context, const DesktopPanel(), (Route route) => route.isFirst);
              },
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.desktopcomputer,
                materialIcon: Icons.desktop_windows,
                containerColor: Colors.blueGrey,
              ),
              trailing: const NextButton(),
            ),
          ),

        // More Settings Tile
        SearchableSettingItem(
          title: "More settings", // Title to search,
          searchTags: [
            "Advanced",
            "Secure App",
            "Security Level",
            "Incognito Keyboard",
            "High Performance Mode",
            "Scroll Speed Multiplier",
            "API Timeout Duration",
            "Cancel Queued Messages on Failure",
            "Replace Emoticons with Emoji",
            "Enable Spellcheck",
            "Send Delay",
            "Use 24 Hour Format for Times",
            "Allow Upside-Down Rotation",
            "Maximum Group Avatar Count",
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const MiscPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "More Settings",
            activePage: MiscPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const MiscPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.ellipsis_circle_fill,
              materialIcon: Icons.more_vert,
              containerColor: Colors.brown,
            ),
            trailing: const NextButton(),
          ),
        ),
      ],
    ),
    SearchableSettingItem(
      title: "Advanced", // Title to search
      child: SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Advanced"),
    ),
    SettingsSection(
      backgroundColor: tileColor,
      searchableSettingsItems: [
        // Private API Features Tile
        SearchableSettingItem(
          title: "Private API Features", // Title to search
          searchTags: [
            "Set up Private API Features",
            "Enable Private API Features",
            "Send Typing Indicators",
            "Automatic Mark Read / Send Read Receipts",
            "Manual Mark Read / Send Read Receipts",
            "Double Tap/Click",
            "Quick Tapback",
            "Up Arrow for Quick Edit",
            "Send Subject Lines",
            "Private API Send",
            "Private API Attachment Send",
          ],
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(context, PrivateAPIPanel(), (Route route) => route.isFirst);
          },
          child: PrivateAPITile(tileColor: tileColor),
        ),

        // Redacted Mode Tile
        SearchableSettingItem(
          title: "Redacted Mode", // Title to search
          searchTags: [
            "Enable Redacted Mode",
            "Hide Message Content",
            "Hide Attachments",
            "Hide Contact Info",
            "Generate Fake Avatars",
          ],
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(context, const RedactedModePanel(), (Route route) => route.isFirst);
          },
          child: RedactedModeTile(tileColor: tileColor),
        ),

        // Tasker Integration Tile (only for Android)
        if (Platform.isAndroid)
          SearchableSettingItem(
            title: "Tasker Integration", // Title to search
            searchTags: ["Tasker Integration Details", "Send Events to Tasker"],
            onTap: () async {
              ns.pushAndRemoveSettingsUntil(context, const TaskerPanel(), (Route route) => route.isFirst);
            },
            child: SettingsTile(
              backgroundColor: tileColor,
              title: "Tasker Integration",
              activePage: TaskerPanel,
              trailing: const NextButton(),
              onTap: () async {
                ns.pushAndRemoveSettingsUntil(context, const TaskerPanel(), (Route route) => route.isFirst);
              },
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.bolt_fill,
                materialIcon: Icons.electric_bolt_outlined,
                containerColor: Colors.grey,
              ),
            ),
          ),

        // Notification Providers Tile
        SearchableSettingItem(
          title: "Notification Providers", // Title to search
          searchTags: ["Google Firebase (FCM)", "Background Service", "Unified Push"], // Search tags
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(context, const NotificationProvidersPanel(), (Route route) => route.isFirst);
          }, // On tap to search
          child: SettingsTile(
            backgroundColor: tileColor,
            onTap: () async {
              ns.pushAndRemoveSettingsUntil(
                context,
                const NotificationProvidersPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.bell,
              materialIcon: Icons.notifications,
              containerColor: Colors.cyan,
            ),
            title: "Notification Providers",
            activePage: NotificationProvidersPanel,
            trailing: const NextButton(),
          ),
        ),

        // Contacts Management Tile
        if (!kIsWeb)
          SearchableSettingItem(
            title: "Contacts Management",
            searchTags: const [
              "Contacts Permission",
              "Refresh Contacts",
              "Sync From Account",
              "Contact Accounts",
              "GrapheneOS",
            ],
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const ContactsManagementPanel(), (Route route) => route.isFirst);
            },
            child: SettingsTile(
              backgroundColor: tileColor,
              onTap: () {
                ns.pushAndRemoveSettingsUntil(context, const ContactsManagementPanel(), (Route route) => route.isFirst);
              },
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.person_crop_circle_badge_checkmark,
                materialIcon: Icons.contacts_rounded,
                containerColor: Colors.green,
              ),
              title: "Contacts Management",
              activePage: ContactsManagementPanel,
              trailing: const NextButton(),
            ),
          ),

        // Storage Analyzer Tile
        if (!kIsWeb)
          SearchableSettingItem(
            title: "Storage Analyzer",
            searchTags: const ["Delete Attachments", "Free Up Space", "Manage Storage", "Clear Cache"],
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const StorageAnalyzerPanel(), (Route route) => route.isFirst);
            },
            child: SettingsTile(
              backgroundColor: tileColor,
              onTap: () {
                ns.pushAndRemoveSettingsUntil(context, const StorageAnalyzerPanel(), (Route route) => route.isFirst);
              },
              leading: SettingsLeadingIcon(
                iosIcon: CupertinoIcons.chart_pie_fill,
                materialIcon: Icons.pie_chart_outline,
                containerColor: Colors.red[700],
              ),
              title: "Storage Analyzer",
              activePage: StorageAnalyzerPanel,
              trailing: const NextButton(),
            ),
          ),

        // Developer Tools Tile
        SearchableSettingItem(
          title: "Developer Tools", // Title to search
          searchTags: [
            "Fetch Contacts With Verbose Logging",
            "View Latest Log",
            "Download / Share Logs",
            "Open Logs",
            "Clear Logs",
            "Open App Data Location",
            "Disable Battery Optimizations",
            "Clear Last Opened Chat",
            "Sync Chat Info",
          ], // Tags to search
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(context, const TroubleshootPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            onTap: () async {
              ns.pushAndRemoveSettingsUntil(context, const TroubleshootPanel(), (Route route) => route.isFirst);
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.wrench_fill,
              materialIcon: Icons.adb,
              containerColor: Colors.lightBlue,
            ),
            title: "Developer Tools",
            activePage: TroubleshootPanel,
            trailing: const NextButton(),
          ),
        ),
      ],
    ),
    SearchableSettingItem(
      title: "More",
      child: SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "More"),
    ),
    SettingsSection(
      backgroundColor: tileColor,
      searchableSettingsItems: [
        SearchableSettingItem(
          title: "Backup & Restore",
          searchTags: [
            "Overwrite Backup?",
            "Delete Backup?",
            "Restore Backup?",
            "Create New",
            "Restore Local",
            "Restore Settings?",
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const BackupRestorePanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const BackupRestorePanel(), (Route route) => route.isFirst);
            },
            trailing: const NextButton(),
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.cloud_upload_fill,
              materialIcon: Icons.backup,
              containerColor: Colors.blueGrey,
            ),
            title: "Backup & Restore",
            activePage: BackupRestorePanel,
          ),
        ),

        // About & Links Section
        const SearchableSettingItem(
          title: "Leave Us a Review", // Title to search
          child: SettingsTile(
            title: "Leave Us a Review",
            onTap: SettingsItemsActions.openStoreReview,
            leading: SettingsLeadingIcon(
              iosIcon: CupertinoIcons.star_fill,
              materialIcon: Icons.star,
              containerColor: Colors.blue,
            ),
          ),
        ),

        if (!kIsWeb && (Platform.isAndroid || Platform.isWindows))
          const SearchableSettingItem(
            title: "Make a Donation", // Title to search
            child: SettingsTile(
              title: "Make a Donation",
              onTap: SettingsItemsActions.openDonationPage,
              leading: SettingsLeadingIcon(
                iosIcon: CupertinoIcons.money_dollar_circle,
                materialIcon: Icons.attach_money,
                containerColor: Colors.green,
              ),
            ),
          ),

        SearchableSettingItem(
          title: "Join Our Discord", // Title to search
          child: SettingsTile(
            title: "Join Our Discord",
            onTap: SettingsItemsActions.openDiscord,
            leading: SettingsLeadingIcon(
              iosIcon: Icons.discord,
              materialIcon: Icons.discord,
              containerColor: HexColor('#7785CC'),
            ),
          ),
        ),

        SearchableSettingItem(
          title: "About & More", // Title to search
          searchTags: [
            "BlueBubbles Website",
            "Documentation",
            "Source Code",
            "Report a Bug",
            "Changelog",
            "Developers",
            "Keyboard Shortcuts",
            "About"
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(context, const AboutPanel(), (Route route) => route.isFirst);
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "About & More",
            activePage: AboutPanel,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(context, const AboutPanel(), (Route route) => route.isFirst);
            },
            trailing: const NextButton(),
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.info_circle_fill,
              materialIcon: Icons.info,
              containerColor: Colors.blue,
            ),
          ),
        ),

        // Danger Zone Section
        if (!kIsWeb)
          SearchableSettingItem(
            title: "Reset App", // Title to search
            child: SettingsTile(
              backgroundColor: tileColor,
              onTap: () {
                showBBDialog(
                  barrierDismissible: false,
                  context: context,
                  title: "Are you sure?",
                  body:
                      "This will delete all app data, including your settings, messages, attachments, and more. This action cannot be undone. It is recommended that you take a backup of your settings before proceeding. This will also close the app once the process is complete.",
                  actions: [
                    BBDialogAction(text: "No", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
                    BBDialogAction(
                      text: "Yes",
                      isDefault: true,
                      onPressed: () => SettingsItemsActions.resetApp(),
                    ),
                  ],
                );
              },
              leading: SettingsLeadingIcon(
                iosIcon: CupertinoIcons.refresh_circled_solid,
                materialIcon: Icons.refresh_rounded,
                containerColor: Colors.red[700],
              ),
              title: kIsWeb ? "Logout" : "Reset App",
            ),
          ),
      ],
    ),
    const SizedBox(height: 16.0),
    SearchableSettingItem(
      title: "App Version: $appVersion",
      searchTags: ["Version"],
      child: Container(),
      onTap: () => showVersionDialog(context),
    ),
    SettingsSection(
      backgroundColor: tileColor,
      children: [
        SettingsSubtitle(
          subtitle: "App Version: $appVersion",
          bottomPadding: false,
        ),
      ],
    ),
  ];
}
