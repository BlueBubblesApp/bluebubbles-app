import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';

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
          color: widget.entry.color?.lightenOrDarken(50) ?? whiteLightTheme.accentColor,
          child: InkWell(
            onTap: () async {
              BuildContext _context = context;
              if (widget.editable) {
                final Color color = await showColorPickerDialog(
                  context,
                  widget.entry.color!,
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
                                    widget.entry.fontSize = value.floor();
                                  });
                                },
                                value: widget.entry.fontSize!.toDouble(),
                                min: 5,
                                max: 30,
                                divisions: 25,
                                label: widget.entry.fontSize.toString(),
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
                  constraints: BoxConstraints(
                      minHeight: 480, minWidth: context.width - 70, maxWidth: context.width - 70),
                );
                widget.entry.color = color;
                await widget.entry.save(widget.currentTheme);
                await widget.currentTheme.fetchData();
                if (widget.currentTheme.selectedDarkTheme) {
                  await SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: widget.currentTheme);
                } else if (widget.currentTheme.selectedLightTheme) {
                  await SettingsManager().saveSelectedTheme(_context, selectedLightTheme: widget.currentTheme);
                }
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
        ),
      ),
    );
  }
}
