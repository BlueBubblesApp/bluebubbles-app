import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bluebubbles/app/layouts/conversation_list/widgets/filters/chat_list_filters.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

/// Brings the desktop window to the foreground. On Linux `windowManager.show()` only un-hides a
/// hidden window; a taskbar-minimized window must be restored (deiconified) first — so any handler
/// reacting to a user action (notification/tray click) must call this, not bare `show()`.
Future<void> showAndFocusWindow() async {
  if (await windowManager.isMinimized()) {
    await windowManager.restore();
  }
  await windowManager.show();
  await windowManager.focus();
}

class BackButton extends StatelessWidget {
  final bool Function()? onPressed;
  final Color? color;

  const BackButton({super.key, this.color, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 48,
        child: XGestureDetector(
          supportTouch: true,
          onTap: !kIsDesktop
              ? null
              : (details) {
                  final result = onPressed?.call() ?? false;
                  if (!result) {
                    if (Get.isSnackbarOpen) {
                      Get.closeAllSnackbars();
                    }
                    Navigator.of(context).pop();
                  }
                },
          child: IconButton(
            icon: Obx(() => Icon(
                  SettingsSvc.settings.skin.value != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
                  color: color ?? context.theme.colorScheme.primary,
                )),
            iconSize: SettingsSvc.settings.skin.value != Skins.Material ? 30 : 24,
            onPressed: () {
              if (kIsDesktop) return;
              final result = onPressed?.call() ?? false;
              if (!result) {
                if (Get.isSnackbarOpen) {
                  Get.closeAllSnackbars();
                }
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ),
    );
  }
}

// todo remove
Widget buildBackButton(BuildContext context,
    {EdgeInsets padding = EdgeInsets.zero, double? iconSize, Skins? skin, bool Function()? callback}) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: padding,
      width: 48,
      child: XGestureDetector(
        supportTouch: true,
        onTap: !kIsDesktop
            ? null
            : (details) {
                final result = callback?.call() ?? true;
                if (result) {
                  if (Get.isSnackbarOpen) {
                    Get.closeAllSnackbars();
                  }
                  Navigator.of(context).pop();
                }
              },
        child: IconButton(
          iconSize: iconSize ?? (SettingsSvc.settings.skin.value != Skins.Material ? 30 : 24),
          icon: skin != null
              ? Icon(skin != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
                  color: context.theme.colorScheme.primary)
              : Obx(() => Icon(
                  SettingsSvc.settings.skin.value != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
                  color: context.theme.colorScheme.primary)),
          onPressed: () {
            if (kIsDesktop) return;
            final result = callback?.call() ?? true;
            if (result) {
              if (Get.isSnackbarOpen) {
                Get.closeAllSnackbars();
              }
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    ),
  );
}

/// The empty-state shown in the conversation list when there is nothing to
/// display for the current filter (all chats, archived, unknown senders, or
/// an active [ChatListFilters] chip selection).
Widget buildEmptyChatListState(
  BuildContext context, {
  bool showArchived = false,
  bool showUnknown = false,
  ChatListFilters? filters,
}) {
  final bool hasActiveFilter = filters?.hasActiveFilter ?? false;

  final IconData icon = hasActiveFilter
      ? Icons.filter_list_off_rounded
      : showArchived
          ? Icons.archive_outlined
          : showUnknown
              ? Icons.person_search_rounded
              : Icons.chat_bubble_outline_rounded;
  final String title = hasActiveFilter
      ? "No conversations match your filters"
      : showArchived
          ? "No archived chats"
          : showUnknown
              ? "No messages from unknown senders"
              : "No conversations yet";
  final String? subtitle = hasActiveFilter
      ? null
      : showArchived || showUnknown
          ? null
          : "Tap the compose button to start a new one";

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 48,
        color: context.theme.colorScheme.outline,
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          title,
          style: context.theme.textTheme.titleMedium?.copyWith(
            color: context.theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
      if (hasActiveFilter) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => ChatsSvc.chatListFilters.value = const ChatListFilters(),
          icon: const Icon(Icons.filter_list_off, size: 18),
          label: const Text("Clear Filters"),
        ),
      ],
    ],
  );
}

Widget buildProgressIndicator(BuildContext context, {double size = 20, double strokeWidth = 2}) {
  return SettingsSvc.settings.skin.value == Skins.iOS
      ? CupertinoActivityIndicator(
          radius: size / 2,
          color: ThemeSvc.isAnyMaterialYouSelected
              ? context.theme.colorScheme.primary
              : context.theme.colorScheme.onSurfaceVariant,
        )
      : Container(
          alignment: Alignment.center,
          constraints: BoxConstraints(maxHeight: size, maxWidth: size),
          child: SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(ThemeSvc.isAnyMaterialYouSelected
                  ? context.theme.colorScheme.primary
                  : context.theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
}

Future<void> showConversationTileMenu(
    BuildContext context, ConversationTileController _this, Chat chat, Offset tapPosition, TextTheme textTheme) async {
  bool ios = SettingsSvc.settings.skin.value == Skins.iOS;
  HapticFeedback.mediumImpact();
  await showMenu(
    color: context.theme.colorScheme.surfaceContainerHighest,
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
            onTap: () {
              final chatState = ChatsSvc.getChatState(chat.guid);
              ChatsSvc.setChatPinned(chatState?.chat ?? chat, !chat.isPinned!);
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      chat.isPinned!
                          ? (ios ? CupertinoIcons.pin_slash : Icons.star_outline)
                          : (ios ? CupertinoIcons.pin : Icons.star),
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    chat.isPinned! ? "Unpin" : "Pin",
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
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
            onTap: () {
              chat.toggleMuteAsync(chat.muteType != "mute");
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      chat.muteType == "mute"
                          ? (ios ? CupertinoIcons.bell : Icons.notifications_active)
                          : (ios ? CupertinoIcons.bell_slash : Icons.notifications_off),
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(chat.muteType == "mute" ? 'Show Alerts' : 'Hide Alerts',
                      style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant)),
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
            final chatState = ChatsSvc.getChatState(chat.guid);
            if (chatState != null) {
              ChatsSvc.setChatHasUnread(chatState.chat, !chat.hasUnreadMessage!);
            } else {
              chat.toggleHasUnreadAsync(!chat.hasUnreadMessage!);
            }
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    chat.hasUnreadMessage!
                        ? (ios ? CupertinoIcons.person_crop_circle_badge_xmark : Icons.mark_chat_unread)
                        : (ios ? CupertinoIcons.person_crop_circle_badge_checkmark : Icons.mark_chat_read),
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant)),
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
              ChatsSvc.setChatArchived(chat, !chat.isArchived!);
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      chat.isArchived!
                          ? (ios ? CupertinoIcons.tray_arrow_up : Icons.unarchive)
                          : (ios ? CupertinoIcons.tray_arrow_down : Icons.archive),
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    chat.isArchived! ? 'Unarchive' : 'Archive',
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
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
              Navigator.pop(context); // Remove PopupMenuItem
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Are you sure?",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: Text("This chat will be deleted from this device only",
                        style: context.theme.textTheme.bodyLarge),
                    backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                    actions: <Widget>[
                      TextButton(
                        child: Text("No",
                            style:
                                context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () {
                          Navigator.of(context).pop(); //Remove AlertDialog
                        },
                      ),
                      TextButton(
                        child: Text("Yes",
                            style:
                                context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () async {
                          ChatsSvc.removeChat(chat);
                          ChatsSvc.softDeleteChat(chat);
                          Navigator.pop(context); //Remove AlertDialog
                        },
                      ),
                    ],
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.delete_forever_outlined,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Delete',
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

IconData getAttachmentIcon(String mimeType) {
  final bool isiOS = SettingsSvc.settings.skin.value == Skins.iOS;

  if (mimeType.isEmpty) {
    return isiOS ? CupertinoIcons.arrow_up_right_square : Icons.open_in_new;
  }

  // ── Exact-match for well-known types ──────────────────────────────────────
  switch (mimeType) {
    // Documents
    case "application/pdf":
      return isiOS ? CupertinoIcons.doc_on_doc : Icons.picture_as_pdf;
    case "application/msword":
    case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
      return isiOS ? CupertinoIcons.doc_text : Icons.article;
    case "application/vnd.ms-excel":
    case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
      return isiOS ? CupertinoIcons.table : Icons.table_chart;
    case "application/vnd.ms-powerpoint":
    case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
      return isiOS ? CupertinoIcons.play_rectangle : Icons.slideshow;
    case "application/rtf":
      return isiOS ? CupertinoIcons.doc_plaintext : Icons.text_snippet;
    // Archives
    case "application/zip":
    case "application/x-zip-compressed":
    case "application/x-tar":
    case "application/gzip":
    case "application/x-gzip":
    case "application/x-7z-compressed":
    case "application/x-rar-compressed":
      return isiOS ? CupertinoIcons.archivebox : Icons.folder_zip;
    // Data / code
    case "application/json":
      return isiOS ? CupertinoIcons.doc_text : Icons.data_object;
    case "application/xml":
    case "text/xml":
      return isiOS ? CupertinoIcons.chevron_left_slash_chevron_right : Icons.code;
    case "application/javascript":
    case "text/javascript":
      return isiOS ? CupertinoIcons.chevron_left_slash_chevron_right : Icons.javascript;
    // Contacts / calendar
    case "text/vcard":
    case "text/x-vcard":
      return isiOS ? CupertinoIcons.person_crop_rectangle : Icons.contact_page;
    case "text/calendar":
      return isiOS ? CupertinoIcons.calendar : Icons.event;
    // Fonts
    case "font/ttf":
    case "font/otf":
    case "font/woff":
    case "font/woff2":
      return isiOS ? CupertinoIcons.textformat : Icons.font_download;
    // Audio formats with distinct icons
    case "audio/mpeg":
    case "audio/mp3":
      return isiOS ? CupertinoIcons.music_note : Icons.music_note;
    case "audio/wav":
    case "audio/x-wav":
    case "audio/flac":
    case "audio/x-flac":
      return isiOS ? CupertinoIcons.waveform : Icons.graphic_eq;
    case "audio/aac":
    case "audio/ogg":
    case "audio/caf":
    case "audio/amr":
      return isiOS ? CupertinoIcons.music_note : Icons.audiotrack;
    // Image formats
    case "image/gif":
      return isiOS ? CupertinoIcons.play_rectangle_fill : Icons.gif_box;
    case "image/svg+xml":
      return isiOS ? CupertinoIcons.paintbrush : Icons.draw;
    case "image/heic":
    case "image/heif":
      return isiOS ? CupertinoIcons.photo : Icons.photo;
    // Video formats
    case "video/quicktime":
      return isiOS ? CupertinoIcons.videocam : Icons.movie;
    case "video/x-msvideo": // AVI
    case "video/x-matroska": // MKV
    case "video/webm":
      return isiOS ? CupertinoIcons.videocam : Icons.video_file;
  }

  // ── Category-level fallbacks ───────────────────────────────────────────────
  if (mimeType.startsWith("audio/")) {
    return isiOS ? CupertinoIcons.music_note : Icons.music_note;
  } else if (mimeType.startsWith("image/")) {
    return isiOS ? CupertinoIcons.photo : Icons.photo;
  } else if (mimeType.startsWith("video/")) {
    return isiOS ? CupertinoIcons.videocam : Icons.videocam;
  } else if (mimeType.startsWith("text/")) {
    return isiOS ? CupertinoIcons.doc_text : Icons.description;
  } else if (mimeType.startsWith("font/")) {
    return isiOS ? CupertinoIcons.textformat : Icons.font_download;
  }

  return isiOS ? CupertinoIcons.arrow_up_right_square : Icons.open_in_new;
}

void showSnackbar(String title, String message,
    {int animationMs = 250, int durationMs = 1500, Function(GetSnackBar)? onTap, TextButton? button}) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    colorText: Get.theme.colorScheme.onInverseSurface,
    backgroundColor: Get.theme.colorScheme.inverseSurface,
    margin: const EdgeInsets.only(bottom: 10),
    maxWidth: Get.width - 20,
    isDismissible: false,
    duration: Duration(milliseconds: durationMs),
    animationDuration: Duration(milliseconds: animationMs),
    mainButton: button,
    onTap: onTap ??
        (GetSnackBar bar) {
          if (Get.isSnackbarOpen) Get.back();
        },
  );
}

Future<void> showToast(String message, {bool isError = false}) async {
  if (message.trim().isEmpty) return;
  if (kIsDesktop) {
    showSnackbar(isError ? "Error" : "Notice", message);
    return;
  }
  try {
    await Fluttertoast.showToast(
      msg: message,
      toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  } catch (e, s) {
    Logger.warn("Failed to show toast: $e");
    Logger.debug(s.toString());
  }
}

Widget getSocketStateIndicatorIcon(SocketState socketState, {double size = 24, bool showAlpha = true}) {
  return Icon(Icons.fiber_manual_record,
      color: getIndicatorColor(socketState).withAlpha(showAlpha ? 200 : 255), size: size);
}

Color getIndicatorColor(SocketState socketState) {
  if (socketState == SocketState.connecting || socketState == SocketState.reconnecting) {
    return HexColor('ffd500');
  } else if (socketState == SocketState.connected) {
    return HexColor('32CD32');
  } else {
    return HexColor('DC143C');
  }
}

Future<Uint8List> avatarAsBytes({
  required Chat chat,
  List<Handle>? participantsOverride,
  double quality = 256,
}) async {
  final participants = participantsOverride ?? chat.handles;
  ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  Canvas canvas = Canvas(pictureRecorder);

  await paintGroupAvatar(
      chat: chat,
      participants: participants,
      canvas: canvas,
      size: quality,
      usingParticipantsOverride: participantsOverride != null);

  ui.Picture picture = pictureRecorder.endRecording();
  ui.Image image = await picture.toImage(quality.toInt(), quality.toInt());

  Uint8List bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

  return bytes;
}

Future<void> paintGroupAvatar({
  required Chat chat,
  required List<Handle>? participants,
  required Canvas canvas,
  required double size,
  required bool usingParticipantsOverride,
}) async {
  late final ThemeData theme;
  final bool systemDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  final isAlive = GetIt.I.isRegistered<LifecycleService>() ? GetIt.I<LifecycleService>().isAlive : false;
  // `isAlive` can report true from a headless background isolate (bg_isolate port is
  // registered process-wide) even though that isolate has no Flutter widget tree, so
  // `Get.context` is still null there — guard against it explicitly.
  if (!isAlive || Get.context == null) {
    if (systemDark) {
      theme = ThemeStruct.getDarkTheme().data;
    } else {
      theme = ThemeStruct.getLightTheme().data;
    }
  } else {
    theme = Get.context!.theme;
  }

  if (chat.customAvatarPath != null && !usingParticipantsOverride) {
    Uint8List? customAvatar;
    try {
      customAvatar = await clip(await File(chat.customAvatarPath!).readAsBytes(), size: size.toInt(), circle: true);
    } catch (e, stack) {
      Logger.warn("Failed to load/clip custom avatar!", error: e, trace: stack);
    }
    if (customAvatar != null) {
      canvas.drawImage(await loadImage(customAvatar), const Offset(0, 0), Paint());
      return;
    }
  }

  if (participants == null) return;
  int maxAvatars = SettingsSvc.settings.maxAvatarsInGroupWidget.value;

  if (participants.length == 1) {
    await paintAvatar(
      handle: participants.first,
      canvas: canvas,
      offset: const Offset(0, 0),
      size: size,
    );
    return;
  }

  Color bgColor = theme.colorScheme.surfaceContainerHighest;
  if (kIsDesktop && systemDark && SettingsSvc.settings.useDesktopAccent.value) {
    bgColor = ThemeSvc.desktopAccentColor ?? bgColor;
  }
  Paint paint = Paint()..color = bgColor;
  Offset _offset = Offset(size * 0.5, size * 0.5);
  if (kIsDesktop) {
    canvas.drawCircle(_offset, size * 0.5, paint);
  } else {
    canvas.drawRect(Rect.fromCenter(center: _offset, width: size, height: size), paint);
  }

  int realAvatarCount = min(participants.length, maxAvatars);

  for (int index = 0; index < realAvatarCount; index++) {
    double padding = size * 0.08;
    double angle = index / realAvatarCount * 2 * pi + pi * 0.25;
    double adjustedWidth = size * (-0.07 * realAvatarCount + 1);
    double innerRadius = size - adjustedWidth * 0.5 - 2 * padding;
    double realSize = adjustedWidth * 0.65;
    double top = size * 0.5 + (innerRadius * 0.5) * sin(angle + pi) - realSize * 0.5;
    double left = size * 0.5 - (innerRadius * 0.5) * cos(angle + pi) - realSize * 0.5;

    if (index == maxAvatars - 1 && participants.length > maxAvatars) {
      Paint paint = Paint();
      paint.isAntiAlias = true;
      paint.color = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
      Offset _offset = Offset(left + realSize * 0.5, top + realSize * 0.5);
      double radius = realSize * 0.5;
      canvas.drawCircle(_offset, radius, paint);

      IconData icon = Icons.people;

      TextPainter()
        ..textDirection = TextDirection.rtl
        ..textAlign = TextAlign.center
        ..text = TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
                fontSize: adjustedWidth * 0.3,
                fontFamily: icon.fontFamily,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8)))
        ..layout()
        ..paint(canvas, Offset(left + realSize * 0.25, top + realSize * 0.25));
    } else {
      Paint paint = Paint()
        ..color =
            SettingsSvc.settings.skin.value == Skins.Samsung ? theme.colorScheme.secondary : theme.colorScheme.surface;
      canvas.drawCircle(Offset(left + realSize * 0.5, top + realSize * 0.5), realSize * 0.5, paint);
      await paintAvatar(
        handle: participants[index],
        canvas: canvas,
        offset: Offset(left + realSize * 0.01, top + realSize * 0.01),
        size: realSize * 0.99,
        borderWidth: size * 0.01,
        fontSize: adjustedWidth * 0.3,
        inGroup: true,
      );
    }
  }
}

Future<void> paintAvatar(
    {required Handle? handle,
    required Canvas canvas,
    required Offset offset,
    required double size,
    double? fontSize,
    double? borderWidth,
    bool inGroup = false}) async {
  fontSize ??= size * 0.5;
  borderWidth ??= size * 0.05;

  // Check ContactV2 avatars from disk first (more efficient)
  ContactV2? contactV2 = handle?.contactsV2.firstOrNull;
  if (contactV2?.avatarPath != null) {
    try {
      final avatarBytes = await File(contactV2!.avatarPath!).readAsBytes();
      Uint8List? contactAvatar = await clip(avatarBytes, size: size.toInt(), circle: kIsDesktop || inGroup);
      if (contactAvatar != null) {
        canvas.drawImage(await loadImage(contactAvatar), offset, Paint());
        return;
      }
    } catch (e) {
      // Fall through to old contact or gradient
    }
  }

  List<Color> colors;
  if (handle?.color == null) {
    colors = toColorGradient(handle?.address);
  } else {
    colors = [
      HexColor(handle!.color!).lightenAmount(0.02),
      HexColor(handle.color!),
    ];
  }

  double dx = offset.dx;
  double dy = offset.dy;

  Paint paint = Paint();
  paint.isAntiAlias = true;
  paint.shader =
      ui.Gradient.linear(Offset(dx + size * 0.5, dy + size * 0.5), Offset(size.toDouble(), size.toDouble()), [
    !SettingsSvc.settings.colorfulAvatars.value && SettingsSvc.settings.skin.value == Skins.iOS
        ? HexColor("928E8E")
        : colors.isNotEmpty
            ? colors[1]
            : HexColor("928E8E"),
    !SettingsSvc.settings.colorfulAvatars.value && SettingsSvc.settings.skin.value == Skins.iOS
        ? HexColor("686868")
        : colors.isNotEmpty
            ? colors[0]
            : HexColor("686868"),
  ]);

  Offset _offset = Offset(dx + size * 0.5, dy + size * 0.5);
  double radius = size * 0.5;
  if (kIsDesktop || inGroup) {
    canvas.drawCircle(_offset, radius, paint);
  } else {
    canvas.drawRect(Rect.fromCenter(center: _offset, width: size, height: size), paint);
  }

  String? initials = handle == null ? "Y" : handle.initials;

  if (initials == null) {
    IconData icon = Icons.person;

    TextPainter()
      ..textDirection = TextDirection.rtl
      ..textAlign = TextAlign.center
      ..text = TextSpan(
          text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: fontSize, fontFamily: icon.fontFamily))
      ..layout()
      ..paint(canvas, Offset(dx + size * 0.25, dy + size * 0.25));
  } else {
    TextPainter text = TextPainter()
      ..textDirection = TextDirection.ltr
      ..textAlign = TextAlign.center
      ..text = TextSpan(
        text: initials,
        style: TextStyle(fontSize: fontSize),
      )
      ..layout();

    text.paint(canvas, Offset(dx + (size - text.width) * 0.5, dy + (size - text.height) * 0.5));
  }
}

Future<Uint8List?> clip(Uint8List data, {required int size, required bool circle}) async {
  ui.Image image;
  Uint8List _data = data;

  // Resize the image if it's the wrong size
  img.Image? _image = img.decodeImage(data);
  if (_image != null) {
    _image = img.copyResize(_image, width: size, height: size);

    _data = img.encodePng(_image);
  }

  image = await loadImage(_data);

  ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  Canvas canvas = Canvas(pictureRecorder);
  Paint paint = Paint();
  paint.isAntiAlias = true;

  Rect bounds = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  Path path = circle ? (Path()..addOval(bounds)) : (Path()..addRect(bounds));

  canvas.clipPath(path);

  canvas.drawImage(image, const Offset(0, 0), paint);

  ui.Picture picture = pictureRecorder.endRecording();
  image = await picture.toImage(image.width, image.height);

  Uint8List? bytes = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();

  return bytes;
}

Future<ui.Image> loadImage(Uint8List data) async {
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(data, (ui.Image image) {
    return completer.complete(image);
  });
  return completer.future;
}

@Deprecated('Use showAreYouSure() from dialog_helpers.dart instead')
Widget areYouSure(BuildContext context,
    {Widget? content,
    String? title = "Are you sure?",
    String? noText = "No",
    String? yesText = "Yes",
    Color? noColor,
    Color? yesColor,
    required Function onNo,
    required Function onYes}) {
  return _AreYouSureDialog(
      content: content,
      title: title,
      onNo: onNo,
      onYes: onYes,
      noText: noText,
      yesText: yesText,
      noColor: noColor,
      yesColor: yesColor);
}

class _AreYouSureDialog extends StatefulWidget {
  final Widget? content;
  final String? title;
  final Function onNo;
  final Function onYes;
  final String? noText;
  final String? yesText;
  final Color? noColor;
  final Color? yesColor;

  const _AreYouSureDialog({
    required this.onNo,
    required this.onYes,
    this.noText,
    this.yesText,
    this.noColor,
    this.yesColor,
    this.content,
    this.title,
  });

  @override
  State<_AreYouSureDialog> createState() => _AreYouSureDialogState();
}

class _AreYouSureDialogState extends State<_AreYouSureDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? "Are you sure?", style: context.theme.textTheme.titleLarge),
      content: _loading ? SizedBox(height: 70, child: Center(child: buildProgressIndicator(context))) : widget.content,
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      actions: _loading
          ? null
          : [
              TextButton(
                child: Text(widget.noText ?? "No",
                    style: context.theme.textTheme.bodyLarge!
                        .copyWith(color: widget.noColor ?? context.theme.colorScheme.primary)),
                onPressed: () => widget.onNo.call(),
              ),
              TextButton(
                child: Text(widget.yesText ?? "Yes",
                    style: context.theme.textTheme.bodyLarge!
                        .copyWith(color: widget.yesColor ?? context.theme.colorScheme.primary)),
                onPressed: () async {
                  final result = widget.onYes.call();
                  if (result is Future) {
                    setState(() => _loading = true);
                    await result;
                  }
                },
              ),
            ],
    );
  }
}

extension VideoAspectRatio on VideoController {
  double get aspectRatio {
    Rect? _rect = rect.value;
    if (_rect == null || _rect.height == 0 || _rect.width == 0) return 1;

    return _rect.width / _rect.height;
  }
}

int? findChildIndexByKey<T>(List<T> input, Key key, Function(T) getField) {
  int index = -1;
  if (key is UniqueKey) {
    index = input.indexWhere((item) => getField(item) == key.toString());
  } else if (key is ObjectKey) {
    index = input.indexWhere((item) => getField(item) == key.value);
  } else if (key is GlobalKey) {
    index = input.indexWhere((item) => getField(item) == key.toString());
  } else if (key is ValueKey<String>) {
    index = input.indexWhere((item) => getField(item) == key.value);
  } else if (key is ValueKey<int>) {
    index = input.indexWhere((item) => getField(item) == key.value.toString());
  } else if (key is ValueKey) {
    index = input.indexWhere((item) => getField(item) == key.value);
  }

  return index == -1 ? null : index;
}
