import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class ThemingColorSelector extends StatefulWidget {
  ThemingColorSelector({Key? key, required this.currentTheme, required this.tuple, required this.editable})
      : super(key: key);
  final ThemeStruct currentTheme;
  final Tuple2<MapEntry<String, Color>, MapEntry<String, Color>?> tuple;
  final bool editable;

  @override
  State<ThemingColorSelector> createState() => _ThemingColorSelectorState();
}

class _ThemingColorSelectorState extends State<ThemingColorSelector> {
  @override
  Widget build(BuildContext context) {
    final textColor = widget.tuple.item2?.value ?? whiteLightTheme.textTheme.titleMedium?.color;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: widget.tuple.item1.value,
          child: Container(
            decoration: widget.tuple.item1.value.computeDifference(context.theme.colorScheme.background) < 15 ? BoxDecoration(
              border: Border.all(width: 0.5, color: context.theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(20)
            ) : null,
            child: InkWell(
              onTap: () async {
                BuildContext _context = context;
                if (widget.editable) {
                  final result = await showThemeDialog(widget.tuple.item1.value);
                  if (result != null) {
                    final map = widget.currentTheme.toMap();
                    map["data"]["colorScheme"][widget.tuple.item1.key] = result.value;
                    widget.currentTheme.data = ThemeStruct.fromMap(map).data;
                    widget.currentTheme.save();
                    if (widget.currentTheme.name == prefs.getString("selected-dark")) {
                      SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: widget.currentTheme);
                    } else if (widget.currentTheme.name == prefs.getString("selected-light")) {
                      SettingsManager().saveSelectedTheme(_context, selectedLightTheme: widget.currentTheme);
                    }
                  }
                } else {
                  showSnackbar('Customization', "Please click the edit button to start customizing!");
                }
              },
              onLongPress: widget.tuple.item2 != null ? () async {
                BuildContext _context = context;
                if (widget.editable) {
                  final result = await showThemeDialog(widget.tuple.item2!.value);
                  if (result != null) {
                    final map = widget.currentTheme.toMap();
                    map["data"]["colorScheme"][widget.tuple.item2!.key] = result.value;
                    widget.currentTheme.data = ThemeStruct.fromMap(map).data;
                    widget.currentTheme.save();
                    if (widget.currentTheme.name == prefs.getString("selected-dark")) {
                      SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: widget.currentTheme);
                    } else if (widget.currentTheme.name == prefs.getString("selected-light")) {
                      SettingsManager().saveSelectedTheme(_context, selectedLightTheme: widget.currentTheme);
                    }
                  }
                } else {
                  showSnackbar('Customization', "Please click the edit button to start customizing!");
                }
              } : null,
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.color_lens,
                      size: 40,
                      color: textColor!.computeDifference(widget.tuple.item1.value) < 15 ? widget.tuple.item1.value.lightenOrDarken(50) : textColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        widget.tuple.item1.key + (widget.tuple.item2 != null ? " / ${widget.tuple.item2!.key}" : ""),
                        style: whiteLightTheme.textTheme.titleMedium?.copyWith(color: textColor.computeDifference(widget.tuple.item1.value) < 15 ? widget.tuple.item1.value.lightenOrDarken(20) : textColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ),),
    );
  }

  Future<Color?> showThemeDialog(Color newColor) async {
    return await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            scrollable: true,
            content: ColorPicker(
              color: newColor,
              onColorChanged: (color) {
                newColor = color;
              },
              title: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Choose a Color',
                      style: Theme.of(context).textTheme.headline6)
              ),
              width: 40,
              height: 40,
              spacing: 0,
              runSpacing: 0,
              borderRadius: 0,
              wheelDiameter: 165,
              enableOpacity: false,
              showColorCode: true,
              colorCodeHasColor: true,
              pickersEnabled: <ColorPickerType, bool>{
                ColorPickerType.wheel: true,
              },
              copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                parseShortHexCode: true,
              ),
              actionButtons: const ColorPickerActionButtons(
                dialogActionButtons: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(newColor);
                },
                child: Text('SAVE'),
              ),
            ],
          );
        }
    );
  }
}
