import 'package:bluebubbles/app/layouts/conversation_details/dialogs/address_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/change_name.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/database/models.dart';
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
  State<StatefulWidget> createState() => _ChatInfoState();
}

class _ChatInfoState extends State<ChatInfo> with ThemeHelpers {
  Chat get chat => widget.chat;

  Future<bool?> showMethodDialog(String title) async {
    return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
            title: Text(
              title,
              style: context.theme.textTheme.titleLarge,
            ),
            content: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage)
                  Text(
                      "Local - Changes only apply to this device.\nPrivate API - Changes will apply to everyone's devices.",
                      style: context.theme.textTheme.bodyLarge),
              ],
            ),
            actions: [
              TextButton(
                  child: Text("Local",
                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  }),
              TextButton(
                  child: Text("Private API",
                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  }),
            ],
          );
        });
  }

  void updatePhoto() async {
    bool? papi = false;
    if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup) {
      papi = await showMethodDialog("Group Icon Update Method");
    }
    if (papi == null) return;
    final usePrivateApi = papi;
    final String? result = await Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => AvatarCrop(chat: chat),
      ),
    );
    if (result == null) return;

    if (!usePrivateApi) {
      await ChatsSvc.setChatCustomAvatarPath(chat, result);
      return;
    }

    if (usePrivateApi &&
        SettingsSvc.settings.enablePrivateAPI.value &&
        SettingsSvc.serverDetails.isMinBigSur &&
        SettingsSvc.serverDetails.supportsGroupChatManagement) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
              title: Text(
                "Updating group photo...",
                style: context.theme.textTheme.titleLarge,
              ),
              content: SizedBox(
                height: 70,
                child: Center(
                  child: CircularProgressIndicator(
                    backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                  ),
                ),
              ),
            );
          });
      final response = await HttpSvc.chat.setIcon(chat.guid, result);
      if (response.statusCode == 200) {
        await ChatsSvc.setChatCustomAvatarPath(chat, result);
        Navigator.of(context, rootNavigator: true).pop();
        showSnackbar("Notice", "Updated group photo successfully!");
      } else {
        try {
          await File(result).delete();
        } catch (_) {}
        Navigator.of(context, rootNavigator: true).pop();
        showSnackbar("Error", "Failed to update group photo!");
      }
    } else if (usePrivateApi) {
      try {
        await File(result).delete();
      } catch (_) {}
      showSnackbar("Error", "Failed to update group photo!");
    }
  }

  void deletePhoto() async {
    bool? papi = false;
    if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup) {
      papi = await showMethodDialog("Group Icon Deletion Method");
    }
    if (papi == null) return;
    final usePrivateApi = papi;

    if (usePrivateApi &&
        SettingsSvc.settings.enablePrivateAPI.value &&
        SettingsSvc.serverDetails.isMinBigSur &&
        SettingsSvc.serverDetails.supportsGroupChatManagement) {
      final response = await HttpSvc.chat.removeIcon(chat.guid);
      if (response.statusCode == 200) {
        await ChatsSvc.setChatCustomAvatarPath(chat, null);
        showSnackbar("Notice", "Deleted group photo successfully!");
      } else {
        showSnackbar("Error", "Failed to delete group photo!");
      }
      return;
    }

    await ChatsSvc.setChatCustomAvatarPath(chat, null);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getChatState(chat.guid);

    bool canCall = !kIsWeb &&
        !kIsDesktop &&
        !chat.chatIdentifier!.startsWith("urn:biz") &&
        (chat.handles.isNotEmpty &&
            ((chat.handles.first.contactsV2.firstOrNull?.phoneNumbers.isNotEmpty ?? false) ||
                !chat.handles.first.address.contains("@")));

    return DeferredPointerHandler(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 10),
        if (iOS)
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: chat.isGroup
                      ? () async {
                          updatePhoto();
                        }
                      : null,
                  child: ContactAvatarGroupWidget(
                    size: 100,
                    editable: !chat.isGroup,
                  ),
                ),
                Obx(() => chat.customAvatarPath != null
                    ? Positioned(
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
                                border: Border.all(color: context.theme.colorScheme.surface, width: 1),
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
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
        if (iOS)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, left: 20.0, right: 20.0),
            child: Center(
              child: Obx(() => RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: context.theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.theme.colorScheme.onSurface,
                      ),
                      children: MessageHelper.buildEmojiText(
                        chatState?.title.value ?? chat.getTitle(),
                        context.theme.textTheme.headlineMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  )),
            ),
          ),
        if (chat.isGroup && !iOS)
          Padding(
            padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
            child: Text("GROUP NAME AND PHOTO",
                style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
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
                  if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage) {
                    papi = await showMethodDialog("Group Name Update Method");
                  }
                  if (papi == null) return;
                  if (!papi) {
                    showChangeName(chat, "local", context);
                  } else {
                    showChangeName(chat, "private-api", context);
                  }
                },
                title: Obx(() => RichText(
                      text: TextSpan(
                        style: context.theme.textTheme.bodyLarge,
                        children: MessageHelper.buildEmojiText(
                          chatState?.title.value ?? chat.getTitle(),
                          context.theme.textTheme.bodyLarge!,
                        ),
                      ),
                    )),
                trailing: Icon(Icons.edit_outlined, color: context.theme.colorScheme.onSurface),
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
                trailing: Icon(Icons.edit_outlined, color: context.theme.colorScheme.onSurface),
              ),
            ),
          ),
        if (chat.isGroup && !iOS)
          Obx(() => chat.customAvatarPath != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      mouseCursor: MouseCursor.defer,
                      onTap: () async {
                        deletePhoto();
                      },
                      title: Text("Remove group photo",
                          style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.error)),
                      trailing: Icon(Icons.close, color: context.theme.colorScheme.error),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        if (!chat.isGroup && !iOS)
          ContactTile(
            key: Key(chat.handles.first.address),
            handle: chat.handles.first,
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
                if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage) {
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
            padding: const EdgeInsets.only(left: 15.0, right: 15, top: 20),
            child: Row(
              mainAxisAlignment: kIsWeb || kIsDesktop ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: intersperse(const SizedBox(width: 5), [
                if (canCall) CallButton(tileColor: tileColor, chat: chat, iOS: iOS),
                VideoCallButton(tileColor: tileColor, chat: chat, iOS: iOS),
                if (chat.handles.isNotEmpty &&
                    ((chat.handles.first.contactsV2.firstOrNull?.emailAddresses.isNotEmpty ?? false) ||
                        chat.handles.first.address.contains("@")))
                  MailButton(tileColor: tileColor, chat: chat, iOS: iOS),
                if (!kIsWeb && !kIsDesktop) InfoButton(tileColor: tileColor, chat: chat, iOS: iOS),
              ]).toList(),
            ),
          ),
        if (chat.isGroup)
          Padding(
            padding: const EdgeInsets.only(left: 15.0, top: 20.0, bottom: 5.0),
            child: Text("${chat.handles.length} ${iOS ? "OTHER MEMBERS" : "OTHER PEOPLE"}",
                style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
          ),
      ]),
    );
  }
}

class InfoButton extends StatelessWidget {
  const InfoButton({
    super.key,
    required this.tileColor,
    required this.chat,
    required this.iOS,
  });

  final Color tileColor;
  final Chat chat;
  final bool iOS;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(15),
        color: tileColor,
        child: InkWell(
          onTap: () async {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            final handle = chat.handles.first;
            if (contact == null || !contact.isNative) {
              await MethodChannelSvc.actions.openContactForm(
                address: handle.address,
                isEmail: handle.address.isEmail,
              );
            } else {
              try {
                await MethodChannelSvc.actions.viewContactForm(nativeContactId: contact.nativeContactId);
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
                  chat.handles.isNotEmpty &&
                          chat.handles.first.contactsV2.isNotEmpty &&
                          chat.handles.first.contactsV2.first.isNative
                      ? (iOS ? CupertinoIcons.info : Icons.info)
                      : (iOS ? CupertinoIcons.plus_circle : Icons.add_circle_outline),
                  color: context.theme.colorScheme.onSurface,
                  size: 20,
                ),
                const SizedBox(height: 7.5),
                Text(
                    chat.handles.isNotEmpty &&
                            chat.handles.first.contactsV2.isNotEmpty &&
                            chat.handles.first.contactsV2.first.isNative
                        ? "Info"
                        : "Add Contact",
                    style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MailButton extends StatelessWidget {
  const MailButton({
    super.key,
    required this.tileColor,
    required this.chat,
    required this.iOS,
  });

  final Color tileColor;
  final Chat chat;
  final bool iOS;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(15),
        color: tileColor,
        child: InkWell(
          onTap: () {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            showAddressPicker(contact, chat.handles.first, context, isEmail: true);
          },
          onLongPress: () {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            showAddressPicker(contact, chat.handles.first, context, isEmail: true, isLongPressed: true);
          },
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iOS ? CupertinoIcons.mail : Icons.email, color: context.theme.colorScheme.onSurface, size: 20),
                const SizedBox(height: 7.5),
                Text("Mail",
                    style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoCallButton extends StatelessWidget {
  const VideoCallButton({
    super.key,
    required this.tileColor,
    required this.chat,
    required this.iOS,
  });

  final Color tileColor;
  final Chat chat;
  final bool iOS;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(15),
        color: tileColor,
        child: InkWell(
          onTap: () {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            showAddressPicker(contact, chat.handles.first, context, video: true, chat: chat);
          },
          onLongPress: () {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            showAddressPicker(contact, chat.handles.first, context, isLongPressed: true, video: true, chat: chat);
          },
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iOS ? CupertinoIcons.video_camera : Icons.video_call_outlined,
                    color: context.theme.colorScheme.onSurface, size: 25),
                const SizedBox(height: 2.5),
                Text("Video Call",
                    style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.tileColor,
    required this.chat,
    required this.iOS,
  });

  final Color tileColor;
  final Chat chat;
  final bool iOS;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(15),
        color: tileColor,
        child: InkWell(
          onTap: () {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            showAddressPicker(contact, chat.handles.first, context);
          },
          onLongPress: () {
            final contact = chat.handles.first.contactsV2.firstOrNull;
            showAddressPicker(contact, chat.handles.first, context, isLongPressed: true);
          },
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iOS ? CupertinoIcons.phone : Icons.call, color: context.theme.colorScheme.onSurface, size: 20),
                const SizedBox(height: 7.5),
                Text("Call",
                    style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
