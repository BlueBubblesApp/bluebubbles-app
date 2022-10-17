import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_custom_cupertino_textfield.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
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
  State<ChatSelectorTextField> createState() => _ChatSelectorTextFieldState();
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
    final bool redactedMode = settings.settings.redactedMode.value;
    final bool hideInfo = redactedMode && settings.settings.hideContactInfo.value;
    final bool generateName = redactedMode && settings.settings.generateFakeContactNames.value;
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
                color: context.theme.colorScheme.primary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                        generateName
                            ? /*ContactManager().getContact(contact.address)?.fakeName ?? */"Person ${index + 1}"
                            : hideInfo
                                ? "          "
                                : contact.displayName!.trim(),
                        style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onPrimary)),
                    SizedBox(
                      width: 5.0,
                    ),
                    InkWell(
                        child: Icon(
                      settings.settings.skin.value == Skins.iOS ? CupertinoIcons.xmark : Icons.close,
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
          cursorColor: context.theme.colorScheme.primary,
          focusNode: inputFieldNode,
          onSubmitted: (String done) async {
            FocusScope.of(context).requestFocus(inputFieldNode);
            if (done.isEmpty) return;
            done = done.trim();
            if (done.isEmail || done.isPhoneNumber) {
              Contact? contact = cs.getContact(done);
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
          placeholderStyle: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
          padding: EdgeInsets.only(right: 5.0, top: 2.0, bottom: 2.0),
          autofocus: true,
          style: context.theme.textTheme.bodyMedium!,
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide.none
            ),
            borderRadius: BorderRadius.circular(20),
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
              style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline),
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
        ],
      ),
    );
  }
}
