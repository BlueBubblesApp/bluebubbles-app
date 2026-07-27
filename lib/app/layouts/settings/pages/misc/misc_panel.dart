import 'package:bluebubbles/helpers/types/classes/language_codes.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
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
  const MiscPanel({super.key});

  @override
  State<StatefulWidget> createState() => _MiscPanelState();
}

class _MiscPanelState extends State<MiscPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(expressive: true, 
      title: "Advanced",
      initialHeader: (!kIsWeb && !kIsDesktop) || SettingsSvc.canAuthenticate ? "Security" : "Speed & Responsiveness",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              if (!kIsWeb && !(kIsDesktop && !Platform.isWindows))
                SettingsSection(expressive: true, 
                  backgroundColor: tileColor,
                  children: [
                    if (SettingsSvc.canAuthenticate)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                localizedReason:
                                    'Please authenticate to ${val == true ? "enable" : "disable"} security',
                                persistAcrossBackgrounding: true,
                              );
                              if (didAuthenticate) {
                                SettingsSvc.settings.shouldSecure.value = val;
                                if (val == false) {
                                  SecureApplicationProvider.of(context, listen: false)!.open();
                                } else if (SettingsSvc.settings.securityLevel.value ==
                                    SecurityLevel.locked_and_secured) {
                                  SecureApplicationProvider.of(context, listen: false)!.secure();
                                }
                                await SettingsSvc.settings.saveOneAsync('shouldSecure');
                              }
                            },
                            initialVal: SettingsSvc.settings.shouldSecure.value,
                            title: "Secure App",
                            subtitle: "Secure app with ${kIsDesktop ? "Windows Security" : "a fingerprint or pin"}",
                            backgroundColor: tileColor,
                            leading: SettingsLeadingIcon(
                                expressive: true,
                                iosIcon: CupertinoIcons.lock_fill,
                                materialIcon: Icons.lock,
                                containerColor:
                                    (SettingsSvc.settings.shouldSecure.value) ? Colors.green : Colors.redAccent),
                          )),
                    if (SettingsSvc.canAuthenticate)
                      Obx(() {
                        if (SettingsSvc.settings.shouldSecure.value) {
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
                                        .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ));
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    if (SettingsSvc.canAuthenticate && !kIsDesktop)
                      Obx(() {
                        if (SettingsSvc.settings.shouldSecure.value) {
                          return SettingsOptions<SecurityLevel>(
                            initial: SettingsSvc.settings.securityLevel.value,
                            onChanged: (val) async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                localizedReason: 'Please authenticate to change your security level',
                                persistAcrossBackgrounding: true,
                              );
                              if (didAuthenticate) {
                                if (val != null) {
                                  SettingsSvc.settings.securityLevel.value = val;
                                  if (val == SecurityLevel.locked_and_secured) {
                                    SecureApplicationProvider.of(context, listen: false)!.secure();
                                  } else {
                                    SecureApplicationProvider.of(context, listen: false)!.open();
                                  }
                                }
                                await SettingsSvc.settings.saveOneAsync('securityLevel');
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
                    if (SettingsSvc.canAuthenticate && !kIsDesktop) const SettingsDivider(),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.incognitoKeyboard.value = val;
                              await SettingsSvc.settings.saveOneAsync('incognitoKeyboard');
                            },
                            initialVal: SettingsSvc.settings.incognitoKeyboard.value,
                            title: "Incognito Keyboard",
                            subtitle:
                                "Disables keyboard suggestions and prevents the keyboard from learning or storing any words you type in the message text field",
                            isThreeLine: true,
                            backgroundColor: tileColor,
                            leading: const SettingsLeadingIcon(
                                expressive: true,
                                iosIcon: CupertinoIcons.keyboard,
                                materialIcon: Icons.keyboard,
                                containerColor: Colors.teal),
                          )),
                  ],
                ),
              if (!kIsWeb && !kIsDesktop || SettingsSvc.canAuthenticate)
                SettingsHeader(
                    iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Speed & Responsiveness"),
              Obx(() => SettingsSection(expressive: true,
                backgroundColor: tileColor,
                children: [
                  SettingsSwitch(
                    onChanged: (bool val) async {
                      SettingsSvc.settings.highPerfMode.value = val;
                      await SettingsSvc.settings.saveOneAsync('highPerfMode');
                    },
                    initialVal: SettingsSvc.settings.highPerfMode.value,
                    title: "High Performance Mode",
                    subtitle: "Removes inline images and videos to boost performance on lower-end devices",
                    isThreeLine: true,
                    backgroundColor: tileColor,
                    leading: const SettingsLeadingIcon(
                        expressive: true,
                        iosIcon: CupertinoIcons.speedometer,
                        materialIcon: Icons.speed_outlined,
                        containerColor: Colors.green),
                  ),
                  if (kIsDesktop) const SettingsDivider(),
                  if (kIsDesktop)
                    SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.reduceMotion.value = val;
                        await SettingsSvc.settings.saveOneAsync('reduceMotion');
                      },
                      initialVal: SettingsSvc.settings.reduceMotion.value,
                      title: "Reduce Motion",
                      subtitle: "Keeps GIFs paused until you hover over them",
                      isThreeLine: true,
                      backgroundColor: tileColor,
                      leading: const SettingsLeadingIcon(
                          expressive: true,
                          iosIcon: CupertinoIcons.pause_circle,
                          materialIcon: Icons.motion_photos_pause_outlined,
                          containerColor: Colors.blue),
                    ),
                  if (iOS) const SettingsDivider(),
                  if (iOS)
                    const SettingsTile(
                      title: "Scroll Speed Multiplier",
                      subtitle: "Controls how fast scrolling occurs",
                      isThreeLine: true,
                      leading: SettingsLeadingIcon(
                          expressive: true,
                          iosIcon: CupertinoIcons.arrow_up_down_square,
                          materialIcon: Icons.mouse_outlined,
                          containerColor: Colors.orange),
                    ),
                  if (iOS)
                    SettingsSlider(
                        startingVal: SettingsSvc.settings.scrollVelocity.value,
                        update: (double val) {
                          SettingsSvc.settings.scrollVelocity.value = double.parse(val.toStringAsFixed(2));
                        },
                        onChangeEnd: (double val) async {
                          await SettingsSvc.settings.saveOneAsync('scrollVelocity');
                        },
                        formatValue: ((double val) => val.toStringAsFixed(2)),
                        backgroundColor: tileColor,
                        min: 0.20,
                        max: 1,
                        divisions: 8),
                ],
              )),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Networking"),
              SettingsSection(expressive: true, 
                backgroundColor: tileColor,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => SettingsTile(
                            title: "API Timeout Duration",
                            subtitle:
                                "Controls the duration (in seconds) until a network request will time out.\nIncrease this setting if you have poor connection.",
                            leading: const SettingsLeadingIcon(
                                expressive: true,
                                iosIcon: CupertinoIcons.stopwatch,
                                materialIcon: Icons.timer,
                                containerColor: Colors.red),
                            trailing: SettingsSvc.settings.apiTimeout.value != 30000
                                ? ElevatedButton(
                                    onPressed: () async {
                                      SettingsSvc.settings.apiTimeout.value = 30000;
                                      await SettingsSvc.settings.saveOneAsync('apiTimeout');
                                    },
                                    child: const Text("Reset"),
                                  )
                                : null,
                          )),
                      Obx(() => SettingsSlider(
                          startingVal: SettingsSvc.settings.apiTimeout.value / 1000,
                          update: (double val) {
                            SettingsSvc.settings.apiTimeout.value = val.toInt() * 1000;
                          },
                          onChangeEnd: (double val) async {
                            await SettingsSvc.settings.saveOneAsync('apiTimeout');
                            HttpSvc.dio = Dio(BaseOptions(
                              connectTimeout: Duration(milliseconds: SettingsSvc.settings.apiTimeout.value),
                              receiveTimeout: Duration(milliseconds: SettingsSvc.settings.apiTimeout.value),
                              sendTimeout: Duration(milliseconds: SettingsSvc.settings.apiTimeout.value),
                            ));
                            HttpSvc.dio.interceptors.add(ApiInterceptor());
                          },
                          backgroundColor: tileColor,
                          min: 5,
                          max: 60,
                          divisions: 11)),
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: Obx(() => Text(
                              "Note: Attachment uploads will timeout after ${SettingsSvc.settings.apiTimeout.value ~/ 1000 * 12} seconds",
                              style: context.theme.textTheme.bodySmall!
                                  .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                            )),
                      ),
                    ],
                  ),
                  const SettingsDivider(padding: EdgeInsets.zero),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.cancelQueuedMessages.toggle();
                          await SettingsSvc.settings.saveOneAsync('cancelQueuedMessages');
                        },
                        initialVal: SettingsSvc.settings.cancelQueuedMessages.value,
                        title: "Cancel Queued Messages on Failure",
                        subtitle: "Cancel messages queued to send in a chat if one fails before them",
                        backgroundColor: tileColor,
                        isThreeLine: true,
                        leading: const SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.hand_raised,
                            materialIcon: Icons.back_hand_outlined,
                            containerColor: Colors.orange),
                      )),
                ],
              ),
              SettingsHeader(
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Other",
              ),
              SettingsSection(expressive: true, 
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.replaceEmoticonsWithEmoji.value = val;
                          await SettingsSvc.settings.saveOneAsync('replaceEmoticonsWithEmoji');
                        },
                        initialVal: SettingsSvc.settings.replaceEmoticonsWithEmoji.value,
                        title: "Replace Emoticons with Emoji",
                        subtitle: "Replace emoticons like :), :D, etc. with their corresponding emojis",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.smiley,
                            materialIcon: Icons.emoji_emotions_outlined,
                            containerColor: Colors.indigo),
                      )),
                  const SettingsDivider(),
                  if (kIsDesktop || kIsWeb)
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.spellcheck.value = val;
                            await SettingsSvc.settings.saveOneAsync('spellcheck');
                          },
                          initialVal: SettingsSvc.settings.spellcheck.value,
                          title: "Enable Spellcheck",
                          backgroundColor: tileColor,
                          leading: const SettingsLeadingIcon(
                              expressive: true,
                              iosIcon: CupertinoIcons.textformat_abc_dottedunderline,
                              materialIcon: Icons.spellcheck_outlined,
                              containerColor: Colors.cyan),
                        )),
                  if (kIsDesktop || kIsWeb)
                    Obx(() => SettingsSvc.settings.spellcheck.value
                        ? SettingsOptions<(String, String)>(
                            useCupertino: false,
                            onChanged: (val) async {
                              if (val == null) return;
                              SettingsSvc.settings.spellcheckLanguage.value = val.$2;
                              await SettingsSvc.settings.saveOneAsync('spellcheckLanguage');
                            },
                            initial: languageNameAndCodes
                                    .firstWhereOrNull((l) => l.$2 == SettingsSvc.settings.spellcheckLanguage.value) ??
                                ("Auto", "auto"),
                            options: [("Auto", "auto"), ...languageNameAndCodes],
                            title: 'Spellcheck Language',
                            textProcessing: (val) => val.$1,
                            capitalize: false,
                          )
                        : const SizedBox.shrink()),
                  if (kIsDesktop || kIsWeb) const SettingsDivider(),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.sendDelay.value = val ? 3 : 0;
                          await SettingsSvc.settings.saveOneAsync('sendDelay');
                        },
                        initialVal: !isNullOrZero(SettingsSvc.settings.sendDelay.value),
                        title: "Send Delay",
                        subtitle:
                            "Adds a delay before sending a message to prevent accidental sends. During this time, you can cancel the message.",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.timer, materialIcon: Icons.timer, containerColor: Colors.green),
                      )),
                  Obx(() {
                    if (!isNullOrZero(SettingsSvc.settings.sendDelay.value)) {
                      return SettingsSlider(
                          startingVal: SettingsSvc.settings.sendDelay.toDouble(),
                          update: (double val) {
                            SettingsSvc.settings.sendDelay.value = val.toInt();
                          },
                          onChangeEnd: (double val) async {
                            await SettingsSvc.settings.saveOneAsync('sendDelay');
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
                        onChanged: (bool val) async {
                          SettingsSvc.settings.use24HrFormat.value = val;
                          await SettingsSvc.settings.saveOneAsync('use24HrFormat');
                        },
                        initialVal: SettingsSvc.settings.use24HrFormat.value,
                        title: "Use 24 Hour Format for Times",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.clock,
                            materialIcon: Icons.access_time,
                            containerColor: Colors.blue),
                      )),
                  const SettingsDivider(),
                  if (Platform.isAndroid)
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.allowUpsideDownRotation.value = val;
                            await SettingsSvc.settings.saveOneAsync('allowUpsideDownRotation');
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.landscapeRight,
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.portraitUp,
                              if (SettingsSvc.settings.allowUpsideDownRotation.value) DeviceOrientation.portraitDown,
                            ]);
                          },
                          initialVal: SettingsSvc.settings.allowUpsideDownRotation.value,
                          title: "Allow Upside-Down Rotation",
                          backgroundColor: tileColor,
                          leading: const SettingsLeadingIcon(
                              expressive: true,
                              iosIcon: CupertinoIcons.rotate_right,
                              materialIcon: Icons.screen_rotation,
                              containerColor: Colors.orange),
                        )),
                  if (Platform.isAndroid) const SettingsDivider(),
                  Obx(() {
                    if (iOS) {
                      return const SettingsTile(
                        title: "Maximum Group Avatar Count",
                        subtitle: "Controls the maximum number of contact avatars in a group chat's widget",
                        isThreeLine: true,
                        leading: SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.person_2,
                            materialIcon: Icons.people,
                            containerColor: Colors.purple),
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
                        startingVal: SettingsSvc.settings.maxAvatarsInGroupWidget.value.toDouble(),
                        update: (double val) {
                          SettingsSvc.settings.maxAvatarsInGroupWidget.value = val.toInt();
                        },
                        onChangeEnd: (double val) async {
                          await SettingsSvc.settings.saveOneAsync('maxAvatarsInGroupWidget');
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
}
