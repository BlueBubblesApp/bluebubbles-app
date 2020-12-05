import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class ContactAvatarWidgetState {
  MemoryImage contactImage;
  String initials;
  ContactAvatarWidgetState({
    this.initials,
    this.contactImage,
  });
}

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key key,
    this.size,
    this.fontSize,
    this.borderThickness = 2.0,
    @required this.handle,
  }) : super(key: key);
  final Handle handle;
  final double size;
  final double fontSize;
  final double borderThickness;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget>
    with AutomaticKeepAliveClientMixin {
  ContactAvatarWidgetState state;
  List<Color> colors;

  bool get isInvalid => (widget.handle?.address ?? null) == null;

  @override
  void initState() {
    super.initState();
    if (isInvalid) return;

    state = ContactManager().getState(widget.handle.address);
    colors = toColorGradient(widget.handle.address);

    ContactManager().stream.listen((event) {
      if (event.any((element) => element == widget?.handle?.address)) {
        refreshInitials(force: true);
      }
    });
    refreshInitials();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshInitials({bool force = false}) async {
    if (isInvalid) return;
    if (state.initials != null && !force) return;
    state.initials = await getInitials(handle: widget.handle);

    Contact contact =
        await ContactManager().getCachedContact(widget.handle.address);

    if (contact != null &&
        contact.avatar != null &&
        contact.avatar.isNotEmpty &&
        state.contactImage == null) {
      try {
        state.contactImage = MemoryImage(contact.avatar);
      } catch (e) {}
    }
    if (this.mounted) setState(() {});
  }

  Future<String> getInitials({Handle handle, double size = 30}) async {
    if (handle == null) return null;
    String name = await ContactManager().getContactTitle(handle.address);
    if (name.contains("@")) return name[0].toUpperCase();

    // If the name is a phone number, return the "person" icon
    if (name.startsWith("+")) return null;

    List<String> items =
        name.split(" ").where((element) => element.isNotEmpty).toList();
    switch (items.length) {
      case 1:
        return items[0][0].toUpperCase();
        break;
      default:
        if (items.length - 1 < 0 || items[items.length - 1].length < 1)
          return "";
        String first = items[0][0].toUpperCase();
        String last = items[items.length - 1][0].toUpperCase();
        if (!last.contains(new RegExp('[A-Za-z]'))) last = items[1][0];
        if (!last.contains(new RegExp('[A-Za-z]'))) last = "";
        return first + last;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isInvalid) {
      return Container(
        width: widget.size ?? 40,
        height: widget.size ?? 40,
      );
    }
    Color color1 = colors.length > 0 ? colors[0] : null;
    Color color2 = colors.length > 0 ? colors[1] : null;
    if (color1 == null ||
        color2 == null ||
        !SettingsManager().settings.colorfulAvatars) {
      color1 = HexColor("686868");
      color2 = HexColor("928E8E");
    }

    return Container(
      width: widget.size ?? 40,
      height: widget.size ?? 40,
      padding: EdgeInsets.all(widget.borderThickness), // borde width
      decoration: new BoxDecoration(
        color: Theme.of(context).backgroundColor, // border color
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: (widget.size != null) ? widget.size / 2 : 20,
        child: state.contactImage == null
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    colors: [color2, color1],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Container(
                  child: state.initials == null
                      ? Icon(
                          Icons.person,
                          size: (widget.size ?? 40) / 2,
                        )
                      : Text(
                          state.initials,
                          style: TextStyle(
                            fontSize: (widget.fontSize == null)
                                ? 18
                                : widget.fontSize,
                          ),
                          textAlign: TextAlign.center,
                        ),
                  alignment: AlignmentDirectional.center,
                ),
              )
            : CircleAvatar(
                backgroundImage: state.contactImage,
              ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
