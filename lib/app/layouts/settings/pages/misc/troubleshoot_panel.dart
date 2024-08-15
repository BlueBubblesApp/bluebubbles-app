import 'package:bluebubbles/app/layouts/settings/pages/misc/live_logging_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/logging_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/log_level_selector.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/services/backend/sync/chat_sync_manager.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
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
  @override
  State<StatefulWidget> createState() => _TroubleshootPanelState();
}

class _TroubleshootPanelState extends OptimizedState<TroubleshootPanel> {
  final RxnBool resyncingHandles = RxnBool();
  final RxnBool resyncingChats = RxnBool();
  final RxInt logFileCount = 1.obs;
  final RxInt logFileSize = 0.obs;
  final RxBool optimizationsDisabled = false.obs;

  @override
  void initState() {
    super.initState();

    // Count how many .log files are in the log directory
    final Directory logDir = Directory(Logger.logDir);
    if (logDir.existsSync()) {
      final List<FileSystemEntity> files = logDir.listSync();
      final logFiles =
          files.where((file) => file.path.endsWith(".log")).toList();
      logFileCount.value = logFiles.length;

      // Size in KB
      for (final file in logFiles) {
        logFileSize.value += file.statSync().size ~/ 1024;
      }
    }

    // Check if battery optimizations are disabled
    DisableBatteryOptimization.isAllBatteryOptimizationDisabled.then((value) {
      optimizationsDisabled.value = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget nextIcon = Obx(() => ss.settings.skin.value != Skins.Material
        ? Icon(
            ss.settings.skin.value != Skins.Material
                ? CupertinoIcons.chevron_right
                : Icons.arrow_forward,
            color: context.theme.colorScheme.outline,
            size: iOS ? 18 : 24,
          )
        : const SizedBox.shrink());

    return SettingsScaffold(
        title: "Troubleshooting",
        initialHeader: (kIsWeb || kIsDesktop) ? "Contacts" : "Logging",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                if (kIsWeb || kIsDesktop)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      SettingsTile(
                        onTap: () async {
                          final RxList<String> log = <String>[].obs;
                          showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                    backgroundColor:
                                        context.theme.colorScheme.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    titlePadding:
                                        const EdgeInsets.only(top: 15),
                                    title: Text("Fetching contacts...",
                                        style:
                                            context.theme.textTheme.titleLarge),
                                    content: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width: ns.width(context) * 4 / 5,
                                        height: context.height * 1 / 3,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                            color: context
                                                .theme.colorScheme.background,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          child: Obx(() => ListView.builder(
                                                physics:
                                                    const AlwaysScrollableScrollPhysics(
                                                        parent:
                                                            BouncingScrollPhysics()),
                                                itemBuilder: (context, index) {
                                                  return Text(
                                                    log[index],
                                                    style: TextStyle(
                                                      color: context
                                                          .theme
                                                          .colorScheme
                                                          .onBackground,
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
                          await cs.fetchNetworkContacts(logger: (newLog) {
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
                if (kIsWeb || kIsDesktop)
                  SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Logging"),
                SettingsSection(backgroundColor: tileColor, children: [
                  const LogLevelSelector(),
                  SettingsTile(
                    title: "Live Logging",
                    subtitle:
                        "A live view of the logs. Useful for debugging issues.",
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.bolt_fill,
                      materialIcon: Icons.bolt_outlined,
                    ),
                    onTap: () {
                      ns.pushSettings(
                        context,
                        LiveLoggingPanel(),
                      );
                    },
                    trailing: nextIcon,
                  ),
                  SettingsTile(
                    title: "View Latest Log",
                    subtitle: "View the latest log file. Useful for debugging issues, in app.",
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.doc_append,
                      materialIcon: Icons.document_scanner_rounded
                    ),
                    onTap: () {
                      ns.pushSettings(
                        context,
                        LoggingPanel(),
                      );
                    },
                    trailing: nextIcon,
                  ),
                  if (Platform.isAndroid)
                    SettingsTile(
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.share_up,
                          materialIcon: Icons.share
                        ),
                        title: "Export / Share Logs",
                        subtitle:
                            "${logFileCount.value} log file(s) | ${logFileSize.value} KB",
                        onTap: () async {
                          if (logFileCount.value == 0) {
                            showSnackbar(
                                "No Logs", "There are no logs to share!");
                            return;
                          }

                          showSnackbar("Please Wait",
                              "Compressing ${logFileCount.value} log file(s)...");
                          String filePath = Logger.compressLogs();
                          final File zippedLogFile = File(filePath);
                          Share.file("BlueBubbles Logs", zippedLogFile.path);
                        }),
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
                          if (logFile.existsSync())
                            logFile.createSync(recursive: true);
                          await launchUrl(Uri.file(logFile.path));
                        }),
                  SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.trash,
                        materialIcon: Icons.delete,
                      ),
                      title: "Clear Logs",
                      subtitle: "Deletes all stored log files.",
                      onTap: () async {
                        Logger.clearLogs();
                        showSnackbar(
                            "Logs Cleared", "All logs have been deleted.");
                        logFileCount.value = 0;
                        logFileSize.value = 0;
                      }),
                  if (kIsDesktop) const SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.folder,
                        materialIcon: Icons.folder,
                      ),
                      title: "Open App Data Location",
                      subtitle: fs.appDocDir.path,
                      onTap: () async =>
                          await launchUrl(Uri.file(fs.appDocDir.path)),
                    ),
                ]),
                if (Platform.isAndroid)
                  SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Optimizations"),
                if (Platform.isAndroid)
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsTile(
                        onTap: () async {
                          if (optimizationsDisabled.value) {
                            showSnackbar("Already Disabled",
                                "Battery optimizations are already disabled for BlueBubbles");
                            return;
                          }

                          final optsDisabled =
                              await disableBatteryOptimizations();
                          if (!optsDisabled) {
                            showSnackbar("Error",
                                "Battery optimizations were not disabled. Please try again.");
                          }
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.battery_25,
                          materialIcon: Icons.battery_5_bar,
                        ),
                        title: "Disable Battery Optimizations",
                        subtitle: "Allow app to run in the background via the OS",
                        trailing: Obx(() => !optimizationsDisabled.value
                            ? nextIcon
                            : Icon(Icons.check,
                                color: context.theme.colorScheme.outline))),
                  ]),
                if (!kIsWeb)
                  SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Database Re-syncing"),
                if (!kIsWeb)
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsTile(
                        title: "Sync Handles & Contacts",
                        subtitle:
                            "Run this troubleshooter if you are experiencing issues with missing or incorrect contact names and photos",
                        onTap: () async {
                          resyncingHandles.value = true;
                          try {
                            final handleSyncer = HandleSyncManager();
                            await handleSyncer.start();
                            eventDispatcher.emit("refresh-all", null);

                            showSnackbar("Success",
                                "Successfully re-synced handles! You may need to close and re-open the app for changes to take effect.");
                          } catch (ex, stacktrace) {
                            Logger.error("Failed to reset contacts!", error: ex, trace: stacktrace);

                            showSnackbar("Failed to re-sync handles!",
                                "Error: ${ex.toString()}");
                          } finally {
                            resyncingHandles.value = false;
                          }
                        },
                        trailing: Obx(() => resyncingHandles.value == null
                            ? const SizedBox.shrink()
                            : resyncingHandles.value == true
                                ? Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 20,
                                      maxWidth: 20,
                                    ),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          context.theme.colorScheme.primary),
                                    ))
                                : Icon(Icons.check,
                                    color: context.theme.colorScheme.outline))),
                    SettingsTile(
                        title: "Sync Chat Info",
                        subtitle: "This will re-sync all chat data & icons from the server to ensure that you have the most up-to-date information.\n\nNote: This will overwrite any group chat icons that are not locked!",
                        onTap: () async {
                          resyncingChats.value = true;
                          try {
                            showSnackbar("Please Wait...", "This may take a few minutes.");

                            final chatSyncer = ChatSyncManager();
                            await chatSyncer.start();
                            eventDispatcher.emit("refresh-all", null);

                            showSnackbar("Success",
                                "Successfully synced your chat info! You may need to close and re-open the app for changes to take effect.");
                          } catch (ex, stacktrace) {
                            Logger.error("Failed to sync chat info!", error: ex, trace: stacktrace);
                            showSnackbar("Failed to sync chat info!",
                                "Error: ${ex.toString()}");
                          } finally {
                            resyncingChats.value = false;
                          }
                        },
                        trailing: Obx(() => resyncingChats.value == null
                            ? const SizedBox.shrink()
                            : resyncingChats.value == true
                                ? Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 20,
                                      maxWidth: 20,
                                    ),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          context.theme.colorScheme.primary),
                                    ))
                                : Icon(Icons.check,
                                    color: context.theme.colorScheme.outline)))
                  ]),
                if (kIsDesktop) const SizedBox(height: 100),
              ],
            ),
          ),
        ]);
  }
}
