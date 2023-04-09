import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';

class BackButton extends StatelessWidget {
  final bool Function()? onPressed;
  final Color? color;

  const BackButton({this.color, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return XGestureDetector(
      onTap: (details) {
        if (!kIsDesktop) return;
        final result = onPressed?.call() ?? false;
        if (!result) {
          while (Get.isOverlaysOpen) {
            Get.back();
          }
          Navigator.of(context).pop();
        }
      },
      child: IconButton(
        icon: Obx(() => Icon(
              ss.settings.skin.value != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
              color: color ?? context.theme.colorScheme.primary,
            )),
        iconSize: ss.settings.skin.value != Skins.Material ? 30 : 24,
        onPressed: () {
          final result = onPressed?.call() ?? false;
          if (!result) {
            while (Get.isOverlaysOpen) {
              Get.back();
            }
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

Widget buildBackButton(BuildContext context, {EdgeInsets padding = EdgeInsets.zero, double? iconSize, Skins? skin, bool Function()? callback}) {
  return Material(
      color: Colors.transparent,
      child: Container(
        padding: padding,
        width: 25,
        child: XGestureDetector(
          onTap: (details) {
            if (!kIsDesktop) return;
            final result = callback?.call() ?? true;
            if (result) {
              while (Get.isOverlaysOpen) {
                Get.back();
              }
              Navigator.of(context).pop();
            }
          },
          child: IconButton(
            iconSize: iconSize ?? (ss.settings.skin.value != Skins.Material ? 30 : 24),
            icon: skin != null
                ? Icon(skin != Skins.Material ? CupertinoIcons.back : Icons.arrow_back, color: context.theme.colorScheme.primary)
                : Obx(() => Icon(ss.settings.skin.value != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
                    color: context.theme.colorScheme.primary)),
            onPressed: () {
              if (kIsDesktop) return;
              final result = callback?.call() ?? true;
              if (result) {
                while (Get.isOverlaysOpen) {
                  Get.back();
                }
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ));
}

Widget buildProgressIndicator(BuildContext context, {double size = 20, double strokeWidth = 2}) {
  return ss.settings.skin.value == Skins.iOS
      ? Theme(
          data: ThemeData(
            cupertinoOverrideTheme:
                CupertinoThemeData(brightness: ThemeData.estimateBrightnessForColor(context.theme.colorScheme.background)),
          ),
          child: CupertinoActivityIndicator(
            radius: size / 2,
          ),
        )
      : Container(
          constraints: BoxConstraints(maxHeight: size, maxWidth: size),
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
          ));
}

Widget buildImagePlaceholder(BuildContext context, Attachment attachment, Widget child, {bool isLoaded = false}) {
  double placeholderWidth = 200;
  double placeholderHeight = 150;

  // If the image doesn't have a valid size, show the loader with static height/width
  if (!attachment.hasValidSize) {
    return Container(
        width: placeholderWidth, height: placeholderHeight, color: context.theme.colorScheme.properSurface, child: child);
  }

  // If we have a valid size, we want to calculate the aspect ratio so the image doesn't "jitter" when loading
  // Calculate the aspect ratio for the placeholders
  double ratio = attachment.aspectRatio;
  double height = attachment.height?.toDouble() ?? placeholderHeight;
  double width = attachment.width?.toDouble() ?? placeholderWidth;

  // YES, this countainer surrounding the AspectRatio is needed.
  // If not there, the box may be too large
  return Container(
      constraints: BoxConstraints(maxHeight: height, maxWidth: width),
      child: AspectRatio(
          aspectRatio: ratio,
          child: Container(width: width, height: height, color: context.theme.colorScheme.properSurface, child: child)));
}

Future<void> showConversationTileMenu(BuildContext context, ConversationTileController _this, Chat chat, Offset tapPosition, TextTheme textTheme) async {
  bool ios = ss.settings.skin.value == Skins.iOS;
  HapticFeedback.mediumImpact();
  await showMenu(
    color: context.theme.colorScheme.properSurface,
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
              chat.togglePin(!chat.isPinned!);
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
                      color: context.theme.colorScheme.properOnSurface,
                    ),
                  ),
                  Text(
                    chat.isPinned! ? "Unpin" : "Pin",
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
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
              chat.toggleMute(chat.muteType != "mute");
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
                      color: context.theme.colorScheme.properOnSurface,
                    ),
                  ),
                  Text(chat.muteType == "mute" ? 'Show Alerts' : 'Hide Alerts', style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
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
            chat.toggleHasUnread(!chat.hasUnreadMessage!);
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
                    color: context.theme.colorScheme.properOnSurface,
                  ),
                ),
                Text(chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread', style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
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
              chat.toggleArchived(!chat.isArchived!);
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
                      color: context.theme.colorScheme.properOnSurface,
                    ),
                  ),
                  Text(
                    chat.isArchived! ? 'Unarchive' : 'Archive',
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
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
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Are you sure?",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: Text(
                        "This chat will be deleted from this device only",
                        style: context.theme.textTheme.bodyLarge
                    ),
                    backgroundColor: context.theme.colorScheme.properSurface,
                    actions: <Widget>[
                      TextButton(
                        child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () async {
                          chats.removeChat(chat);
                          Chat.softDelete(chat);
                          Navigator.pop(context);
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
                      Icons.delete_forever,
                      color: context.theme.colorScheme.properOnSurface,
                    ),
                  ),
                  Text(
                    'Delete',
                    style: textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
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
  if (mimeType.isEmpty) {
    return ss.settings.skin.value == Skins.iOS
        ? CupertinoIcons.arrow_up_right_square
        : Icons.open_in_new;
  }
  if (mimeType == "application/pdf") {
    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.doc_on_doc : Icons.picture_as_pdf;
  } else if (mimeType == "application/zip") {
    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.folder : Icons.folder;
  } else if (mimeType.startsWith("audio")) {
    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.music_note : Icons.music_note;
  } else if (mimeType.startsWith("image")) {
    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.photo : Icons.photo;
  } else if (mimeType.startsWith("video")) {
    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.videocam : Icons.videocam;
  } else if (mimeType.startsWith("text")) {
    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.doc_text : Icons.note;
  }
  return ss.settings.skin.value == Skins.iOS
      ? CupertinoIcons.arrow_up_right_square
      : Icons.open_in_new;
}

void showSnackbar(String title, String message,
    {int animationMs = 250, int durationMs = 1500, Function(GetBar)? onTap, TextButton? button}) {
  Get.snackbar(title, message,
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
              (GetBar bar) {
            if (Get.isSnackbarOpen ?? false) Get.back();
          });
}

Widget getIndicatorIcon(SocketState socketState, {double size = 24, bool showAlpha = true}) {
  if (socketState == SocketState.connecting) {
    return Icon(Icons.fiber_manual_record, color: HexColor('ffd500').withAlpha(showAlpha ? 200 : 255), size: size);
  } else if (socketState == SocketState.connected) {
    return Icon(Icons.fiber_manual_record, color: HexColor('32CD32').withAlpha(showAlpha ? 200 : 255), size: size);
  } else {
    return Icon(Icons.fiber_manual_record, color: HexColor('DC143C').withAlpha(showAlpha ? 200 : 255), size: size);
  }
}

Color getIndicatorColor(SocketState socketState) {
  if (socketState == SocketState.connecting) {
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
  final participants = participantsOverride ?? chat.participants;
  ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  Canvas canvas = Canvas(pictureRecorder);

  await paintGroupAvatar(chat: chat, participants: participants, canvas: canvas, size: quality, usingParticipantsOverride: participantsOverride != null);

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
  final bool systemDark = SchedulerBinding.instance.window.platformBrightness == Brightness.dark;
  if (!ls.isAlive) {
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
    } catch (e) {
      Logger.error(e);
    }
    if (customAvatar != null) {
      canvas.drawImage(await loadImage(customAvatar), const Offset(0, 0), Paint());
      return;
    }
  }

  if (participants == null) return;
  int maxAvatars = ss.settings.maxAvatarsInGroupWidget.value;

  if (participants.length == 1) {
    await paintAvatar(
      handle: participants.first,
      canvas: canvas,
      offset: const Offset(0, 0),
      size: size,
    );
    return;
  }

  Color bgColor = theme.colorScheme.properSurface;
  if (kIsDesktop && systemDark && ss.settings.useWindowsAccent.value && Platform.isWindows) {
    bgColor = ts.windowsAccentColor ?? bgColor;
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
      paint.color = theme.colorScheme.properSurface.withOpacity(0.8);
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
                color: theme.colorScheme.properOnSurface.withOpacity(0.8)))
        ..layout()
        ..paint(canvas, Offset(left + realSize * 0.25, top + realSize * 0.25));
    } else {
      Paint paint = Paint()..color = ss.settings.skin.value == Skins.Samsung
            ? theme.colorScheme.secondary
            : theme.colorScheme.background;
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
      bool inGroup=false}) async {
  fontSize ??= size * 0.5;
  borderWidth ??= size * 0.05;
  Contact? contact = handle?.contact ?? (handle != null ? cs.getContact(handle.address) : null);
  if (contact?.avatar != null) {
    Uint8List? contactAvatar =
    await clip(contact!.avatar ?? contact.avatar!, size: size.toInt(), circle: kIsDesktop || inGroup);
    if (contactAvatar != null) {
      canvas.drawImage(await loadImage(contactAvatar), offset, Paint());
      return;
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
        !ss.settings.colorfulAvatars.value
            ? HexColor("928E8E")
            : colors.isNotEmpty
            ? colors[1]
            : HexColor("928E8E"),
        !ss.settings.colorfulAvatars.value
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
