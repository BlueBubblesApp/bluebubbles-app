import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TroubleshootPanel extends StatelessWidget {
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
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
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
                          Get.defaultDialog(
                            backgroundColor: context.theme.colorScheme.secondary,
                            radius: 15.0,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20),
                            titlePadding: EdgeInsets.only(top: 15),
                            title: "Fetching contacts...",
                            titleStyle: Theme.of(context).textTheme.headline1,
                            confirm: Container(
                              margin: EdgeInsets.only(bottom: 10),
                              child: TextButton(
                                child: Text("CLOSE"),
                                onPressed: () {
                                  Get.back();
                                },
                              ),
                            ),
                            content: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: CustomNavigator.width(context) * 4 / 5,
                                height: context.height * 1 / 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    color: Theme.of(context).backgroundColor.computeLuminance() > 0.5
                                        ? Theme.of(context).colorScheme.secondary.lightenPercent(50)
                                        : Theme.of(context).colorScheme.secondary.darkenPercent(50),
                                  ),
                                  padding: EdgeInsets.all(10),
                                  child: Obx(() => ListView.builder(
                                    physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    itemBuilder: (context, index) {
                                      return Text(
                                        log[index],
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      );
                                    },
                                    itemCount: log.length,
                                  )),
                                ),
                              ),
                            ),
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
