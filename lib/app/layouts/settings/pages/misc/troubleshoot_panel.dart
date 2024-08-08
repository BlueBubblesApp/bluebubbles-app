import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
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
  final RxList<File> savedLogs = <File>[].obs;
  final RxnBool resyncingHandles = RxnBool();

  @override
  Widget build(BuildContext context) {
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
                            backgroundColor: context.theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            titlePadding: const EdgeInsets.only(top: 15),
                            title: Text("Fetching contacts...", style: context.theme.textTheme.titleLarge),
                            content: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: ns.width(context) * 4 / 5,
                                height: context.height * 1 / 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    color: context.theme.colorScheme.background,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Obx(() => ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    itemBuilder: (context, index) {
                                      return Text(
                                        log[index],
                                        style: TextStyle(
                                          color: context.theme.colorScheme.onBackground,
                                          fontSize: 10,
                                        ),
                                      );
                                    },
                                    itemCount: log.length,
                                  )),
                                ),
                              ),
                            ),
                          )
                        );
                        await cs.fetchNetworkContacts(logger: (newLog) {
                          log.add(newLog);
                        });
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.group,
                        materialIcon: Icons.contacts,
                      ),
                      title: "Fetch Contacts With Verbose Logging",
                      subtitle: "This will fetch contacts from the server with extra info to help devs debug contacts issues",
                    ),
                  ],
                ),
              if (kIsWeb || kIsDesktop)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Logging"
                ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
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
                        if (logFile.existsSync()) logFile.createSync(recursive: true);
                        await launchUrl(Uri.file(logFile.path));
                      }
                    ),
                  if (kIsDesktop)
                    const SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.folder,
                        materialIcon: Icons.folder,
                      ),
                      title: "Open App Data Location",
                      subtitle: fs.appDocDir.path,
                      onTap: () async => await launchUrl(Uri.file(fs.appDocDir.path)),
                    ),
                ]
              ),
              if (!kIsWeb)
                SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Database Re-syncing"
                ),
              if (!kIsWeb)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      title: "Re-Sync Handles & Contacts",
                      subtitle: "Run this troubleshooter if you are experiencing issues with missing or incorrect contact names and photos",
                      onTap: () async {
                          resyncingHandles.value = true;
                          try {
                            final handleSyncer = HandleSyncManager();
                            await handleSyncer.start();
                            eventDispatcher.emit("refresh-all", null);

                            showSnackbar("Success", "Successfully re-synced handles! You may need to close and re-open the app for changes to take effect.");
                          } catch (ex, stacktrace) {
                            Logger.error("Failed to reset contacts!");
                            Logger.error(ex.toString());
                            Logger.error(stacktrace.toString());

                            showSnackbar("Failed to re-sync handles!", "Error: ${ex.toString()}");
                          } finally {
                            resyncingHandles.value = false;
                          }
                      },
                      trailing: Obx(() => resyncingHandles.value == null
                          ? const SizedBox.shrink()
                          : resyncingHandles.value == true ? Container(
                          constraints: const BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )) : Icon(Icons.check, color: context.theme.colorScheme.outline)
                      )),
                  ]),
              if (kIsDesktop)
                const SizedBox(height: 100),
            ],
          ),
        ),
      ]
    );
  }
}
