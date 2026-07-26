import 'package:bluebubbles/app/components/animated_dropdown_menu.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/address_picker.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/chat_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:universal_io/io.dart';

class ContactTile extends StatelessWidget {
  final Handle handle;
  final Chat chat;
  final bool canBeRemoved;

  ContactV2? get contact => handle.contactsV2.firstOrNull;

  bool get hasPhones {
    return contact?.addresses.any((addr) => !addr.contains('@')) ?? false;
  }

  bool get hasEmails {
    return contact?.addresses.any((addr) => addr.contains('@')) ?? false;
  }

  const ContactTile({
    super.key,
    required this.handle,
    required this.chat,
    required this.canBeRemoved,
  });

  void _removeParticipant(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
          title: Text(
            "Removing participant...",
            style: context.theme.textTheme.titleLarge,
          ),
          content: SizedBox(
            height: 70,
            child: Center(child: buildProgressIndicator(context)),
          ),
        );
      },
    );

    HttpSvc.chat.modifyParticipant("remove", chat.guid, handle.address).then((response) async {
      navigator.pop();
      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        final result = await ChatInterface.bulkSyncChats(
          chatsData: [response.data['data'] as Map<String, dynamic>],
        );
        if (result.chats.isNotEmpty) {
          ChatsSvc.updateChat(result.chats.first, override: true);
        }
      }
      Logger.info("Removed participant ${handle.address}");
      showSnackbar("Notice", "Removed participant from chat!");
    }).catchError((err, stack) {
      Logger.error("Failed to remove participant ${handle.address}", error: err, trace: stack);
      late final String error;
      if (err is Response) {
        error = err.data["error"]["message"].toString();
      } else {
        error = err.toString();
      }
      showSnackbar("Error", "Failed to remove participant: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    final handleState = HandleSvc.getOrCreateHandleState(handle);
    return Obx(() {
      final String displayName = handleState.displayName.value ?? handle.address;
      final String address = handleState.formattedAddress.value ?? handle.address;
      final bool isEmail = handle.address.isEmail;
      final child = InkWell(
        mouseCursor: MouseCursor.defer,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: handle.address));
          if (!Platform.isAndroid || (FilesystemSvc.androidInfo?.version.sdkInt ?? 0) < 33) {
            showToast("Address copied to clipboard");
          }
        },
        onTap: kIsDesktop
            ? null
            : () async {
                final contactV2 = handle.contactsV2.firstOrNull;
                if (contactV2 == null || !contactV2.isNative) {
                  await MethodChannelSvc.actions.openContactForm(
                    address: handle.address,
                    isEmail: handle.address.isEmail,
                  );
                } else {
                  try {
                    await MethodChannelSvc.actions.viewContactForm(nativeContactId: contactV2.nativeContactId);
                  } catch (_) {
                    showSnackbar("Error", "Failed to find contact on device!");
                  }
                }
              },
        onSecondaryTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outlined, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              displayName,
                              style: context.theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 8),
                    ListTile(
                      mouseCursor: MouseCursor.defer,
                      leading: const Icon(Icons.copy_outlined),
                      title: const Text("Copy address"),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Clipboard.setData(ClipboardData(text: handle.address));
                        showToast("Address copied to clipboard");
                      },
                    ),
                    if (canBeRemoved)
                      ListTile(
                        mouseCursor: MouseCursor.defer,
                        leading: Icon(Icons.person_remove_outlined, color: context.theme.colorScheme.error),
                        title: Text("Remove from chat", style: TextStyle(color: context.theme.colorScheme.error)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _removeParticipant(context);
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
        child: ListTile(
          title: RichText(
            text: TextSpan(
              children: MessageHelper.buildEmojiText(
                displayName,
                context.theme.textTheme.bodyLarge!,
              ),
            ),
          ),
          subtitle: handle.contactsV2.isEmpty
              ? null
              : Text(
                  address,
                  style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
                ),
          leading: ContactAvatarWidget(
            key: Key("${handle.address}-contact-tile"),
            handle: handle,
            borderThickness: 0.1,
          ),
          trailing: _buildTrailing(context, contact: contact, isEmail: isEmail),
        ),
      );

      return canBeRemoved && !kIsDesktop
          ? Slidable(
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                extentRatio: 0.25,
                children: [
                  SlidableAction(
                    label: 'Remove',
                    backgroundColor: Colors.red,
                    icon: SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.trash : Icons.delete_outlined,
                    onPressed: (_) => _removeParticipant(context),
                  ),
                ],
              ),
              child: child,
            )
          : child;
    });
  }

  Widget _buildTrailing(BuildContext context, {required ContactV2? contact, required bool isEmail}) {
    if (kIsWeb || (kIsDesktop && !isEmail) || (!isEmail && !hasPhones)) {
      return Container(width: 2);
    }

    final bool showEmail = (contact == null && isEmail) || hasEmails;
    final bool showPhone = ((contact == null && !isEmail) || hasPhones) && !kIsWeb && !kIsDesktop;
    final bool showVideo = showPhone;

    if (!showEmail && !showPhone && !showVideo) {
      return Container(width: 2);
    }

    if (SettingsSvc.settings.skin.value == Skins.iOS) {
      return _buildCupertinoMenu(
        context,
        contact: contact,
        showEmail: showEmail,
        showPhone: showPhone,
        showVideo: showVideo,
      );
    }

    return _buildMaterialMenu(
      context,
      contact: contact,
      showEmail: showEmail,
      showPhone: showPhone,
      showVideo: showVideo,
    );
  }

  Widget _buildCupertinoMenu(
    BuildContext context, {
    required ContactV2? contact,
    required bool showEmail,
    required bool showPhone,
    required bool showVideo,
  }) {
    final itemTheme = PullDownMenuItemTheme(
      textStyle: TextStyle(
        color: context.theme.colorScheme.onSurface,
      ),
      onHoverTextColor: context.theme.colorScheme.onSurface,
      onHoverBackgroundColor: context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
    );

    return PullDownButton(
      routeTheme: PullDownMenuRouteTheme(
        backgroundColor: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
      ),
      itemBuilder: (context) => [
        if (showEmail)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'Email',
            icon: CupertinoIcons.mail,
            onTap: () => showAddressPicker(contact, handle, isEmail: true, context),
          ),
        if (showPhone)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'Call',
            icon: CupertinoIcons.phone,
            onTap: () => showAddressPicker(contact, handle, context),
          ),
        if (showVideo)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'FaceTime',
            icon: CupertinoIcons.video_camera,
            onTap: () => showAddressPicker(contact, handle, context, video: true),
          ),
      ],
      buttonBuilder: (context, showMenu) => ClipOval(
        child: Material(
          color: context.theme.colorScheme.secondary,
          child: SizedBox(
            width: 30,
            height: 30,
            child: InkWell(
              onTap: showMenu,
              child: Icon(
                CupertinoIcons.ellipsis,
                color: context.theme.colorScheme.onSecondary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialMenu(
    BuildContext context, {
    required ContactV2? contact,
    required bool showEmail,
    required bool showPhone,
    required bool showVideo,
  }) {
    return AnimatedDropdownMenu(
      trigger: (context, showMenu) => ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: showMenu,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.more_vert,
                color: context.theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      menuBuilder: (overlayContext, hideMenu) => DropdownMenuCard(
        width: 180,
        children: [
          if (showEmail)
            MenuItemRow(
              icon: Icons.email_outlined,
              label: 'Email',
              onTap: () => hideMenu().then((_) => showAddressPicker(contact, handle, isEmail: true, overlayContext)),
            ),
          if (showPhone)
            MenuItemRow(
              icon: Icons.call_outlined,
              label: 'Call',
              onTap: () => hideMenu().then((_) => showAddressPicker(contact, handle, overlayContext)),
            ),
          if (showVideo)
            MenuItemRow(
              icon: Icons.video_call_outlined,
              label: 'Video',
              onTap: () => hideMenu().then((_) => showAddressPicker(contact, handle, overlayContext, video: true)),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
