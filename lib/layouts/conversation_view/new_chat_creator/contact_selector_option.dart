import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';

class ContactSelectorOption extends StatelessWidget {
  const ContactSelectorOption({Key key, @required this.item, @required this.onSelected}) : super(key: key);
  final UniqueContact item;
  final Function(UniqueContact item) onSelected;

  String getTypeStr(String type) {
    if (isNullOrEmpty(type)) return "";
    return " ($type)";
  }

  Future<String> get chatParticipants async {
    if (!item.isChat) return "";

    List<String> formatted = [];
    for (var item in item.chat.participants) {
      String contact = ContactManager().getCachedContactSync(item.address)?.displayName;
      if (contact == null) {
        contact = await formatPhoneNumber(item.address);
      }

      if (contact != null) {
        formatted.add(contact);
      }
    }

    return formatted.join(", ");
  }

  @override
  Widget build(BuildContext context) {
    var getTextWidget = (String text) {
      return Text(
        text,
        style: Theme.of(context).textTheme.subtitle1,
        overflow: TextOverflow.ellipsis,
      );
    };

    return ListTile(
      key: new Key("chat-${item.displayName}"),
      onTap: () => onSelected(item),
      title: Text(
        !item.isChat ? "${item.displayName}${getTypeStr(item.label)}" : item.chat.title ?? "Group Chat",
        style: Theme.of(context).textTheme.bodyText1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: (!item.isChat || item.chat.participants.length == 1)
          ? getTextWidget(item?.address ?? item.chat.participants[0]?.address ?? "Person")
          : FutureBuilder(
              future: chatParticipants,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return getTextWidget(item.displayName ?? item.address ?? "Person");
                }

                return getTextWidget(snapshot.data);
              },
            ),
      leading: !item.isChat
          ? ContactAvatarWidget(
              handle: Handle(address: item.address),
              borderThickness: 0.1,
              editable: false,
            )
          : ContactAvatarGroupWidget(
              chat: item.chat,
              participants: item.chat.participants,
              editable: false,
            ),
      trailing: item.isChat
          ? Icon(
              SettingsManager().settings.skin == Skins.iOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
              color: Theme.of(context).primaryColor,
            )
          : null,
    );
  }
}
