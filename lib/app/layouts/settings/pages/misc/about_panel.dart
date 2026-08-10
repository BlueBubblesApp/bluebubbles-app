import 'package:bluebubbles/app/layouts/settings/dialogs/version_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPanel extends StatefulWidget {
  const AboutPanel({super.key});

  @override
  State<StatefulWidget> createState() => _AboutPanelState();
}

class _AboutPanelState extends State<AboutPanel> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
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
                          await launchUrl(Uri(scheme: "https", host: "bluebubbles.app"),
                              mode: LaunchMode.externalApplication);
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.globe,
                          materialIcon: Icons.language,
                          containerColor: Colors.green,
                        ),
                        trailing: const NextButton()),
                    const SettingsDivider(),
                    SettingsTile(
                        title: "Documentation",
                        subtitle: "RTFM: Read the [Fine] Manual and learn how to use BlueBubbles or fix common issues",
                        onTap: () async {
                          await launchUrl(Uri(scheme: "https", host: "docs.bluebubbles.app"),
                              mode: LaunchMode.externalApplication);
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.doc_append,
                          materialIcon: Icons.document_scanner,
                          containerColor: Colors.blueAccent,
                        ),
                        trailing: const NextButton()),
                    const SettingsDivider(),
                    SettingsTile(
                        title: "Source Code",
                        subtitle: "View the source code for BlueBubbles, and contribute!",
                        onTap: () async {
                          await launchUrl(Uri(scheme: "https", host: "github.com", path: "BlueBubblesApp"),
                              mode: LaunchMode.externalApplication);
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.chevron_left_slash_chevron_right,
                          materialIcon: Icons.code,
                          containerColor: Colors.orange,
                        ),
                        trailing: const NextButton()),
                    const SettingsDivider(),
                    SettingsTile(
                        title: "Report a Bug",
                        subtitle: "Found a bug? Report it here!",
                        onTap: () async {
                          await launchUrl(
                              Uri(scheme: "https", host: "github.com", path: "BlueBubblesApp/bluebubbles-app/issues"),
                              mode: LaunchMode.externalApplication);
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.triangle_righthalf_fill,
                          materialIcon: Icons.bug_report,
                          containerColor: Colors.redAccent,
                        ),
                        trailing: const NextButton()),
                  ],
                ),
                SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Info"),
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
                                  h1: context.theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
                                  h2: context.theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                                  h3: context.theme.textTheme.titleSmall!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              backgroundColor: context.theme.colorScheme.surface,
                              appBar: BBAppBar(
                                toolbarHeight: 50,
                                leading: buildBackButton(context),
                                iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
                                title: Padding(
                                  padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                  child: Text(
                                    "Changelog",
                                    style: context.theme.textTheme.titleLarge,
                                  ),
                                ),
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
                    const SettingsDivider(),
                    SettingsTile(
                      title: "Developers",
                      onTap: () {
                        final devs = {
                          "Zach": "zlshames",
                          "Tanay": "tneotia",
                          "Joel": "jjoelj",
                        };
                        showBBDialog(
                          context: context,
                          title: "GitHub Profiles",
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: devs.entries
                                .map((e) => Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8),
                                      child: RichText(
                                        text: TextSpan(
                                            text: e.key,
                                            style: context.theme.textTheme.bodyLarge!.copyWith(
                                                decoration: TextDecoration.underline,
                                                color: context.theme.colorScheme.primary),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () async {
                                                await launchUrl(Uri(scheme: "https", host: "github.com", path: e.value),
                                                    mode: LaunchMode.externalApplication);
                                              }),
                                      ),
                                    ))
                                .toList(),
                          ),
                          actions: [
                            BBDialogAction(
                              text: "Close",
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                            ),
                          ],
                        );
                      },
                      subtitle: "Meet the developers behind BlueBubbles",
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.person_alt,
                        materialIcon: Icons.person,
                        containerColor: Colors.green,
                      ),
                    ),
                    if (kIsWeb || kIsDesktop) const SettingsDivider(),
                    if (kIsWeb || kIsDesktop)
                      SettingsTile(
                        title: "Keyboard Shortcuts",
                        onTap: () {
                          showBBDialog(
                            context: context,
                            title: "Keyboard Shortcuts",
                            content: SizedBox(
                              height: MediaQuery.of(context).size.height / 2,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 5,
                                  dataRowMinHeight: 75,
                                  dataRowMaxHeight: 75,
                                  dataTextStyle: context.theme.textTheme.bodyLarge,
                                  headingTextStyle:
                                      context.theme.textTheme.bodyLarge!.copyWith(fontStyle: FontStyle.italic),
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
                                        DataCell(Text('Reply to most recent message in the currently selected chat')),
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
                                        DataCell(
                                            Text('Switch to the chat below the currently selected one (Desktop only)')),
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
                                        DataCell(
                                            Text('Switch to the chat above the currently selected one (Desktop only)')),
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
                              BBDialogAction(
                                text: "Close",
                                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                              ),
                            ],
                          );
                        },
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.keyboard,
                          materialIcon: Icons.keyboard,
                          containerColor: Colors.teal,
                        ),
                      ),
                    const SettingsDivider(),
                    SettingsTile(
                      title: "About",
                      subtitle: "Version and other information",
                      onTap: () => showVersionDialog(context),
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.info_circle,
                        materialIcon: Icons.info,
                        containerColor: Colors.blue,
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
