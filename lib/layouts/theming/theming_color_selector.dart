import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubble_messages/helpers/contstants.dart';
import 'package:bluebubble_messages/layouts/theming/theming_color_picker_popup.dart';
import 'package:flutter/material.dart';

class ThemingColorSelector extends StatefulWidget {
  ThemingColorSelector({Key key, this.colorTitle, this.isDarkMode})
      : super(key: key);
  final ThemeColors colorTitle;
  final bool isDarkMode;

  @override
  _ThemingColorSelectorState createState() => _ThemingColorSelectorState();
}

class _ThemingColorSelectorState extends State<ThemingColorSelector> {
  Color getColorForTitle(bool isDarkMode, ThemeColors title) {
    ThemeData theme;
    if (isDarkMode) {
      theme = AdaptiveTheme.of(context).darkTheme;
    } else {
      theme = AdaptiveTheme.of(context).theme;
    }
    switch (title) {
      case ThemeColors.Headline1:
        return theme.textTheme.headline1.color;
      case ThemeColors.Headline2:
        return theme.textTheme.headline2.color;
      case ThemeColors.Bodytext1:
        return theme.textTheme.bodyText1.color;
      case ThemeColors.BodyText2:
        return theme.textTheme.bodyText2.color;
      case ThemeColors.Subtitle1:
        return theme.textTheme.subtitle1.color;
      case ThemeColors.Subtitle2:
        return theme.textTheme.subtitle2.color;
      case ThemeColors.AccentColor:
        return theme.accentColor;
      case ThemeColors.DividerColor:
        return theme.dividerColor;
      case ThemeColors.BackgroundColor:
        return theme.backgroundColor;
    }
  }

  ThemeData themeDataForTitle(ThemeColors title, ThemeData data, Color newVal) {
    switch (title) {
      case ThemeColors.Headline1:
        return data.copyWith(
          textTheme: data.textTheme.copyWith(
            headline1: data.textTheme.headline1.copyWith(color: newVal),
          ),
        );
      case ThemeColors.Headline2:
        return data.copyWith(
          textTheme: data.textTheme.copyWith(
            headline2: data.textTheme.headline1.copyWith(color: newVal),
          ),
        );
      case ThemeColors.Bodytext1:
        return data.copyWith(
          textTheme: data.textTheme.copyWith(
            bodyText1: data.textTheme.headline1.copyWith(color: newVal),
          ),
        );
      case ThemeColors.BodyText2:
        return data.copyWith(
          textTheme: data.textTheme.copyWith(
            bodyText2: data.textTheme.headline1.copyWith(color: newVal),
          ),
        );
      case ThemeColors.Subtitle1:
        return data.copyWith(
          textTheme: data.textTheme.copyWith(
            subtitle1: data.textTheme.headline1.copyWith(color: newVal),
          ),
        );
      case ThemeColors.Subtitle2:
        return data.copyWith(
          textTheme: data.textTheme.copyWith(
            subtitle2: data.textTheme.headline1.copyWith(color: newVal),
          ),
        );
      case ThemeColors.AccentColor:
        return data.copyWith(accentColor: newVal);
      case ThemeColors.DividerColor:
        return data.copyWith(dividerColor: newVal);
      case ThemeColors.BackgroundColor:
        return data.copyWith(backgroundColor: newVal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).accentColor,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => ThemingColorPickerPopup(
              initialColor:
                  getColorForTitle(widget.isDarkMode, widget.colorTitle),
              onSet: (Color color) {
                if (widget.isDarkMode) {
                  AdaptiveTheme.of(context).setTheme(
                    light: AdaptiveTheme.of(context).theme,
                    dark: themeDataForTitle(
                      widget.colorTitle,
                      AdaptiveTheme.of(context).darkTheme,
                      color,
                    ),
                    isDefault: true,
                  );
                } else {
                  AdaptiveTheme.of(context).setTheme(
                    light: themeDataForTitle(
                      widget.colorTitle,
                      AdaptiveTheme.of(context).theme,
                      color,
                    ),
                    dark: AdaptiveTheme.of(context).darkTheme,
                    isDefault: true,
                  );
                }
              },
            ),
          );
        },
        child: ListTile(
          title: Text(
            widget.colorTitle.toString().split(".").last,
            style: Theme.of(context).textTheme.bodyText1,
          ),
          trailing: Icon(
            Icons.color_lens,
            color: getColorForTitle(widget.isDarkMode, widget.colorTitle),
          ),
        ),
      ),
    );
  }
}
