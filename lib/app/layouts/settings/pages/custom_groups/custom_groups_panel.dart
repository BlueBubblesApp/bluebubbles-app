import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/cupertino_custom_groups_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_groups_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/material_custom_groups_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/samsung_custom_groups_panel.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class CustomGroupsPanel extends StatelessWidget {
  const CustomGroupsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CustomGroupsController>()) {
      Get.put(CustomGroupsController(), permanent: kIsDesktop || kIsWeb);
    }
    return const ThemeSwitcher(
      iOSSkin: CupertinoCustomGroupsPanel(),
      materialSkin: MaterialCustomGroupsPanel(),
      samsungSkin: SamsungCustomGroupsPanel(),
    );
  }
}
