import 'package:bluebubbles/utils/logger/logger.dart';

import '../../pages/misc/misc_panel.dart';
import '../../pages/scheduling/message_reminders_panel.dart';
import '../../pages/scheduling/scheduled_messages_panel.dart';
import '../tiles/connection_server_tile.dart';
import '../tiles/private_api_tile.dart';
import '../tiles/redacted_mode_tile.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/notification_providers_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/redacted_mode_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/tasker_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/conversation_list/chat_list_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/desktop_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/message_view/attachment_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/message_view/conversation_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/about_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/troubleshoot_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/profile/profile_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/system/notification_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theming_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_items_actions.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
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
  required RxnDouble progress,
  required RxnInt totalSize,
  required RxBool uploadingContacts,
}) {
  // return searchable items, headers, tiles, or sections
  return [
    if (!kIsWeb && (!iOS || kIsDesktop))
      SearchableSettingItem(
        title: "Profile",
        child: SettingsHeader(
          height: 40,
          iosSubtitle: iosSubtitle,
          materialSubtitle: materialSubtitle,
          text: "Profile",
        ),
      ),
    if (!kIsWeb && (!iOS || kIsDesktop))
      SearchableSettingItem(
        title: SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value
            ? "User Name"
            : SettingsSvc.settings.userName.value,
        child: SettingsSection(
          backgroundColor: tileColor,
          children: [
            SettingsTile(
              backgroundColor: tileColor,
              title: SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideContactInfo.value
                  ? "User Name"
                  : SettingsSvc.settings.userName.value,
              subtitle: "Tap to view more details",
              onTap: () {
                ns.pushAndRemoveSettingsUntil(
                  context,
                  const ProfilePanel(),
                  (Route route) => route.isFirst,
                );
              },
              leading: const ContactAvatarWidget(
                handle: null,
                borderThickness: 0.1,
                editable: false,
                fontSize: 22,
                size: 50,
              ),
              trailing: const NextButton(),
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
        "Check for Server Updates"
      ],
      onTap: () {
        ns.pushAndRemoveSettingsUntil(
          context,
          ServerManagementPanel(),
          (Route route) => route.isFirst,
        );
      },
      // Helps search
      child: SettingsSection(
        backgroundColor: tileColor,
        children: [
          // Optimized reactive tile for connection state
          ConnectionServerTile(
            tileColor: tileColor,
            samsung: samsung,
            iOS: iOS,
            material: material,
          ),

          if (SettingsSvc.serverDetails.supportsScheduledMessages) const SettingsDivider(),
          if (SettingsSvc.serverDetails.supportsScheduledMessages)
            SearchableSettingItem(
                title: "Scheduled Messages",
                searchTags: ["Scheduled Messages"],
                child: SettingsTile(
                  backgroundColor: tileColor,
                  title: "Scheduled Messages",
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
                    containerColor: Colors.redAccent,
                  ),
                )),

          if (Platform.isAndroid) const SettingsDivider(),
          if (Platform.isAndroid)
            SearchableSettingItem(
              title: "Message Reminders",
              searchTags: ["Message Reminders"],
              child: SettingsTile(
                backgroundColor: tileColor,
                title: "Message Reminders",
                onTap: () {
                  ns.pushAndRemoveSettingsUntil(
                    context,
                    const MessageRemindersPanel(),
                    (Route route) => route.isFirst,
                  );
                },
                trailing: const NextButton(),
                leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.alarm_fill,
                  materialIcon: Icons.alarm,
                  containerColor: Colors.blueAccent,
                ),
              ),
            ),
        ],
      ),
    ),
    SearchableSettingItem(
        title: "Appearance",
        child: SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Appearance")),
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
          "Download iOS Emoji font"
        ],
        onTap: () {
          ns.pushAndRemoveSettingsUntil(
            context,
            ThemingPanel(),
            (Route route) => route.isFirst,
          );
        },
        child: SettingsSection(
          backgroundColor: tileColor,
          children: [
            SettingsTile(
              backgroundColor: tileColor,
              title: "Appearance Settings",
              onTap: () {
                ns.pushAndRemoveSettingsUntil(
                  context,
                  ThemingPanel(),
                  (Route route) => route.isFirst,
                );
              },
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  "${SettingsSvc.settings.skin.value.toString().split(".").last}  |  ${AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst!}",
                  style: context.theme.textTheme.bodyMedium!
                      .apply(color: context.theme.colorScheme.outline.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 5),
                const NextButton(),
              ]),
              leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.paintbrush_fill,
                  materialIcon: Icons.palette,
                  containerColor: Colors.blueGrey),
            ),
          ],
        )),
    SearchableSettingItem(
      title: "Application Settings", // Title to search
      child: SettingsHeader(
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        text: "Application Settings",
      ),
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
            "Swipe Direction"
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(
              context,
              const AttachmentPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Media Settings",
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const AttachmentPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.photo_fill,
              materialIcon: Icons.attachment,
              iconSize: 18,
              containerColor: Colors.deepPurpleAccent,
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
            "Chat options"
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(
              context,
              const NotificationPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Notification Settings",
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const NotificationPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.bell_fill,
              materialIcon: Icons.notifications_on,
              containerColor: Colors.redAccent,
            ),
            trailing: const NextButton(),
          ),
        ),

        // Chat List Settings Tile
        SearchableSettingItem(
          title: "Chat List Settings", // Title to search
          searchTags: [
            "Show Connection Indicator",
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
            "Long Press for Camera"
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(
              context,
              const ChatListPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Chat List Settings",
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const ChatListPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.square_list_fill,
              materialIcon: Icons.list,
              containerColor: Colors.blueAccent,
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
            "Scroll to Bottom When Sending Messages"
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(
              context,
              const ConversationPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "Conversation Settings",
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const ConversationPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.chat_bubble_fill,
              materialIcon: Icons.sms,
              containerColor: Colors.green,
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
                "Show Reply Field"
              ],
              onTap: () {
                ns.pushAndRemoveSettingsUntil(
                  context,
                  const DesktopPanel(),
                  (Route route) => route.isFirst,
                );
              },
              child: SettingsTile(
                backgroundColor: tileColor,
                title: "Desktop Settings",
                onTap: () {
                  ns.pushAndRemoveSettingsUntil(
                    context,
                    const DesktopPanel(),
                    (Route route) => route.isFirst,
                  );
                },
                leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.desktopcomputer,
                  materialIcon: Icons.desktop_windows,
                ),
                trailing: const NextButton(),
              )),

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
            "Maximum Group Avatar Count"
          ],
          onTap: () {
            ns.pushAndRemoveSettingsUntil(
              context,
              const MiscPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "More Settings",
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const MiscPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.ellipsis_circle_fill,
              materialIcon: Icons.more_vert,
            ),
            trailing: const NextButton(),
          ),
        )
      ],
    ),
    SearchableSettingItem(
      title: "Advanced", // Title to search
      child: SettingsHeader(
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        text: "Advanced",
      ),
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
            "Private API Attachment Send"
          ],
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(
              context,
              PrivateAPIPanel(),
              (Route route) => route.isFirst,
            );
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
            "Generate Fake Avatars"
          ],
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(
              context,
              const RedactedModePanel(),
              (Route route) => route.isFirst,
            );
          },
          child: RedactedModeTile(tileColor: tileColor),
        ),

        // Tasker Integration Tile (only for Android)
        if (Platform.isAndroid)
          SearchableSettingItem(
            title: "Tasker Integration", // Title to search
            searchTags: ["Tasker Integration Details", "Send Events to Tasker"],
            onTap: () async {
              ns.pushAndRemoveSettingsUntil(
                context,
                const TaskerPanel(),
                (Route route) => route.isFirst,
              );
            },
            child: SettingsTile(
              backgroundColor: tileColor,
              title: "Tasker Integration",
              trailing: const NextButton(),
              onTap: () async {
                ns.pushAndRemoveSettingsUntil(
                  context,
                  const TaskerPanel(),
                  (Route route) => route.isFirst,
                );
              },
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.bolt_fill,
                materialIcon: Icons.electric_bolt_outlined,
                containerColor: Colors.orangeAccent,
              ),
            ),
          ),

        // Notification Providers Tile
        SearchableSettingItem(
          title: "Notification Providers", // Title to search
          searchTags: ["Google Firebase (FCM)", "Background Service", "Unified Push"], // Search tags
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(
              context,
              const NotificationProvidersPanel(),
              (Route route) => route.isFirst,
            );
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
              containerColor: Colors.green,
            ),
            title: "Notification Providers",
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
            "Sync Chat Info"
          ], // Tags to search
          onTap: () async {
            ns.pushAndRemoveSettingsUntil(
              context,
              const TroubleshootPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            onTap: () async {
              ns.pushAndRemoveSettingsUntil(
                context,
                const TroubleshootPanel(),
                (Route route) => route.isFirst,
              );
            },
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.wrench_fill,
              materialIcon: Icons.adb,
              containerColor: Colors.blueAccent,
            ),
            title: "Developer Tools",
            subtitle: "View logs, troubleshoot bugs, and more",
            trailing: const NextButton(),
          ),
        ),
      ],
    ),
    SearchableSettingItem(
      title: "Backup and restore",
      child: SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Backup and Restore"),
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
            ns.pushAndRemoveSettingsUntil(
              context,
              const BackupRestorePanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const BackupRestorePanel(),
                (Route route) => route.isFirst,
              );
            },
            trailing: const NextButton(),
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.cloud_upload_fill,
              materialIcon: Icons.backup,
              containerColor: Colors.amber,
            ),
            title: "Backup & Restore",
            subtitle: "Backup and restore all app settings and custom themes",
          ),
        ),

        if (!kIsWeb && !kIsDesktop)
          SearchableSettingItem(
            title: "Export Contacts", // Title to search
            child: SettingsTile(
              backgroundColor: tileColor,
              onTap: () => SettingsItemsActions.exportContacts(
                context: context,
                progress: progress,
                totalSize: totalSize,
                uploadingContacts: uploadingContacts,
              ),
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.group_solid,
                materialIcon: Icons.contacts,
                containerColor: Colors.green,
              ),
              title: "Export Contacts",
              subtitle: "Send contacts to server for use on the desktop app",
            ),
          ),
        // About & Links Section
        SearchableSettingItem(
          title: "Leave Us a Review", // Title to search
          child: SettingsTile(
            title: "Leave Us a Review",
            subtitle:
                "Enjoying the app? Leave us a review on the ${Platform.isAndroid ? 'Google Play Store' : 'Microsoft Store'}!",
            onTap: SettingsItemsActions.openStoreReview,
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.star_fill,
              materialIcon: Icons.star,
              containerColor: Colors.blue,
            ),
            isThreeLine: false,
          ),
        ),

        if (!kIsWeb && (Platform.isAndroid || Platform.isWindows))
          const SearchableSettingItem(
            title: "Make a Donation", // Title to search
            child: SettingsTile(
              title: "Make a Donation",
              subtitle: "Support the developers by making a one-time or recurring donation to the BlueBubbles Team!",
              onTap: SettingsItemsActions.openDonationPage,
              leading: SettingsLeadingIcon(
                iosIcon: CupertinoIcons.money_dollar_circle,
                materialIcon: Icons.attach_money,
                containerColor: Colors.green,
              ),
              isThreeLine: false,
            ),
          ),

        SearchableSettingItem(
          title: "Join Our Discord", // Title to search
          child: SettingsTile(
            title: "Join Our Discord",
            subtitle: "Join our Discord server to chat with other BlueBubbles users and the developers",
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
            ns.pushAndRemoveSettingsUntil(
              context,
              const AboutPanel(),
              (Route route) => route.isFirst,
            );
          },
          child: SettingsTile(
            backgroundColor: tileColor,
            title: "About & More",
            subtitle: "Links, Changelog, & More",
            onTap: () {
              ns.pushAndRemoveSettingsUntil(
                context,
                const AboutPanel(),
                (Route route) => route.isFirst,
              );
            },
            trailing: const NextButton(),
            leading: const SettingsLeadingIcon(
              iosIcon: CupertinoIcons.info_circle_fill,
              materialIcon: Icons.info,
              containerColor: Colors.blueAccent,
            ),
          ),
        ),

// Danger Zone Section
        if (!kIsWeb)
          SearchableSettingItem(
            title: "Delete All Attachments", // Title to search
            child: SettingsTile(
              backgroundColor: tileColor,
              onTap: () {
                showBBDialog(
                  barrierDismissible: true,
                  context: context,
                  title: "Are you sure?",
                  body:
                      "This will remove all attachments from this app. Recent attachments will be automatically re-downloaded when you enter a chat. This will not delete attachments from your server.",
                  actions: [
                    BBDialogAction(
                      text: "No",
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    ),
                    BBDialogAction(
                      text: "Yes",
                      isDefault: true,
                      onPressed: () async {
                        final dir = Directory(FilesystemSvc.attachmentsPath);
                        await dir.delete(recursive: true);
                        showSnackbar("Success", "Deleted cached attachments");
                      },
                    ),
                  ],
                );
              },
              leading: SettingsLeadingIcon(
                iosIcon: CupertinoIcons.trash_slash_fill,
                materialIcon: Icons.delete_forever_outlined,
                containerColor: Colors.red[700],
              ),
              title: "Delete All Attachments",
              subtitle: "Remove all attachments from this app",
            ),
          ),

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
                    BBDialogAction(
                      text: "No",
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    ),
                    BBDialogAction(
                      text: "Yes",
                      isDefault: true,
                      onPressed: () async {
                        FilesystemSvc.deleteDB();
                        SocketSvc.forgetConnection();
                        SettingsSvc.settings = Settings();
                        await SettingsSvc.settings.saveAsync();

                        await PrefsSvc.admin.clearAll();
                        await PrefsSvc.theme.setSelectedThemes(
                          darkTheme: "OLED Dark",
                          lightTheme: "Bright White",
                        );
                        Database.themes.putMany(ThemesService.defaultThemes);

                        await FCMData.deleteFcmData();

                        try {
                          if (FirebaseSvc.token != null) {
                            await MethodChannelSvc.actions.firebaseDeleteToken();
                          }
                        } catch (e, s) {
                          Logger.error("Failed to delete Firebase FCM token", error: e, trace: s);
                        }

                        exit(0);
                      },
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
              subtitle: kIsWeb ? null : "Resets the app to default settings",
            ),
          ),
      ],
    ),
  ];
}
