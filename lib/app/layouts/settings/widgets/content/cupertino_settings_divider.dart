import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class CupertinoSettingsDivider extends StatelessWidget {
  const CupertinoSettingsDivider({
    super.key,
    required this.tileColor,
  });

  final Color tileColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tileColor,
      child: Padding(
        padding:
            const EdgeInsets.only(left: 62.0),
        child: SettingsDivider(
            color: context.theme.colorScheme
                .surfaceVariant),
      ),
    );
  }
}
