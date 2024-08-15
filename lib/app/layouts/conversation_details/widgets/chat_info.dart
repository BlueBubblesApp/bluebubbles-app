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
  const ChatInfo({super.key, required this.chat});

  final Chat chat;
  
  @override
  OptimizedState createState() => _ChatInfoState();
}

class _ChatInfoState extends OptimizedState<ChatInfo> {
  Chat get chat => widget.chat;

  Future<bool?> showMethodDialog(String title) async {
    return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.properSurface,
            title: Text(
              title,
              style: context.theme.textTheme.titleLarge,
            ),
            content: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ss.settings.enablePrivateAPI.value && chat.isIMessage)
                  Text(
                      "Local - Changes only apply to this device.\nPrivate API - Changes will apply to everyone's devices.",
                      style: context.theme.textTheme.bodyLarge
                  ),
              ],
            ),
            actions: [
              TextButton(
                  child: Text(
                      "Local",
                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  }
              ),
              TextButton(
                  child: Text(
                      "Private API",
                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  }
              ),
            ],
          );
        }
    );
  }

  void updatePhoto() async {
    bool? papi = false;
    if (ss.settings.enablePrivateAPI.value && chat.isIMessage) {
      papi = await showMethodDialog("Group Icon Update Method");
    }
    if (papi == null) return;
    final String? result = await Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => AvatarCrop(chat: chat),
      ),
    );
    if (result != null) {
      chat.customAvatarPath = result;
    }
    if (papi && ss.settings.enablePrivateAPI.value && result != null && (await ss.isMinBigSur) && ss.serverDetailsSync().item4 >= 226) {
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

  void deletePhoto() async {
    bool? papi = false;
    if (ss.settings.enablePrivateAPI.value && chat.isIMessage) {
      papi = await showMethodDialog("Group Icon Deletion Method");
    }
    if (papi == null) return;
    try {
      File file = File(chat.customAvatarPath!);
      file.delete();
    } catch (_) {}
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
                      updatePhoto();
                    } : null,
                    child: ContactAvatarGroupWidget(
                      chat: chat,
                      size: 100,
                      editable: !chat.isGroup,
                    ),
                  ),
                  Obx(() => chat.customAvatarPath != null ? Positioned(
                    right: -5,
                    top: -5,
                    child: DeferPointer(
                      child: InkWell(
                        onTap: () async {
                          deletePhoto();
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
                  onTap: () async {
                    bool? papi = false;
                    if (ss.settings.enablePrivateAPI.value && chat.isIMessage) {
                      papi = await showMethodDialog("Group Name Update Method");
                    }
                    if (papi == null) return;
                    if (!papi) {
                      showChangeName(chat, "local", context);
                    } else {
                      showChangeName(chat, "private-api", context);
                    }
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
                    updatePhoto();
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
                    deletePhoto();
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
              child: TextButton(
                child: Text(
                  "${(chat.displayName?.isNotEmpty ?? false) ? "Change" : "Add"} Name",
                  style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.primaryColor),
                  textScaler: const TextScaler.linear(1.15),
                ),
                onPressed: () async {
                  bool? papi = false;
                  if (ss.settings.enablePrivateAPI.value && chat.isIMessage) {
                    papi = await showMethodDialog("Group Name Update Method");
                  }
                  if (papi == null) return;
                  if (!papi) {
                    showChangeName(chat, "local", context);
                  } else {
                    showChangeName(chat, "private-api", context);
                  }
                },
              ),
            ),
          if (!chat.isGroup && iOS)
            Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10, top: 20),
              child: Row(
                mainAxisAlignment: kIsWeb || kIsDesktop ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: intersperse(const SizedBox(width: 5), [
                  if (!kIsWeb && !kIsDesktop && !chat.chatIdentifier!.startsWith("urn:biz")
                      && (chat.participants.isNotEmpty && ((chat.participants.first.contact?.phones.isNotEmpty ?? false)
                          || !chat.participants.first.address.contains("@"))))
                    Expanded(
                      child: Row(
                        children: [
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
                                        color: context.theme.colorScheme.onSurface,
                                        size: 20
                                      ),
                                      const SizedBox(height: 7.5),
                                      Text("Call", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Material(
                              borderRadius: BorderRadius.circular(15),
                              color: tileColor,
                              child: InkWell(
                                onTap: () {
                                  final contact = chat.participants.first.contact;
                                  showAddressPicker(contact, chat.participants.first, context, video: true);
                                },
                                onLongPress: () {
                                  final contact = chat.participants.first.contact;
                                  showAddressPicker(contact, chat.participants.first, context, isLongPressed: true, video: true);
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: SizedBox(
                                  height: 60,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          iOS ? CupertinoIcons.video_camera : Icons.video_call_outlined,
                                          color: context.theme.colorScheme.onSurface,
                                          size: 25
                                      ),
                                      const SizedBox(height: 2.5),
                                      Text("Video Call", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (chat.participants.isNotEmpty && ((chat.participants.first.contact?.emails.isNotEmpty ?? false) || chat.participants.first.address.contains("@")))
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
                                  color: context.theme.colorScheme.onSurface,
                                  size: 20
                                ),
                                const SizedBox(height: 7.5),
                                Text("Mail", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
                              await mcs.invokeMethod("open-contact-form", {'address': handle.address, 'address_type': handle.address.isEmail ? 'email' : 'phone'});
                            } else {
                              try {
                                await mcs.invokeMethod("view-contact-form", {'id': contact.id});
                              } catch (_) {
                                showSnackbar("Error", "Failed to find contact on device!");
                              }
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
                                  chat.participants.isNotEmpty && chat.participants.first.contact != null
                                      ? (iOS ? CupertinoIcons.info : Icons.info)
                                      : (iOS ? CupertinoIcons.plus_circle : Icons.add_circle_outline),
                                  color: context.theme.colorScheme.onSurface,
                                  size: 20,
                                ),
                                const SizedBox(height: 7.5),
                                Text(
                                  chat.participants.isNotEmpty && chat.participants.first.contact != null ? "Info" : "Add Contact",
                                  style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ]).toList(),
              ),
            ),
          if (chat.isGroup)
            Padding(
              padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
              child: Text(
                "${chat.participants.length} ${iOS ? "OTHER MEMBERS" : "OTHER PEOPLE"}",
                style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)
              ),
            ),
        ]
      ),
    );
  }
}
