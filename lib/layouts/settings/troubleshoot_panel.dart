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
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class TroubleshootPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle = context.theme.textTheme.labelLarge?.copyWith(
        color: ThemeManager().inDarkMode(context)
            ? context.theme.colorScheme.onBackground
            : context.theme.colorScheme.properOnSurface,
        fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme.textTheme.labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background
        : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface
        : context.theme.colorScheme.background;

    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    Directory? savedLogsDir;
    RxList<File>? savedLogs;
    if (kIsDesktop) {
      savedLogsDir = Directory(join(Logger.logFile.parent.path, "Saved Logs"));
      if (savedLogsDir.existsSync()) {
        savedLogs = RxList.from(savedLogsDir
            .listSync()
            .whereType<File>()
            .toList()
            .reversed);
      } else {
        savedLogs = RxList();
      }
    }

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
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsTile(
                      onTap: () async {
                        final RxList<String> log = <String>[].obs;
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  backgroundColor: context.theme.colorScheme.surface,
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
                                ));
                        await ContactManager().fetchContactsDesktop(logger: (newLog) {
                          log.add(newLog);
                        });
                      },
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.group,
                        materialIcon: Icons.contacts,
                      ),
                      title: "Fetch Contacts With Verbose Logging",
                      subtitle:
                          "This will fetch contacts from the server with extra info to help devs debug contacts issues",
                    ),
                  ]),
                if (kIsWeb || kIsDesktop)
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Logging"),
                SettingsSection(backgroundColor: tileColor, children: [
                  if (!kIsDesktop)
                    Obx(() => SettingsTile(
                          onTap: () async {
                            if (Logger.saveLogs.value) {
                              await Logger.stopSavingLogs();
                              Logger.saveLogs.value = false;
                              savedLogs!.value =
                                  RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
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
                  if (kIsDesktop)
                    SettingsTile(
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.doc,
                          materialIcon: Icons.file_open,
                        ),
                        title: "Open Real-time Log File",
                        subtitle: Logger.logFile.path,
                        onTap: () async {
                          if (Logger.logFile.existsSync()) Logger.logFile.createSync();
                          await launchUrl(Uri.file(Logger.logFile.path));
                        }),
                  if (kIsDesktop)
                    SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.doc,
                          materialIcon: Icons.file_open,
                        ),
                        title: "Open Startup Log File",
                        subtitle: Logger.startupFile.path,
                        onTap: () async {
                          if (Logger.startupFile.existsSync()) Logger.startupFile.createSync();
                          await launchUrl(Uri.file(Logger.startupFile.path));
                        }),
                  if (kIsDesktop)
                    SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.folder,
                        materialIcon: Icons.folder,
                      ),
                      title: "Open App Data Location",
                      subtitle: SettingsManager().appDocDir.path,
                      onTap: () async => await launchUrl(Uri.file(SettingsManager().appDocDir.path)),
                    ),
                ]),
                if (kIsDesktop)
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Saved Logs"),
                if (kIsDesktop)
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsTile(
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.folder,
                          materialIcon: Icons.folder,
                        ),
                        title: "Open Saved Logs Location",
                        subtitle: savedLogsDir!.path,
                        onTap: () async {
                          if (!savedLogsDir!.existsSync()) savedLogsDir.createSync(recursive: true);
                          await launchUrl(Uri.file(savedLogsDir.path));
                        }),
                    SettingsDivider(),
                    Obx(() => SettingsTile(
                          onTap: () async {
                            if (Logger.saveLogs.value) {
                              await Logger.stopSavingLogs();
                              Logger.saveLogs.value = false;
                              savedLogs!.value =
                                  RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                            } else {
                              Logger.startSavingLogs();
                            }
                          },
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                            materialIcon: Icons.history_edu,
                          ),
                          title: "${Logger.saveLogs.value ? "Stop" : "Start"} Saving Logs",
                          subtitle: Logger.saveLogs.value
                              ? "Logging started, tap here to end and save"
                              : "Create a bug report for developers to analyze",
                        )),
                    SettingsDivider(),
                    SettingsTile(
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.refresh,
                        materialIcon: Icons.refresh,
                      ),
                      onTap: () {
                        savedLogs!.value = RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                      },
                      title: "Refresh Saved Logs",
                      subtitle: "Reload the Saved Logs directory",
                    ),
                    SettingsDivider(),
                    Obx(() {
                      if (savedLogs?.isNotEmpty ?? false) {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemBuilder: (BuildContext context, int index) {
                            String? dayString;
                            String? timeString;
                            File file = savedLogs![index];
                            String name = basename(file.path);
                            RegExpMatch? timestamp = RegExp("BlueBubbles_Logs_(.*)_(.*).txt").firstMatch(name);
                            if (timestamp == null) dayString = "Unknown";

                            String? date = timestamp?.group(1);
                            String? time = timestamp?.group(2);
                            if (date == null || time == null) dayString = "Unknown";

                            List<String> splitDate = date?.split("-") ?? [];
                            List<String> splitTime = time?.split("-") ?? [];
                            if (splitDate.length == 3 && splitTime.length == 3) {
                              int? year = int.tryParse(splitDate[0]);
                              int? month = int.tryParse(splitDate[1]);
                              int? day = int.tryParse(splitDate[2]);
                              int? hour = int.tryParse(splitTime[0]);
                              int? minute = int.tryParse(splitTime[1]);
                              int? second = int.tryParse(splitTime[2]);
                              if (year != null &&
                                  month != null &&
                                  day != null &&
                                  hour != null &&
                                  minute != null &&
                                  second != null) {
                                DateTime dateTime = DateTime(year, month, day, hour, minute, second);
                                dayString = DateFormat(DateFormat.YEAR_ABBR_MONTH_WEEKDAY_DAY).format(dateTime);
                                timeString = DateFormat(SettingsManager().settings.use24HrFormat.value
                                        ? DateFormat.HOUR24_MINUTE_SECOND
                                        : DateFormat.HOUR_MINUTE_SECOND)
                                    .format(dateTime);
                              }
                            }
                            if (dayString == null) {
                              if ((date ?? "").length >= 6) {
                                List<String> chars = date!.characters.toList();
                                int? year = int.tryParse(chars.sublist(0, 4).join());
                                if (year == null) return SizedBox.shrink();

                                bool twoDigit = chars[5] == "0";
                                int? month = int.tryParse(chars.sublist(4, twoDigit ? 6 : 5).join());
                                if (month == null) return SizedBox.shrink();

                                if (twoDigit && date.length < 7) return SizedBox.shrink();
                                int? day = int.tryParse(chars.sublist(twoDigit ? 6 : 5).join());
                                if (day == null) return SizedBox.shrink();

                                DateTime dateTime = DateTime(year, month, day);
                                dayString = DateFormat(DateFormat.YEAR_ABBR_MONTH_WEEKDAY_DAY).format(dateTime);
                              }
                            }
                            return SettingsTile(
                              leading: SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.doc,
                                materialIcon: Icons.file_open,
                              ),
                              title: "$dayString${timeString != null ? " at $timeString" : ""}",
                              subtitle: basename(savedLogs[index].path),
                              onTap: () async => await launchUrl(Uri.file(savedLogs![index].path)),
                              trailing: IconButton(
                                icon: Icon(SettingsManager().settings.skin.value == Skins.iOS
                                    ? CupertinoIcons.trash
                                    : Icons.delete),
                                onPressed: () {
                                  savedLogs![index].deleteSync();
                                  savedLogs.value =
                                      RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                                },
                              ),
                            );
                          },
                          itemCount: savedLogs!.length,
                        );
                      }
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          child: Text("When you save logs, they'll show up here", style: context.textTheme.bodySmall),
                        ),
                      );
                    }),
                  ]),
                if (kIsDesktop)
                  SizedBox(height: 100),
              ],
            ),
          ),
        ]);
  }
}
