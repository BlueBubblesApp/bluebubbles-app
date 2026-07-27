import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskerPanel extends StatefulWidget {
  const TaskerPanel({super.key});

  @override
  State<StatefulWidget> createState() => _TaskerPanelState();
}

class _TaskerPanelState extends State<TaskerPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(expressive: true, 
        title: "Tasker Integration",
        initialHeader: "Integration Details",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                SettingsSection(expressive: true, 
                  backgroundColor: tileColor,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                      child: Text(
                        "BlueBubbles has the ability to integrate with Tasker. Fetch your server URL from Tasker or send server events to Tasker to use in your integrations! If you've made something cool, feel free to share it on our Discord!",
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Tasker Integration Details",
                      subtitle: "View more details on how to create Tasker integrations with BlueBubbles",
                      isThreeLine: true,
                      onTap: () async {
                        await launchUrl(
                            Uri(
                                scheme: "https",
                                host: "docs.bluebubbles.app",
                                path: "client/usage-guides/tasker-integration"),
                            mode: LaunchMode.externalApplication);
                      },
                      leading: const SettingsLeadingIcon(
                        expressive: true,
                        iosIcon: CupertinoIcons.info_circle,
                        materialIcon: Icons.info_outline,
                        containerColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
                SettingsHeader(
                    iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Integration Settings"),
                SettingsSection(expressive: true, 
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.sendEventsToTasker.value = val;
                            await SettingsSvc.settings.saveOneAsync('sendEventsToTasker');
                          },
                          initialVal: SettingsSvc.settings.sendEventsToTasker.value,
                          title: "Send Events to Tasker",
                          subtitle: "Send events emitted by the server to Tasker via Intent broadcasts",
                          backgroundColor: tileColor,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ]);
  }
}
