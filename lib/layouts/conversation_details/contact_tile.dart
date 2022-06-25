import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
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
      launchUrl(Uri(scheme: "tel", path: phoneNumber));
    }
  }

  Future<void> startEmail(String email) async {
    launchUrl(Uri(scheme: "mailto", path: email));
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
                        context.theme.textTheme.bodyLarge!)),
              )
            : FutureBuilder<String>(
                future: formatPhoneNumber(handle),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      handle.address,
                      style: context.theme.textTheme.bodyLarge,
                    );
                  }

                  return RichText(
                      text: TextSpan(
                          children: MessageHelper.buildEmojiText(
                              snapshot.data ?? "Unknown contact details", Theme.of(context).textTheme.bodyLarge!)));
                }),
        subtitle: (contact == null || hideInfo || generateName)
            ? Text(
                generateName ? ContactManager().getContact(handle.address)?.fakeAddress ?? "" : "",
                style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
              )
            : FutureBuilder<String>(
                future: formatPhoneNumber(handle),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      handle.address,
                      style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
                    );
                  }

                  return Text(
                    snapshot.data ?? "Unknown contact details",
                    style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
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
                    if ((contact == null && isEmail) || (contact?.emails.length ?? 0) > 0)
                      ButtonTheme(
                        minWidth: 1,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: CircleBorder(),
                            backgroundColor: context.theme.colorScheme.secondary,
                          ),
                          onLongPress: () => onPressContact(context, isLongPressed: true),
                          onPressed: () => onPressContact(context),
                          child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.mail : Icons.email,
                              color: context.theme.colorScheme.onSecondary,
                              size: 20),
                        ),
                      ),
                    (((contact == null && !isEmail) || (contact?.phones.length ?? 0) > 0) && !kIsWeb && !kIsDesktop)
                        ? ButtonTheme(
                            minWidth: 1,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                shape: CircleBorder(),
                                backgroundColor: context.theme.colorScheme.secondary,
                              ),
                              onLongPress: () => onPressContact(context, isLongPressed: true),
                              onPressed: () => onPressContact(context),
                              child: Icon(
                                  SettingsManager().settings.skin.value == Skins.iOS
                                      ? CupertinoIcons.phone
                                      : Icons.call,
                                  color: context.theme.colorScheme.onSecondary,
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

  void onPressContact(BuildContext context, {bool isEmail = false, bool isLongPressed = false}) async {
    void performAction(String address) async {
      if (isEmail) {
        launchUrl(Uri(scheme: "mailto", path: address));
      } else if (await Permission.phone.request().isGranted) {
        launchUrl(Uri(scheme: "tel", path: address));
      }
    }

    if (contact == null) {
      performAction(handle.address);
    } else {
      List<String> items = isEmail ? getUniqueEmails(contact!.emails) : getUniqueNumbers(contact!.phones);
      if (items.length == 1) {
        performAction(items.first);
      } else if (!isEmail && handle.defaultPhone != null && !isLongPressed) {
        performAction(handle.defaultPhone!);
      } else if (isEmail && handle.defaultEmail != null && !isLongPressed) {
        performAction(handle.defaultEmail!);
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: context.theme.colorScheme.properSurface,
              title:
              Text("Select Address", style: context.theme.textTheme.titleLarge),
              content: ObxValue<Rx<bool>>(
                      (data) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++)
                        TextButton(
                          child: Text(items[i],
                              style: context.theme.textTheme.bodyLarge,
                              textAlign: TextAlign.start),
                          onPressed: () {
                            if (data.value) {
                              if (isEmail) {
                                handle.defaultEmail = items[i];
                                handle.updateDefaultEmail(items[i]);
                              } else {
                                handle.defaultPhone = items[i];
                                handle.updateDefaultPhone(items[i]);
                              }
                            }
                            performAction(items[i]);
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
                              activeColor: context.theme.colorScheme.primary,
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
                                "Remember my selection", style: context.theme.textTheme.bodyMedium
                              )),
                        ],
                      ),
                      Text(
                        "Long press the ${isEmail ? "email" : "call"} button to reset your default selection",
                        style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
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

                    api.chatParticipant("remove", chat.guid, handle.address).then((response) async {
                      Logger.info("Removed participant ${handle.address}");
                      Chat updatedChat = Chat.fromMap(response.data["data"]);
                      updatedChat.save();
                      await ChatBloc().updateChatPosition(updatedChat);
                      Chat chatWithParticipants = updatedChat.getParticipants();

                      Logger.info("Updating chat with ${chatWithParticipants.participants.length} participants");
                      updateChat.call(chatWithParticipants);
                      Navigator.of(context).pop();
                    }).catchError((err) {
                      Logger.error("Failed to remove participant ${handle.address}");

                      late final String error;
                      if (err is Response) {
                        error = err.data["error"]["message"].toString();
                      } else {
                        error = err.toString();
                      }

                      showSnackbar("Error", "Failed to remove participant: $error");
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
