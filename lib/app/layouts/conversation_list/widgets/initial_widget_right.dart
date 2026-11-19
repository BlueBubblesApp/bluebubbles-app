import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/services/ui/navigator/navigator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart';

class InitialWidgetRight extends StatefulWidget {
  const InitialWidgetRight({super.key});

  @override
  State<StatefulWidget> createState() => _InitialWidgetRightState();
}

class _InitialWidgetRightState extends State<InitialWidgetRight> {
  @override
  Widget build(BuildContext context) {
    // The chat list shows through while a chat slides out
    if (!NavigationSvc.isTabletMode(context)) return const SizedBox.shrink();
    return Obx(
      () => Scaffold(
        backgroundColor: SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
            ? Colors.transparent
            : context.theme.colorScheme.surface,
        extendBodyBehindAppBar: true,
        body: Center(
          child: Text("Select a chat from the list", style: context.theme.textTheme.bodyLarge),
        ),
      ),
    );
  }
}
