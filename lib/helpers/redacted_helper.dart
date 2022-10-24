import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/widgets.dart';

String getContactName(BuildContext context, String? contactTitle, String? contactAddress, {Chat? currentChat}) {
  final bool redactedMode = ss.settings.redactedMode.value;
  final bool hideInfo = redactedMode && ss.settings.hideContactInfo.value;
  final bool generateName = redactedMode && ss.settings.generateFakeContactNames.value;

  String contactName = contactTitle ?? "";
  if (hideInfo || generateName) {
    currentChat = ChatManager().activeChat?.chat ?? currentChat;
    int index = (currentChat?.participants ?? []).indexWhere((h) => h.address == contactAddress);
    List<String> fakeNames = currentChat?.participants.map((e) => e.fakeName).toList() ?? [];
    if (generateName && fakeNames.isNotEmpty) {
      if (index >= 0 && index < fakeNames.length) {
        contactName = fakeNames[index];
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
