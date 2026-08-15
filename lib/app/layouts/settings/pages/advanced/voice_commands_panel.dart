import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VoiceCommandsPanel extends StatefulWidget {
  const VoiceCommandsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _VoiceCommandsPanelState();
}

class _VoiceCommandsPanelState extends State<VoiceCommandsPanel> with ThemeHelpers {
  static const List<String> _examplePhrases = [
    '"Hey Google, send a BlueBubbles message to Mom"',
    '"Hey Google, send a message to Mom on BlueBubbles"',
    '"Hey Google, send a BlueBubbles message to Mom saying I\'m on my way"',
  ];

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Voice Commands",
      initialHeader: "How It Works",
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                    child: Text(
                      "You can ask your phone's assistant to send a message for you. BlueBubbles matches the name "
                      "you say against your existing conversations, then either opens the chat or asks you to "
                      "confirm before sending.\n\n"
                      "Voice commands only work with conversations you already have. If nothing matches the name "
                      "you said, BlueBubbles tells you instead of guessing — start the chat in the app first.",
                    ),
                  ),
                ],
              ),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Try Saying"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _examplePhrases
                          .map(
                            (phrase) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(phrase, style: context.theme.textTheme.bodyMedium),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Sending"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.voiceCommandAutoSend.value = val;
                        await SettingsSvc.settings.saveOneAsync('voiceCommandAutoSend');
                      },
                      initialVal: SettingsSvc.settings.voiceCommandAutoSend.value,
                      title: "Send Without Confirming",
                      subtitle: "Send immediately when the command already includes the message. "
                          "Leave this off if you'd rather review what was heard first.",
                      backgroundColor: tileColor,
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
