import 'package:bluebubble_messages/helpers/contstants.dart';
import 'package:bluebubble_messages/layouts/theming/theming_color_selector.dart';
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
