import 'package:bluebubbles/app/components/charts/charts.dart';
import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/contacts/contacts_management_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// Expressive body shared by the Material and Samsung skins — M3E stat tiles
/// for permission/sync status, and `M3ESection`-grouped rows for the sync
/// action and account selector. Same data as the iOS skin, M3E chrome only.
class ContactsExpressiveBody extends StatelessWidget with ContactsManagementHelpersMixin {
  const ContactsExpressiveBody({super.key, required this.controller});

  final ContactsManagementController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            final status = controller.permissionStatus.value;
            return StatTileGrid(
              tiles: [
                M3EStatTile(
                  value: permissionStatusLabel(status),
                  label: "Contacts Permission",
                  icon: status.isGranted ? Icons.check_circle_outline : Icons.error_outline,
                  containerColor: status.isGranted
                      ? context.theme.colorScheme.tertiaryContainer
                      : context.theme.colorScheme.errorContainer,
                  onContainerColor:
                      status.isGranted ? context.theme.colorScheme.onTertiaryContainer : context.theme.colorScheme.onErrorContainer,
                ),
                M3EStatTile(
                  value: '${controller.lastDeviceContactCount.value ?? "—"}',
                  label: "Device Contacts",
                  icon: Icons.contacts_outlined,
                  containerColor: context.theme.colorScheme.primaryContainer,
                  onContainerColor: context.theme.colorScheme.onPrimaryContainer,
                ),
              ],
            );
          }),
          const SizedBox(height: 8),
          Obx(() {
            final status = controller.permissionStatus.value;
            if (status.isGranted) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: M3ETonalButton(
                  icon: status.isPermanentlyDenied ? Icons.settings_outlined : Icons.lock_open_rounded,
                  label: status.isPermanentlyDenied ? "Open Settings" : "Grant Permission",
                  onPressed: controller.checkingPermission.value
                      ? null
                      : status.isPermanentlyDenied
                          ? openAppSettings
                          : controller.requestPermission,
                ),
              ),
            );
          }),
          const M3ESectionHeader(label: "Sync", padding: EdgeInsets.only(left: 4, bottom: 8)),
          Obx(() => M3ESection(
                backgroundColor: context.tileColor,
                children: [
                  M3EListTile(
                    icon: Icons.sync_rounded,
                    title: "Refresh Contacts Now",
                    supportingText: "Manually re-sync device contacts and match them to conversations.",
                    trailing: controller.syncing.value
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                    onTap: controller.syncing.value ? null : controller.refreshContactsNow,
                  ),
                  M3EListTile(
                    icon: Icons.link_rounded,
                    title: "Matched To Conversations",
                    trailing: Text('${controller.lastMatchedContactCount.value ?? "—"}'),
                  ),
                  M3EListTile(
                    icon: Icons.mark_chat_read_outlined,
                    title: "Conversations Updated",
                    trailing: Text('${controller.lastAffectedHandleCount.value ?? "—"}'),
                  ),
                ],
              )),
          const SizedBox(height: 8),
          const M3ESectionHeader(label: "Sync From Account", padding: EdgeInsets.only(left: 4, bottom: 8)),
          Obx(() {
            if (controller.loadingAccounts.value && controller.accounts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return M3ESection(
              backgroundColor: context.tileColor,
              children: [
                M3EListTile(
                  icon: Icons.select_all_rounded,
                  title: "All Accounts",
                  supportingText: "Sync contacts from every account on this device (default).",
                  trailing: controller.isAccountSelected(null)
                      ? Icon(Icons.check_rounded, color: context.theme.colorScheme.primary)
                      : null,
                  onTap: () => controller.selectAccount(null),
                ),
                for (final account in controller.accounts)
                  M3EListTile(
                    icon: Icons.person_outline_rounded,
                    title: accountLabel(account),
                    supportingText: "${accountSubtitle(account)} • ${accountCount(account)} contacts",
                    trailing: controller.isAccountSelected(account)
                        ? Icon(Icons.check_rounded, color: context.theme.colorScheme.primary)
                        : null,
                    onTap: () => controller.selectAccount(account),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
