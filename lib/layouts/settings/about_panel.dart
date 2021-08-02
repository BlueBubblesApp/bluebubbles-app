import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutPanel extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
        || SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(context.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "About & Links",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(
                      height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                      alignment: Alignment.bottomLeft,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: headerColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                        child: Text("Links".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Support Us",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {"link": "https://bluebubbles.app/donate/", "forceBrowser": false});
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
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {"link": "https://bluebubbles.app/", "forceBrowser": false});
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
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {"link": "https://github.com/BlueBubblesApp", "forceBrowser": false});
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
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {"link": "https://discord.gg/hbx7EhNFjp", "forceBrowser": false});
                    },
                    leading: SvgPicture.asset(
                      "assets/icon/discord.svg",
                      color: HexColor("#7289DA"),
                      alignment: Alignment.centerRight,
                      width: 32,
                    ),
                  ),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Info"
                  ),
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
                                h3: Theme.of(context)
                                    .textTheme
                                    .headline3!
                                    .copyWith(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                            backgroundColor: Theme.of(context).backgroundColor,
                            appBar: CupertinoNavigationBar(
                              backgroundColor: Theme.of(context).accentColor,
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
                          backgroundColor: Theme.of(context).accentColor,
                          content: SizedBox(
                            width: context.width * 3 / 5,
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
                                        recognizer: TapGestureRecognizer()..onTap = () {
                                          MethodChannelInterface().invokeMethod("open-link", {"link": "https://github.com/zlshames", "forceBrowser": false});
                                        }
                                    ),
                                  ),
                                ),
                                Container(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(8),
                                  child: RichText(
                                    text: TextSpan(
                                        text: "Tanay",
                                        style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                                        recognizer: TapGestureRecognizer()..onTap = () {
                                          MethodChannelInterface().invokeMethod("open-link", {"link": "https://github.com/tneotia", "forceBrowser": false});
                                        }
                                    ),
                                  ),
                                ),
                                Container(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(8),
                                  child: RichText(
                                    text: TextSpan(
                                        text: "Joel",
                                        style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                                        recognizer: TapGestureRecognizer()..onTap = () {
                                          MethodChannelInterface().invokeMethod("open-link", {"link": "https://github.com/jjoelj", "forceBrowser": false});
                                        }
                                    ),
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
                          return AlertDialog(
                            scrollable: true,
                            content: ListBody(
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    IconTheme(data: Theme.of(context).iconTheme, child: Image.asset(
                                      "assets/icon/icon.png",
                                      width: 30,
                                      height: 30,
                                    ),),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                        child: ListBody(
                                          children: <Widget>[
                                            Text("BlueBubbles", style: Theme.of(context).textTheme.headline5),
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
                                      data: whiteLightTheme,
                                      child: LicensePage(
                                        applicationName: "BlueBubbles",
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
                        },
                      );
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.info_circle,
                      materialIcon: Icons.info,
                    ),
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Container(
                    height: 30,
                    decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                      color: headerColor,
                      border: Border(
                          top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                      ),
                    ) : null,
                  ),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )
          ],
        ),
      ),
    );
  }
}
