import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPanel extends StatelessWidget {
  // Not sure how to do this other than manually yet
  final desktopVersion = "1.8.0.0";
  final desktopPre = false;

  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
        Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() <
                Theme.of(context).backgroundColor.computeLuminance() ||
            SettingsManager().settings.skin.value == Skins.Material) &&
        (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

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
                      backgroundColor: tileColor,
                      title: "Support Us",
                      onTap: () async {
                        await launch("https://bluebubbles.app/donate/");
                      },
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.money_dollar_circle,
                        materialIcon: Icons.attach_money,
                      ),
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Website",
                      onTap: () async {
                        await launch("https://bluebubbles.app/");
                      },
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.globe,
                        materialIcon: Icons.language,
                      ),
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Source Code",
                      onTap: () async {
                        await launch("https://github.com/BlueBubblesApp");
                      },
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.chevron_left_slash_chevron_right,
                        materialIcon: Icons.code,
                      ),
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Join Our Discord",
                      onTap: () async {
                        await launch("https://discord.gg/hbx7EhNFjp");
                      },
                      leading: SvgPicture.asset(
                        "assets/icon/discord.svg",
                        color: HexColor("#7289DA"),
                        alignment: Alignment.centerRight,
                        width: 32,
                      ),
                    ),
                  ],
                ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Info"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Changelog",
                      onTap: () async {
                        String changelog =
                            await DefaultAssetBundle.of(context).loadString('assets/changelog/changelog.md');
                        Navigator.of(context).push(
                          ThemeSwitcher.buildPageRoute(
                            builder: (context) => Scaffold(
                              body: Markdown(
                                data: changelog,
                                physics: AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                  Theme.of(context)
                                    ..textTheme.copyWith(
                                      headline1: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                ).copyWith(
                                  h1: Theme.of(context)
                                      .textTheme
                                      .headline1!
                                      .copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                                  h2: Theme.of(context)
                                      .textTheme
                                      .headline2!
                                      .copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                                  h3: Theme.of(context).textTheme.headline3!.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).textTheme.headline1?.color,
                                      ),
                                ),
                              ),
                              backgroundColor: Theme.of(context).backgroundColor,
                              appBar: CupertinoNavigationBar(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                middle: Text(
                                  "Changelog",
                                  style: Theme.of(context).textTheme.headline1,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.doc_plaintext,
                        materialIcon: Icons.article,
                      ),
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Developers",
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              "Developers! Developers!",
                              style: Theme.of(context).textTheme.headline1,
                              textAlign: TextAlign.center,
                            ),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            content: SizedBox(
                              width: CustomNavigator.width(context) * 3 / 5,
                              height: context.height * 1 / 9,
                              child: ListView(
                                physics: AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                children: [
                                  Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(8),
                                    child: RichText(
                                      text: TextSpan(
                                          text: "Zach",
                                          style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              await launch("https://github.com/zlshames");
                                            }),
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(8),
                                    child: RichText(
                                      text: TextSpan(
                                          text: "Tanay",
                                          style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              await launch("https://github.com/tneotia");
                                            }),
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(8),
                                    child: RichText(
                                      text: TextSpan(
                                          text: "Joel",
                                          style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              await launch("https://github.com/jjoelj");
                                            }),
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                      "Maxwell",
                                      style: Theme.of(context).textTheme.bodyText1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                child: Text(
                                  "Close",
                                  style: Theme.of(context).textTheme.bodyText1!.copyWith(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        );
                      },
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.person_alt,
                        materialIcon: Icons.person,
                      ),
                    ),
                    if (kIsWeb || kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (kIsWeb || kIsDesktop)
                      SettingsTile(
                        backgroundColor: tileColor,
                        title: "Keyboard Shortcuts",
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Keyboard Shortcuts', style: context.theme.textTheme.bodyText1),
                                  scrollable: true,
                                  backgroundColor: context.theme.backgroundColor.lightenOrDarken(),
                                  content: Container(
                                    height: MediaQuery.of(context).size.height / 2,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        columnSpacing: 5,
                                        dataRowHeight: 75,
                                        columns: const <DataColumn>[
                                          DataColumn(
                                            label: Text(
                                              'Key Combination',
                                              style: TextStyle(fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Action',
                                              style: TextStyle(fontStyle: FontStyle.italic),
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
                                      child: Text('Close'),
                                    )
                                  ],
                                );
                              });
                        },
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.keyboard,
                          materialIcon: Icons.keyboard,
                        ),
                      ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "About",
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return FutureBuilder<PackageInfo>(
                                future: PackageInfo.fromPlatform(),
                                builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
                                  return AlertDialog(
                                    contentPadding: EdgeInsets.only(
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
                                    backgroundColor: context.theme.colorScheme.secondary,
                                    content: ListBody(
                                      children: <Widget>[
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            IconTheme(
                                              data: Theme.of(context).iconTheme,
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
                                                      style: context.textTheme.headline2!.copyWith(
                                                        fontSize: 24,
                                                      ),
                                                    ),
                                                    if (!kIsDesktop)
                                                      Text(
                                                          "Version Number: " +
                                                              (snapshot.hasData ? snapshot.data!.version : "N/A"),
                                                          style: context.textTheme.subtitle1!),
                                                    if (!kIsDesktop)
                                                      Text(
                                                          "Version Code: " +
                                                              (snapshot.hasData
                                                                  ? snapshot.data!.buildNumber.toString().lastChars(
                                                                      min(4, snapshot.data!.buildNumber.length))
                                                                  : "N/A"),
                                                          style: context.textTheme.subtitle1!),
                                                    if (kIsDesktop)
                                                      Text(
                                                        "${desktopVersion}_${Platform.operatingSystem.capitalizeFirst!}${desktopPre ? "_Beta" : ""}",
                                                        style: context.textTheme.subtitle1!,
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
                                        child: Text(MaterialLocalizations.of(context).viewLicensesButtonLabel),
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
                                        child: Text(MaterialLocalizations.of(context).closeButtonLabel),
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
                      leading: SettingsLeadingIcon(
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
