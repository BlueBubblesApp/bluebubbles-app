import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget(
      {super.key,
      this.size,
      this.fontSize,
      this.borderThickness = 2.0,
      this.editable = true,
      this.handle,
      this.contact,
      this.scaleSize = true,
      this.preferHighResAvatar = false,
      this.padding = EdgeInsets.zero});
  final Handle? handle;
  final Contact? contact;
  final double? size;
  final double? fontSize;
  final double borderThickness;
  final bool editable;
  final bool scaleSize;
  final bool preferHighResAvatar;
  final EdgeInsets padding;

  @override
  State<ContactAvatarWidget> createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends OptimizedState<ContactAvatarWidget> {
  Contact? get contact => widget.contact ?? widget.handle?.contact;
  String get keyPrefix => widget.handle?.address ?? randomString(8);

  @override
  void initState() {
    super.initState();
    eventDispatcher.stream.listen((event) {
      if (event.item1 != 'refresh-avatar') return;
      if (event.item2[0] != widget.handle?.address) return;
      widget.handle?.color = event.item2[1];
      setState(() {});
    });
  }

  void onAvatarTap() async {
    if (!ss.settings.colorfulAvatars.value && !ss.settings.colorfulBubbles.value) return;

    bool didReset = false;
    final Color color = await showColorPickerDialog(
      context,
      widget.handle?.color != null ? HexColor(widget.handle!.color!) : toColorGradient(widget.handle!.address)[0],
      title: Container(
          width: ns.width(context) - 112,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Choose a Color', style: context.theme.textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                didReset = true;
                Get.back();
                widget.handle!.color = null;
                widget.handle!.save(updateColor: true);
                eventDispatcher.emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
              },
              child: const Text("RESET"),
            )
          ])),
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
      constraints: BoxConstraints(minHeight: 480, minWidth: ns.width(context) - 70, maxWidth: ns.width(context) - 70),
    );

    if (didReset) return;

    // Check if the color is the same as the real gradient, and if so, set it to null
    // Because it is not custom, then just use the regular gradient
    List gradient = toColorGradient(widget.handle?.address ?? "");
    if (!isNullOrEmpty(gradient) && gradient[0] == color) {
      widget.handle!.color = null;
    } else {
      widget.handle!.color = color.value.toRadixString(16);
    }

    widget.handle!.save(updateColor: true);

    eventDispatcher.emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
  }

  @override
  Widget build(BuildContext context) {
    Color tileColor =
        ts.inDarkMode(context) ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;

    final size = ((widget.size ?? 40) * (widget.scaleSize ? ss.settings.avatarScale.value : 1)).roundToDouble();
    List<Color> colors = [];
    if (widget.handle?.color == null) {
      colors = toColorGradient(widget.handle?.address);
    } else {
      colors = [
        HexColor(widget.handle!.color!).lightenAmount(0.02),
        HexColor(widget.handle!.color!),
      ];
    }

    return Obx(() => MouseRegion(
          cursor: !widget.editable || !ss.settings.colorfulAvatars.value || widget.handle == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: !widget.editable || (widget.handle == null && contact == null)
                ? null
                : () async {
                    if (contact != null) {
                      await mcs.invokeMethod("view-contact-form", {'id': contact!.id});
                    } else {
                      await mcs.invokeMethod("open-contact-form", {
                        'address': widget.handle!.address,
                        'address_type': widget.handle!.address.isEmail ? 'email' : 'phone'
                      });
                    }
                  },
            onLongPress: !widget.editable || widget.handle == null ? null : onAvatarTap,
            child: Container(
              key: Key("$keyPrefix-avatar-container"),
              width: size,
              height: size,
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    !ss.settings.colorfulAvatars.value ? HexColor("928E8E") : (iOS ? colors[1] : colors[0]),
                    !ss.settings.colorfulAvatars.value ? HexColor("686868") : colors[0]
                  ],
                  stops: [0.3, 0.9],
                ),
                border: Border.all(
                    color: ss.settings.skin.value == Skins.Samsung ? tileColor : context.theme.colorScheme.background,
                    width: widget.borderThickness,
                    strokeAlign: BorderSide.strokeAlignOutside),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: Obx(() {
                final hideContactInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
                final genAvatars = ss.settings.redactedMode.value && ss.settings.generateFakeAvatars.value;
                final iOS = ss.settings.skin.value == Skins.iOS;
                final avatar = contact?.avatar;
                if (!hideContactInfo && widget.handle == null && ss.settings.userAvatarPath.value != null) {
                  dynamic file = File(ss.settings.userAvatarPath.value!);
                  return CircleAvatar(
                    key: ValueKey(ss.settings.userAvatarPath.value!),
                    radius: size / 2,
                    backgroundImage: Image.file(file).image,
                    backgroundColor: Colors.transparent,
                  );
                } else if (isNullOrEmpty(avatar) || hideContactInfo) {
                  String? initials = widget.handle?.initials?.substring(0, iOS ? null : 1);
                  if (!isNullOrEmpty(initials) && !hideContactInfo) {
                    return Text(
                      initials!,
                      key: Key("$keyPrefix-avatar-text"),
                      style: TextStyle(
                        fontSize: (widget.fontSize ?? 18).roundToDouble() * (material ? 1.25 : 1),
                        color: material ? context.theme.colorScheme.background : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    );
                  } else if (genAvatars && widget.handle?.fakeAvatar != null) {
                    return widget.handle!.fakeAvatar;
                  } else if (genAvatars && widget.contact?.fakeAvatar != null) {
                    return widget.contact!.fakeAvatar;
                  } else {
                    return Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: Icon(
                          iOS ? CupertinoIcons.person_fill : Icons.person,
                          color: material ? context.theme.colorScheme.background : Colors.white,
                          key: Key("$keyPrefix-avatar-icon"),
                          size: size / 2 * (material ? 1.25 : 1),
                        ));
                  }
                } else {
                  return SizedBox.expand(
                    child: Image.memory(
                      avatar!,
                      cacheHeight: size.toInt() * 2,
                      cacheWidth: size.toInt() * 2,
                      filterQuality: FilterQuality.none,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  );
                }
              }),
            ),
          ),
        ));
  }
}
