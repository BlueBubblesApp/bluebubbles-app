import 'package:flutter/material.dart';

class ThemingColorSelector extends StatefulWidget {
  ThemingColorSelector({Key key}) : super(key: key);

  @override
  _ThemingColorSelectorState createState() => _ThemingColorSelectorState();
}

class _ThemingColorSelectorState extends State<ThemingColorSelector> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).accentColor,
        borderRadius: BorderRadius.circular(40),
      ),
      height: 100,
      width: MediaQuery.of(context).size.width * 1 / 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[],
      ),
    );
  }
}
