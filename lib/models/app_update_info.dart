import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:github/github.dart' hide Source;

class AppUpdateInfo {
  final bool available;

  /// Null only when no matching release was found at all (e.g. no beta
  /// release exists yet on the beta track) — in that case [available] is
  /// always `false` too, so callers only need to null-check after confirming
  /// [available].
  final Release? latestRelease;

  final bool isDesktopRelease;

  /// The channel this info was fetched for — `null` means the generic/legacy
  /// check (desktop), which doesn't distinguish channels at all. Set (Android
  /// GitHub-sideload auto-update) means [latestRelease] was matched against
  /// this specific channel's tag marker (see [AppUpdateChannelInfo]).
  ///
  /// Kept as the actual channel rather than e.g. an `isBeta` bool so a future
  /// third+ track (nightly, etc.) doesn't need a new field here — just a new
  /// [AppUpdateChannel] value.
  final AppUpdateChannel? channel;

  final String version;
  final String code;
  final String buildNumber;

  /// Populated only for the Android GitHub-sideload auto-update flow, where
  /// [latestRelease] is required to carry an `.apk` asset.
  final String? apkDownloadUrl;
  final String? apkAssetName;
  final int? apkSizeBytes;

  AppUpdateInfo({
    required this.available,
    this.latestRelease,
    required this.isDesktopRelease,
    this.channel,
    required this.version,
    required this.code,
    required this.buildNumber,
    this.apkDownloadUrl,
    this.apkAssetName,
    this.apkSizeBytes,
  });

  /// " (Beta)"-style suffix for displaying [version] on a non-stable channel,
  /// or an empty string when there's nothing worth calling out (no channel,
  /// or the stable channel itself).
  String get channelSuffix =>
      channel != null && channel != AppUpdateChannel.stable ? " (${channel!.label})" : "";
}
