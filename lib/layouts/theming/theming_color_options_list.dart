import 'package:bluebubble_messages/helpers/contstants.dart';
import 'package:bluebubble_messages/helpers/themes.dart';
import 'package:bluebubble_messages/layouts/theming/theming_color_selector.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:flutter/material.dart';

class ThemingColorOptionsList extends StatefulWidget {
  ThemingColorOptionsList({Key key, this.isDarkMode}) : super(key: key);
  final bool isDarkMode;

  @override
  _ThemingColorOptionsListState createState() =>
      _ThemingColorOptionsListState();
}

class _ThemingColorOptionsListState extends State<ThemingColorOptionsList> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.all(70),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            child: Container(
              child: Text(
                widget.isDarkMode ? "Dark Theme" : "Light Theme",
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton(
                  isExpanded: false,
                  dropdownColor: Theme.of(context).accentColor,
                  items: widget.isDarkMode
                      ? DarkThemes.values
                          .map<DropdownMenuItem<DarkThemes>>((e) {
                          return DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.toString().split(".").last,
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          );
                        }).toList()
                      : LightThemes.values
                          .map<DropdownMenuItem<LightThemes>>((e) {
                          return DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.toString().split(".").last,
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          );
                        }).toList(),
                  onChanged: (value) {
                    if (widget.isDarkMode) {
                      SettingsManager().settings.darkColorPreset = value;
                      SettingsManager().saveSettings(SettingsManager().settings,
                          context: context);
                    } else {
                      SettingsManager().settings.lightColorPreset = value;
                      SettingsManager().saveSettings(SettingsManager().settings,
                          context: context);
                    }
                  },
                  value: widget.isDarkMode
                      ? SettingsManager().settings.darkPreset
                      : SettingsManager().settings.lightPreset,
                  hint: Text(
                    "Preset",
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return ThemingColorSelector(
                colorTitle: ThemeColors.values[index],
                isDarkMode: widget.isDarkMode,
              );
            },
            childCount: ThemeColors.values.length,
          ),
        )
      ],
    );
  }
}
