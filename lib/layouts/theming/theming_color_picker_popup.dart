import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ThemingColorPickerPopup extends StatefulWidget {
  ThemingColorPickerPopup({Key key, this.onSet, this.entry}) : super(key: key);
  final ThemeEntry entry;
  final Function(Color color, {int fontSize}) onSet;

  @override
  _ThemingColorPickerPopupState createState() =>
      _ThemingColorPickerPopupState();
}

class _ThemingColorPickerPopupState extends State<ThemingColorPickerPopup> {
  Color currentColor;
  int currentFontSize;

  @override
  void initState() {
    super.initState();
    currentColor = widget.entry.color;
    if (widget.entry.isFont) currentFontSize = widget.entry.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.8),
      title: Text("Choose a Color",
          style:
              whiteLightTheme.textTheme.headline1.apply(color: Colors.white)),
      content: SingleChildScrollView(
        physics: ThemeSwitcher.getScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
                pickerColor: widget.entry.color,
                onColorChanged: (Color color) => currentColor = color,
                showLabel: true,
                pickerAreaHeightPercent: 0.8,
                labelTextStyle: whiteLightTheme.textTheme.bodyText1
                    .apply(color: Colors.white)),
            if (widget.entry.isFont)
              Text(
                "Font Size",
                style: whiteLightTheme.textTheme.bodyText1
                    .apply(color: Colors.white),
              ),
            if (widget.entry.isFont)
              Slider(
                onChanged: (double value) {
                  setState(() {
                    currentFontSize = value.floor();
                  });
                },
                value: currentFontSize.toDouble(),
                min: 5,
                max: 30,
                divisions: 25,
                label: currentFontSize.toString(),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        FlatButton(
          child: Text("OK",
              style: whiteLightTheme.textTheme.bodyText1
                  .apply(color: Colors.white)),
          onPressed: () {
            widget.onSet(currentColor, fontSize: currentFontSize);
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
