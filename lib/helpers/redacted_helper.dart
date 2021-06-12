import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/widgets.dart';

String getContactName(BuildContext context, String contactTitle, String contactAddress) {
  final bool redactedMode = SettingsManager()?.settings?.redactedMode ?? false;
  final bool hideInfo = redactedMode && (SettingsManager()?.settings?.hideContactInfo ?? false);
  final bool generateName = redactedMode && (SettingsManager()?.settings?.generateFakeContactNames ?? false);

  String contactName = contactTitle;
  if (hideInfo) {
    Chat currentChat = CurrentChat.of(context)?.chat;
    int index = (currentChat?.participants ?? []).indexWhere((h) => h.address == contactAddress);
    List<String> fakeNames = currentChat?.fakeParticipants ?? [];
    if (generateName) {
      if (index >= 0 && index < fakeNames.length) {
        contactName = currentChat?.fakeParticipants[index];
      }
    }

    // If the contact name still equals the contact title, override it
    if (index == -1 || contactName == contactTitle) {
      index = (index < 0) ? 0 : index;
      contactName = "Participant ${index + 1}";
    }
  }

  return contactName;
}
