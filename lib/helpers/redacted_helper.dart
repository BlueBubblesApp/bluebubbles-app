import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/widgets.dart';

String getContactName(BuildContext context, String? contactTitle, String? contactAddress, {Chat? currentChat}) {
  final bool redactedMode = SettingsManager().settings.redactedMode.value;
  final bool hideInfo = redactedMode && SettingsManager().settings.hideContactInfo.value;
  final bool generateName = redactedMode && SettingsManager().settings.generateFakeContactNames.value;

  String contactName = contactTitle ?? "";
  if (hideInfo || generateName) {
    currentChat = CurrentChat.activeChat?.chat ?? currentChat;
    int index = (currentChat?.participants ?? []).indexWhere((h) => h.address == contactAddress);
    List<String?> fakeNames = currentChat?.fakeParticipants ?? [];
    if (generateName && fakeNames.isNotEmpty) {
      if (index >= 0 && index < fakeNames.length) {
        contactName = currentChat?.fakeParticipants[index] ?? "Fake Name";
      }
    } else if (generateName) {
      contactName = "Fake Name";
    }

    // If the contact name still equals the contact title, override it
    if ((index == -1 && contactName != "Fake Name") || contactName == contactTitle) {
      index = (index < 0) ? 0 : index;
      contactName = "Participant ${index + 1}";
    }
  }

  return contactName;
}
