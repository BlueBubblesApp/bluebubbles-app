import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Optimized reactive tile for Connection & Server settings
/// Only rebuilds when socket.state changes
class ConnectionServerTile extends StatelessWidget {
  final Color tileColor;

  const ConnectionServerTile({
    super.key,
    required this.tileColor,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      String? subtitle;
      switch (SocketSvc.state.value) {
        case SocketState.connected:
          subtitle = "Connected";
          break;
        case SocketState.disconnected:
          subtitle = "Disconnected";
          break;
        case SocketState.error:
          subtitle = "Error";
          break;
        case SocketState.connecting:
          subtitle = "Connecting";
          break;
        case SocketState.reconnecting:
          subtitle = "Reconnecting";
          break;
      }

      return SettingsTile(
        backgroundColor: tileColor,
        title: "Connection & Server",
        onTap: () {
          NavigationSvc.pushAndRemoveSettingsUntil(
            context,
            ServerManagementPanel(),
            (Route route) => route.isFirst,
          );
        },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: HttpSvc.origin));
          if (!Platform.isAndroid || (FilesystemSvc.androidInfo?.version.sdkInt ?? 0) < 33) {
            showToast("Server address copied to clipboard");
          }
        },
        leading: SettingsLeadingIcon(
          iosIcon: CupertinoIcons.antenna_radiowaves_left_right,
          materialIcon: Icons.router,
          containerColor: getIndicatorColor(SocketSvc.state.value),
          expressive: true,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withAlpha(220)),
            ),
            const SizedBox(width: 5),
            const NextButton(),
          ],
        ),
      );
    });
  }
}
