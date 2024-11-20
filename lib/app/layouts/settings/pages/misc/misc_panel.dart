import 'package:bluebubbles/helpers/types/classes/language_codes.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secure_application/secure_application.dart';
import 'package:universal_io/io.dart';

class MiscPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MiscPanelState();
}

class _MiscPanelState extends OptimizedState<MiscPanel> {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Advanced",
      initialHeader: (!kIsWeb && !kIsDesktop) || ss.canAuthenticate ? "Security" : "Speed & Responsiveness",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              if (!kIsWeb && !(kIsDesktop && !Platform.isWindows))
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    if (ss.canAuthenticate)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                  localizedReason:
                                      'Please authenticate to ${val == true ? "enable" : "disable"} security',
                                  options: const AuthenticationOptions(stickyAuth: true));
                              if (didAuthenticate) {
                                ss.settings.shouldSecure.value = val;
                                if (val == false) {
                                  SecureApplicationProvider.of(context, listen: false)!.open();
                                } else if (ss.settings.securityLevel.value == SecurityLevel.locked_and_secured) {
                                  SecureApplicationProvider.of(context, listen: false)!.secure();
                                }
                                saveSettings();
                              }
                            },
                            initialVal: ss.settings.shouldSecure.value,
                            title: "Secure App",
                            subtitle: "Secure app with ${kIsDesktop ? "Windows Security" : "a fingerprint or pin"}",
                            backgroundColor: tileColor,
                            leading: SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.lock_fill,
                              materialIcon: Icons.lock,
                              containerColor: (ss.settings.shouldSecure.value) ? Colors.green : Colors.redAccent
                            ),
                          )),
                    if (ss.canAuthenticate)
                      Obx(() {
                        if (ss.settings.shouldSecure.value) {
                          return Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(children: [
                                        TextSpan(text: "Security Info", style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: "\n\n"),
                                        TextSpan(
                                            text:
                                                "BlueBubbles will use the fingerprints and pin/password set on your device as authentication. Please note that BlueBubbles does not have access to your authentication information - all biometric checks are handled securely by your operating system. The app is only notified when the unlock is successful."),
                                      ]),
                                      if (!kIsDesktop)
                                        const TextSpan(children: [
                                          TextSpan(text: "\n\n"),
                                          TextSpan(
                                              text: "There are two different security levels you can choose from:"),
                                          TextSpan(text: "\n\n"),
                                          TextSpan(text: "Locked", style: TextStyle(fontWeight: FontWeight.bold)),
                                          TextSpan(
                                              text: " - Requires biometrics/pin only when the app is first started"),
                                          TextSpan(text: "\n\n"),
                                          TextSpan(
                                              text: "Locked and secured",
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          TextSpan(
                                              text:
                                                  " - Requires biometrics/pin any time the app is brought into the foreground, hides content in the app switcher, and disables screenshots & screen recordings"),
                                        ]),
                                    ],
                                    style: context.theme.textTheme.bodySmall!
                                        .copyWith(color: context.theme.colorScheme.properOnSurface),
                                  ),
                                ),
                              ));
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (ss.canAuthenticate && !kIsDesktop)
                      Obx(() {
                        if (ss.settings.shouldSecure.value) {
                          return SettingsOptions<SecurityLevel>(
                            initial: ss.settings.securityLevel.value,
                            onChanged: (val) async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                  localizedReason: 'Please authenticate to change your security level',
                                  options: const AuthenticationOptions(stickyAuth: true));
                              if (didAuthenticate) {
                                if (val != null) {
                                  ss.settings.securityLevel.value = val;
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
                            textProcessing: (val) => val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                            title: "Security Level",
                            secondaryColor: headerColor,
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (ss.canAuthenticate && !kIsDesktop)
                      const SettingsDivider(),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              ss.settings.incognitoKeyboard.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.incognitoKeyboard.value,
                            title: "Incognito Keyboard",
                            subtitle:
                                "Disables keyboard suggestions and prevents the keyboard from learning or storing any words you type in the message text field",
                            isThreeLine: true,
                            backgroundColor: tileColor,
                            leading: const SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.keyboard,
                              materialIcon: Icons.keyboard,
                              containerColor: Colors.teal
                            ),
                          )),
                  ],
                ),
              if (!kIsWeb && !kIsDesktop || ss.canAuthenticate)
                SettingsHeader(
                    iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Speed & Responsiveness"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          ss.settings.highPerfMode.value = val;
                          saveSettings();
                        },
                        initialVal: ss.settings.highPerfMode.value,
                        title: "High Performance Mode",
                        subtitle: "Removes inline images and videos to boost performance on lower-end devices",
                        isThreeLine: true,
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.speedometer,
                          materialIcon: Icons.speed_outlined,
                          containerColor: Colors.green
                        ),
                      )),
                  const SettingsDivider(),
                  Obx(() {
                    if (iOS) {
                      return const SettingsTile(
                        title: "Scroll Speed Multiplier",
                        subtitle: "Controls how fast scrolling occurs",
                        isThreeLine: true,
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.arrow_up_down_square,
                          materialIcon: Icons.mouse_outlined,
                          containerColor: Colors.orange
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (iOS) {
                      return SettingsSlider(
                          startingVal: ss.settings.scrollVelocity.value,
                          update: (double val) {
                            ss.settings.scrollVelocity.value = double.parse(val.toStringAsFixed(2));
                          },
                          onChangeEnd: (double val) {
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(2)),
                          backgroundColor: tileColor,
                          min: 0.20,
                          max: 1,
                          divisions: 8);
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                ],
              ),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Networking"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsTile(
                    title: "API Timeout Duration",
                    subtitle:
                        "Controls the duration (in seconds) until a network request will time out.\nIncrease this setting if you have poor connection.",
                    isThreeLine: true,
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.stopwatch,
                      materialIcon: Icons.timer,
                      containerColor: Colors.red
                    ),
                    trailing: ss.settings.apiTimeout.value != 30000 ? ElevatedButton(
                      onPressed: () {
                        ss.settings.apiTimeout.value = 30000;
                        saveSettings();
                      },
                      child: const Text("Reset to Default"),
                    ) : null,
                  )),
                  Obx(() => SettingsSlider(
                      startingVal: ss.settings.apiTimeout.value / 1000,
                      update: (double val) {
                        ss.settings.apiTimeout.value = val.toInt() * 1000;
                      },
                      onChangeEnd: (double val) {
                        saveSettings();
                        http.dio = Dio(BaseOptions(
                          connectTimeout: const Duration(milliseconds: 15000),
                          receiveTimeout: Duration(milliseconds: ss.settings.apiTimeout.value),
                          sendTimeout: Duration(milliseconds: ss.settings.apiTimeout.value),
                        ));
                        http.dio.interceptors.add(ApiInterceptor());
                      },
                      backgroundColor: tileColor,
                      min: 5,
                      max: 60,
                      divisions: 11)),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Obx(() => Text(
                          "Note: Attachment uploads will timeout after ${ss.settings.apiTimeout.value ~/ 1000 * 12} seconds",
                          style: context.theme.textTheme.bodySmall!
                              .copyWith(color: context.theme.colorScheme.properOnSurface),
                        )),
                  ),
                  const SettingsDivider(padding: EdgeInsets.zero),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          ss.settings.cancelQueuedMessages.toggle();
                          saveSettings();
                        },
                        initialVal: ss.settings.cancelQueuedMessages.value,
                        title: "Cancel Queued Messages on Failure",
                        subtitle: "Cancel messages queued to send in a chat if one fails before them",
                        backgroundColor: tileColor,
                        isThreeLine: true,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.hand_raised,
                          materialIcon: Icons.back_hand_outlined,
                          containerColor: Colors.orange
                        ),
                      )),
                ],
              ),
              SettingsHeader(
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Other",
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.replaceEmoticonsWithEmoji.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.replaceEmoticonsWithEmoji.value,
                    title: "Replace Emoticons with Emoji",
                    subtitle: "Replace emoticons like :), :D, etc. with their corresponding emojis",
                    backgroundColor: tileColor,
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.smiley,
                      materialIcon: Icons.emoji_emotions_outlined,
                      containerColor: Colors.indigo
                    ),
                  )),
                  const SettingsDivider(),
                  if (kIsDesktop || kIsWeb)
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.spellcheck.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.spellcheck.value,
                          title: "Enable Spellcheck",
                          backgroundColor: tileColor,
                          leading: const SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.textformat_abc_dottedunderline,
                              materialIcon: Icons.spellcheck_outlined,
                              containerColor: Colors.cyan
                          ),
                        )),
                  if (kIsDesktop || kIsWeb)
                    Obx(() => ss.settings.spellcheck.value ? SettingsOptions<(String, String)>(
                      useCupertino: false,
                      onChanged: (val) {
                        if (val == null) return;
                        ss.settings.spellcheckLanguage.value = val.$2;
                        saveSettings();
                      },
                      initial: languageNameAndCodes.firstWhereOrNull((l) => l.$2 == ss.settings.spellcheckLanguage.value) ?? ("Auto", "auto"),
                      options: [("Auto", "auto"), ...languageNameAndCodes],
                      title: 'Spellcheck Language',
                      textProcessing: (val) => val.$1,
                      capitalize: false,
                    ) : const SizedBox.shrink()),
                  if (kIsDesktop || kIsWeb)
                    const SettingsDivider(),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          ss.settings.sendDelay.value = val ? 3 : 0;
                          saveSettings();
                        },
                        initialVal: !isNullOrZero(ss.settings.sendDelay.value),
                        title: "Send Delay",
                        subtitle: "Adds a delay before sending a message to prevent accidental sends. During this time, you can cancel the message.",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.timer,
                          materialIcon: Icons.timer,
                          containerColor: Colors.green
                        ),
                      )),
                  Obx(() {
                    if (!isNullOrZero(ss.settings.sendDelay.value)) {
                      return SettingsSlider(
                          startingVal: ss.settings.sendDelay.toDouble(),
                          update: (double val) {
                            ss.settings.sendDelay.value = val.toInt();
                          },
                          onChangeEnd: (double val) {
                            saveSettings();
                          },
                          formatValue: ((double val) => "${val.toStringAsFixed(0)} sec"),
                          backgroundColor: tileColor,
                          min: 1,
                          max: 10,
                          divisions: 9);
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  const SettingsDivider(),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          ss.settings.use24HrFormat.value = val;
                          saveSettings();
                        },
                        initialVal: ss.settings.use24HrFormat.value,
                        title: "Use 24 Hour Format for Times",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.clock,
                          materialIcon: Icons.access_time,
                          containerColor: Colors.blue
                        ),
                      )),
                  const SettingsDivider(),
                  if (Platform.isAndroid)
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.allowUpsideDownRotation.value = val;
                            saveSettings();
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.landscapeRight,
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.portraitUp,
                              if (ss.settings.allowUpsideDownRotation.value) DeviceOrientation.portraitDown,
                            ]);
                          },
                          initialVal: ss.settings.allowUpsideDownRotation.value,
                          title: "Allow Upside-Down Rotation",
                          backgroundColor: tileColor,
                          leading: const SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.rotate_right,
                            materialIcon: Icons.screen_rotation,
                            containerColor: Colors.orange
                          ),
                        )),
                  if (Platform.isAndroid)
                    const SettingsDivider(),
                  Obx(() {
                    if (iOS) {
                      return const SettingsTile(
                        title: "Maximum Group Avatar Count",
                        subtitle: "Controls the maximum number of contact avatars in a group chat's widget",
                        isThreeLine: true,
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.person_2,
                          materialIcon: Icons.people,
                          containerColor: Colors.purple
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (iOS) {
                      return SettingsSlider(
                        divisions: 3,
                        max: 5,
                        min: 3,
                        startingVal: ss.settings.maxAvatarsInGroupWidget.value.toDouble(),
                        update: (double val) {
                          ss.settings.maxAvatarsInGroupWidget.value = val.toInt();
                        },
                        onChangeEnd: (double val) {
                          saveSettings();
                        },
                        formatValue: ((double val) => val.toStringAsFixed(0)),
                        backgroundColor: tileColor,
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void saveSettings() {
    ss.saveSettings(ss.settings);
  }
}
