import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_mixin.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';

class ContactSelectorOption extends StatelessWidget {
  const ContactSelectorOption(
      {Key key, @required this.item, @required this.onSelected})
      : super(key: key);
  final UniqueContact item;
  final Function(UniqueContact item) onSelected;

  String getTypeStr(String type) {
    if (isNullOrEmpty(type)) return "";
    return " ($type)";
  }

  String get chatParticipants {
    if (!item.isChat) return "";

    List<String> participants = item.chat.participants
        .map((e) =>
            ContactManager().getCachedContactSync(e.address)?.displayName ??
            formatPhoneNumber(e.address))
        .toList();
    return participants.join(", ");
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: new Key("chat-${item.displayName}"),
      onTap: () => onSelected(item),
      title: Text(
        !item.isChat
            ? "${item.displayName}${getTypeStr(item.label)}"
            : item.chat.title,
        style: Theme.of(context).textTheme.bodyText1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        !item.isChat ? item.address : chatParticipants,
        style: Theme.of(context).textTheme.subtitle1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: !item.isChat
          ? ContactAvatarWidget(
              handle: Handle(address: item.address),
            )
          : ContactAvatarGroupWidget(
              chat: item.chat,
              participants: item.chat.participants,
            ),
      trailing: item.isChat
          ? Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).primaryColor,
            )
          : null,
    );
  }
}
