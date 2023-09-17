import 'package:bluebubbles/app/layouts/conversation_details/dialogs/address_picker.dart';
import 'package:bluebubbles/services/network/backend_service.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:universal_io/io.dart';

class ContactTile extends StatelessWidget {
  final Handle handle;
  final Chat chat;
  final bool canBeRemoved;

  Contact? get contact => handle.contact;

  ContactTile({
    Key? key,
    required this.handle,
    required this.chat,
    required this.canBeRemoved,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool redactedMode = ss.settings.redactedMode.value;
    final bool hideInfo = redactedMode && ss.settings.hideContactInfo.value;
    final bool isEmail = handle.address.isEmail;
    final child = InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: handle.address));
        if (!Platform.isAndroid || (fs.androidInfo?.version.sdkInt ?? 0) < 33) {
          showSnackbar("Copied", "Address copied to clipboard!");
        }
      },
      onTap: () async {
        if (contact == null) {
          await mcs.invokeMethod("open-contact-form",
              {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
        } else {
          await mcs.invokeMethod("view-contact-form", {'id': contact!.id});
        }
      },
      child: ListTile(
        mouseCursor: MouseCursor.defer,
        title: RichText(
          text: TextSpan(
            children: MessageHelper.buildEmojiText(
                handle.displayName,
                context.theme.textTheme.bodyLarge!
            ),
          ),
        ),
        subtitle: contact == null || hideInfo ? null : Text(
          handle.formattedAddress ?? handle.address,
          style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
        ),
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
                      shape: const CircleBorder(),
                      backgroundColor: ss.settings.skin.value != Skins.iOS ? null : context.theme.colorScheme.secondary,
                    ),
                    onLongPress: () => showAddressPicker(contact, handle, context, isEmail: true, isLongPressed: true),
                    onPressed: () => showAddressPicker(contact, handle, isEmail: true, context),
                    child: Icon(
                        ss.settings.skin.value == Skins.iOS ? CupertinoIcons.mail : Icons.email,
                        color: ss.settings.skin.value != Skins.iOS
                            ? context.theme.colorScheme.onBackground
                            : context.theme.colorScheme.onSecondary,
                        size: ss.settings.skin.value != Skins.iOS ? 25 : 20
                    ),
                  ),
                ),
              if (((contact == null && !isEmail) || (contact?.phones.length ?? 0) > 0) && !kIsWeb && !kIsDesktop)
                ButtonTheme(
                  minWidth: 1,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: ss.settings.skin.value != Skins.iOS ? null : context.theme.colorScheme.secondary,
                    ),
                    onLongPress: () => showAddressPicker(contact, handle, context, isLongPressed: true),
                    onPressed: () => showAddressPicker(contact, handle, context),
                    child: Icon(
                        ss.settings.skin.value == Skins.iOS
                            ? CupertinoIcons.phone
                            : Icons.call,
                        color: ss.settings.skin.value != Skins.iOS
                            ? context.theme.colorScheme.onBackground
                            : context.theme.colorScheme.onSecondary,
                        size: ss.settings.skin.value != Skins.iOS ? 25 : 20
                    ),
                  ),
                ),
              if (((contact == null && !isEmail) || (contact?.phones.length ?? 0) > 0) && !kIsWeb && !kIsDesktop)
                ButtonTheme(
                  minWidth: 1,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: ss.settings.skin.value != Skins.iOS ? null : context.theme.colorScheme.secondary,
                    ),
                    onLongPress: () => showAddressPicker(contact, handle, context, isLongPressed: true, video: true),
                    onPressed: () => showAddressPicker(contact, handle, context, video: true),
                    child: Icon(
                        ss.settings.skin.value == Skins.iOS
                            ? CupertinoIcons.video_camera
                            : Icons.video_call_outlined,
                        color: ss.settings.skin.value != Skins.iOS
                            ? context.theme.colorScheme.onBackground
                            : context.theme.colorScheme.onSecondary,
                        size: ss.settings.skin.value != Skins.iOS ? 25 : 20
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return canBeRemoved ? Slidable(
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            label: 'Remove',
            backgroundColor: Colors.red,
            icon: ss.settings.skin.value == Skins.iOS ? CupertinoIcons.trash : Icons.delete_outlined,
            onPressed: (_) async {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: context.theme.colorScheme.properSurface,
                    title: Text(
                      "Removing participant...",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: Container(
                      height: 70,
                      child: Center(child: buildProgressIndicator(context)),
                    ),
                  );
                }
              );

              backend.chatParticipant("remove", chat.guid, handle.address).then((response) async {
                Get.back();
                Logger.info("Removed participant ${handle.address}");
                showSnackbar("Notice", "Removed participant from chat!");
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
      child: child,
    ) : child;
  }
}
