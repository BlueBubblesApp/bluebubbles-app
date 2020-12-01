import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/helpers/utils.dart';

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
        cursorColor: Theme.of(context).primaryColor,
        autofocus: widget.autoFocus,
        decoration: BoxDecoration(
          color: Theme.of(context).accentColor,
          borderRadius: BorderRadius.circular(10),
        ),
        placeholder: "Search",
        placeholderStyle: Theme.of(context).textTheme.bodyText1.apply(
              color: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .color
                  .lightenOrDarken(40),
            ),
        style: Theme.of(context).textTheme.bodyText1,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
    );
  }
}
