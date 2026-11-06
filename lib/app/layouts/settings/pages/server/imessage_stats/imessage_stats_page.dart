import 'package:bluebubbles/app/layouts/settings/pages/server/imessage_stats/cupertino_imessage_stats_page.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/imessage_stats/material_imessage_stats_page.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/imessage_stats/samsung_imessage_stats_page.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:flutter/material.dart';

class IMessageStatsPage extends CustomStateful<ServerManagementPanelController> {
  const IMessageStatsPage({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _IMessageStatsPageState();
}

class _IMessageStatsPageState extends CustomState<IMessageStatsPage, void, ServerManagementPanelController> {
  @override
  void initState() {
    super.initState();
    forceDelete = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadSelectedStatsIfEmpty());
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: CupertinoIMessageStatsPage(parentController: controller),
      materialSkin: MaterialIMessageStatsPage(parentController: controller),
      samsungSkin: SamsungIMessageStatsPage(parentController: controller),
    );
  }
}
