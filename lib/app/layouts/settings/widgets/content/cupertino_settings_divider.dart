import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class CupertinoSettingsDivider extends StatelessWidget {
  const CupertinoSettingsDivider({
    super.key,
    required this.tileColor,
    this.leftPadding = 62.0,
  });

  final Color tileColor;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tileColor,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: SettingsDivider(
            color: context.theme.colorScheme
                .outline.withOpacity(0.5)),
      ),
    );
  }
}
