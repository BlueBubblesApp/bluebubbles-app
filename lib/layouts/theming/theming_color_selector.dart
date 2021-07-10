import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/theming/theming_color_picker_popup.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:flutter/material.dart';

class ThemingColorSelector extends StatefulWidget {
  ThemingColorSelector({Key? key, required this.currentTheme, required this.entry, required this.editable}) : super(key: key);
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
          color: whiteLightTheme.accentColor,
          child: InkWell(
            onTap: () {
              BuildContext _context = context;
              if (widget.editable!) {
                showDialog(
                  context: context,
                  builder: (context) => ThemingColorPickerPopup(
                    entry: widget.entry,
                    onSet: (Color? color, {int? fontSize}) async {
                      widget.entry!.color = color;
                      if (fontSize != null && widget.entry!.isFont!) {
                        widget.entry!.fontSize = fontSize;
                      }
                      await widget.entry!.save(widget.currentTheme!);
                      await widget.currentTheme!.fetchData();
                      if (widget.currentTheme!.selectedDarkTheme) {
                        await SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: widget.currentTheme);
                      } else if (widget.currentTheme!.selectedLightTheme) {
                        await SettingsManager().saveSelectedTheme(_context, selectedLightTheme: widget.currentTheme);
                      }
                    },
                  ),
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
                    widget.entry!.isFont! ? Icons.text_fields : Icons.color_lens,
                    size: 40,
                    color: widget.entry!.color,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.entry!.name!,
                      style: whiteLightTheme.textTheme.headline2,
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
