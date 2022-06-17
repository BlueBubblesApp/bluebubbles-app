import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TroubleshootPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

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
                    backgroundColor: tileColor,
                    onTap: () async {
                      if (Logger.saveLogs.value) {
                        await Logger.stopSavingLogs();
                        Logger.saveLogs.value = false;
                      } else {
                        Logger.startSavingLogs();
                      }
                    },
                    leading: SettingsLeadingIcon(
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
                        backgroundColor: tileColor,
                        onTap: () async {
                          final RxList<String> log = <String>[].obs;
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: context.theme.colorScheme.secondary,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20),
                              titlePadding: EdgeInsets.only(top: 15),
                              title: Text("Fetching contacts...", style: context.theme.textTheme.titleLarge),
                              content: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: CustomNavigator.width(context) * 4 / 5,
                                  height: context.height * 1 / 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      color: context.theme.colorScheme.background,
                                    ),
                                    padding: EdgeInsets.all(10),
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
                        leading: SettingsLeadingIcon(
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
