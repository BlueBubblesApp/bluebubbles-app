import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theming_panel.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DesktopMenuBar extends StatelessWidget {
  const DesktopMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      color: context.theme.colorScheme.properSurface,
      child: Row(
        children: [
          _buildMenuButton(context, "Server", () {
             ns.pushSettings(context, ServerManagementPanel());
          }),
          _buildMenuButton(context, "Private API", () {
             ns.pushSettings(context, PrivateAPIPanel());
          }),
          _buildMenuButton(context, "Appearance", () {
             ns.pushSettings(context, ThemingPanel());
          }),
          _buildMenuButton(context, "Settings", () {
             ns.pushSettings(context, SettingsPage());
          }),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          title,
          style: context.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
