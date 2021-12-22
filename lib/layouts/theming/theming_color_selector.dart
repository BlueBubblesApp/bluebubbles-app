import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

class ThemingColorSelector extends StatefulWidget {
  ThemingColorSelector({Key? key, required this.currentTheme, required this.entry, required this.editable})
      : super(key: key);
  final ThemeObject currentTheme;
  final ThemeEntry entry;
  final bool editable;

  @override
  _ThemingColorSelectorState createState() => _ThemingColorSelectorState();
}

class _ThemingColorSelectorState extends State<ThemingColorSelector> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: widget.entry.color?.lightenOrDarken(50) ?? whiteLightTheme.colorScheme.secondary,
          child: InkWell(
            onTap: () async {
              BuildContext _context = context;
              if (widget.editable) {
                Color newColor = widget.entry.color!;
                int? fontSize = widget.entry.fontSize;
                int? fontWeight = widget.entry.fontWeight;
                await showDialog(
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
                        heading: StatefulBuilder(
                          builder: (BuildContext context, void Function(void Function()) setState) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.entry.isFont!)
                                    Padding(
                                        padding: EdgeInsets.only(left: 25),
                                        child: Text("Font Size")
                                    ),
                                  if (widget.entry.isFont!)
                                    Slider(
                                      onChanged: (double value) {
                                        setState(() {
                                          fontSize = value.floor();
                                        });
                                      },
                                      value: fontSize!.toDouble(),
                                      min: 5,
                                      max: 30,
                                      divisions: 25,
                                      label: fontSize.toString(),
                                    ),
                                  if (widget.entry.isFont!)
                                    Padding(
                                        padding: EdgeInsets.only(left: 25),
                                        child: Text("Font Weight")
                                    ),
                                  if (widget.entry.isFont!)
                                    Slider(
                                      onChanged: (double value) {
                                        setState(() {
                                          fontWeight = value.floor();
                                        });
                                      },
                                      value: fontWeight!.toDouble(),
                                      min: 1,
                                      max: 9,
                                      divisions: 8,
                                      label: "w" + fontWeight.toString() + "00" + (fontWeight == 4 ? " (Default)" : ""),
                                    ),
                                  if (widget.entry.isFont!)
                                    Padding(
                                        padding: EdgeInsets.only(left: 25, bottom: 10),
                                        child: Text("Color")
                                    ),
                                ]
                            );
                          },
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
                            Navigator.of(context).pop();
                          },
                          child: Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.entry.color = newColor;
                            widget.entry.fontWeight = fontWeight;
                            widget.entry.fontSize = fontSize;
                            widget.entry.save(widget.currentTheme);
                            widget.currentTheme.fetchData();
                            if (widget.currentTheme.selectedDarkTheme) {
                              SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: widget.currentTheme);
                            } else if (widget.currentTheme.selectedLightTheme) {
                              SettingsManager().saveSelectedTheme(_context, selectedLightTheme: widget.currentTheme);
                            }
                          },
                          child: Text('SAVE'),
                        ),
                      ],
                    );
                  }
                );
              } else {
                showSnackbar('Customization', "Please click the edit button to start customizing!");
              }
            },
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.entry.isFont! ? Icons.text_fields : Icons.color_lens,
                    size: 40,
                    color: widget.entry.color,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.entry.name!,
                      style: whiteLightTheme.textTheme.headline2?.copyWith(color: widget.entry.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),),
    );
  }
}
