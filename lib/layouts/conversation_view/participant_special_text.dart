import 'package:contacts_service/contacts_service.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

class ParticipantText extends SpecialText {
  final TextEditingController controller;
  final int start;
  final BuildContext context;
  final Contact contact;
  ParticipantText(
    TextStyle textStyle,
    SpecialTextGestureTapCallback onTap, {
    this.start,
    this.controller,
    this.context,
    String startFlag,
    this.contact,
  }) : super(startFlag, " ", textStyle, onTap: onTap);

  @override
  bool isEnd(String value) {
    debugPrint("isEnd: " + value);
    bool isEnd = super.isEnd(value) &&
        contact != null &&
        (value.endsWith(",") || value.endsWith(", "));
    return isEnd;
  }

  // String _getValue(String initial) {
  //   if (contact != null) {
  //     if (contact.phones.length > 0) {
  //       return contact.phones.first.value;
  //     } else if (contact.emails.length > 0) {
  //       return contact.emails.first.value;
  //     }
  //   } else {
  //     return initial;
  //   }
  // }

  @override
  InlineSpan finishText() {
    String text = toString();
    String displayedText = contact.displayName.replaceAll(",", "");

    return ExtendedWidgetSpan(
      actualText: text,
      start: start,
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        child: Padding(
          padding: EdgeInsets.only(right: 5.0, top: 2.0, bottom: 2.0),
          child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(5.0)),
              child: Container(
                padding: EdgeInsets.all(5.0),
                color: Colors.orange,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      displayedText.trim(),
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
                        controller.value = controller.value.copyWith(
                          text: controller.text
                              .replaceRange(start, start + text.length, ""),
                          selection: TextSelection.fromPosition(
                            TextPosition(offset: start),
                          ),
                        );
                      },
                    )
                  ],
                ),
              )),
        ),
        onTap: () {
          showDialog(
              context: context,
              barrierDismissible: true,
              builder: (c) {
                TextEditingController textEditingController =
                    TextEditingController()..text = text.trim();
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Container(),
                    ),
                    Material(
                        child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: TextField(
                        controller: textEditingController,
                        decoration: InputDecoration(
                            suffixIcon: FlatButton(
                          child: Text("OK"),
                          onPressed: () {
                            controller.value = controller.value.copyWith(
                                text: controller.text.replaceRange(
                                    start,
                                    start + text.length,
                                    textEditingController.text + " "),
                                selection: TextSelection.fromPosition(
                                    TextPosition(
                                        offset: start +
                                            (textEditingController.text + " ")
                                                .length)));

                            Navigator.pop(context);
                          },
                        )),
                      ),
                    )),
                    Expanded(
                      child: Container(),
                    )
                  ],
                );
              });
        },
      ),
      deleteAll: true,
    );
  }
}

class ParticipantSpanBuilder extends SpecialTextSpanBuilder {
  ParticipantSpanBuilder(this.controller, this.context, this.contacts);
  final TextEditingController controller;
  final List<Contact> contacts;
  final BuildContext context;
  @override
  SpecialText createSpecialText(String flag,
      {TextStyle textStyle, SpecialTextGestureTapCallback onTap, int index}) {
    if (flag == null || flag == '') {
      return null;
    }

    if (!flag.startsWith(' ')) {
      return ParticipantText(
        textStyle,
        onTap,
        start: index,
        context: context,
        controller: controller,
        startFlag: flag,
        contact: contacts.length > index ? contacts[index] : null,
      );
    }
    return null;
  }
}
