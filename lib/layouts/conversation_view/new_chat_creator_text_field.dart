import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/participant_special_text.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:extended_text_field/extended_text_field.dart';

class NewChatCreatorTextField extends StatefulWidget {
  final String createText;
  final Function(List<Contact>) onCreate;
  final Function(String) filter;
  final TextEditingController controller;
  NewChatCreatorTextField({
    Key key,
    @required this.createText,
    @required this.onCreate,
    @required this.filter,
    @required this.controller,
  }) : super(key: key);

  @override
  _NewChatCreatorTextFieldState createState() =>
      _NewChatCreatorTextFieldState();
}

class _NewChatCreatorTextFieldState extends State<NewChatCreatorTextField> {
  String currentText = "";
  Map<String, Contact> _participants = {};
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  Future<Contact> tryFindContact(String value) async {
    for (Contact contact in ContactManager().contacts) {
      if (contact.displayName.toLowerCase().trim() ==
          value.toLowerCase().trim()) {
        return contact;
      } else {
        for (Item phone in contact.phones) {
          if (cleansePhoneNumber(phone.value) == cleansePhoneNumber(value)) {
            return contact;
          }
        }
        for (Item email in contact.emails) {
          if (cleansePhoneNumber(email.value) == cleansePhoneNumber(value)) {
            return contact;
          }
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12.0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 14),
            child: Text(
              "To: ",
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ),
          Flexible(
            child: ExtendedTextField(
              autofocus: true,
              autocorrect: false,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyText1,
              onChanged: (String val) async {
                if (val.endsWith(",") || val.endsWith(", ")) {
                  await _getParticipantsFromText(val);
                } else {
                  widget.filter(val.split(",").last.trim());
                }
                currentText = val;
              },
              controller: widget.controller,
              specialTextSpanBuilder: ParticipantSpanBuilder(
                widget.controller,
                context,
                _participants,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: FlatButton(
              color: Theme.of(context).accentColor,
              onPressed: () async {
                await _getParticipantsFromText(widget.controller.text);
                widget.onCreate(_participants.values.toList());
              },
              child: Text(
                widget.createText,
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _getParticipantsFromText(String val) async {
    List<String> participants = val.split(", ");
    participants.removeWhere((element) => element == " " || element == "");
    _participants = new Map();
    for (String participant in participants) {
      Contact contact = await tryFindContact(participant);
      if (contact != null) {
        _participants[participant] = contact;
      } else {
        //this is just to ensure that if there is a space after the comma, we remove that first
        widget.controller.text =
            widget.controller.text.replaceAll(participant + ", ", "");

        //if the comma with space after it wasn't found, then we do this
        widget.controller.text =
            widget.controller.text.replaceAll(participant + ",", "");
        if (participant.length > 1) {
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Invalid Contact " + participant),
          ));
        }
      }
    }

    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(
        offset: widget.controller.text.length,
      ),
    );
    setState(() {});
    widget.filter("");
  }
}
