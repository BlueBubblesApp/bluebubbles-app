import 'dart:io';

import 'package:bluebubbles/app/layouts/settings/pages/advanced/firebase_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/unified_push.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationProvidersPanel extends StatefulWidget {
  const NotificationProvidersPanel({super.key});

  @override
  State<StatefulWidget> createState() => _NotificationProvidersState();
}

class _NotificationProvidersState extends State<NotificationProvidersPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(expressive: true, 
        title: "Notification Providers",
        initialHeader: "Overview",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        headerColor: headerColor,
        tileColor: tileColor,
        bodySlivers: [
          SliverList(
              delegate: SliverChildListDelegate(<Widget>[
            SettingsSection(expressive: true, backgroundColor: tileColor, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 15, left: 15, top: 15, right: 15),
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                          text:
                              "Notification Providers are what allow you to receive notifications from your server. "),
                      const TextSpan(
                          text:
                              "By default, Google Firebase (FCM) will be used, however, you have the option to use other methods. "),
                      const TextSpan(
                          style: TextStyle(fontWeight: FontWeight.bold),
                          text:
                              "While you can use multiple providers, we do not recommend it, and it should not be necessary."),
                    ],
                    style: context.theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ]),
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Providers"),
            SettingsSection(expressive: true, 
              backgroundColor: tileColor,
              children: [
                SettingsTile(
                    title: "Google Firebase (FCM)",
                    subtitle: "Receive notifications using Google Services",
                    onTap: () async {
                      NavigationSvc.pushSettings(
                        context,
                        const FirebasePanel(),
                      );
                    },
                    leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Obx(() => Material(
                          shape: SettingsSvc.settings.skin.value == Skins.Samsung
                              ? SquircleBorder(
                                  side: BorderSide(
                                      color: context.theme.colorScheme.outline.withValues(alpha: 0.5), width: 1.0),
                                )
                              : null,
                          color: Colors.transparent,
                          borderRadius: SettingsSvc.settings.skin.value == Skins.iOS ? BorderRadius.circular(6) : null,
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
                                            color: Colors.grey.withValues(alpha: 0.5),
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
                    trailing: const NextButton()),
                if (Platform.isAndroid) const SettingsDivider(),
                if (Platform.isAndroid)
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.keepAppAlive.value = val;
                          SettingsSvc.settings.customHeaders.value = HttpSvc.headers;
                          await SettingsSvc.settings.saveManyAsync(['keepAppAlive', 'customHeaders']);

                          // We don't need to start the service here because it will be started
                          // when the app is inactive.
                          if (!val) {
                            await MethodChannelSvc.actions.stopForegroundService();
                          }
                        },
                        initialVal: SettingsSvc.settings.keepAppAlive.value,
                        title: "Background Service",
                        subtitle: "Keep an always-open socket connection to the server for notifications",
                        isThreeLine: true,
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                            expressive: true,
                            iosIcon: CupertinoIcons.bolt_badge_a_fill,
                            materialIcon: Icons.bolt,
                            containerColor: Colors.blueAccent),
                      )),
                const SettingsDivider(),
                SettingsTile(
                    title: "Unified Push",
                    subtitle: "Receive notifications using a custom distributor",
                    onTap: () async {
                      NavigationSvc.pushSettings(
                        context,
                        UnifiedPushPanel(),
                      );
                    },
                    leading: const SettingsLeadingIcon(
                      expressive: true,
                      iosIcon: CupertinoIcons.bell_circle,
                      materialIcon: Icons.circle_notifications_outlined,
                      containerColor: Colors.purpleAccent,
                    ),
                    trailing: const NextButton()),
              ],
            ),
          ])),
        ]);
  }
}
