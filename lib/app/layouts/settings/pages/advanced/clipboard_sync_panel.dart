import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ClipboardSyncPanel extends StatefulWidget {
  const ClipboardSyncPanel({super.key});

  @override
  State<StatefulWidget> createState() => _ClipboardSyncPanelState();
}

class _ClipboardSyncPanelState extends State<ClipboardSyncPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Clipboard Sync",
      initialHeader: "Clipboard Sync",
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
                    padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                    child: RichText(
                      text: TextSpan(
                        style: context.theme.textTheme.bodyMedium,
                        children: const [
                          TextSpan(
                            text: "Keeps your clipboard in sync across all connected devices via your "
                                "BlueBubbles server.\n\n",
                          ),
                          TextSpan(
                            text: "iPhone↔Mac sync is handled automatically by Apple Universal Clipboard. "
                                "This setting enables Windows↔Mac sync over your existing server connection. "
                                "iOS devices receive only — they do not send.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Obx(
                    () => SettingsSwitch(
                      onChanged: (bool val) async {
                        ss.settings.enableClipboardSync.value = val;
                        await ss.settings.saveOne('enableClipboardSync');
                        if (val) {
                          ClipboardSyncSvc.start();
                        } else {
                          ClipboardSyncSvc.stop();
                        }
                      },
                      initialVal: ss.settings.enableClipboardSync.value,
                      title: "Enable Clipboard Sync",
                      subtitle: "Sync clipboard text between this device and your Mac server",
                      backgroundColor: tileColor,
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.doc_on_clipboard,
                        materialIcon: Icons.content_paste,
                        containerColor: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
