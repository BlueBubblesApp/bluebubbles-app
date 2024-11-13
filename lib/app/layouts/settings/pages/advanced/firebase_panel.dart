
import 'dart:io';

import 'package:bluebubbles/app/layouts/settings/pages/server/oauth_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class FirebasePanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _FirebasePanelState();
}

class _FirebasePanelState extends OptimizedState<FirebasePanel> {

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
        title: "Google Firebase",
        initialHeader: "Overview",
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
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 8, left: 15, top: 15, right: 15),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text:
                                    "BlueBubbles' main notification provider is Google Firebase, utilizing Firebase Cloud Messaging (FCM). "),
                            const TextSpan(
                                text:
                                    "The server has an automated set up process built-in to make it easy to get set up with your very own Firebase Project.",),
                          ],
                          style: context.theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 8, left: 15, top: 0, right: 15),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text:
                                    "Use this page to manage your Firebase configurations. "),
                          ],
                          style: context.theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Open Firebase Console",
                      subtitle: "${kIsDesktop || kIsWeb ? 'Click' : 'Tap'} to open the Firebase Console. Login to view your Firebase Project.",
                      isThreeLine: true,
                      onTap: () async {
                        await launchUrl(Uri(scheme: "https", host: "console.firebase.google.com"), mode: LaunchMode.externalApplication);
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.arrow_up_right,
                        materialIcon: Icons.arrow_outward_outlined,
                        containerColor: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Firebase Cloud Messaging"
                ),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      return SettingsTile(
                        backgroundColor: tileColor,
                        title: "Firebase Status",
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _enabled ? "Configured" : "Not Configured",
                              style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withOpacity(0.85)),
                            )
                          ]
                        ),
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.settings,
                          materialIcon: Icons.settings,
                          containerColor:
                              _enabled
                                  ? Colors.green
                                  : Colors.redAccent,
                        )
                      );
                    }),
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull && socket.socket.connected;
                      if (_enabled) return const SizedBox.shrink();
                      return const SettingsDivider();
                    }),
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull && socket.socket.connected;
                      if (_enabled) return const SizedBox.shrink();

                      return SettingsTile(
                        backgroundColor: tileColor,
                        title: "Load Configurations from Server",
                        subtitle: 'Download Firebase configurations directly from your server.',
                        trailing: Obx(() => ss.settings.skin.value != Skins.Material ? Icon(
                            ss.settings.skin.value != Skins.Material
                                ? CupertinoIcons.refresh
                                : Icons.refresh,
                            color: context.theme.colorScheme.outline.withOpacity(0.5),
                            size: 18,
                          ) : const SizedBox.shrink()),
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.cloud_download,
                          materialIcon: Icons.download,
                        ),
                        onTap: () async {
                          RxBool isLoading = RxBool(true);
                          RxnString error = RxnString(null);
                          Future.delayed(Duration.zero, () async {
                            try {
                              bool hasConfigs = await fdb.fetchFirebaseConfig();
                              if (hasConfigs) {
                                await fcm.registerDevice();
                              } else {
                                error.value = "Firebase not configured on the server!";
                              }
                            } catch (e) {
                              Logger.error("Error loading Firebase Configurations: ${e.toString()}");
                            } finally {
                              isLoading.value = false;
                            }
                          });

                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                title: Obx(() => Text(
                                  error.value != null ? "Error!" : isLoading.value ? "Loading..." : "Done!", style: context.theme.textTheme.titleLarge)),
                                content: Obx(() {
                                  if (isLoading.value) {
                                    return Container(
                                      height: 70,
                                      width: 70,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Text(
                                      error.value ?? "Successfully loaded Firebase Configurations!",
                                      style: context.theme.textTheme.bodyLarge,
                                    );
                                  }
                                }),
                                actions: <Widget>[
                                  Obx(() => (isLoading.value == true)
                                      ? const SizedBox.shrink()
                                      : TextButton(
                                          child: Text("Close",
                                              style: context.theme.textTheme.bodyLarge!
                                                  .copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                  ),
                                ]
                              );
                            },
                          );

                          await fdb.fetchFirebaseConfig();
                          await fcm.registerDevice();
                        },
                      );
                    }),
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      if (_enabled && !isSnap) return const SizedBox.shrink();
                      return const SettingsDivider();
                    }),
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      if (_enabled && !isSnap) return const SizedBox.shrink();

                      return SettingsTile(
                        leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Obx(() => Material(
                              shape: ss.settings.skin.value == Skins.Samsung
                                  ? SquircleBorder(
                                      side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.5), width: 1.0),
                                    )
                                  : null,
                              color: Colors.transparent,
                              borderRadius: ss.settings.skin.value == Skins.iOS ? BorderRadius.circular(6) : null,
                              child: SizedBox(
                                  width: 31,
                                  height: 31,
                                  child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.5),
                                              blurRadius: 0,
                                              spreadRadius: 0.5,
                                              offset: const Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.asset("assets/images/google-sign-in.png",
                                              width: 33, fit: BoxFit.contain)))))))
                        ]),
                        title: "Load Configurations from Google",
                        subtitle: "Sign in with Google to load your Firebase configurations.",
                        backgroundColor: tileColor,
                        onTap: () {
                          ns.pushSettings(context, OauthPanel());
                        },
                        trailing: const NextButton()
                      );
                    }),
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      if (!_enabled) return const SizedBox.shrink();
                      return const SettingsDivider();
                    }),
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      if (!_enabled) return const SizedBox.shrink();

                      return SettingsTile(
                        backgroundColor: tileColor,
                        title: "Re-register Device with Server",
                        trailing: Obx(() => ss.settings.skin.value != Skins.Material ? Icon(
                            ss.settings.skin.value != Skins.Material
                                ? CupertinoIcons.refresh
                                : Icons.refresh_outlined,
                            color: context.theme.colorScheme.outline.withOpacity(0.5),
                            size: 18,
                          ) : const SizedBox.shrink()),
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.device_phone_portrait,
                          materialIcon: Icons.devices,
                        ),
                        onTap: () async {
                          try {
                            await fcm.registerDevice();
                            showSnackbar("Device Registered", "Successfully re-registered device with server!");
                          } catch (e, s) {
                            Logger.error("Failed to re-register device with server", error: e, trace: s);
                            showSnackbar("Error", "Failed to re-register device with server! Error: ${e.toString()}");
                          }
                        },
                      );
                    })
                  ],
                ),
                Obx(() {
                  final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                  if (!_enabled) return const SizedBox.shrink();
                  return SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Project Details"
                  );
                }),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      if (!_enabled) return const SizedBox.shrink();
                      return Container(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 22, top: 8.0, right: 15),
                          child: SelectableText.rich(
                              TextSpan(children: [
                                const TextSpan(text: "Project ID: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ss.fcmData.projectID!),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: "App ID: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ss.fcmData.applicationID!),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: "Firebase URL: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ss.fcmData.firebaseURL ?? "N/A"),

                              ]),
                          )
                        )
                      );
                    }),
                  ],
                ),
                Obx(() {
                  final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                  if (!_enabled) return const SizedBox.shrink();
                  return SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Danger Zone"
                  );
                }),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() {
                      final _enabled = ss.settings.firstFcmRegisterDate.value != 0 && !ss.fcmData.isNull;
                      if (!_enabled) return const SizedBox.shrink();

                      return SettingsTile(
                        backgroundColor: tileColor,
                        title: "Clear Configurations",
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Tap to Clear",
                              style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withOpacity(0.85)),
                            )
                          ]
                        ),
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.trash,
                          materialIcon: Icons.delete,
                          containerColor: Colors.redAccent,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                title: Text("Are You Sure?", style: context.theme.textTheme.titleLarge),
                                content: Text(
                                  'This will remove all Firebase configurations from the app. You will no longer receive notifications or Server URL updates from Firebase and you will need to re-register your device if you want to use Firebase again. This will also close the app. Are you sure you want to continue?',
                                  style: context.theme.textTheme.bodyLarge,
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Cancel",
                                        style: context.theme.textTheme.bodyLarge!
                                            .copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Yes",
                                        style: context.theme.textTheme.bodyLarge!
                                            .copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () async {
                                      // Clear the FCM data from the database, shared preferences, and locally
                                      await FCMData.deleteFcmData();

                                      // Delete the Firebase FCM token
                                      try {
                                        if (fcm.token != null) {
                                          await mcs.invokeMethod("firebase-delete-token");
                                        }
                                      } catch (e, s) {
                                        Logger.error("Failed to delete Firebase FCM token", error: e, trace: s);
                                      }

                                      ss.settings.firstFcmRegisterDate.value = 0;
                                      await ss.settings.saveOne('firstFcmRegisterDate');
                                      exit(0);
                                    },
                                  ),
                                ]
                              );
                            },
                          );
                        }
                      );
                    }),
                  ],
                )
              ],
            ),
          ),
        ]
    );
  }
}
