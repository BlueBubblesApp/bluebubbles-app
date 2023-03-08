import 'package:bluebubbles/app/layouts/conversation_details/dialogs/address_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/change_name.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class ChatInfo extends StatefulWidget {
  const ChatInfo({Key? key, required this.chat}) : super(key: key);

  final Chat chat;
  
  @override
  OptimizedState createState() => _ChatInfoState();
}

class _ChatInfoState extends OptimizedState<ChatInfo> {
  Chat get chat => widget.chat;

  void updatePhoto(bool papi) async {
    final Uint8List? data = await Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => AvatarCrop(chat: chat),
      ),
    );
    if (papi && ss.settings.enablePrivateAPI.value && data != null && (await ss.isMinBigSur) && ss.serverDetailsSync().item4 >= 226) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: context.theme.colorScheme.properSurface,
              title: Text(
                "Updating group photo...",
                style: context.theme.textTheme.titleLarge,
              ),
              content: Container(
                height: 70,
                child: Center(
                  child: CircularProgressIndicator(
                    backgroundColor: context.theme.colorScheme.properSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                  ),
                ),
              ),
            );
          }
      );
      final response = await http.setChatIcon(chat.guid, chat.customAvatarPath!);
      if (response.statusCode == 200) {
        Get.back();
        showSnackbar("Notice", "Updated group photo successfully!");
      } else {
        Get.back();
        showSnackbar("Error", "Failed to update group photo!");
      }
    }
  }

  void deletePhoto(bool papi) async {
    File file = File(chat.customAvatarPath!);
    file.delete();
    chat.customAvatarPath = null;
    chat.save(updateCustomAvatarPath: true);
    if (papi && ss.settings.enablePrivateAPI.value && (await ss.isMinBigSur) && ss.serverDetailsSync().item4 >= 226) {
      final response = await http.deleteChatIcon(chat.guid);
      if (response.statusCode == 200) {
        showSnackbar("Notice", "Deleted group photo successfully!");
      } else {
        showSnackbar("Error", "Failed to delete group photo!");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
    String _title = chat.properTitle;
    if (hideInfo) {
      _title = chat.participants.length > 1 ? "Group Chat" : chat.participants[0].fakeName;
    }
    return DeferredPointerHandler(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          if (iOS)
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: chat.isGroup ? () async {
                      updatePhoto(true);
                    } : null,
                    onLongPress: chat.isGroup ? () async {
                      updatePhoto(false);
                    } : null,
                    child: ContactAvatarGroupWidget(
                      chat: chat,
                      size: 100,
                    ),
                  ),
                  Obx(() => chat.customAvatarPath != null ? Positioned(
                    right: -5,
                    top: -5,
                    child: DeferPointer(
                      child: InkWell(
                        onTap: () async {
                          deletePhoto(true);
                        },
                        onLongPress: () {
                          deletePhoto(false);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            border: Border.all(color: context.theme.colorScheme.background, width: 1),
                            shape: BoxShape.circle,
                            color: context.theme.colorScheme.tertiaryContainer,
                          ),
                          child: Icon(
                            Icons.close,
                            color: context.theme.colorScheme.onTertiaryContainer,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ) : const SizedBox.shrink()),
                ],
              ),
            ),
          if (iOS)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Center(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: context.theme.textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.theme.colorScheme.onBackground,
                    ),
                    children: MessageHelper.buildEmojiText(
                      _title,
                      context.theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.theme.colorScheme.onBackground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (chat.isGroup && !iOS)
            Padding(
              padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
              child: Text(
                  "GROUP NAME AND PHOTO",
                  style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)
              ),
            ),
          if (chat.isGroup && !iOS)
            Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  mouseCursor: MouseCursor.defer,
                  onTap: () {
                    if (!ss.settings.enablePrivateAPI.value || !chat.isIMessage) {
                      showChangeName(chat, "local", context);
                    } else {
                      showChangeName(chat, "private-api", context);
                    }
                  },
                  onLongPress: () {
                    showChangeName(chat, "local", context);
                  },
                  title: RichText(
                    text: TextSpan(
                      style: context.theme.textTheme.bodyLarge,
                      children: MessageHelper.buildEmojiText(
                        _title,
                        context.theme.textTheme.bodyLarge!,
                      ),
                    ),
                  ),
                  trailing: Icon(Icons.edit_outlined, color: context.theme.colorScheme.onBackground),
                ),
              ),
            ),
          if (chat.isGroup && !iOS)
            Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  mouseCursor: MouseCursor.defer,
                  onTap: () async {
                    updatePhoto(true);
                  },
                  onLongPress: () {
                    updatePhoto(false);
                  },
                  title: Text("Update group photo", style: context.theme.textTheme.bodyLarge!),
                  trailing: Icon(Icons.edit_outlined, color: context.theme.colorScheme.onBackground),
                ),
              ),
            ),
          if (chat.isGroup && !iOS)
            Obx(() => chat.customAvatarPath != null ? Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  mouseCursor: MouseCursor.defer,
                  onTap: () async {
                    deletePhoto(true);
                  },
                  onLongPress: () {
                    deletePhoto(false);
                  },
                  title: Text("Remove group photo", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.error)),
                  trailing: Icon(Icons.close, color: context.theme.colorScheme.error),
                ),
              ),
            ) : const SizedBox.shrink()),
          if (!chat.isGroup && !iOS)
            ContactTile(
              key: Key(chat.participants.first.address),
              handle: chat.participants.first,
              chat: chat,
              canBeRemoved: false,
            ),
          if (chat.isGroup && iOS)
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: Text(
                      "${(chat.displayName?.isNotEmpty ?? false) ? "Change" : "Add"} Name",
                      style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.primaryColor),
                      textScaleFactor: 1.15,
                    ),
                    onPressed: () {
                      if (!ss.settings.enablePrivateAPI.value || !chat.isIMessage) {
                        showChangeName(chat, "local", context);
                      } else {
                        showChangeName(chat, "private-api", context);
                      }
                    },
                    onLongPress: () {
                      showChangeName(chat, "local", context);
                    },
                  ),
                  Container(
                    child: IconButton(
                      icon: Icon(
                        iOS ? CupertinoIcons.info : Icons.info_outline,
                        size: 15,
                        color: context.theme.colorScheme.primary,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 15,
                      constraints: const BoxConstraints(maxWidth: 20, maxHeight: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: context.theme.colorScheme.properSurface,
                              title: Text("Group Naming Info", style: context.theme.textTheme.titleLarge),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!ss.settings.enablePrivateAPI.value || !chat.isIMessage)
                                    Text(
                                      "${!chat.isIMessage ? "This chat is SMS" : "You have Private API disabled"}, so changing the name or avatar here will only change it locally for you. You will not see these changes on other devices, and the other members of this chat will not see these changes.",
                                      style: context.theme.textTheme.bodyLarge
                                    ),
                                  if (ss.settings.enablePrivateAPI.value && chat.isIMessage)
                                    Text(
                                      "You have Private API enabled, so changing the name or avatar here will change the name or avatar for everyone in this chat. If you only want to change the name locally, you can tap and hold the \"Change Name\" button. If you only want to change the avatar locally, you can tap and hold the avatar icon (or tap and hold the delete icon).",
                                      style: context.theme.textTheme.bodyLarge
                                    ),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text(
                                    "Close",
                                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }
                                ),
                              ]
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          if (!chat.isGroup && iOS)
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10, top: 20),
              child: Row(
                mainAxisAlignment: kIsWeb || kIsDesktop ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  if (!kIsWeb && !kIsDesktop && !chat.chatIdentifier!.startsWith("urn:biz")
                      && ((chat.participants.first.contact?.phones.isNotEmpty ?? false)
                          || !chat.participants.first.address.contains("@")))
                    Expanded(
                      child: Material(
                        borderRadius: BorderRadius.circular(15),
                        color: tileColor,
                        child: InkWell(
                          onTap: () {
                            final contact = chat.participants.first.contact;
                            showAddressPicker(contact, chat.participants.first, context);
                          },
                          onLongPress: () {
                            final contact = chat.participants.first.contact;
                            showAddressPicker(contact, chat.participants.first, context, isLongPressed: true);
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: SizedBox(
                            height: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iOS ? CupertinoIcons.phone : Icons.call,
                                  color: context.theme.colorScheme.primary,
                                  size: 20
                                ),
                                const SizedBox(height: 7.5),
                                Text("Call", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop
                      && ((chat.participants.first.contact?.phones.isNotEmpty ?? false)
                          || !chat.participants.first.address.contains("@")))
                    const SizedBox(width: 5),
                  if ((chat.participants.first.contact?.emails.isNotEmpty ?? false) || chat.participants.first.address.contains("@"))
                    Expanded(
                      child: Material(
                        borderRadius: BorderRadius.circular(15),
                        color: tileColor,
                        child: InkWell(
                          onTap: () {
                            final contact = chat.participants.first.contact;
                            showAddressPicker(contact, chat.participants.first, context, isEmail: true);
                          },
                          onLongPress: () {
                            final contact = chat.participants.first.contact;
                            showAddressPicker(contact, chat.participants.first, context, isEmail: true, isLongPressed: true);
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: SizedBox(
                            height: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iOS ? CupertinoIcons.mail : Icons.email,
                                  color: context.theme.colorScheme.primary,
                                  size: 20
                                ),
                                const SizedBox(height: 7.5),
                                Text("Mail", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    const SizedBox(width: 5),
                  if (!kIsWeb && !kIsDesktop)
                    Expanded(
                      child: Material(
                        borderRadius: BorderRadius.circular(15),
                        color: tileColor,
                        child: InkWell(
                          onTap: () async {
                            final contact = chat.participants.first.contact;
                            final handle = chat.participants.first;
                            if (contact == null) {
                              await mcs.invokeMethod("open-contact-form",
                                  {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
                            } else {
                              await mcs.invokeMethod("view-contact-form", {'id': contact.id});
                            }
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: SizedBox(
                            height: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  chat.participants.first.contact != null
                                      ? (iOS ? CupertinoIcons.info : Icons.info)
                                      : (iOS ? CupertinoIcons.plus_circle : Icons.add_circle_outline),
                                  color: context.theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(height: 7.5),
                                Text(
                                  chat.participants.first.contact != null ? "Info" : "Add Contact",
                                  style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.primary)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (chat.isGroup)
            Padding(
              padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
              child: Text(
                "${chat.participants.length} ${iOS ? "MEMBERS" : "OTHER PEOPLE"}",
                style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)
              ),
            ),
        ]
      ),
    );
  }
}
