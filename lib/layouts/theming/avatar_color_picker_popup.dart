import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AvatarColorPickerPopup extends StatefulWidget {
  AvatarColorPickerPopup({Key? key, this.handle, this.onSet, this.onReset}) : super(key: key);
  final Handle? handle;
  final Function(Color? color)? onSet;
  final Function()? onReset;

  @override
  _AvatarColorPickerPopupState createState() => _AvatarColorPickerPopupState();
}

class _AvatarColorPickerPopupState extends State<AvatarColorPickerPopup> {
  Color? currentColor;

  @override
  void initState() {
    super.initState();

    currentColor = Colors.black;
    if (widget.handle!.color != null) {
      currentColor = HexColor(widget.handle!.color!);
    } else {
      List gradient = toColorGradient(widget.handle?.address ?? "");
      if (!isNullOrEmpty(gradient)!) {
        currentColor = gradient[0];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.8),
      title: Text("Choose a new color for this person",
          style: whiteLightTheme.textTheme.headline1!.apply(color: Colors.white)),
      content: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: CustomBouncingScrollPhysics()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
                pickerColor: currentColor!,
                onColorChanged: (Color color) => currentColor = color,
                showLabel: true,
                pickerAreaHeightPercent: 0.8,
                labelTextStyle: whiteLightTheme.textTheme.bodyText1!.apply(color: Colors.white)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text("RESTORE", style: whiteLightTheme.textTheme.bodyText1!.apply(color: Colors.white)),
          onPressed: () {
            widget.onReset!();
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text("OK", style: whiteLightTheme.textTheme.bodyText1!.apply(color: Colors.white)),
          onPressed: () {
            widget.onSet!(currentColor);
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
