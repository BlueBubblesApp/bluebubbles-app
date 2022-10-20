
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class OldThemesDialog extends StatelessWidget {
  OldThemesDialog(this.oldThemes, this.clearOld, {Key? key}) : super(key: key);
  final List<ThemeObject> oldThemes;
  final Function() clearOld;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Old Themes", style: context.theme.textTheme.titleLarge),
      backgroundColor: context.theme.colorScheme.properSurface,
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                  Text("Tap an old theme to view its colors"),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: context.mediaQuery.size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: oldThemes.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                            oldThemes[index].name ?? "Unknown Theme",
                            style: context.theme.textTheme.bodyLarge),
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text("${oldThemes[index].name ?? "Unknown Theme"} Colors", style: context.theme.textTheme.titleLarge),
                                backgroundColor: context.theme.colorScheme.properSurface,
                                content: SingleChildScrollView(
                                  child: Container(
                                    width: double.maxFinite,
                                    child: StatefulBuilder(builder: (context, setState) {
                                      return ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight: context.mediaQuery.size.height * 0.4,
                                        ),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: 4,
                                          itemBuilder: (context, index2) {
                                            final hex = oldThemes[index].entries.firstWhere((element) => element.name == ThemeColors.Colors.reversed.toList()[index2]).color!.hex;
                                            return ListTile(
                                                title: Text(
                                                    ThemeColors.Colors.reversed.toList()[index2],
                                                    style: context.theme.textTheme.bodyLarge),
                                                subtitle: Text(
                                                  hex,
                                                ),
                                                leading: Container(
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: oldThemes[index].entries.firstWhere((element) => element.name == ThemeColors.Colors.reversed.toList()[index2]).color!
                                                  ),
                                                  height: 30,
                                                  width: 30,
                                                ),
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: hex));
                                                  showSnackbar('Copied', 'Hex code copied to clipboard');
                                                }
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                      child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      }
                                  ),
                                ],
                              )
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
            child: Text("Delete Old", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              themeObjectBox.removeAll();
              themeEntryBox.removeAll();
              clearOld();
              Navigator.of(context).pop();
            }
        ),
        TextButton(
            child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              Navigator.of(context).pop();
            }
        ),
      ],
    );
  }
}
