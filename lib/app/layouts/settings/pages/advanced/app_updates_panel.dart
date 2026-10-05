import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdatesPanel extends StatefulWidget {
  const AppUpdatesPanel({super.key});

  @override
  State<StatefulWidget> createState() => _AppUpdatesPanelState();
}

class _AppUpdatesPanelState extends State<AppUpdatesPanel> with ThemeHelpers {
  @override
  void initState() {
    super.initState();
    // Refresh availability whenever the page is opened. Manual so it never
    // touches the auto-check schedule.
    UpdateSvc.checkForUpdate(manual: true);
  }

  Future<void> _checkNow() async {
    await UpdateSvc.checkForUpdate(manual: true);
    if (mounted && !UpdateSvc.updateAvailable.value) {
      showSnackbar("Up To Date", "You're already on the latest version.");
    }
  }

  Future<void> _install(AppUpdateInfo release) async {
    final ValueNotifier<double?> progress = ValueNotifier(0);
    final sub = UpdateSvc.downloadProgress.listen((p) => progress.value = p);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (ctx, value, _) => BBProgressDialog(title: "Downloading Update...", progress: value),
      ),
    );
    await UpdateSvc.downloadAndInstall(release);
    await sub.cancel();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "App Updates",
      initialHeader: "App Updates",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
              child: Text(
                "Automatically check GitHub for new BlueBubbles releases and install them yourself. "
                "This is only available when the app was not installed from the Play Store.",
              ),
            ),
            Obx(() {
              final release = UpdateSvc.availableUpdate.value;
              return AnimatedSizeAndFade.showHide(
                show: release != null,
                child: release == null
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsHeader(
                              iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Update Available"),
                          SettingsSection(
                            backgroundColor: tileColor,
                            children: [
                              SettingsTile(
                                backgroundColor: tileColor,
                                title: "Version ${release.version}${release.channelSuffix}",
                                subtitle: release.latestRelease?.name,
                                isThreeLine: release.latestRelease?.name != null,
                                leading: const SettingsLeadingIcon(
                                  iosIcon: CupertinoIcons.arrow_down_circle_fill,
                                  materialIcon: Icons.system_update,
                                  containerColor: Colors.green,
                                ),
                              ),
                              if (release.latestRelease?.htmlUrl != null) ...[
                                const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                                SettingsTile(
                                  backgroundColor: tileColor,
                                  title: "View Changelog",
                                  trailing: const NextButton(),
                                  onTap: () async {
                                    await launchUrl(Uri.parse(release.latestRelease!.htmlUrl!),
                                        mode: LaunchMode.externalApplication);
                                  },
                                ),
                              ],
                              const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                              SettingsTile(
                                backgroundColor: tileColor,
                                title: "Install Update",
                                trailing: const NextButton(),
                                onTap: () async {
                                  await _install(release);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
              );
            }),
            SettingsHeader(
                iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Automatic Update Checks"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Obx(() => SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.autoUpdateCheckEnabled.value = val;
                        await SettingsSvc.settings.saveOneAsync('autoUpdateCheckEnabled');
                      },
                      initialVal: SettingsSvc.settings.autoUpdateCheckEnabled.value,
                      title: "Automatically Check for Updates",
                      subtitle: "Check for new releases on app startup and resume",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
              ],
            ),
            Obx(() => AnimatedSizeAndFade.showHide(
                  show: SettingsSvc.settings.autoUpdateCheckEnabled.value,
                  child: SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      SettingsOptions<AppUpdateCheckInterval>(
                        title: "Check Interval",
                        initial: SettingsSvc.settings.updateCheckInterval.value,
                        options: AppUpdateCheckInterval.values,
                        textProcessing: (i) => i.label,
                        capitalize: false,
                        onChanged: (val) async {
                          if (val == null) return;
                          SettingsSvc.settings.updateCheckInterval.value = val;
                          await SettingsSvc.settings.saveOneAsync('updateCheckInterval');
                        },
                      ),
                      const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                      SettingsOptions<AppUpdateChannel>(
                        title: "Update Track",
                        initial: SettingsSvc.settings.updateChannel.value,
                        options: AppUpdateChannel.values,
                        textProcessing: (c) => c.label,
                        capitalize: false,
                        onChanged: (val) async {
                          if (val == null) return;
                          SettingsSvc.settings.updateChannel.value = val;
                          await SettingsSvc.settings.saveOneAsync('updateChannel');
                        },
                      ),
                    ],
                  ),
                )),
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Manual Check"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Obx(() => SettingsTile(
                      backgroundColor: tileColor,
                      title: "Check for Updates",
                      subtitle: UpdateSvc.checking.value ? "Checking..." : null,
                      onTap: UpdateSvc.checking.value
                          ? null
                          : () async {
                              await _checkNow();
                            },
                      trailing: UpdateSvc.checking.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const NextButton(),
                    )),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
