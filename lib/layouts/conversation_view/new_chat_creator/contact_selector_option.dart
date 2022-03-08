import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactSelectorOption extends StatelessWidget {
  const ContactSelectorOption({Key? key, required this.item, required this.onSelected, required this.index, this.shouldShowChatType = false})
      : super(key: key);
  final UniqueContact item;
  final Function(UniqueContact item) onSelected;
  final int index;
  final bool shouldShowChatType;

  String getTypeStr(String? type) {
    if (isNullOrEmpty(type)!) return "";
    return " ($type)";
  }

  Future<String> get chatParticipants async {
    if (!item.isChat) return "";

    List<String> formatted = [];
    for (var item in item.chat!.participants) {
      String? contact = ContactManager().getContact(item.address)?.displayName;
      contact ??= await formatPhoneNumber(item);

      formatted.add(contact);
    }

    return formatted.join(", ");
  }

  FutureBuilder<String> formattedNumberFuture(dynamic item) {
    String address = '';
    if (item is String) {
      address = item;
    } else if (item is Handle) {
      address = item.address;
    }

    return FutureBuilder<String>(
        future: formatPhoneNumber(item),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return getTextWidget(context, address);
          }

          return getTextWidget(context, snapshot.data);
        });
  }

  Widget getTextWidget(BuildContext context, String? text) {
    return TextOneLine(
      text!,
      style: Theme.of(context).textTheme.subtitle1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool redactedMode = SettingsManager().settings.redactedMode.value;
    final bool hideInfo = redactedMode && SettingsManager().settings.hideContactInfo.value;
    final bool generateName = redactedMode && SettingsManager().settings.generateFakeContactNames.value;
    String title = "";
    if (generateName) {
      if (item.isChat) {
        title = item.chat!.fakeNames.length == 1 ? item.chat!.fakeNames[0] : "Group Chat";
      } else {
        title = "Person ${index + 1}";
      }
    } else if (!hideInfo) {
      if (item.isChat) {
        title = item.chat!.title ?? "Group Chat";
      } else {
        title = "${item.displayName}${getTypeStr(item.label)}";
      }
    }

    Widget subtitle;
    if (redactedMode) {
      subtitle = getTextWidget(context, "");
    } else if (!item.isChat || item.chat!.participants.length == 1) {
      if (item.address != null) {
        if (!item.address!.isEmail) {
          subtitle = formattedNumberFuture(item);
        } else {
          subtitle = getTextWidget(context, item.address);
        }
      } else if (item.chat != null && !item.chat!.participants[0].address.isEmail) {
        subtitle = formattedNumberFuture(item.chat!.participants[0]);
      } else if (item.chat!.participants[0].address.isEmail) {
        subtitle = getTextWidget(context, item.chat!.participants[0].address);
      } else {
        subtitle = getTextWidget(context, "Person ${index + 1}");
      }
    } else {
      subtitle = FutureBuilder<String>(
        future: chatParticipants,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return getTextWidget(context, item.displayName ?? item.address ?? "Person ${index + 1}");
          }

          return getTextWidget(context, snapshot.data);
        },
      );
    }

    return Container(
      color: SettingsManager().settings.skin.value == Skins.Samsung ? Theme.of(context).colorScheme.secondary : null,
      child: ListTile(
        key: Key("chat-${item.displayName}"),
        onTap: () => onSelected(item),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyText1,
          overflow: TextOverflow.ellipsis,
        ),
        tileColor: SettingsManager().settings.skin.value == Skins.Samsung ? null : Theme.of(context).backgroundColor,
        subtitle: subtitle,
        leading: !item.isChat
            ? ContactAvatarWidget(
                key: Key("${item.address}-contact-selector-option"),
                handle: Handle(address: item.address!),
                borderThickness: 0.1,
                editable: false,
              )
            : ContactAvatarGroupWidget(
                chat: item.chat!,
                editable: false,
              ),
        trailing: item.isChat
            ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (shouldShowChatType)
                  Padding(
                    padding: const EdgeInsets.only(right: 5.0),
                    child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          border: Border.all(
                              color: item.chat!.isIMessage ? Theme.of(context).primaryColor : Colors.green
                          ),
                        ),
                        child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                            child: Text(
                                item.chat!.isIMessage ? "iMessage" : "SMS",
                                style: TextStyle(color: item.chat!.isIMessage ? Theme.of(context).primaryColor : Colors.green)
                            )
                        )
                    ),
                  ),
                Icon(
                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.forward : Icons.arrow_forward,
                    color: shouldShowChatType && !item.chat!.isIMessage ? Colors.green : Theme.of(context).primaryColor,
                  ),
              ],
            )
            : null,
      ),
    );
  }
}
