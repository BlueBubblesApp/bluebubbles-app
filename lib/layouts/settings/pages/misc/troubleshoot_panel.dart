import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TroubleshootPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _TroubleshootPanelState();
}

class _TroubleshootPanelState extends OptimizedState<TroubleshootPanel> with ThemeHelpers {

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Troubleshooting",
      initialHeader: "Logging",
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
                  Obx(() => SettingsTile(
                    onTap: () async {
                      if (Logger.saveLogs.value) {
                        await Logger.stopSavingLogs();
                        Logger.saveLogs.value = false;
                      } else {
                        Logger.startSavingLogs();
                      }
                    },
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                      materialIcon: Icons.history_edu,
                    ),
                    title: "${Logger.saveLogs.value ? "End" : "Start"} Logging",
                    subtitle: Logger.saveLogs.value
                        ? "Logging started, tap here to end and save"
                        : "Create a bug report for developers to analyze",
                  )),
                ]
              ),
              if (kIsWeb || kIsDesktop)
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Contacts"),
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
                                  width: navigatorService.width(context) * 4 / 5,
                                  height: context.height * 1 / 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      color: context.theme.colorScheme.background,
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: Obx(() => ListView.builder(
                                      physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          await ContactManager().fetchContactsDesktop(logger: (newLog) {
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
                    ]
                ),
            ],
          ),
        ),
      ]
    );
  }
}
