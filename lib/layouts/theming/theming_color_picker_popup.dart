import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ThemingColorPickerPopup extends StatefulWidget {
  ThemingColorPickerPopup({Key key, this.initialColor, this.onSet})
      : super(key: key);
  final Color initialColor;
  final Function(Color) onSet;

  @override
  _ThemingColorPickerPopupState createState() =>
      _ThemingColorPickerPopupState();
}

class _ThemingColorPickerPopupState extends State<ThemingColorPickerPopup> {
  Color currentColor;

  @override
  void initState() {
    super.initState();
    currentColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).accentColor,
      title:
          Text("Choose a Color", style: Theme.of(context).textTheme.headline1),
      content: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: ColorPicker(
          pickerColor: widget.initialColor,
          onColorChanged: (Color color) => currentColor = color,
          showLabel: true,
          pickerAreaHeightPercent: 0.8,
        ),
      ),
      actions: <Widget>[
        FlatButton(
          child: Text("OK", style: Theme.of(context).textTheme.bodyText1),
          onPressed: () {
            widget.onSet(currentColor);
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
