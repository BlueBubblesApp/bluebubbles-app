import 'dart:io';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum DetailsMenuAction {
  Reply(PlatformSupport.all, CupertinoIcons.reply, Icons.reply, "Reply"),
  Save(PlatformSupport.all, CupertinoIcons.cloud_download, Icons.file_download, "Save"),
  OpenInImageViewer(PlatformSupport.desktop, CupertinoIcons.photo, Icons.image_outlined, "Open In Image Viewer"),
  OpenInBrowser(PlatformSupport.android, CupertinoIcons.macwindow, Icons.open_in_browser, "Open In Browser"),
  OpenInNewTab(PlatformSupport.web, CupertinoIcons.macwindow, Icons.open_in_browser, "Open In New Tab"),
  CopyText(PlatformSupport.all, CupertinoIcons.doc_on_clipboard, Icons.content_copy, "Copy"),
  CopyAttachment(PlatformSupport.desktop, CupertinoIcons.doc_on_clipboard, Icons.content_copy, "Copy Attachment"),
  SaveOriginal(PlatformSupport.all, CupertinoIcons.cloud_download, Icons.file_download, "Save Original"),
  SaveLivePhoto(PlatformSupport.all, CupertinoIcons.photo, Icons.motion_photos_on_outlined, "Save Live Photo"),
  OpenDirectMessage(
    PlatformSupport.all,
    CupertinoIcons.arrow_up_right_square,
    Icons.open_in_new,
    "Open Direct Message",
  ),
  ViewThread(PlatformSupport.all, CupertinoIcons.bubble_left_bubble_right, Icons.forum, "View Thread"),
  Share(PlatformSupport.android | PlatformSupport.windows, CupertinoIcons.share, Icons.share, "Share"),
  ReDownloadFromServer(PlatformSupport.all, CupertinoIcons.refresh, Icons.refresh, "Re-download From Server"),
  RemindLater(PlatformSupport.android, CupertinoIcons.alarm, Icons.alarm, "Remind Later"),
  CreateContact(
    PlatformSupport.android,
    CupertinoIcons.person_crop_circle_badge_plus,
    Icons.contact_page_outlined,
    "Create Contact",
  ),
  UndoSend(PlatformSupport.all, CupertinoIcons.arrow_uturn_left, Icons.undo, "Undo Send"),
  Edit(PlatformSupport.all, CupertinoIcons.pencil, Icons.edit_outlined, "Edit"),
  Forward(PlatformSupport.all, CupertinoIcons.arrow_right, Icons.forward, "Forward"),
  StartConversation(PlatformSupport.all, CupertinoIcons.chat_bubble, Icons.message, "Start Conversation"),
  CopySelection(PlatformSupport.all, CupertinoIcons.text_cursor, Icons.content_copy, "Copy Selection"),
  Delete(PlatformSupport.all, CupertinoIcons.trash, Icons.delete_outlined, "Delete"),
  Bookmark(PlatformSupport.all, CupertinoIcons.bookmark, Icons.bookmark_outlined, "Add/Remove Bookmark"),
  SelectMultiple(PlatformSupport.all, CupertinoIcons.checkmark_square, Icons.check_box_outlined, "Select Multiple"),
  MessageInfo(PlatformSupport.all, CupertinoIcons.info, Icons.info, "Message Info"),
  CancelSend(PlatformSupport.all, CupertinoIcons.xmark_circle, Icons.cancel_outlined, "Cancel Send"),
  RefreshPreview(PlatformSupport.all, CupertinoIcons.arrow_clockwise, Icons.refresh, "Refresh Preview");

  const DetailsMenuAction(this.platformSupport, this.iosIcon, this.nonIosIcon, this.text);

  /// [PlatformSupport] flags.
  final int platformSupport;
  final IconData iosIcon;
  final IconData nonIosIcon;
  final String text;

  bool get isPlatformSupported {
    final current = kIsWeb
        ? PlatformSupport.web
        : Platform.isAndroid
        ? PlatformSupport.android
        : Platform.isWindows
        ? PlatformSupport.windows
        : PlatformSupport.linux;
    return platformSupport & current != 0;
  }
}

/// Bit flags for [DetailsMenuAction.platformSupport]; combine with `|`.
abstract final class PlatformSupport {
  static const android = 1 << 0;
  static const windows = 1 << 1;
  static const linux = 1 << 2;
  static const web = 1 << 3;
  static const desktop = windows | linux;
  static const all = android | desktop | web;
}

extension DetailsMenuActionExtension on List<DetailsMenuAction> {
  List<DetailsMenuAction> get platformSupportedActions => where((action) => action.isPlatformSupported).toList();
}

class CustomDetailsMenuActionWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String title;
  final IconData iosIcon;
  final IconData nonIosIcon;
  final bool? shouldDisable;

  const CustomDetailsMenuActionWidget({
    super.key,
    this.onTap,
    required this.title,
    required this.iosIcon,
    required this.nonIosIcon,
    this.shouldDisable,
  });

  @override
  Widget build(BuildContext context) {
    bool isDisabled = shouldDisable ?? false;
    Color color = isDisabled ? Colors.grey : context.theme.colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: ListTile(
          mouseCursor: MouseCursor.defer,
          dense: !kIsDesktop && !kIsWeb,
          title: Text(title, style: context.theme.textTheme.bodyLarge!.copyWith(color: color)),
          trailing: Icon(SettingsSvc.settings.skin.value == Skins.iOS ? iosIcon : nonIosIcon, color: color),
        ),
      ),
    );
  }
}

class DetailsMenuActionWidget extends CustomDetailsMenuActionWidget {
  final DetailsMenuAction action;
  final String? customTitle;
  final bool? shouldDisableBtn;

  DetailsMenuActionWidget({super.key, super.onTap, this.customTitle, required this.action, this.shouldDisableBtn})
    : super(
        title: customTitle ?? action.text,
        iosIcon: action.iosIcon,
        nonIosIcon: action.nonIosIcon,
        shouldDisable: shouldDisableBtn,
      );
}
