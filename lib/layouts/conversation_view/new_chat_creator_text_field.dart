import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewChatCreatorTextField extends StatefulWidget {
  final TextEditingController controller;
  final Function onCreate;
  final Function(UniqueContact) onRemove;
  final List<UniqueContact> selectedContacts;
  NewChatCreatorTextField({
    Key key,
    @required this.controller,
    @required this.onCreate,
    @required this.onRemove,
    @required this.selectedContacts
  }) : super(key: key);

  @override
  _NewChatCreatorTextFieldState createState() =>
      _NewChatCreatorTextFieldState();
}

class _NewChatCreatorTextFieldState extends State<NewChatCreatorTextField> {
  FocusNode inputFieldNode;
  
  @override
  void initState() {
    super.initState();
    inputFieldNode = FocusNode();
  }

  @override
  void dispose() {
    inputFieldNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    for (UniqueContact contact in widget.selectedContacts) {
      items.add(
        Padding(
          padding: EdgeInsets.only(right: 5.0, top: 2.0, bottom: 2.0),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            child: Container(
              padding: EdgeInsets.all(5.0),
              color: Theme.of(context).primaryColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    contact.displayName.trim(),
                    //style: textStyle?.copyWith(color: Colors.orange),
                  ),
                  SizedBox(
                    width: 5.0,
                  ),
                  InkWell(
                    child: Icon(
                      Icons.close,
                      size: 15.0,
                    ),
                    onTap: () {
                      widget.onRemove(contact);
                    },
                  )
                ],
              ),
            )
          ),
        )
      );
    }

    // Add the next text field
    items.add(
      SizedBox(
        width: 100.0,
        child: CupertinoTextField(
          focusNode: inputFieldNode,
          onSubmitted: (String done) {
            FocusScope.of(context).requestFocus(inputFieldNode);
            if (done.length == 0) return;
            if (validatePhoneNumber(done)) {
              widget.controller.clear();
              widget.selectedContacts.add(
                new UniqueContact(address: done, displayName: done)
              );
            } else {
              Scaffold.of(context).showSnackBar(SnackBar(
                content: Text("Invalid Number $done"),
                duration: Duration(milliseconds: 500),
              ));
            }
          },
          controller: widget.controller,
          maxLength: 50,
          maxLines: 1,
          autocorrect: false,
          placeholder: "Type a name...",
          padding: EdgeInsets.only(right: 5.0, top: 2.0, bottom: 2.0),
          autofocus: true,
          style: Theme.of(context).textTheme.bodyText2.apply(
            color: ThemeData.estimateBrightnessForColor(
                        Theme.of(context).backgroundColor) ==
                    Brightness.light
                ? Colors.black
                : Colors.white,
            fontSizeDelta: -0.25
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).backgroundColor,
          )
        )
      )
    );

    return Padding(
      padding: EdgeInsets.only(left: 12.0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              "To: ",
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ),
          Flexible(
            flex: 1,
            fit: FlexFit.tight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: items,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12, right: 10.0),
            child: FlatButton(
              color: Theme.of(context).accentColor,
              onPressed: () async {
                widget.onCreate();
              },
              child: Text(
                "Create",
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          )
        ],
      ),
    );
  }
}
