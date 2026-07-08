import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_ios.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_material.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_samsung.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_shared.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';

class ParticipantsFindMyMapCard extends StatelessWidget {
  final Chat chat;

  const ParticipantsFindMyMapCard({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return ParticipantsFindMyMapCardScaffold(
      chat: chat,
      builder: (context, vm) => ThemeSwitcher(
        iOSSkin: ParticipantsFindMyMapCardIOS(vm: vm),
        materialSkin: ParticipantsFindMyMapCardMaterial(vm: vm),
        samsungSkin: ParticipantsFindMyMapCardSamsung(vm: vm),
      ),
    );
  }
}
