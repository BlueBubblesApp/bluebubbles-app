import 'package:bluebubbles/layouts/conversation_view/participant_special_text.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:rich_input/rich_input.dart';
import 'package:extended_text_field/extended_text_field.dart';

class NewChatCreatorTextField extends StatefulWidget {
  final String createText;
  final Function() onCreate;
  final Function(String) addToParticipants;
  final Function(String) removeParticipant;
  final Function(String) filter;
  NewChatCreatorTextField({
    Key key,
    @required this.createText,
    @required this.onCreate,
    @required this.addToParticipants,
    @required this.removeParticipant,
    @required this.filter,
  }) : super(key: key);

  @override
  _NewChatCreatorTextFieldState createState() =>
      _NewChatCreatorTextFieldState();
}

class _NewChatCreatorTextFieldState extends State<NewChatCreatorTextField> {
  TextEditingController _controller = new TextEditingController();
  String currentText = "";
  List<Contact> participants = [];
  Map<String, Contact> _participants = {};
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String cleansePhoneNumber(String input) {
    String output = input.replaceAll("-", "");
    output = output.replaceAll("(", "");
    output = output.replaceAll(")", "");
    output = output.replaceAll(" ", "");
    return output;
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
                  // widget.filter(null);

                  List<String> participants = val.split(", ");
                  participants.removeLast();
                  String latestParticipant = participants.last;
                  debugPrint("latest participant: " +
                      latestParticipant +
                      ", participants: " +
                      participants.toString());

                  // if (latestParticipant == "") {
                  //   latestParticipant =
                  //       val.split(", ").first.replaceAll(",", "").trim();
                  // }
                  // if (latestParticipant == "") {
                  //   return;
                  // }
                  Contact contact = await tryFindContact(latestParticipant);
                  _participants[latestParticipant] = contact;
                  int indexToStartRemovingAt = val.indexOf(latestParticipant);
                  if (contact == null) {
                    _controller.text = val.substring(0, indexToStartRemovingAt);
                    Scaffold.of(context).showSnackBar(SnackBar(
                      content: Text("Invalid Contact"),
                    ));
                  }
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(
                      offset: _controller.text.length,
                    ),
                  );
                } else {
                  // widget.filter(val.split(", ").last);
                }
                currentText = val;
              },
              controller: _controller,
              // specialTextSpanBuilder:
              //     ParticipantSpanBuilder(_controller, context, participants),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: FlatButton(
              color: Theme.of(context).accentColor,
              onPressed: () {
                widget.onCreate();
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
}
