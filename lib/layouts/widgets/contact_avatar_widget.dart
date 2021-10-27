import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactAvatarWidgetState {
  MemoryImage? contactImage;
  String? initials;

  ContactAvatarWidgetState({
    this.initials,
    this.contactImage,
  });
}

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key? key,
    this.size,
    this.fontSize,
    this.borderThickness = 2.0,
    this.editable = true,
    this.onTap,
    required this.handle,
  }) : super(key: key);
  final Handle? handle;
  final double? size;
  final double? fontSize;
  final double borderThickness;
  final bool editable;
  final Function? onTap;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> with AutomaticKeepAliveClientMixin {
  ContactAvatarWidgetState? state;
  late List<Color> colors;
  bool requested = false;

  bool get isInvalid => (widget.handle?.address ?? null) == null;

  String get keyPrefix => widget.handle?.address ?? randomString(8);

  @override
  void initState() {
    super.initState();

    state = ContactManager().getState(widget.handle?.address ?? "");

    if (!isInvalid) {
      ContactManager().colorStream.listen((event) {
        if (!event.containsKey(widget.handle?.address)) return;

        Color? color = event[widget.handle?.address];
        if (color == null) {
          colors = toColorGradient(widget.handle!.address);
          widget.handle!.color = null;
        } else {
          colors = [color.lightenAmount(0.02), color];
          widget.handle!.color = color.value.toRadixString(16);
        }

        if (this.mounted) setState(() {});
      });

      ContactManager().stream.listen((event) {
        if (event.any((element) => element == widget.handle?.address)) {
          refresh(force: true);
        }
      });
    }

    refresh();
  }

  Future<void> refresh({bool force = false}) async {
    // Update the colors
    if (widget.handle?.color == null) {
      colors = toColorGradient(widget.handle?.address);
    } else {
      colors = [
        HexColor(widget.handle!.color!).lightenAmount(0.02),
        HexColor(widget.handle!.color!),
      ];
    }

    if (state!.initials != null && (state!.contactImage != null || requested) && !force) return;
    state!.initials = await getInitials(handle: widget.handle);

    Contact? contact = await ContactManager().getCachedContact(widget.handle);
    if (contact == null && !isInvalid) {
      List<Contact> contactRes = [];
      List<Contact> contacts = ContactManager().contacts;
      if (widget.handle!.address.isEmail) {
        contactRes =
            contacts.where((element) => element.emails!.any((e) => e.value == widget.handle!.address)).toList();
      } else {
        contactRes =
            contacts.where((element) => element.phones!.any((e) => e.value == widget.handle!.address)).toList();
      }

      if (contactRes.length > 0) {
        contact = contactRes.first;
        if (isNullOrEmpty(contact.avatar)! && !kIsWeb && !kIsDesktop) {
          contact.avatar =
              await ContactsService.getAvatar(contact, photoHighRes: !SettingsManager().settings.lowMemoryMode.value);
        }
      }
    }

    if (contact != null && contact.avatar != null && contact.avatar!.isNotEmpty && state!.contactImage == null) {
      try {
        state!.contactImage = MemoryImage(contact.avatar!);
      } catch (e) {}
    }

    requested = true;
    if (this.mounted) setState(() {});
  }

  Future<String?> getInitials({Handle? handle, double size = 30}) async {
    if (handle == null) return "Y";
    String? name = (await ContactManager().getContactTitle(handle)) ?? "Unknown Name";
    if (name.isEmail) return name[0].toUpperCase();

    // Check if it's just a regular number, no contact
    if (name.isPhoneNumber) return null;

    List<String> items = name.split(" ").where((element) => element.isNotEmpty).toList();
    switch (items.length) {
      case 1:
        return items[0][0].toUpperCase();
      default:
        if (items.length - 1 < 0 || items[items.length - 1].length < 1) return "";
        String first = items[0][0].toUpperCase();
        String last = items[items.length - 1][0].toUpperCase();
        if (!last.contains(new RegExp('[A-Za-z]'))) last = items[1][0];
        if (!last.contains(new RegExp('[A-Za-z]'))) last = "";
        return first + last;
    }
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
                    await widget.handle!.update();
                    ContactManager().colorStreamObject.sink.add({widget.handle!.address: null});
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

    await widget.handle!.updateColor(widget.handle!.color);

    ContactManager()
        .colorStreamObject
        .sink
        .add({widget.handle!.address: widget.handle?.color == null ? null : HexColor(widget.handle!.color!)});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: onAvatarTap,
      child: Container(
        key: Key("$keyPrefix-avatar-container"),
        width: widget.size ?? 40,
        height: widget.size ?? 40,
        padding: EdgeInsets.all(widget.borderThickness),
        decoration: new BoxDecoration(
          color: SettingsManager().settings.skin.value == Skins.Samsung ? context.theme.accentColor : context.theme.backgroundColor, // border color
          shape: BoxShape.circle,
        ),
        child: Obx(
          () => CircleAvatar(
            key: Key("$keyPrefix-avatar"),
            radius: (widget.size != null) ? widget.size! / 2 : 20,
            backgroundImage:
                !(SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactPhotos.value)
                    ? state!.contactImage
                    : null,
            child: state!.contactImage == null ||
                    (SettingsManager().settings.redactedMode.value &&
                        SettingsManager().settings.hideContactPhotos.value)
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        colors: [
                          !SettingsManager().settings.colorfulAvatars.value
                              ? HexColor("928E8E")
                              : colors.length > 0
                                  ? colors[1]
                                  : HexColor("928E8E"),
                          !SettingsManager().settings.colorfulAvatars.value
                              ? HexColor("686868")
                              : colors.length > 0
                                  ? colors[0]
                                  : HexColor("686868")
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.size ?? 40),
                    ),
                    child: Container(
                      child: (SettingsManager().settings.redactedMode.value &&
                                  SettingsManager().settings.removeLetterAvatars.value) ||
                              state!.initials == null
                          ? Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.person_fill : Icons.person,
                              key: Key("$keyPrefix-avatar-icon"),
                              size: (widget.size ?? 40) / 2,
                            )
                          : Text(
                              state!.initials!,
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
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
