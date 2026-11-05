import 'package:flutter/foundation.dart';
import 'package:version/version.dart';

@immutable
class ServerDetails {
  final int macOSVersion;
  final int macOSMinorVersion;
  final String serverVersion;
  final int serverVersionCode;
  final bool? privateApiEnabled;
  final String? iCloudAccount;
  final String? proxyService;

  /// API generations the server implements, from `api_versions`; empty for servers that predate it.
  final List<int> apiVersions;

  /// The server's own build version, from `server_build_version`. [serverVersion] stays the
  /// v1 feature level (1.x) so that older clients' feature gates keep working.
  final String? serverBuildVersion;

  const ServerDetails({
    required this.macOSVersion,
    required this.macOSMinorVersion,
    required this.serverVersion,
    required this.serverVersionCode,
    this.privateApiEnabled,
    this.iCloudAccount,
    this.proxyService,
    this.apiVersions = const [],
    this.serverBuildVersion,
  });

  const ServerDetails.empty()
      : macOSVersion = 0,
        macOSMinorVersion = 0,
        serverVersion = "",
        serverVersionCode = 0,
        privateApiEnabled = null,
        iCloudAccount = null,
        proxyService = null,
        apiVersions = const [],
        serverBuildVersion = null;

  /// The Swift rewrite, which implements everything the 1.x Electron server did.
  bool get isV2Server => apiVersions.contains(2);

  // A v2 server reports a 1.x feature level today, but the formula below would score a 2.x as 200,
  // under several 1.x thresholds
  int get _featureCode => isV2Server ? 1 << 30 : serverVersionCode;

  /// The v1 feature level for [serverVersion]: major * 100 + minor * 21 + patch, e.g. v1.6.0 → 226.
  @Deprecated('v1-only: a 2.x scores under several 1.x thresholds. Gate new features on isV2Server')
  static int versionCodeFor(String serverVersion) {
    final v = Version.parse(serverVersion);
    return v.major * 100 + v.minor * 21 + v.patch;
  }

  // ---------------------------------------------------------------------------
  // Server feature helpers (thresholds are [versionCodeFor] values)
  // ---------------------------------------------------------------------------

  /// Can restart the Private API helper bundle from the client (~v0.1.x).
  bool get supportsRestartPrivateApi => _featureCode >= 41;

  /// Download the original, unconverted attachment (after v1.0.0).
  bool get supportsOriginalDownload => _featureCode > 100;

  /// Min supported server version (v0.2.0).
  bool get minimumWebSupportedVersion => _featureCode >= 42;

  /// Exposes Private API status indicators, iMessage stats, contacts API on
  /// desktop/web, server update checks, and is the minimum for web clients (v0.2.0).
  bool get supportsPrivateApiStatus => _featureCode >= 42;

  /// Supports iMessage stats(v0.2.0).
  bool get supportsMessageStats => _featureCode >= 42;

  /// Supports contacts API (v0.2.0).
  bool get supportsContactsApi => _featureCode >= 42;

  /// Private API subject line field when composing messages (v0.3.0).
  bool get supportsSubjectLines => _featureCode >= 63;

  /// Send regular iMessages via the Private API for faster delivery (v0.4.0).
  bool get supportsPrivateApiSend => _featureCode >= 84;

  /// Improved incremental message sync algorithm (v1.2.0).
  bool get supportsImprovedSync => _featureCode >= 142;

  /// Undo send (unsend) and edit already-sent messages (v1.2.6).
  bool get supportsEditAndUnsend => _featureCode >= 148;

  /// Scheduled message sending (v1.5.0).
  bool get supportsScheduledMessages => _featureCode >= 205;

  /// Server-side handle / contact sync endpoint (v1.5.2).
  bool get supportsHandleSync => _featureCode >= 207;

  /// Send attachments via the Private API (v1.5.3).
  bool get supportsPrivateApiAttachmentSend => _featureCode >= 208;

  /// Private API group chat management — update/delete group icon, leave a
  /// group chat, and send handwritten / Digital Touch messages (v1.6.0).
  bool get supportsGroupChatManagement => _featureCode >= 226;

  /// Incremental sync using message row IDs instead of timestamps (v1.6.0).
  bool get supportsRowIdSync => _featureCode >= 226;

  /// Create new group chats via the Private API (v1.8.0).
  bool get supportsCreateGroupChat => _featureCode >= 268;

  /// macOS version as a display string, e.g. "14.2".
  String get macOSVersionString => '$macOSVersion.$macOSMinorVersion';

  // ---------------------------------------------------------------------------
  // macOS version range helpers
  // ---------------------------------------------------------------------------

  /// macOS Sierra (10.12) or newer.
  bool get isMinSierra => macOSVersion > 10 || (macOSVersion == 10 && macOSMinorVersion >= 12);

  /// macOS Catalina (10.15) or newer.
  bool get isMinCatalina => macOSMinorVersion >= 15 || macOSVersion >= 11;

  /// macOS Big Sur (11.0) or newer.
  bool get isMinBigSur => macOSVersion >= 11;

  /// macOS Monterey (12.0) or newer.
  bool get isMinMonterey => macOSVersion >= 12;

  /// macOS Ventura (13.0) or newer.
  bool get isMinVentura => macOSVersion >= 13;

  /// macOS Sonoma (14.0) or newer.
  bool get isMinSonoma => macOSVersion >= 14;

  /// macOS Sequoia (15.0) or newer.
  bool get isMinSequoia => macOSVersion >= 15;
}
