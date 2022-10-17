import 'package:bluebubbles/layouts/widgets/custom_cupertino_text_field.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsTextField extends StatelessWidget {
  const SettingsTextField(
      {Key? key,
        this.onTap,
        required this.title,
        this.trailing,
        required this.controller,
        this.placeholder,
        this.maxLines = 14,
        this.keyboardType = TextInputType.multiline,
        this.inputFormatters = const []})
      : super(key: key);

  final TextEditingController controller;
  final Function? onTap;
  final String title;
  final String? placeholder;
  final Widget? trailing;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: onTap as void Function()?,
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: trailing,
              subtitle: Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: CustomCupertinoTextField(
                  cursorColor: Theme.of(context).primaryColor,
                  onLongPressStart: () {
                    Feedback.forLongPress(context);
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: inputFormatters,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyMedium!.apply(
                      color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      fontSizeDelta: -0.25),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: 1,
                  placeholder: placeholder ?? "Enter your text here",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.labelLarge,
                  autofocus: ss.settings.autoOpenKeyboard.value,
                  decoration: BoxDecoration(
                    color: Theme.of(context).backgroundColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Divider(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
              thickness: 1,
            ),
          ],
        ),
      ),
    );
  }
}
