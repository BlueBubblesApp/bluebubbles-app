import 'package:permission_handler/permission_handler.dart';

/// Shared presentation helpers for the Contacts Management page, mixed into
/// every skin's widgets so status/label formatting stays in one place.
mixin ContactsManagementHelpersMixin {
  String permissionStatusLabel(PermissionStatus status) {
    if (status.isGranted) return "Granted";
    if (status.isPermanentlyDenied) return "Permanently Denied";
    if (status.isRestricted) return "Restricted";
    return "Not Granted";
  }

  String permissionStatusDescription(PermissionStatus status) {
    if (status.isGranted) {
      return "BlueBubbles can read your device's contacts.";
    }
    if (status.isPermanentlyDenied) {
      return "Access was denied and can only be re-enabled from system Settings.";
    }
    return "Grant access to show contact names and photos in your conversations.";
  }

  /// Display label for an account row: `{'name': String, 'type': String, 'count': int}`.
  String accountLabel(Map<String, dynamic> account) => account['name'] as String? ?? 'Unknown account';

  String accountSubtitle(Map<String, dynamic> account) => account['type'] as String? ?? '';

  int accountCount(Map<String, dynamic> account) => account['count'] as int? ?? 0;
}
