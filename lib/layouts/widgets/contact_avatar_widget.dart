import 'dart:async';

import 'package:contacts_service/contacts_service.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/theming/avatar_color_picker_popup.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();

    state = ContactManager().getState(widget.handle?.address ?? "");

    if (!isInvalid) {
      ContactManager().colorStream.listen((event) {
        if (!event.containsKey(widget.handle?.address)) return;

        Color? color = event[widget.handle?.address!];
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
      List<Contact> contacts = ContactManager().contacts ?? [];
      if (widget.handle!.address!.isEmail) {
        contactRes = contacts.where((element) => element.emails!.any((e) => e.value == widget.handle!.address)).toList();
      } else {
        contactRes = contacts.where((element) => element.phones!.any((e) => e.value == widget.handle!.address)).toList();
      }

      if (contactRes.length > 0) {
        contact = contactRes.first;
        if (isNullOrEmpty(contact.avatar)!) {
          contact.avatar = await ContactsService.getAvatar(contact);
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

  void onAvatarTap() {
    if (widget.onTap != null) widget.onTap!();
    if (!widget.editable || !SettingsManager().settings.colorfulAvatars) return;
    showDialog(
      context: context,
      builder: (context) => AvatarColorPickerPopup(
        handle: widget.handle,
        onReset: () async {
          widget.handle!.color = null;
          await widget.handle!.update();
          ContactManager().colorStreamObject.sink.add({widget.handle!.address!: null});
        },
        onSet: (Color? color) async {
          if (color == null) return;

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
              .add({widget.handle!.address!: widget.handle?.color == null ? null : HexColor(widget.handle!.color!)});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Color? color1 = colors.length > 0 ? colors[0] : null;
    Color? color2 = colors.length > 0 ? colors[1] : null;
    if (color1 == null || color2 == null || !SettingsManager().settings.colorfulAvatars) {
      color1 = HexColor("686868");
      color2 = HexColor("928E8E");
    }

    final bool hideLetterAvatars =
        SettingsManager().settings.redactedMode && SettingsManager().settings.removeLetterAvatars;
    final bool hideAvatars = SettingsManager().settings.redactedMode && SettingsManager().settings.hideContactPhotos;

    return GestureDetector(
        onTap: onAvatarTap,
        child: Container(
          width: widget.size ?? 40,
          height: widget.size ?? 40,
          padding: EdgeInsets.all(widget.borderThickness),
          // borde width
          decoration: new BoxDecoration(
            color: Theme.of(context).backgroundColor, // border color
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: (widget.size != null) ? widget.size! / 2 : 20,
            child: state!.contactImage == null || hideAvatars
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        colors: [color2, color1],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Container(
                      child: state!.initials == null || hideLetterAvatars
                          ? Icon(
                              Icons.person,
                              size: (widget.size ?? 40) / 2,
                            )
                          : Text(
                              state!.initials!,
                              style: TextStyle(
                                fontSize: (widget.fontSize == null) ? 18 : widget.fontSize,
                              ),
                              textAlign: TextAlign.center,
                            ),
                      alignment: AlignmentDirectional.center,
                    ),
                  )
                : CircleAvatar(
                    backgroundImage: state!.contactImage,
                  ),
          ),
        ));
  }

  @override
  bool get wantKeepAlive => true;
}
