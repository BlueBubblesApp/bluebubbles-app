import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/sync_time_range_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/sync_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/soft_deleted_chats_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/logging_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/log_level_selector.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class TroubleshootPanel extends StatefulWidget {
  const TroubleshootPanel({super.key});

  @override
  State<StatefulWidget> createState() => _TroubleshootPanelState();
}

class _TroubleshootPanelState extends State<TroubleshootPanel> with ThemeHelpers {
  final RxnBool resyncingHandles = RxnBool();
  final RxnBool resyncingChats = RxnBool();
  final RxInt logFileCount = 0.obs;
  final RxInt logFileSize = 0.obs;
  final RxBool optimizationsDisabled = false.obs;

  bool isExportingLogs = false;

  @override
  void initState() {
    super.initState();
    _refreshLogStats();

    // Check if battery optimizations are disabled
    if (Platform.isAndroid) {
      DisableBatteryOptimization.isAllBatteryOptimizationDisabled.then((value) {
        optimizationsDisabled.value = value ?? false;
      });
    }
  }

  void _refreshLogStats() {
    int count = 0;
    int sizeKb = 0;

    final Directory logDir = Directory(Logger.logDir);
    if (logDir.existsSync()) {
      final List<FileSystemEntity> files = logDir.listSync();
      final List<FileSystemEntity> logFiles = files.where((file) => file.path.endsWith(".log")).toList();
      count = logFiles.length;

      for (final file in logFiles) {
        sizeKb += file.statSync().size ~/ 1024;
      }
    }

    logFileCount.value = count;
    logFileSize.value = sizeKb;
  }

  @override
  Widget build(BuildContext context) {
    bool isWebOrDesktop = kIsWeb || kIsDesktop;
    return SettingsScaffold(
        title: "Developer Tools",
        initialHeader: (isWebOrDesktop) ? "Contacts" : "Logging",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                if (isWebOrDesktop)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      SettingsTile(
                        onTap: () async {
                          final RxList<String> log = <String>[].obs;
                          showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                    backgroundColor: context.theme.colorScheme.surface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    titlePadding: const EdgeInsets.only(top: 15),
                                    title: Text("Fetching contacts...", style: context.theme.textTheme.titleLarge),
                                    content: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width: NavigationSvc.width(context) * 4 / 5,
                                        height: context.height * 1 / 3,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(25),
                                            color: context.theme.colorScheme.surface,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          child: Obx(() => ListView.builder(
                                                physics: const AlwaysScrollableScrollPhysics(
                                                    parent: BouncingScrollPhysics()),
                                                itemBuilder: (context, index) {
                                                  return Text(
                                                    log[index],
                                                    style: TextStyle(
                                                      color: context.theme.colorScheme.onSurface,
                                                      fontSize: 10,
                                                    ),
                                                  );
                                                },
                                                itemCount: log.length,
                                              )),
                                        ),
                                      ),
                                    ),
                                  ));
                          await ContactsSvcV2.fetchNetworkContacts(logger: (newLog) {
                            log.add(newLog);
                          });
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.group,
                          materialIcon: Icons.contacts,
                        ),
                        title: "Fetch Contacts With Verbose Logging",
                        subtitle:
                            "This will fetch contacts from the server with extra info to help devs debug contacts issues",
                      ),
                    ],
                  ),
                if (isWebOrDesktop)
                  SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Logging"),
                SettingsSection(backgroundColor: tileColor, children: [
                  const LogLevelSelector(),
                  SettingsTile(
                    title: "View Latest Log",
                    subtitle: "View the latest log file. Useful for debugging issues, in app.",
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.doc_append,
                      materialIcon: Icons.document_scanner_rounded,
                      containerColor: Colors.blueAccent,
                    ),
                    onTap: () {
                      NavigationSvc.pushSettings(
                        context,
                        const LoggingPanel(),
                      );
                    },
                    trailing: const NextButton(),
                  ),
                  if (Platform.isAndroid) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                  if (Platform.isAndroid)
                    Obx(
                      () => SettingsTile(
                          leading: const SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.share_up,
                            materialIcon: Icons.share,
                            containerColor: Colors.green,
                          ),
                          title: "Download / Share Logs",
                          subtitle: "${logFileCount.value} log file(s) | ${logFileSize.value} KB",
                          onTap: () async {
                            _refreshLogStats();
                            if (logFileCount.value == 0) {
                              showSnackbar("No Logs", "There are no logs to download!");
                              return;
                            }

                            if (isExportingLogs) return;
                            isExportingLogs = true;

                            try {
                              showSnackbar("Please Wait", "Compressing ${logFileCount.value} log file(s)...");
                              String filePath = await Logger.compressLogs();
                              final String fileName = File(filePath).uri.pathSegments.last;

                              try {
                                final String savedPath = await FilesystemSvc.saveToDownloads(
                                  File(filePath),
                                  mimeType: 'application/zip',
                                );
                                showSnackbar("Logs Saved", "Saved $fileName to your Downloads folder.");
                                if (kIsDesktop) await launchUrl(Uri.file(savedPath));
                              } catch (_) {
                                // saveToDownloads failed on Android — fall back to share sheet.
                                Share.files([filePath], mimeType: 'application/zip');
                              }
                            } catch (ex, stacktrace) {
                              Logger.error("Failed to export logs!", error: ex, trace: stacktrace);
                              showSnackbar("Failed to export logs!", "Error: ${ex.toString()}");
                            } finally {
                              isExportingLogs = false;
                              _refreshLogStats();
                            }
                          }),
                    ),
                  if (kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                  if (kIsDesktop)
                    SettingsTile(
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.doc,
                          materialIcon: Icons.file_open,
                        ),
                        title: "Open Logs",
                        subtitle: Logger.logDir,
                        onTap: () async {
                          final File logFile = File(Logger.logDir);
                          if (logFile.existsSync()) {
                            logFile.createSync(recursive: true);
                          }
                          await launchUrl(Uri.file(logFile.path));
                        }),
                  const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                  SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.trash,
                        materialIcon: Icons.delete,
                        containerColor: Colors.redAccent,
                      ),
                      title: "Clear Logs",
                      subtitle: "Deletes all stored log files.",
                      onTap: () async {
                        Logger.clearLogs();
                        showSnackbar("Logs Cleared", "All logs have been deleted.");
                        _refreshLogStats();
                      }),
                  if (kIsDesktop) const SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.folder,
                        materialIcon: Icons.folder,
                      ),
                      title: "Open App Data Location",
                      subtitle: FilesystemSvc.appDocDir.path,
                      onTap: () async => await launchUrl(Uri.file(FilesystemSvc.appDocDir.path)),
                    ),
                ]),
                if (Platform.isAndroid)
                  SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Optimizations"),
                if (Platform.isAndroid)
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsTile(
                        onTap: () async {
                          if (optimizationsDisabled.value) {
                            showSnackbar(
                                "Already Disabled", "Battery optimizations are already disabled for BlueBubbles");
                            return;
                          }

                          final optsDisabled = await disableBatteryOptimizations();
                          if (!optsDisabled) {
                            showSnackbar("Error", "Battery optimizations were not disabled. Please try again.");
                          }
                        },
                        leading: Obx(() => SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.battery_25,
                              materialIcon: Icons.battery_5_bar,
                              containerColor: optimizationsDisabled.value ? Colors.green : Colors.redAccent,
                            )),
                        title: "Disable Battery Optimizations",
                        subtitle:
                            "Allow app to run in the background via the OS. This may not do anything on some devices.",
                        trailing: Obx(() => !optimizationsDisabled.value
                            ? const NextButton()
                            : Icon(Icons.check, color: context.theme.colorScheme.outline))),
                  ]),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Troubleshooting"),
                SettingsSection(backgroundColor: tileColor, children: [
                  SettingsTile(
                    onTap: () => NavigationSvc.pushSettings(context, const SoftDeletedChatsPanel()),
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.trash_slash,
                      materialIcon: Icons.restore_from_trash,
                      containerColor: Colors.orangeAccent,
                    ),
                    title: "View Soft-Deleted Chats",
                    subtitle: "Shows only soft-deleted chats. Allows restoring them back to the main chat list.",
                    trailing: const NextButton(),
                  ),
                  const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                  SettingsTile(
                      onTap: () async {
                        NavigationSvc.pushSettings(
                          context,
                          ChatSelectorView(
                            onSelect: (Chat chat) async {
                              final bool? confirmed = await showBBDialog<bool>(
                                context: context,
                                title: "Delete Chat?",
                                body:
                                    "This will permanently delete the chat, all of its messages, and all of its participants (handles). This cannot be undone.",
                                actions: [
                                  BBDialogAction(
                                    text: "Cancel",
                                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                                  ),
                                  BBDialogAction(
                                    text: "Delete",
                                    isDestructive: true,
                                    color: Colors.redAccent,
                                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                                  ),
                                ],
                              );

                              if (confirmed != true) return;

                              try {
                                await ChatsSvc.deleteChat(chat, deleteHandles: true);
                                showSnackbar(
                                  "Chat Deleted",
                                  "Successfully deleted chat and all associated data.",
                                );
                              } catch (ex, stacktrace) {
                                Logger.error("Failed to delete chat!", error: ex, trace: stacktrace);
                                showSnackbar("Failed to Delete Chat", "Error: ${ex.toString()}");
                              }
                            },
                          ),
                        );
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.chat_bubble_2,
                        materialIcon: Icons.delete_forever,
                        containerColor: Colors.redAccent,
                      ),
                      title: "Delete a Chat",
                      subtitle:
                          "Permanently deletes a selected chat, all its messages, and all its participants. Use this to simulate a brand-new chat arrival."),
                  const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                  SettingsTile(
                      onTap: () async {
                        final bool? confirmed = await showBBDialog<bool>(
                          context: context,
                          title: "Delete All Messaging Data?",
                          body: "This will permanently delete ALL messages, attachments, chats, "
                              "participants (handles), and contacts from this device. This includes "
                              "attachment files, custom chat avatars/backgrounds, contact avatars, "
                              "and message caches. Your settings and themes will not be affected. "
                              "This cannot be undone.",
                          bodyTextAlign: TextAlign.center,
                          actions: [
                            BBDialogAction(
                              text: "Cancel",
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                            ),
                            BBDialogAction(
                              text: "Delete All",
                              isDestructive: true,
                              color: Colors.redAccent,
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                            ),
                          ],
                        );

                        if (confirmed != true) return;

                        try {
                          await ChatsSvc.deleteAllMessagingData();
                          showSnackbar(
                            "Messaging Data Deleted",
                            "Successfully deleted all messages, chats, attachments, participants, and contacts.",
                          );
                        } catch (ex, stacktrace) {
                          Logger.error("Failed to delete all messaging data!", error: ex, trace: stacktrace);
                          showSnackbar("Failed to Delete Messaging Data", "Error: ${ex.toString()}");
                          return;
                        }

                        if (!context.mounted) return;
                        await showAreYouSure(
                          context,
                          title: "Sync Messages Now?",
                          content: const Text(
                              "Would you like to sync messages from the server now? You can also do this later."),
                          noText: "Not Now",
                          yesText: "Sync Now",
                          onNo: () => Navigator.of(context, rootNavigator: true).pop(),
                          onYes: () async {
                            Navigator.of(context, rootNavigator: true).pop();
                            if (!context.mounted) return;
                            final range = await showSyncTimeRangeDialog(context);
                            if (range == null) return;

                            // Same mechanism as "Manually Sync Messages" on the Server
                            // Management page: a single global message query bounded by
                            // start/end, which discovers and creates any chats referenced
                            // by the synced messages.
                            final mgr = IncrementalSyncManager(
                              startTimestamp: range.start.millisecondsSinceEpoch,
                              endTimestamp: range.end.millisecondsSinceEpoch,
                            );
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (context) => SyncDialog(manager: mgr),
                            );
                            await mgr.start();
                          },
                        );
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.trash,
                        materialIcon: Icons.delete_forever,
                        containerColor: Colors.redAccent,
                      ),
                      title: "Delete All Messaging Data",
                      subtitle:
                          "Permanently deletes ALL messages, chats, attachments, participants, and contacts on this device."),
                ]),
                if (kIsDesktop) const SizedBox(height: 100),
              ],
            ),
          ),
        ]);
  }
}
