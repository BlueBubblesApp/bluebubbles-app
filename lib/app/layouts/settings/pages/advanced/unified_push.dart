import 'dart:async';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        initialHeader: "Unified Push",
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
                      bottom: 8.0, left: 15, top: 8.0, right: 15),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                            text:
                                "Unified Push allows you to receive notifications without FCM."),
                      ],
                      style: context.theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                Obx(() {
                  final _enabled = enabled.value;
                  return SettingsSwitch(
                    onChanged: onChanged,
                    initialVal: _enabled,
                    title: "Enable Unified Push",
                    backgroundColor: tileColor,
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
