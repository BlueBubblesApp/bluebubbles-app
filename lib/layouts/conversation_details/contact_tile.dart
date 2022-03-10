import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/redacted_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactTile extends StatelessWidget {
  final Handle handle;
  final Chat chat;
  final Function updateChat;
  final bool canBeRemoved;
  late final MemoryImage? contactImage;
  late final Contact? contact;

  ContactTile({
    Key? key,
    required this.handle,
    required this.chat,
    required this.updateChat,
    required this.canBeRemoved,
  }) : super(key: key) {
    contact = ContactManager().getContact(handle.address);
    if (contact != null) ContactManager().loadContactAvatar(contact!);
  }

  Future<void> makeCall(String phoneNumber) async {
    if (await Permission.phone.request().isGranted) {
      launch("tel://$phoneNumber");
    }
  }

  Future<void> startEmail(String email) async {
    launch('mailto:$email');
  }

  List<String> getUniqueNumbers(Iterable<String> numbers) {
    List<String> phones = [];
    for (String phone in numbers) {
      bool exists = false;
      for (String current in phones) {
        if (cleansePhoneNumber(phone) == cleansePhoneNumber(current)) {
          exists = true;
          break;
        }
      }

      if (!exists) {
        phones.add(phone);
      }
    }

    return phones;
  }

  Widget _buildContactTile(BuildContext context) {
    final bool redactedMode = SettingsManager().settings.redactedMode.value;
    final bool hideInfo = redactedMode && SettingsManager().settings.hideContactInfo.value;
    final bool generateName = redactedMode && SettingsManager().settings.generateFakeContactNames.value;
    final bool isEmail = handle.address.isEmail;
    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: handle.address));
        showSnackbar('Copied', 'Address copied to clipboard');
      },
      onTap: () async {
        if (contact == null) {
          await MethodChannelInterface().invokeMethod("open-contact-form",
              {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
        } else {
          await MethodChannelInterface().invokeMethod("view-contact-form", {'id': contact!.id});
        }
      },
      child: ListTile(
        title: (contact?.displayName != null || hideInfo || generateName)
            ? RichText(
                text: TextSpan(
                    children: MessageHelper.buildEmojiText(
                        getContactName(context, contact?.displayName ?? "", handle.address, currentChat: chat),
                        Theme.of(context).textTheme.bodyText1!)),
              )
            : FutureBuilder<String>(
                future: formatPhoneNumber(handle),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      handle.address,
                      style: Theme.of(context).textTheme.bodyText1,
                    );
                  }

                  return RichText(
                      text: TextSpan(
                          children: MessageHelper.buildEmojiText(
                              snapshot.data ?? "Unknown contact details", Theme.of(context).textTheme.bodyText1!)));
                }),
        subtitle: (contact == null || hideInfo || generateName)
            ? Text(
                generateName ? ContactManager().getContact(handle.address)?.fakeAddress ?? "" : "",
                style: Theme.of(context).textTheme.subtitle1!.apply(fontSizeDelta: -0.5),
              )
            : FutureBuilder<String>(
                future: formatPhoneNumber(handle),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      handle.address,
                      style: Theme.of(context).textTheme.subtitle1!.apply(fontSizeDelta: -0.5),
                    );
                  }

                  return Text(
                    snapshot.data ?? "Unknown contact details",
                    style: Theme.of(context).textTheme.subtitle1!.apply(fontSizeDelta: -0.5),
                  );
                }),
        leading: ContactAvatarWidget(
          key: Key("${handle.address}-contact-tile"),
          handle: handle,
          borderThickness: 0.1,
        ),
        trailing: kIsWeb || (kIsDesktop && !isEmail) || (!isEmail && (contact?.phones.isEmpty ?? true))
            ? Container(width: 2)
            : FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    if (isEmail)
                      ButtonTheme(
                        minWidth: 1,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: CircleBorder(),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                          ),
                          onPressed: () {
                            startEmail(handle.address);
                          },
                          child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.mail : Icons.email,
                              color: Theme.of(context).primaryColor,
                              size: 20),
                        ),
                      ),
                    (((contact == null && !isEmail) || (contact?.phones.length ?? 0) > 0) && !kIsWeb && !kIsDesktop)
                        ? ButtonTheme(
                            minWidth: 1,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                shape: CircleBorder(),
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                              ),
                              onLongPress: () => onPressContactTrailing(context, longPressed: true),
                              onPressed: () => onPressContactTrailing(context),
                              child: Icon(
                                  SettingsManager().settings.skin.value == Skins.iOS
                                      ? CupertinoIcons.phone
                                      : Icons.call,
                                  color: Theme.of(context).primaryColor,
                                  size: 20),
                            ),
                          )
                        : Container()
                  ],
                ),
              ),
      ),
    );
  }

  void onPressContactTrailing(BuildContext context, {bool longPressed = false}) {
    if (contact == null) {
      makeCall(handle.address);
    } else {
      List<String> phones = getUniqueNumbers(contact!.phones);
      if (phones.length == 1) {
        makeCall(contact!.phones.first);
      } else if (handle.defaultPhone != null && !longPressed) {
        makeCall(handle.defaultPhone!);
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              title:
                  Text("Select a Phone Number", style: TextStyle(color: Theme.of(context).textTheme.bodyText1!.color)),
              content: ObxValue<Rx<bool>>(
                  (data) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < phones.length; i++)
                            TextButton(
                              child: Text(phones[i],
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyText1!.color),
                                  textAlign: TextAlign.start),
                              onPressed: () {
                                if (data.value) {
                                  handle.defaultPhone = phones[i];
                                  handle.updateDefaultPhone(phones[i]);
                                }
                                makeCall(phones[i]);
                                Navigator.of(context).pop();
                              },
                            ),
                          Row(
                            children: <Widget>[
                              SizedBox(
                                height: 48.0,
                                width: 24.0,
                                child: Checkbox(
                                  value: data.value,
                                  activeColor: Theme.of(context).primaryColor,
                                  onChanged: (bool? value) {
                                    data.value = value!;
                                  },
                                ),
                              ),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      primary: Colors.transparent, padding: EdgeInsets.only(left: 5), elevation: 0.0),
                                  onPressed: () {
                                    data = data.toggle();
                                  },
                                  child: Text(
                                    "Remember my selection",
                                  )),
                            ],
                          ),
                          Text(
                            "Long press the call button to reset your default selection",
                            style: Theme.of(context).textTheme.subtitle1,
                          )
                        ],
                      ),
                  false.obs),
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return canBeRemoved
        ? Slidable(
            endActionPane: ActionPane(
              motion: StretchMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  label: 'Remove',
                  backgroundColor: Colors.red,
                  icon: SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.trash : Icons.delete,
                  onPressed: (context) async {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: SizedBox(
                              height: 40,
                              width: 40,
                              child: CircularProgressIndicator(),
                            ),
                          );
                        });

                    Map<String, dynamic> params = {};
                    params["identifier"] = chat.guid;
                    params["address"] = handle.address;
                    SocketManager().sendMessage("remove-participant", params, (response) async {
                      Logger.info("Removed participant participant " + response.toString());

                      if (response["status"] == 200) {
                        Chat updatedChat = Chat.fromMap(response["data"]);
                        updatedChat.save();
                        await ChatBloc().updateChatPosition(updatedChat);
                        Chat chatWithParticipants = updatedChat.getParticipants();

                        Logger.info("Updating chat with ${chatWithParticipants.participants.length} participants");
                        updateChat(chatWithParticipants);
                        Navigator.of(context).pop();
                      }
                    });
                  },
                ),
              ],
            ),
            child: _buildContactTile(context),
          )
        : _buildContactTile(context);
  }
}
