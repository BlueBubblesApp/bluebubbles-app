import 'dart:typed_data';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
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
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> with AutomaticKeepAliveClientMixin {
  Contact? contact;

  String get keyPrefix => widget.handle?.address ?? randomString(8);

  @override
  void initState() {
    super.initState();
    contact = ContactManager().getContact(widget.handle?.address);
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh-avatar' && event["data"][0] == widget.handle?.address && mounted) {
        print("REFRESHING");
        widget.handle?.color = event['data'][1];
        setState(() {});
      }
    });
  }

  void onAvatarTap() async {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (!widget.editable || !SettingsManager().settings.colorfulAvatars.value || widget.handle == null) return;
    bool didReset = false;
    final Color color = await showColorPickerDialog(
      context,
      widget.handle?.color != null ? HexColor(widget.handle!.color!) : toColorGradient(widget.handle!.address)[0],
      title: Container(
          width: CustomNavigator.width(context) - 112,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Choose a Color',
                    style: Theme.of(context).textTheme.headline6),
                TextButton(
                  onPressed: () async {
                    didReset = true;
                    Get.back();
                    widget.handle!.color = null;
                    widget.handle!.save(updateColor: true);
                    EventDispatcher().emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
                  },
                  child: Text("RESET"),
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
          minHeight: 480, minWidth: CustomNavigator.width(context) - 70, maxWidth: CustomNavigator.width(context) - 70),
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
    super.build(context);
    String? initials = ContactManager().getContactInitials(widget.handle);

    return GestureDetector(
      onTap: onAvatarTap,
      child: Container(
        key: Key("$keyPrefix-avatar-container"),
        width: (widget.size ?? 40) * (widget.scaleSize ? SettingsManager().settings.avatarScale.value : 1),
        height: (widget.size ?? 40) * (widget.scaleSize ? SettingsManager().settings.avatarScale.value : 1),
        padding: EdgeInsets.all(widget.borderThickness),
        decoration: BoxDecoration(
          color: SettingsManager().settings.skin.value == Skins.Samsung ? context.theme.colorScheme.secondary : context.theme.backgroundColor, // border color
          shape: BoxShape.circle,
        ),
        child: Obx(() {
          Uint8List? avatar;
          if (contact?.avatar.value != null || contact?.avatarHiRes.value != null) {
            if (widget.preferHighResAvatar) {
              avatar = contact?.avatarHiRes.value ?? contact?.avatar.value;
            } else {
              avatar = contact?.avatar.value ?? contact?.avatarHiRes.value;
            }
          }

          List<Color> colors = [];
          if (widget.handle?.color == null) {
            colors = toColorGradient(widget.handle?.address);
          } else {
            colors = [
              HexColor(widget.handle!.color!).lightenAmount(0.02),
              HexColor(widget.handle!.color!),
            ];
          }
          return CircleAvatar(
            key: Key("$keyPrefix-avatar"),
            radius: ((widget.size != null) ? widget.size! / 2 : 20) * (widget.scaleSize ? SettingsManager().settings.avatarScale.value : 1),
            backgroundImage:
            !(SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactPhotos.value) && avatar != null
                ? MemoryImage(avatar)
                : null,
            child: avatar == null ||
                (SettingsManager().settings.redactedMode.value &&
                    SettingsManager().settings.hideContactPhotos.value)
                ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    colors: [
                      !SettingsManager().settings.colorfulAvatars.value
                          ? HexColor("928E8E")
                          : colors.isNotEmpty
                          ? colors[1]
                          : HexColor("928E8E"),
                      !SettingsManager().settings.colorfulAvatars.value
                          ? HexColor("686868")
                          : colors.isNotEmpty
                          ? colors[0]
                          : HexColor("686868")
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.size ?? 40),
                ),
                child: Container(
                  child: (SettingsManager().settings.redactedMode.value &&
                      SettingsManager().settings.removeLetterAvatars.value) ||
                      initials == null
                      ? Icon(
                    SettingsManager().settings.skin.value == Skins.iOS
                        ? CupertinoIcons.person_fill
                        : Icons.person,
                    key: Key("$keyPrefix-avatar-icon"),
                    size: ((widget.size ?? 40) / 2) * (widget.scaleSize ? SettingsManager().settings.avatarScale.value : 1),
                  )
                      : Text(
                    initials,
                    key: Key("$keyPrefix-avatar-text"),
                    style: TextStyle(
                      fontSize: widget.fontSize ?? 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  alignment: AlignmentDirectional.center,
                ),
              )
                  : null,
            );
          }
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
