import 'dart:async';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class UnifiedPushPanelController extends StatefulController {
  final state = upr;
}

class UnifiedPushPanel extends CustomStateful<UnifiedPushPanelController> {
  UnifiedPushPanel()
      : super(parentController: Get.put(UnifiedPushPanelController()));

  @override
  State<UnifiedPushPanel> createState() => _UnifiedPushPanelState();
}

class _UnifiedPushPanelState
    extends CustomState<UnifiedPushPanel, void, UnifiedPushPanelController> {
  final RxBool enabled = ss.settings.enableUnifiedPush;
  final RxString endpoint = ss.settings.endpointUnifiedPush;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
        title: "Unified Push",
        initialHeader: "Overview",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        headerColor: headerColor,
        tileColor: tileColor,
        bodySlivers: [
          SliverList(
              delegate: SliverChildListDelegate(<Widget>[
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
                                "Unified Push allows you to receive notifications without Firebase or the background service. "),
                        const TextSpan(
                            text:
                                "All you need is a distributor. You can self-host your own distributor or use a third-party service.",),
                      ],
                      style: context.theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ]
            ),
            SettingsHeader(
              iosSubtitle: iosSubtitle,
              materialSubtitle: materialSubtitle,
              text: "Recommendation"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 8, left: 15, top: 15, right: 15),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(text: "We recommend using "),
                        const TextSpan(text: "nfty.sh", style: TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(
                            text:
                                ", as it is free and easy to setup. They also have an Android App that will integrate directly with BlueBubbles. "),
                        const TextSpan(
                            text:
                                "Simply install the app, then come back here and enable Unified Push. The integration will automatically create a subscriber for you, which you can use as a Webhook in the BlueBubbles Server."),
                      ],
                      style: context.theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                SettingsTile(
                  title: "ntfy.sh",
                  subtitle: "Tap to download ntfy from Google Play",
                  onTap: () async {
                    final params = { "id": "io.heckel.ntfy" };
                    await launchUrl(Uri(scheme: "https", host: "play.google.com", path: "store/apps/details", queryParameters: params), mode: LaunchMode.externalApplication);
                  },
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.arrow_up_right,
                    materialIcon: Icons.arrow_outward,
                    containerColor: Colors.blueAccent,
                  ),
                ),
              ]
            ),
            SettingsHeader(
              iosSubtitle: iosSubtitle,
              materialSubtitle: materialSubtitle,
              text: "Unified Push"),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Obx(() {
                  final _enabled = enabled.value;
                  return SettingsSwitch(
                    onChanged: onChanged,
                    initialVal: _enabled,
                    title: "Enable Unified Push",
                    backgroundColor: tileColor,
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.bell_circle,
                      materialIcon: Icons.circle_notifications_outlined,
                      containerColor: Colors.purpleAccent,
                    )
                  );
                }),
              ],
            ),
            Obx(() {
              final _registered = endpoint.value != "";
              return AnimatedSizeAndFade.showHide(
                show: _registered,
                child: Column(children: [
                  SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Unified Push Settings"),
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 8.0, left: 15, top: 8.0, right: 15),
                        child: Obx(() {
                          final _endpoint = endpoint.value;
                          return Text(
                              "To complete setup, use the Registration Topic in your distributor with the Blue Bubbles Server's Webhook setting. \n\n"
                              "$_endpoint",
                              style: context.theme.textTheme.bodyMedium);
                        }),
                      ),
                    ],
                  )
                ]),
              );
            }),
          ])),
        ]);
  }

  void onChanged(bool val) async {
    StreamSubscription<String>? sub;
    sub = controller.state.endpoint.listen((val) {
        setState(() {
            endpoint.value = val;
        });
        sub?.cancel();
        sub = null;
    });
    ss.settings.enableUnifiedPush.value = val;
    if (val) {
      await mcs.invokeMethod("UnifiedPushHandler", {"operation": "register"});
    } else {
      await mcs.invokeMethod("UnifiedPushHandler", {"operation": "unregister"});
      ss.settings.endpointUnifiedPush.value = "";
    }
    ss.saveSettings();
  }
}
