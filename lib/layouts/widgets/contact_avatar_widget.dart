import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key key,
    this.size,
    this.fontSize,
    this.color1,
    this.color2,
    @required this.handle,
  }) : super(key: key);
  final Handle handle;
  final double size;
  final double fontSize;
  final Color color1;
  final Color color2;

  @override
  _ContactAvatarWidgetState createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  MemoryImage contactImage;
  String initials;

  bool get isInvalid => (widget.handle?.address ?? null) == null;

  @override
  void initState() {
    super.initState();
    if (isInvalid) return;
    ContactManager().stream.listen((event) {
      for (String address in event) {
        if (address == widget.handle.address) {
          refresh();
          break;
        }
      }
    });
    refresh();
  }

  Future<void> refresh() async {
    if (isInvalid) return;
    initials = await getInitials(handle: widget.handle);
    Contact contact =
        await ContactManager().getCachedContact(widget.handle.address);

    if (contact != null &&
        contact.avatar != null &&
        contact.avatar.isNotEmpty &&
        contactImage == null) {
      try {
        contactImage = MemoryImage(contact.avatar);
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
    if (isInvalid) {
      return Container(
        width: widget.size ?? 40,
        height: widget.size ?? 40,
      );
    }
    Color color1 = widget.color1;
    Color color2 = widget.color2;
    if (color1 == null || color2 == null) {
      color1 = HexColor("686868");
      color2 = HexColor("928E8E");
    }

    return CircleAvatar(
      radius: (widget.size != null) ? widget.size / 2 : 20,
      child: contactImage == null
          ? Container(
              width: widget.size ?? 40,
              height: widget.size ?? 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  colors: [color2, color1],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                child: initials == null
                    ? Icon(Icons.person)
                    : Text(
                        initials,
                        style: TextStyle(
                          fontSize:
                              (widget.fontSize == null) ? 18 : widget.fontSize,
                        ),
                      ),
                alignment: AlignmentDirectional.center,
              ),
            )
          : CircleAvatar(
              backgroundImage: contactImage,
            ),
    );
  }
}
