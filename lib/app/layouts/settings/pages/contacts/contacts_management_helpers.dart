import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Icon + brand color for a device contacts account, keyed by Android
/// account type (package name).
class ContactAccountIcon {
  final IconData icon;
  final Color color;
  const ContactAccountIcon(this.icon, this.color);
}

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

  int accountCount(Map<String, dynamic> account) => account['count'] as int? ?? 0;

  static const ContactAccountIcon _defaultAccountIcon = ContactAccountIcon(Icons.person_outline_rounded, Colors.blueGrey);

  /// Icon/color keyed by a prefix of the Android account type (package
  /// name). Checked in order — more specific prefixes must come before
  /// broader ones that would otherwise swallow them (e.g. the Google Meet
  /// package contains `com.google`, and Outlook contains `com.microsoft`,
  /// so both specific entries are listed first).
  static const Map<String, ContactAccountIcon> _accountIconsByType = {
    // Google Meet (still shipped as the old Duo package name) before the
    // generic Google entry, which would otherwise match it first.
    'com.google.android.apps.tachyon': ContactAccountIcon(Icons.duo_rounded, Color(0xFF00AC47)),
    'com.google': ContactAccountIcon(Icons.g_mobiledata_rounded, Color(0xFF4285F4)),
    'com.whatsapp': ContactAccountIcon(Icons.chat_rounded, Color(0xFF25D366)),
    'org.thoughtcrime.securesms': ContactAccountIcon(Icons.forum_rounded, Color(0xFF3A76F0)),
    'com.facebook': ContactAccountIcon(Icons.facebook_rounded, Color(0xFF1877F2)),
    'org.telegram.messenger': ContactAccountIcon(Icons.telegram_rounded, Color(0xFF26A5E4)),
    'com.discord': ContactAccountIcon(Icons.discord_rounded, Color(0xFF5865F2)),
    'com.snapchat.android': ContactAccountIcon(Icons.snapchat_rounded, Color(0xFFFFFC00)),
    'com.skype.raider': ContactAccountIcon(Icons.video_call_rounded, Color(0xFF00AFF0)),
    'com.viber.voip': ContactAccountIcon(Icons.phone_in_talk_rounded, Color(0xFF7360F2)),
    'com.tencent.mm': ContactAccountIcon(Icons.wechat_rounded, Color(0xFF07C160)),
    'jp.naver.line.android': ContactAccountIcon(Icons.chat_bubble_rounded, Color(0xFF06C755)),
    'com.linkedin.android': ContactAccountIcon(Icons.business_center_rounded, Color(0xFF0A66C2)),
    'com.yahoo.mobile.client.android.mail': ContactAccountIcon(Icons.mail_rounded, Color(0xFF6001D2)),
    // Outlook before the generic Microsoft entry (Exchange/Teams/other
    // Microsoft-account syncs), which would otherwise match it first.
    'com.microsoft.office.outlook': ContactAccountIcon(Icons.mail_rounded, Color(0xFF0078D4)),
    'com.microsoft': ContactAccountIcon(Icons.mail_lock_rounded, Color(0xFF0078D4)),
    'com.android.exchange': ContactAccountIcon(Icons.mail_rounded, Color(0xFF0078D4)),
    'com.osp.app.signin': ContactAccountIcon(Icons.badge_rounded, Color(0xFF1428A0)),
    'com.samsung': ContactAccountIcon(Icons.badge_rounded, Color(0xFF1428A0)),
    'vnd.sec.contact.phone': ContactAccountIcon(Icons.smartphone_rounded, Colors.grey),
    'com.android': ContactAccountIcon(Icons.smartphone_rounded, Colors.grey),
  };

  /// Resolves the icon/color to show for an account row, matching its
  /// `type` (Android account package name) against [_accountIconsByType]
  /// by prefix, or falling back to a generic person icon.
  ContactAccountIcon accountIcon(Map<String, dynamic> account) {
    final type = (account['type'] as String? ?? '').toLowerCase();
    for (final entry in _accountIconsByType.entries) {
      if (type.contains(entry.key)) return entry.value;
    }
    return _defaultAccountIcon;
  }
}
