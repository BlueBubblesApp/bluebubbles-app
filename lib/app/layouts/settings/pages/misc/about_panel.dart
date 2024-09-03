import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _AboutPanelState();
}

class _AboutPanelState extends OptimizedState<AboutPanel> {

  @override
  Widget build(BuildContext context) {
    final Widget nextIcon = Obx(() => ss.settings.skin.value != Skins.Material
        ? Icon(
            ss.settings.skin.value != Skins.Material
                ? CupertinoIcons.chevron_right
                : Icons.arrow_forward,
            color: context.theme.colorScheme.outline,
            size: iOS ? 18 : 24,
          )
        : const SizedBox.shrink());

    return SettingsScaffold(
        title: "About & Links",
        initialHeader: "Links",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      title: "BlueBubbles Website",
                      subtitle: "Visit the BlueBubbles Homepage",
                      onTap: () async {
                        await launchUrl(Uri(scheme: "https", host: "bluebubbles.app"), mode: LaunchMode.externalApplication);
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.globe,
                        materialIcon: Icons.language,
                        containerColor: Colors.green,
                      ),
                      trailing: nextIcon
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    SettingsTile(
                      title: "Documentation",
                      subtitle: "RTFM: Read the [Fine] Manual and learn how to use BlueBubbles or fix common issues",
                      onTap: () async {
                        await launchUrl(Uri(scheme: "https", host: "docs.bluebubbles.app"), mode: LaunchMode.externalApplication);
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.doc_append,
                        materialIcon: Icons.document_scanner,
                        containerColor: Colors.blueAccent,
                      ),
                      trailing: nextIcon
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    SettingsTile(
                      title: "Source Code",
                      subtitle: "View the source code for BlueBubbles, and contribute!",
                      onTap: () async {
                        await launchUrl(Uri(scheme: "https", host: "github.com", path: "BlueBubblesApp"), mode: LaunchMode.externalApplication);
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.chevron_left_slash_chevron_right,
                        materialIcon: Icons.code,
                        containerColor: Colors.orange,
                      ),
                      trailing: nextIcon
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    SettingsTile(
                      title: "Report a Bug",
                      subtitle: "Found a bug? Report it here!",
                      onTap: () async {
                        await launchUrl(Uri(scheme: "https", host: "github.com", path: "BlueBubblesApp/bluebubbles-app/issues"), mode: LaunchMode.externalApplication);
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.triangle_righthalf_fill,
                        materialIcon: Icons.bug_report,
                        containerColor: Colors.redAccent,
                      ),
                      trailing: nextIcon
                    ),
                  ],
                ),
                SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Info"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      title: "Changelog",
                      onTap: () async {
                        String changelog =
                            await DefaultAssetBundle.of(context).loadString('assets/changelog/changelog.md');
                        Navigator.of(context).push(
                          ThemeSwitcher.buildPageRoute(
                            builder: (context) => Scaffold(
                              body: Markdown(
                                data: changelog,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                  context.theme
                                    ..textTheme.copyWith(
                                      headlineMedium: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                ).copyWith(
                                  h1: context.theme
                                      .textTheme
                                      .titleLarge!
                                      .copyWith(fontWeight: FontWeight.bold),
                                  h2: context.theme
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(fontWeight: FontWeight.bold),
                                  h3: context.theme.textTheme.titleSmall!.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              backgroundColor: context.theme.colorScheme.background,
                              appBar: AppBar(
                                toolbarHeight: 50,
                                elevation: 0,
                                scrolledUnderElevation: 3,
                                surfaceTintColor: context.theme.colorScheme.primary,
                                leading: buildBackButton(context),
                                backgroundColor: headerColor,
                                iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
                                centerTitle: iOS,
                                title: Padding(
                                  padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                  child: Text(
                                    "Changelog",
                                    style: context.theme.textTheme.titleLarge,
                                  ),
                                ),
                                systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                                    ? SystemUiOverlayStyle.light
                                    : SystemUiOverlayStyle.dark,
                              ),
                            ),
                          ),
                        );
                      },
                      subtitle: "See what's new in the latest version",
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.doc_plaintext,
                        materialIcon: Icons.article,
                        containerColor: Colors.blueAccent,
                      ),
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    SettingsTile(
                      title: "Developers",
                      onTap: () {
                        final devs = {
                          "Zach": "zlshames",
                          "Tanay": "tneotia",
                          "Joel": "jjoelj",
                        };
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              "GitHub Profiles",
                              style: context.theme.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            backgroundColor: context.theme.colorScheme.properSurface,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: devs.entries.map((e) => Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(8),
                                child: RichText(
                                  text: TextSpan(
                                    text: e.key,
                                    style: context.theme.textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline, color: context.theme.colorScheme.primary),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        await launchUrl(Uri(scheme: "https", host: "github.com", path: e.value), mode: LaunchMode.externalApplication);
                                      }),
                                ),
                              )).toList(),
                            ),
                            actions: [
                              TextButton(
                                child: Text(
                                  "Close",
                                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        );
                      },
                      subtitle: "Meet the developers behind BlueBubbles",
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.person_alt,
                        materialIcon: Icons.person,
                        containerColor: Colors.green,
                      ),
                    ),
                    if (kIsWeb || kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (kIsWeb || kIsDesktop)
                      SettingsTile(
                        title: "Keyboard Shortcuts",
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Keyboard Shortcuts', style: context.theme.textTheme.titleLarge),
                                  scrollable: true,
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                  content: Container(
                                    height: MediaQuery.of(context).size.height / 2,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        columnSpacing: 5,
                                        dataRowMinHeight: 75,
                                        dataRowMaxHeight: 75,
                                        dataTextStyle: context.theme.textTheme.bodyLarge,
                                        headingTextStyle: context.theme.textTheme.bodyLarge!.copyWith(fontStyle: FontStyle.italic),
                                        columns: const <DataColumn>[
                                          DataColumn(
                                            label: Text(
                                              'Key Combination',
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Action',
                                            ),
                                          ),
                                        ],
                                        rows: const <DataRow>[
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + COMMA')),
                                              DataCell(Text('Open settings')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + N')),
                                              DataCell(Text('Start new chat (Desktop only)')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('ALT + N')),
                                              DataCell(Text('Start new chat')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + F')),
                                              DataCell(Text('Open search page')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('ALT + R')),
                                              DataCell(
                                                  Text('Reply to most recent message in the currently selected chat')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + R')),
                                              DataCell(Text(
                                                  'Reply to most recent message in the currently selected chat (Desktop only)')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('ALT + G')),
                                              DataCell(Text('Sync from server')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + SHIFT + R')),
                                              DataCell(Text('Sync from server (Desktop only)')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + G')),
                                              DataCell(Text('Sync from server (Desktop only)')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + SHIFT + 1-6')),
                                              DataCell(Text(
                                                  'Apply reaction to most recent message in the currently selected chat')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + ARROW DOWN')),
                                              DataCell(Text('Switch to the chat below the currently selected one')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + TAB')),
                                              DataCell(Text(
                                                  'Switch to the chat below the currently selected one (Desktop only)')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + ARROW UP')),
                                              DataCell(Text('Switch to the chat above the currently selected one')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + SHIFT + TAB')),
                                              DataCell(Text(
                                                  'Switch to the chat above the currently selected one (Desktop only)')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('CTRL + I')),
                                              DataCell(Text('Open chat details page')),
                                            ],
                                          ),
                                          DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text('ESC')),
                                              DataCell(Text('Close pages')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Close'),
                                    )
                                  ],
                                );
                              });
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.keyboard,
                          materialIcon: Icons.keyboard,
                        ),
                      ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    SettingsTile(
                      title: "About",
                      subtitle: "Version and other information",
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return FutureBuilder<PackageInfo>(
                                future: PackageInfo.fromPlatform(),
                                builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
                                  return AlertDialog(
                                    contentPadding: const EdgeInsets.only(
                                      top: 24,
                                      left: 24,
                                      right: 24,
                                    ),
                                    elevation: 10.0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        10.0,
                                      ),
                                    ),
                                    scrollable: true,
                                    backgroundColor: context.theme.colorScheme.properSurface,
                                    content: ListBody(
                                      children: <Widget>[
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            IconTheme(
                                              data: context.theme.iconTheme,
                                              child: Image.asset(
                                                "assets/icon/icon.png",
                                                width: 30,
                                                height: 30,
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                                child: ListBody(
                                                  children: <Widget>[
                                                    Text(
                                                      "BlueBubbles",
                                                      style: context.theme.textTheme.titleLarge,
                                                    ),
                                                    if (!kIsDesktop)
                                                      Text(
                                                          "Version Number: ${snapshot.hasData ? snapshot.data!.version : "N/A"}",
                                                          style: context.theme.textTheme.bodyLarge),
                                                    if (!kIsDesktop)
                                                      Text(
                                                          "Version Code: ${snapshot.hasData
                                                                  ? snapshot.data!.buildNumber.toString().lastChars(
                                                                      min(4, snapshot.data!.buildNumber.length))
                                                                  : "N/A"}",
                                                          style: context.theme.textTheme.bodyLarge),
                                                    if (kIsDesktop)
                                                      Text(
                                                        "${fs.packageInfo.version}_${Platform.operatingSystem.capitalizeFirst!}${isSnap ? "_Snap" : isFlatpak ? "_Flatpak" : ""}",
                                                        style: context.theme.textTheme.bodyLarge,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("View Licenses", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                        onPressed: () {
                                          Navigator.of(context).push(MaterialPageRoute<void>(
                                            builder: (BuildContext context) => Theme(
                                              data: context.theme,
                                              child: LicensePage(
                                                applicationName: "BlueBubbles",
                                                applicationVersion: snapshot.hasData ? snapshot.data!.version : "",
                                                applicationIcon: Image.asset(
                                                  "assets/icon/icon.png",
                                                  width: 30,
                                                  height: 30,
                                                ),
                                              ),
                                            ),
                                          ));
                                        },
                                      ),
                                      TextButton(
                                        child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  );
                                });
                          },
                        );
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.info_circle,
                        materialIcon: Icons.info,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]);
  }
}
