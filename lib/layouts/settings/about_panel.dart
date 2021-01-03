import 'dart:ui';

import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../helpers/hex_color.dart';
import 'package:flutter/material.dart';

class AboutPanel extends StatefulWidget {
  AboutPanel({Key key}) : super(key: key);

  @override
  _AboutPanelState createState() => _AboutPanelState();
}

class _AboutPanelState extends State<AboutPanel> {
  Brightness brightness;
  bool gotBrightness = false;

  @override
  void initState() {
    super.initState();

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {
          gotBrightness = false;
        });
      }
    });
  }

  void loadBrightness() {
    if (gotBrightness) return;
    if (context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = Theme.of(context).accentColor.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        // extendBodyBehindAppBar: true,
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: brightness,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
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
                  Container(padding: EdgeInsets.only(top: 5.0)),
                  SettingsTile(
                    title: "Donations",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link",
                          {"link": "https://bluebubbles.app/donate/"});
                    },
                    trailing: Icon(
                      Icons.attach_money,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SettingsTile(
                    title: "Website",
                    onTap: () {
                      MethodChannelInterface().invokeMethod(
                          "open-link", {"link": "https://bluebubbles.app/"});
                    },
                    trailing: Icon(
                      Icons.link,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SettingsTile(
                    title: "Source Code",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link",
                          {"link": "https://github.com/BlueBubblesApp"});
                    },
                    trailing: Icon(
                      Icons.code,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SettingsTile(
                    title: "Changelog",
                    onTap: () async {
                      String changelog = await DefaultAssetBundle.of(context)
                          .loadString('assets/changelog/changelog.md');
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
                                    .headline1
                                    .copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                h2: Theme.of(context)
                                    .textTheme
                                    .headline2
                                    .copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                h3: Theme.of(context)
                                    .textTheme
                                    .headline3
                                    .copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
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
                    trailing: Icon(
                      Icons.code,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SettingsTile(
                    title: "Join Our Discord",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link",
                          {"link": "https://discord.gg/hbx7EhNFjp"});
                    },
                    trailing: SvgPicture.asset(
                      "assets/icon/discord.svg",
                      color: HexColor("#7289DA"),
                      alignment: Alignment.centerRight,
                      width: 30,
                    ),
                  ),
                  SettingsTile(
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
                            width: MediaQuery.of(context).size.width * 3 / 5,
                            height: MediaQuery.of(context).size.height * 1 / 9,
                            child: ListView(
                              physics: AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              children: [
                                Container(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    "Zach",
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                                Container(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    "Maxwell",
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            FlatButton(
                              child: Text(
                                "Close",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1
                                    .copyWith(
                                      color: Theme.of(context).primaryColor,
                                    ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                    trailing: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SettingsTile(
                    title: "About",
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: "BlueBubbles",
                        applicationIcon: Image.asset(
                          "assets/icon/icon.png",
                          width: 30,
                          height: 30,
                        ),
                      );
                    },
                    trailing: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                    ),
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
