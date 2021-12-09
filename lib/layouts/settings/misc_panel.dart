import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secure_application/secure_application.dart';

class MiscPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    Theme
        .of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme
        .of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme
        .of(context)
        .primaryColor, fontWeight: FontWeight.bold);
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
      title: "Miscellaneous & Advanced",
      initialHeader: SettingsManager().canAuthenticate ? "Security" : "Speed & Responsiveness",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              if (SettingsManager().canAuthenticate)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    if (SettingsManager().canAuthenticate)
                      Obx(() =>
                          SettingsSwitch(
                            onChanged: (bool val) async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                  localizedReason:
                                  'Please authenticate to ${val == true ? "enable" : "disable"} security',
                                  stickyAuth: true);
                              if (didAuthenticate) {
                                SettingsManager().settings.shouldSecure.value = val;
                                if (val == false) {
                                  SecureApplicationProvider.of(context, listen: false)!.open();
                                } else if (SettingsManager().settings.securityLevel.value ==
                                    SecurityLevel.locked_and_secured) {
                                  SecureApplicationProvider.of(context, listen: false)!.secure();
                                }
                                saveSettings();
                              }
                            },
                            initialVal: SettingsManager().settings.shouldSecure.value,
                            title: "Secure App",
                            subtitle: "Secure app with a fingerprint or pin",
                            backgroundColor: tileColor,
                          )),
                    if (SettingsManager().canAuthenticate && SettingsManager().settings.shouldSecure.value)
                      Obx(() {
                        if (SettingsManager().settings.shouldSecure.value) {
                          return Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: "Security Info", style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(
                                          text:
                                          "BlueBubbles will use the fingerprints and pin/password set on your device as authentication. Please note that BlueBubbles does not have access to your authentication information - all biometric checks are handled securely by your operating system. The app is only notified when the unlock is successful."),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "There are two different security levels you can choose from:"),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "Locked", style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: " - Requires biometrics/pin only when the app is first started"),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "Locked and secured", style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text:
                                          " - Requires biometrics/pin any time the app is brought into the foreground, hides content in the app switcher, and disables screenshots & screen recordings"),
                                    ],
                                    style: Theme
                                        .of(context)
                                        .textTheme
                                        .subtitle1
                                        ?.copyWith(color: Theme
                                        .of(context)
                                        .textTheme
                                        .bodyText1
                                        ?.color),
                                  ),
                                ),
                              ));
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    if (SettingsManager().canAuthenticate)
                      Obx(() {
                        if (SettingsManager().settings.shouldSecure.value) {
                          return SettingsOptions<SecurityLevel>(
                            initial: SettingsManager().settings.securityLevel.value,
                            onChanged: (val) async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                  localizedReason: 'Please authenticate to change your security level', stickyAuth: true);
                              if (didAuthenticate) {
                                if (val != null) {
                                  SettingsManager().settings.securityLevel.value = val;
                                  if (val == SecurityLevel.locked_and_secured) {
                                    SecureApplicationProvider.of(context, listen: false)!.secure();
                                  } else {
                                    SecureApplicationProvider.of(context, listen: false)!.open();
                                  }
                                }
                                saveSettings();
                              }
                            },
                            options: SecurityLevel.values,
                            textProcessing: (val) =>
                            val.toString().split(".")[1]
                                .replaceAll("_", " ")
                                .capitalizeFirst!,
                            title: "Security Level",
                            backgroundColor: tileColor,
                            secondaryColor: headerColor,
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    if (SettingsManager().canAuthenticate)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsManager().settings.incognitoKeyboard.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.incognitoKeyboard.value,
                        title: "Incognito Keyboard",
                        subtitle: "Disables keyboard suggestions and prevents the keyboard from learning or storing any words you type in the message text field",
                        backgroundColor: tileColor,
                      )),
                  ],
                ),
              if (SettingsManager().canAuthenticate)
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Speed & Responsiveness"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() =>
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.lowMemoryMode.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.lowMemoryMode.value,
                        title: "Low Memory Mode",
                        subtitle:
                        "Reduces background processes and deletes cached storage items to improve performance on lower-end devices",
                        backgroundColor: tileColor,
                      )),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsTile(
                        title: "Scroll Speed Multiplier",
                        subtitle: "Controls how fast scrolling occurs",
                        backgroundColor: tileColor,
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsSlider(
                          text: "Scroll Speed Multiplier",
                          startingVal: SettingsManager().settings.scrollVelocity.value,
                          update: (double val) {
                            SettingsManager().settings.scrollVelocity.value = double.parse(val.toStringAsFixed(2));
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(2)),
                          backgroundColor: tileColor,
                          min: 0.20,
                          max: 1,
                          divisions: 8);
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                ],
              ),
              SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Other",),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() =>
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.sendDelay.value = val ? 3 : 0;
                          saveSettings();
                        },
                        initialVal: !isNullOrZero(SettingsManager().settings.sendDelay.value),
                        title: "Send Delay",
                        backgroundColor: tileColor,
                      )),
                  Obx(() {
                    if (!isNullOrZero(SettingsManager().settings.sendDelay.value)) {
                      return SettingsSlider(
                          text: "Set send delay",
                          startingVal: SettingsManager().settings.sendDelay.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.sendDelay.value = val.toInt();
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(0) + " sec"),
                          backgroundColor: tileColor,
                          min: 1,
                          max: 10,
                          divisions: 9);
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() =>
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.use24HrFormat.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.use24HrFormat.value,
                        title: "Use 24 Hour Format for Times",
                        backgroundColor: tileColor,
                      )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsTile(
                        title: "Maximum Group Avatar Count",
                        subtitle: "Controls the maximum number of contact avatars in a group chat's widget",
                        backgroundColor: tileColor,
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(
                        () {
                      if (SettingsManager().settings.skin.value == Skins.iOS) {
                        return SettingsSlider(
                          divisions: 3,
                          max: 5,
                          min: 3,
                          text: 'Maximum avatars in a group chat widget',
                          startingVal: SettingsManager().settings.maxAvatarsInGroupWidget.value.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.maxAvatarsInGroupWidget.value = val.toInt();
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(0)),
                          backgroundColor: tileColor,
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ]
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}
