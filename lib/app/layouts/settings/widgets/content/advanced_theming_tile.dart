import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class AdvancedThemingTile extends StatefulWidget {
  AdvancedThemingTile({super.key, required this.currentTheme, required this.tuple, required this.editable});
  final ThemeStruct currentTheme;
  final Tuple2<MapEntry<String, Color>, MapEntry<String, Color>?> tuple;
  final bool editable;

  @override
  State<AdvancedThemingTile> createState() => _AdvancedThemingTileState();
}

class _AdvancedThemingTileState extends OptimizedState<AdvancedThemingTile> {
  @override
  Widget build(BuildContext context) {
    final textColor = widget.tuple.item2?.value ?? Colors.black;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: widget.tuple.item1.value,
          child: Container(
            decoration: widget.tuple.item1.value.computeDifference(ts.inDarkMode(context)
                || ss.settings.skin.value == Skins.Samsung
                ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface) < 15 ? BoxDecoration(
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
                    if (widget.currentTheme.name == ss.prefs.getString("selected-dark")) {
                      await ts.changeTheme(_context, dark: widget.currentTheme);
                    } else if (widget.currentTheme.name == ss.prefs.getString("selected-light")) {
                      await ts.changeTheme(_context, light: widget.currentTheme);
                    }
                  }
                } else {
                  if (ss.settings.monetTheming.value != Monet.none) {
                    showSnackbar('Notice', "Turn off Material You to start customizing!");
                  } else {
                    showSnackbar('Notice', "Create a new theme to start customizing!");
                  }
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
                    if (widget.currentTheme.name == ss.prefs.getString("selected-dark")) {
                      await ts.changeTheme(_context, dark: widget.currentTheme);
                    } else if (widget.currentTheme.name == ss.prefs.getString("selected-light")) {
                      await ts.changeTheme(_context, light: widget.currentTheme);
                    }
                  }
                } else {
                  if (ss.settings.monetTheming.value != Monet.none) {
                    showSnackbar('Notice', "Turn off Material You to start customizing!");
                  } else {
                    showSnackbar('Notice', "Create a new theme to start customizing!");
                  }
                }
              } : null,
              onDoubleTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        "Info - ${widget.tuple.item1.key} ${widget.tuple.item2 != null ? "/ ${widget.tuple.item2!.key}" : ""}",
                        style: context.theme.textTheme.titleLarge,
                      ),
                      backgroundColor: context.theme.colorScheme.properSurface,
                      content: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                            "${ThemeStruct.colorDescriptions[widget.tuple.item1.key]}${widget.tuple.item2 != null ? "\n\n${ThemeStruct.colorDescriptions[widget.tuple.item2!.key]}" : ""}",
                            style: context.theme.textTheme.bodyLarge),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.color_lens,
                    size: 40,
                    color: textColor.computeDifference(widget.tuple.item1.value) < 15 ? widget.tuple.item1.value.lightenOrDarken(50) : textColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.tuple.item1.key + (widget.tuple.item2 != null ? " / ${widget.tuple.item2!.key}" : ""),
                      style: context.textTheme.titleMedium?.copyWith(color: textColor.computeDifference(widget.tuple.item1.value) < 15 ? widget.tuple.item1.value.lightenOrDarken(20) : textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          )
        )
      ),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Choose a Color', style: Theme.of(context).textTheme.titleLarge)
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
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(newColor);
                },
                child: const Text('SAVE'),
              ),
            ],
          );
        }
    );
  }
}
