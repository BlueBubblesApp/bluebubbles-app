import 'package:bluebubbles/app/layouts/settings/widgets/search/settings_items_actions.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// Owns permission status, the account list with live per-account contact
/// counts, and manual-refresh/sync-stats state for the Contacts Management
/// page. Shared across all three skins (mirrors `StorageAnalyzerController`'s
/// single-instance, untagged pattern).
class ContactsManagementController extends GetxController {
  final Rx<PermissionStatus> permissionStatus = PermissionStatus.denied.obs;
  final RxBool checkingPermission = false.obs;

  final RxList<Map<String, dynamic>> accounts = <Map<String, dynamic>>[].obs;
  final RxBool loadingAccounts = false.obs;

  /// Null means "all accounts" — the default, unfiltered behavior.
  final RxnString selectedAccountName = RxnString();
  final RxnString selectedAccountType = RxnString();

  final RxBool syncing = false.obs;
  final RxnInt lastDeviceContactCount = RxnInt();
  final RxnInt lastMatchedContactCount = RxnInt();
  final RxnInt lastAffectedHandleCount = RxnInt();

  final RxBool uploadingContacts = false.obs;
  final RxnDouble exportProgress = RxnDouble();
  final RxnInt exportTotalSize = RxnInt();

  @override
  void onInit() {
    super.onInit();
    selectedAccountName.value = SettingsSvc.settings.contactSyncAccountName.value;
    selectedAccountType.value = SettingsSvc.settings.contactSyncAccountType.value;
    refreshPermissionStatus();
    refreshAccounts();
  }

  /// Re-checks the OS permission status directly (never shows the OS prompt)
  /// — always live, unlike the resume-time throttled check.
  Future<void> refreshPermissionStatus() async {
    if (kIsWeb || kIsDesktop) return;

    checkingPermission.value = true;
    try {
      await ContactsSvcV2.checkPermissionStatus();
      permissionStatus.value = await Permission.contacts.status;
    } finally {
      checkingPermission.value = false;
    }
  }

  /// Requests the OS permission (shows the system prompt if not yet decided).
  Future<void> requestPermission() async {
    checkingPermission.value = true;
    try {
      await ContactsSvcV2.requestContactPermission();
      permissionStatus.value = await Permission.contacts.status;
    } finally {
      checkingPermission.value = false;
    }
  }

  Future<void> refreshAccounts() async {
    if (kIsWeb || kIsDesktop) return;

    loadingAccounts.value = true;
    try {
      final result = await ContactsSvcV2.getAccountContactCounts();
      accounts.assignAll(result);
    } finally {
      loadingAccounts.value = false;
    }
  }

  bool isAccountSelected(Map<String, dynamic>? account) {
    if (account == null) return selectedAccountName.value == null;
    return selectedAccountName.value == account['name'] && selectedAccountType.value == account['type'];
  }

  /// Selects an account to filter contact sync to, or `null` for "All
  /// accounts" (the default). Persists the choice and immediately re-syncs
  /// so the change takes effect right away.
  Future<void> selectAccount(Map<String, dynamic>? account) async {
    selectedAccountName.value = account?['name'] as String?;
    selectedAccountType.value = account?['type'] as String?;

    SettingsSvc.settings.contactSyncAccountName.value = selectedAccountName.value;
    SettingsSvc.settings.contactSyncAccountType.value = selectedAccountType.value;
    await SettingsSvc.settings.saveManyAsync(['contactSyncAccountName', 'contactSyncAccountType']);

    await refreshContactsNow();
  }

  /// Manually triggers a contact sync and updates the diagnostic counts.
  Future<void> refreshContactsNow() async {
    syncing.value = true;
    try {
      final stats = await ContactsSvcV2.syncContactsToHandlesWithStats();
      lastDeviceContactCount.value = stats['deviceContactCount'] as int?;
      lastMatchedContactCount.value = stats['matchedContactCount'] as int?;
      lastAffectedHandleCount.value = (stats['affectedHandleIds'] as List).length;
      // Per-account counts may have shifted since the last check (e.g. new
      // contacts synced onto an account) — keep the selector's numbers fresh.
      await refreshAccounts();
    } finally {
      syncing.value = false;
    }
  }

  /// Uploads device contacts to the server, showing a progress dialog.
  Future<void> exportContacts(BuildContext context) async {
    await SettingsItemsActions.exportContacts(
      context: context,
      progress: exportProgress,
      totalSize: exportTotalSize,
      uploadingContacts: uploadingContacts,
    );
  }
}
