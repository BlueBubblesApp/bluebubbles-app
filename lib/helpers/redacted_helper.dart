import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/widgets.dart';

String getContactName(BuildContext context, String? contactTitle, String? contactAddress, {Chat? currentChat}) {
  final bool redactedMode = settings.settings.redactedMode.value;
  final bool hideInfo = redactedMode && settings.settings.hideContactInfo.value;
  final bool generateName = redactedMode && settings.settings.generateFakeContactNames.value;

  String contactName = contactTitle ?? "";
  if (hideInfo || generateName) {
    currentChat = ChatManager().activeChat?.chat ?? currentChat;
    int index = (currentChat?.participants ?? []).indexWhere((h) => h.address == contactAddress);
    List<String> fakeNames = currentChat?.fakeNames ?? [];
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
