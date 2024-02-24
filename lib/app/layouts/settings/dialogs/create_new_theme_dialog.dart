import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateNewThemeDialog extends StatelessWidget {
  CreateNewThemeDialog(this._context, this.isDarkMode, this.currentTheme, this.onComplete, {super.key});
  final BuildContext _context;
  final bool isDarkMode;
  final ThemeStruct currentTheme;
  final Function(ThemeStruct) onComplete;
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.colorScheme.properSurface,
      actions: [
        TextButton(
          child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
          onPressed: () {
            if (ThemeStruct.findOne(controller.text) != null || controller.text.isEmpty) {
              showSnackbar("Error", "Please use a unique name for your new theme");
            } else {
              Navigator.of(kIsDesktop ? context : _context).pop();
              ThemeData finalData = currentTheme.data;
              final tuple = ts.getStructsFromData(finalData, finalData);
              if (isDarkMode) {
                finalData = tuple.item2;
              } else {
                finalData = tuple.item1;
              }
              ThemeStruct newTheme = ThemeStruct(themeData: finalData, name: controller.text);
              onComplete.call(newTheme);
            }
          },
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  ss.settings.skin.value == Skins.iOS
                      ? CupertinoIcons.info
                      : Icons.info_outline,
                  size: 20,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 20),
                Expanded(
                    child: Text(
                      "Your new theme will copy the colors currently displayed in the advanced theming menu",
                      style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                    )
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Theme Name",
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: context.theme.colorScheme.outline,
                  )),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: context.theme.colorScheme.primary,
                  )),
            ),
          ),
        ],
      ),
      title: Text("Create a New Theme", style: context.theme.textTheme.titleLarge),
    );
  }
}
