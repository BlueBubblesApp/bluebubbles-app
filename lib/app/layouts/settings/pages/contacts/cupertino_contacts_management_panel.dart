import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

/// iOS skin — plain `SettingsTile`/`SettingsSection` rows, matching
/// `troubleshoot_panel.dart`'s style (no M3E, which is Material/Samsung only).
class CupertinoContactsManagementPanel extends StatelessWidget with ContactsManagementHelpersMixin {
  const CupertinoContactsManagementPanel({super.key, required this.controller});

  final ContactsManagementController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Contacts Management",
      initialHeader: "Permission",
      iosSubtitle: context.iosSubtitle,
      materialSubtitle: context.materialSubtitle,
      tileColor: context.tileColor,
      headerColor: context.headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSection(backgroundColor: context.tileColor, children: [
              Obx(() {
                final status = controller.permissionStatus.value;
                return SettingsTile(
                  leading: SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.person_crop_circle_badge_checkmark,
                    materialIcon: Icons.contacts_rounded,
                    containerColor: status.isGranted ? Colors.green : context.theme.colorScheme.error,
                  ),
                  title: "Contacts Permission: ${permissionStatusLabel(status)}",
                  subtitle: permissionStatusDescription(status),
                  isThreeLine: true,
                  trailing: controller.checkingPermission.value
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: status.isPermanentlyDenied
                              ? openAppSettings
                              : status.isGranted
                                  ? controller.refreshPermissionStatus
                                  : controller.requestPermission,
                          child: Text(
                            status.isPermanentlyDenied ? "Open Settings" : status.isGranted ? "Refresh" : "Grant",
                          ),
                        ),
                );
              }),
            ]),
            SettingsHeader(iosSubtitle: context.iosSubtitle, materialSubtitle: context.materialSubtitle, text: "Sync"),
            SettingsSection(backgroundColor: context.tileColor, children: [
              Obx(() => SettingsTile(
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.refresh,
                      materialIcon: Icons.sync_rounded,
                      containerColor: Colors.blueAccent,
                    ),
                    title: "Refresh Contacts Now",
                    subtitle: "Manually re-sync device contacts and match them to conversations.",
                    trailing: controller.syncing.value ? const CupertinoActivityIndicator() : null,
                    onTap: controller.syncing.value ? null : controller.refreshContactsNow,
                  )),
              if (Platform.isAndroid) ...[
                const SettingsDivider(),
                Obx(() => SettingsSwitch(
                      initialVal: SettingsSvc.settings.syncContactsAutomatically.value,
                      title: "Auto-Sync Contacts",
                      subtitle: "Automatically re-upload contacts to server when changes are detected",
                      backgroundColor: context.tileColor,
                      onChanged: (bool val) async {
                        SettingsSvc.settings.syncContactsAutomatically.value = val;
                        await SettingsSvc.settings.saveOneAsync("syncContactsAutomatically");
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.person_2,
                        materialIcon: Icons.people,
                        containerColor: Colors.green,
                      ),
                    )),
              ],
              if (!kIsWeb && !kIsDesktop) ...[
                const SettingsDivider(),
                SettingsTile(
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.group_solid,
                    materialIcon: Icons.contacts,
                    containerColor: Colors.green,
                  ),
                  title: "Export Contacts",
                  subtitle: "Sync contacts to the desktop app",
                  onTap: () => controller.exportContacts(context),
                ),
              ],
            ]),
            SettingsHeader(
                iosSubtitle: context.iosSubtitle, materialSubtitle: context.materialSubtitle, text: "Sync Info"),
            SettingsSection(backgroundColor: context.tileColor, children: [
              Obx(() => SettingsTile(
                    title: "Device Contacts Found",
                    trailing: Text('${controller.lastDeviceContactCount.value ?? "—"}'),
                  )),
              const SettingsDivider(),
              Obx(() => SettingsTile(
                    title: "Matched To Conversations",
                    trailing: Text('${controller.lastMatchedContactCount.value ?? "—"}'),
                  )),
              const SettingsDivider(),
              Obx(() => SettingsTile(
                    title: "Conversations Updated",
                    trailing: Text('${controller.lastAffectedHandleCount.value ?? "—"}'),
                  )),
            ]),
            SettingsHeader(
                iosSubtitle: context.iosSubtitle,
                materialSubtitle: context.materialSubtitle,
                text: "Sync From Account"),
            Obx(() {
              if (controller.loadingAccounts.value && controller.accounts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }

              return SettingsSection(backgroundColor: context.tileColor, children: [
                SettingsTile(
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.square_grid_2x2,
                    materialIcon: Icons.select_all_rounded,
                    containerColor: Colors.blueAccent,
                  ),
                  title: "All Accounts",
                  subtitle: "Sync contacts from every account on this device (default).",
                  trailing: controller.isAccountSelected(null)
                      ? const Icon(CupertinoIcons.check_mark, color: Colors.blueAccent)
                      : null,
                  onTap: () => controller.selectAccount(null),
                ),
                for (final account in controller.accounts) ...[
                  const SettingsDivider(),
                  SettingsTile(
                    leading: SettingsLeadingIcon(
                      iosIcon: accountIcon(account).icon,
                      materialIcon: accountIcon(account).icon,
                      containerColor: accountIcon(account).color,
                    ),
                    title: accountLabel(account),
                    subtitle: "${accountSubtitle(account)} • ${accountCount(account)} contacts",
                    trailing: controller.isAccountSelected(account)
                        ? const Icon(CupertinoIcons.check_mark, color: Colors.blueAccent)
                        : null,
                    onTap: () => controller.selectAccount(account),
                  ),
                ],
              ]);
            }),
          ]),
        ),
      ],
    );
  }
}
