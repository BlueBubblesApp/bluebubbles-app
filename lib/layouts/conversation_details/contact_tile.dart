import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:intent/intent.dart' as android_intent;
import 'package:intent/action.dart' as android_action;
import 'package:permission_handler/permission_handler.dart';

class ContactTile extends StatefulWidget {
  final Contact contact;
  final Handle handle;
  ContactTile({
    Key key,
    this.contact,
    this.handle,
  }) : super(key: key);

  @override
  _ContactTileState createState() => _ContactTileState();
}

class _ContactTileState extends State<ContactTile> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (widget.contact == null) {
          await ContactsService.openContactForm();
        } else {
          await ContactsService.openExistingContact(widget.contact);
        }
      },
      child: ListTile(
        title: Text(
          widget.contact != null
              ? widget.contact.displayName
              : widget.handle.address,
          style: TextStyle(color: Colors.white),
        ),
        trailing: SizedBox(
          width: MediaQuery.of(context).size.width / 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ButtonTheme(
                minWidth: 1,
                child: RaisedButton(
                  shape: CircleBorder(),
                  color: HexColor('26262a'),
                  onPressed: () async {
                    if (widget.contact != null &&
                        widget.contact.phones.length > 0) {
                      if (await Permission.phone.request().isGranted) {
                        android_intent.Intent()
                          ..setAction(android_action.Action.ACTION_CALL)
                          ..setData(Uri(
                              scheme: "tel",
                              path: widget.contact.phones.first.value))
                          ..startActivity().catchError((e) => print(e));
                      }
                    }
                  },
                  child: Icon(
                    Icons.call,
                    color: Colors.blue,
                  ),
                ),
              ),
              ButtonTheme(
                minWidth: 1,
                child: RaisedButton(
                  shape: CircleBorder(),
                  color: HexColor('26262a'),
                  onPressed: () {},
                  child: Icon(
                    Icons.videocam,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
