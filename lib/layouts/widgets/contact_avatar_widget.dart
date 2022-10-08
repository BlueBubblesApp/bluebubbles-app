import 'dart:typed_data';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key? key,
    this.size,
    this.fontSize,
    this.borderThickness = 2.0,
    this.editable = true,
    this.onTap,
    required this.handle,
    this.scaleSize = true,
    this.preferHighResAvatar = false,
  }) : super(key: key);
  final Handle? handle;
  final double? size;
  final double? fontSize;
  final double borderThickness;
  final bool editable;
  final Function? onTap;
  final bool scaleSize;
  final bool preferHighResAvatar;

  @override
  State<ContactAvatarWidget> createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends OptimizedState<ContactAvatarWidget> {
  Contact? contact;

  String get keyPrefix => widget.handle?.address ?? randomString(8);

  @override
  void initState() {
    super.initState();
    contact = ContactManager().getContact(widget.handle?.address);
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh-avatar' && event["data"][0] == widget.handle?.address && mounted) {
        widget.handle?.color = event['data'][1];
        setState(() {});
      }

      if (contact == null && event["type"] == 'update-contacts') {
        contact = ContactManager().getContact(widget.handle?.address);
        setState(() {});
      }
    });
  }

  void onAvatarTap() async {
    if (widget.onTap != null) {
      widget.onTap!.call();
      return;
    }

    if (!widget.editable
        || !SettingsManager().settings.colorfulAvatars.value
        || widget.handle == null) return;

    bool didReset = false;
    final Color color = await showColorPickerDialog(
      context,
      widget.handle?.color != null ? HexColor(widget.handle!.color!) : toColorGradient(widget.handle!.address)[0],
      title: Container(
        width: navigatorService.width(context) - 112,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Choose a Color', style: context.theme.textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                didReset = true;
                Get.back();
                widget.handle!.color = null;
                widget.handle!.save(updateColor: true);
                EventDispatcher().emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
              },
              child: const Text("RESET"),
            )
          ]
        )
      ),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: <ColorPickerType, bool>{
        ColorPickerType.wheel: true,
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        parseShortHexCode: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        dialogActionButtons: true,
      ),
      constraints: BoxConstraints(
          minHeight: 480, minWidth: navigatorService.width(context) - 70, maxWidth: navigatorService.width(context) - 70),
    );

    if (didReset) return;

    // Check if the color is the same as the real gradient, and if so, set it to null
    // Because it is not custom, then just use the regular gradient
    List gradient = toColorGradient(widget.handle?.address ?? "");
    if (!isNullOrEmpty(gradient)! && gradient[0] == color) {
      widget.handle!.color = null;
    } else {
      widget.handle!.color = color.value.toRadixString(16);
    }

    widget.handle!.save(updateColor: true);

    EventDispatcher().emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
  }

  @override
  Widget build(BuildContext context) {
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface
        : context.theme.colorScheme.background;

    final size = (widget.size ?? 40) *
        (widget.scaleSize ? SettingsManager().settings.avatarScale.value : 1);
    List<Color> colors = [];
    if (widget.handle?.color == null) {
      colors = toColorGradient(widget.handle?.address);
    } else {
      colors = [
        HexColor(widget.handle!.color!).lightenAmount(0.02),
        HexColor(widget.handle!.color!),
      ];
    }

    return MouseRegion(
      cursor: !widget.editable
          || !SettingsManager().settings.colorfulAvatars.value
          || widget.handle == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onAvatarTap,
        child: Container(
          key: Key("$keyPrefix-avatar-container"),
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              colors: [
                !SettingsManager().settings.colorfulAvatars.value
                    ? HexColor("928E8E")
                    : colors[1],
                !SettingsManager().settings.colorfulAvatars.value
                    ? HexColor("686868")
                    : colors[0]
              ],
            ),
            border: Border.all(
              color: SettingsManager().settings.skin.value == Skins.Samsung
                ? tileColor
                : context.theme.colorScheme.background,
              width: widget.borderThickness,
              strokeAlign: StrokeAlign.outside
            ),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: Obx(() {
            // don't remove!! needed to prevent Obx from exception
            // improper use of GetX
            // ignore: unused_local_variable
            final placeholderVar = null.obs.value;
            Uint8List? avatar;
            if (contact?.hasAvatar ?? false) {
              if (widget.preferHighResAvatar) {
                avatar = contact?.avatarHiRes.value ?? contact?.avatar.value;
              } else {
                avatar = contact?.avatar.value ?? contact?.avatarHiRes.value;
              }
            }

            if (isNullOrEmpty(avatar)!) {
              String? initials = ContactManager().getContactInitials(widget.handle);
              if (!isNullOrEmpty(initials)!) {
                return Text(
                  initials!,
                  key: Key("$keyPrefix-avatar-text"),
                  style: TextStyle(
                    fontSize: widget.fontSize ?? 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                );
              } else {
                return Icon(
                  SettingsManager().settings.skin.value == Skins.iOS
                      ? CupertinoIcons.person_fill
                      : Icons.person,
                  color: Colors.white,
                  key: Key("$keyPrefix-avatar-icon"),
                  size: size / 2,
                );
              }
            } else {
              return Image.memory(
                avatar!,
                cacheHeight: size.toInt() * 2,
                cacheWidth: size.toInt() * 2,
                filterQuality: FilterQuality.none,
              );
            }
          }),
        ),
      ),
    );
  }
}
