import 'dart:math';

import 'package:bluebubbles/core/abstractions/update_service.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/filesystem/filesystem_service.dart';
import 'package:bluebubbles/services/network/http_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';

class GithubUpdateService extends UpdateService {
  @override
  final String name = "Github Update Service";

  @override
  final int version = 1;

  @override
  bool required = false;

  bool shouldCheck = false;

  @override
  Future<void> initMobile() async {
    if (headless) {
      shouldCheck = false;
    } else if (device.installedFromStore) {
      shouldCheck = false;
    } else {
      shouldCheck = true;
    }
  }

  @override
  Future<void> initDesktop() async {
    // todo
  }

  @override
  Future<void> checkForServerUpdate() async {
    if (!shouldCheck) return;

    final response = await http.checkUpdate();
    if (response.statusCode == 200) {
      bool available = response.data['data']['available'] ?? false;
      Map<String, dynamic> metadata = response.data['data']['metadata'] ?? {};
      if (!available || settings.prefs.getString("server-update-check") == metadata['version']) return;
      showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          backgroundColor: context.theme.colorScheme.properSurface,
          title: Text("Server Update Check", style: context.theme.textTheme.titleLarge),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: 15.0,
              ),
              Text(available ? "Updates available:" : "Your server is up-to-date!", style: context.theme.textTheme.bodyLarge),
              const SizedBox(
                height: 15.0,
              ),
              if (metadata.isNotEmpty)
                Text("Version: ${metadata['version'] ?? "Unknown"}\nRelease Date: ${metadata['release_date'] ?? "Unknown"}\nRelease Name: ${metadata['release_name'] ?? "Unknown"}\n\nWarning: Installing the update will briefly disconnect you.", style: context.theme.textTheme.bodyLarge)
            ],
          ),
          actions: [
            TextButton(
              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                await settings.prefs.setString("server-update-check", metadata['version']);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Install", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                await settings.prefs.setString("server-update-check", metadata['version']);
                http.installUpdate();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Future<void> checkForClientUpdate() async {
    if (!shouldCheck) return;

    final github = GitHub();
    final stream = github.repositories.listReleases(RepositorySlug('bluebubblesapp', 'bluebubbles-app'));
    final release = await stream.firstWhere((element) => !(element.isDraft ?? false) && !(element.isPrerelease ?? false) && element.tagName != null);
    final version = release.tagName!.split("+").first.replaceAll("v", "");
    final code = release.tagName!.split("+").last;
    final buildNumber = fs.packageInfo.buildNumber.lastChars(min(4, fs.packageInfo.buildNumber.length));
    if (int.parse(code) <= int.parse(buildNumber) || settings.prefs.getString("client-update-check") == code) return;
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("App Update Check", style: context.theme.textTheme.titleLarge),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              height: 15.0,
            ),
            Text("Updates available:", style: context.theme.textTheme.bodyLarge),
            const SizedBox(
              height: 15.0,
            ),
            Text("Version: $version\nRelease Date: ${buildDate(release.createdAt)}\nRelease Name: ${release.name}", style: context.theme.textTheme.bodyLarge)
          ],
        ),
        actions: [
          if (release.htmlUrl != null)
            TextButton(
              child: Text("Download", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                await launchUrl(Uri.parse(release.htmlUrl!), mode: LaunchMode.externalApplication);
              },
            ),
          TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () async {
              await settings.prefs.setString("client-update-check", code);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
  