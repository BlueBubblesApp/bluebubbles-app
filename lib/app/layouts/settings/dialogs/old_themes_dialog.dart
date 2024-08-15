import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/database.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class OldThemesDialog extends StatelessWidget {
  OldThemesDialog(this.oldThemes, this.clearOld, {super.key});
  // ignore: deprecated_member_use_from_same_package
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
                const Padding(
                  padding: EdgeInsets.all(8.0),
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
                    findChildIndexCallback: (key) => findChildIndexByKey(oldThemes, key, (item) => item.name),
                    itemBuilder: (context, index) {
                      return ListTile(
                        key: ValueKey(oldThemes[index].name),
                        mouseCursor: MouseCursor.defer,
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
                                          findChildIndexCallback: (key) => findChildIndexByKey(ThemeColors.Colors.toList(), key, (item) => item),
                                          itemBuilder: (context, index2) {
                                            final hex = oldThemes[index].entries.firstWhere((element) => element.name == ThemeColors.Colors.reversed.toList()[index2]).color!.hex;
                                            return ListTile(
                                                key: ValueKey(ThemeColors.Colors.reversed.toList()[index2]),
                                                mouseCursor: SystemMouseCursors.click,
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
                                                  if (!Platform.isAndroid || (fs.androidInfo?.version.sdkInt ?? 0) < 33) {
                                                    showSnackbar("Copied", "Hex code copied to clipboard!");
                                                  }
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
              Database.themeObjects.removeAll();
              Database.themeEntries.removeAll();
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
