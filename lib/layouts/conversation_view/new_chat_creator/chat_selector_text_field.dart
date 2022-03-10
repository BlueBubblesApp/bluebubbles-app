import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_custom_cupertino_textfield.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatSelectorTextField extends StatefulWidget {
  ChatSelectorTextField({
    Key? key,
    required this.controller,
    required this.onRemove,
    required this.selectedContacts,
    required this.allContacts,
    required this.isCreator,
    required this.onSelected,
  }) : super(key: key);
  final TextEditingController controller;
  final Function(UniqueContact) onRemove;
  final bool isCreator;
  final List<UniqueContact> selectedContacts;
  final List<UniqueContact> allContacts;
  final Function(UniqueContact item) onSelected;

  @override
  _ChatSelectorTextFieldState createState() => _ChatSelectorTextFieldState();
}

class _ChatSelectorTextFieldState extends State<ChatSelectorTextField> {
  late FocusNode inputFieldNode;

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
    final bool redactedMode = SettingsManager().settings.redactedMode.value;
    final bool hideInfo = redactedMode && SettingsManager().settings.hideContactInfo.value;
    final bool generateName = redactedMode && SettingsManager().settings.generateFakeContactNames.value;
    widget.selectedContacts.forEachIndexed((index, contact) {
      items.add(
        GestureDetector(
          onTap: () {
            widget.onRemove(contact);
          },
          child: Padding(
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
                        generateName
                            ? ContactManager().getContact(contact.address)?.fakeName ?? "Person ${index + 1}"
                            : hideInfo
                                ? "          "
                                : contact.displayName!.trim(),
                        style: Theme.of(context).textTheme.bodyText1),
                    SizedBox(
                      width: 5.0,
                    ),
                    InkWell(
                        child: Icon(
                      SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.xmark : Icons.close,
                      size: 15.0,
                    ))
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

    // Add the next text field
    items.add(
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 255.0),
        child: ContactSelectorCustomCupertinoTextfield(
          cursorColor: Theme.of(context).primaryColor,
          focusNode: inputFieldNode,
          onSubmitted: (String done) async {
            FocusScope.of(context).requestFocus(inputFieldNode);
            if (done.isEmpty) return;
            done = done.trim();
            if (done.isEmail || done.isPhoneNumber) {
              Contact? contact = ContactManager().getContact(done);
              if (contact == null) {
                widget.onSelected(UniqueContact(address: done, displayName: done.isEmail ? done : await formatPhoneNumber(done)));
              } else {
                widget.onSelected(UniqueContact(address: done, displayName: contact.displayName));
              }
            } else {
              if (widget.allContacts.isEmpty) {
                showSnackbar('Error', "Invalid Number/Email, $done");
                // This is 4 chars due to invisible character
              } else if (widget.controller.text.length >= 4) {
                widget.onSelected(widget.allContacts[0]);
              }
            }
          },
          controller: widget.controller,
          maxLength: 50,
          maxLines: 1,
          autocorrect: false,
          placeholder: "  Type a name...",
          placeholderStyle: Theme.of(context).textTheme.subtitle1!,
          padding: EdgeInsets.only(right: 5.0, top: 2.0, bottom: 2.0),
          autofocus: true,
          style: Theme.of(context).textTheme.bodyText1!.apply(
                color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                    ? Colors.black
                    : Colors.white,
                fontSizeDelta: -0.25,
              ),
          decoration: BoxDecoration(
            color: Theme.of(context).backgroundColor,
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(left: 12.0, bottom: 10, top: 10),
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
          // Padding(
          //   padding: EdgeInsets.only(left: 12, right: 10.0),
          //   child: FlatButton(
          //     color: Theme.of(context).colorScheme.secondary,
          //     onPressed: () async {
          //       // widget.onCreate();
          //     },
          //     child: Text(
          //       ChatSelector.of(context).widget.isCreator ? "Create" : "Add",
          //       style: Theme.of(context).textTheme.bodyText1,
          //     ),
          //   ),
          // )
        ],
      ),
    );
  }
}
