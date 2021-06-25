import 'package:bluebubbles/helpers/utils.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SearchTextBox extends StatefulWidget {
  SearchTextBox({Key key, this.autoFocus = false}) : super(key: key);
  final bool autoFocus;

  @override
  _SearchTextBoxState createState() => _SearchTextBoxState();
}

class _SearchTextBoxState extends State<SearchTextBox> {
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: "search_text_box",
      child: CupertinoTextField(
        cursorColor: Get.theme.primaryColor,
        autofocus: widget.autoFocus,
        decoration: BoxDecoration(
          color: Get.theme.accentColor,
          borderRadius: BorderRadius.circular(10),
        ),
        placeholder: "Search",
        placeholderStyle: Get.theme.textTheme.bodyText1.apply(
          color: lightenOrDarken(Get.theme.textTheme.bodyText1.color, 40),
        ),
        style: Get.theme.textTheme.bodyText1,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
    );
  }
}
