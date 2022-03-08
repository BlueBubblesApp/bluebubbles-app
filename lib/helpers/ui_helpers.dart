import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

Widget buildBackButton(BuildContext context,
    {EdgeInsets padding = EdgeInsets.zero, double? iconSize, Skins? skin, bool Function()? callback}) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: padding,
      width: 25,
      child: IconButton(
        iconSize: iconSize ?? (SettingsManager().settings.skin.value != Skins.Material ? 30 : 24),
        icon: skin != null
            ? Icon(skin != Skins.Material ? CupertinoIcons.back : Icons.arrow_back, color: Theme.of(context).primaryColor)
            : Obx(() => Icon(SettingsManager().settings.skin.value != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
                color: Theme.of(context).primaryColor)),
        onPressed: () {
          final result = callback?.call() ?? true;
          if (result) {
            while (Get.isOverlaysOpen) {
              Get.back();
            }
            Navigator.of(context).pop();
          }
        },
      ),
    )
  );
}

Widget buildProgressIndicator(BuildContext context, {double size = 20, double strokeWidth = 2}) {
  return SettingsManager().settings.skin.value == Skins.iOS
      ? Theme(
          data: ThemeData(
            cupertinoOverrideTheme:
                CupertinoThemeData(brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor)),
          ),
          child: CupertinoActivityIndicator(
            radius: size / 2,
          ),
        )
      : Container(
          constraints: BoxConstraints(maxHeight: size, maxWidth: size),
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ));
}

Widget buildImagePlaceholder(BuildContext context, Attachment attachment, Widget child, {bool isLoaded = false}) {
  double placeholderWidth = 200;
  double placeholderHeight = 150;

  // If the image doesn't have a valid size, show the loader with static height/width
  if (!attachment.hasValidSize) {
    return Container(
        width: placeholderWidth, height: placeholderHeight, color: Theme.of(context).colorScheme.secondary, child: child);
  }

  // If we have a valid size, we want to calculate the aspect ratio so the image doesn't "jitter" when loading
  // Calculate the aspect ratio for the placeholders
  double ratio = AttachmentHelper.getAspectRatio(attachment.height, attachment.width, context: context);
  double height = attachment.height?.toDouble() ?? placeholderHeight;
  double width = attachment.width?.toDouble() ?? placeholderWidth;

  // YES, this countainer surrounding the AspectRatio is needed.
  // If not there, the box may be too large
  return Container(
      constraints: BoxConstraints(maxHeight: height, maxWidth: width),
      child: AspectRatio(
          aspectRatio: ratio,
          child: Container(width: width, height: height, color: Theme.of(context).colorScheme.secondary, child: child)));
}

Future<void> showConversationTileMenu(context, _this, chat, tapPosition, textTheme) async {
  bool ios = SettingsManager().settings.skin.value == Skins.iOS;
  HapticFeedback.mediumImpact();
  await showMenu(
    color: Theme.of(context).colorScheme.secondary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ios ? 10 : 0)),
    context: context,
    position: RelativeRect.fromLTRB(
      tapPosition.dx,
      tapPosition.dy,
      tapPosition.dx,
      tapPosition.dy,
    ),
    items: <PopupMenuEntry>[
      if (!kIsWeb)
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await chat.togglePin(!chat.isPinned!);
              if (_this.mounted) _this.setState(() {});
              Navigator.pop(context);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      chat.isPinned!
                          ? (ios ? CupertinoIcons.pin_slash : Icons.star_outline)
                          : (ios ? CupertinoIcons.pin : Icons.star),
                      color: textTheme.bodyText1!.color,
                    ),
                  ),
                  Text(
                    chat.isPinned! ? "Unpin" : "Pin",
                    style: textTheme.bodyText1!,
                  ),
                ],
              ),
            ),
          ),
        ),
      if (!kIsWeb)
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await chat.toggleMute(chat.muteType != "mute");
              if (_this.mounted) _this.setState(() {});
              Navigator.pop(context);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      chat.muteType == "mute"
                          ? (ios ? CupertinoIcons.bell : Icons.notifications_active)
                          : (ios ? CupertinoIcons.bell_slash : Icons.notifications_off),
                      color: textTheme.bodyText1!.color,
                    ),
                  ),
                  Text(chat.muteType == "mute" ? 'Show Alerts' : 'Hide Alerts', style: textTheme.bodyText1!),
                ],
              ),
            ),
          ),
        ),
      PopupMenuItem(
        padding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ChatBloc().toggleChatUnread(chat, !chat.hasUnreadMessage!);
            if (_this.mounted) _this.setState(() {});
            Navigator.pop(context);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(
                    chat.hasUnreadMessage!
                        ? (ios ? CupertinoIcons.person_crop_circle_badge_xmark : Icons.mark_chat_unread)
                        : (ios ? CupertinoIcons.person_crop_circle_badge_checkmark : Icons.mark_chat_read),
                    color: textTheme.bodyText1!.color,
                  ),
                ),
                Text(chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread', style: textTheme.bodyText1!),
              ],
            ),
          ),
        ),
      ),
      if (!kIsWeb)
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (chat.isArchived!) {
                ChatBloc().unArchiveChat(chat);
              } else {
                ChatBloc().archiveChat(chat);
              }
              if (_this.mounted) _this.setState(() {});
              Navigator.pop(context);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      chat.isArchived!
                          ? (ios ? CupertinoIcons.tray_arrow_up : Icons.unarchive)
                          : (ios ? CupertinoIcons.tray_arrow_down : Icons.archive),
                      color: textTheme.bodyText1!.color,
                    ),
                  ),
                  Text(
                    chat.isArchived! ? 'Unarchive' : 'Archive',
                    style: textTheme.bodyText1!,
                  ),
                ],
              ),
            ),
          ),
        ),
      if (!kIsWeb)
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              ChatBloc().deleteChat(chat);
              Chat.deleteChat(chat);
              if (_this.mounted) _this.setState(() {});
              Navigator.pop(context);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.delete_forever,
                      color: textTheme.bodyText1!.color,
                    ),
                  ),
                  Text(
                    'Delete',
                    style: textTheme.bodyText1!,
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
  EventDispatcher().emit('focus-keyboard', null);
}
