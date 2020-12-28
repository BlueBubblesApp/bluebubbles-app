import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ServerManagementPanel extends StatefulWidget {
  ServerManagementPanel({Key key}) : super(key: key);

  @override
  _ServerManagementPanelState createState() => _ServerManagementPanelState();
}

class _ServerManagementPanelState extends State<ServerManagementPanel> {
  int latency;
  String fetchStatus;
  int lastRestart;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: getBrightness(context),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Server Management",
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
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String subtitle;

                        switch (connectionStatus) {
                          case SocketState.CONNECTED:
                            subtitle = "Connected (Tap to test latency)";
                            break;
                          default:
                            subtitle = "Disconnected (Nothing to do)";
                        }

                        return SettingsTile(
                          title: "Test Latency",
                          subTitle: subtitle,
                          onTap: () async {
                            if (![SocketState.CONNECTED]
                                .contains(connectionStatus)) return;

                            int now =
                                DateTime.now().toUtc().millisecondsSinceEpoch;
                            SocketManager()
                                .sendMessage("get-server-metadata", {},
                                    (Map<String, dynamic> res) {
                              int later =
                                  DateTime.now().toUtc().millisecondsSinceEpoch;
                              if (this.mounted) {
                                setState(() {
                                  latency = later - now;
                                });
                              }
                            });
                          },
                          trailing:
                              Text((latency == null) ? "N/A" : "$latency ms"),
                        );
                      }),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String subtitle;

                        if (fetchStatus == null) {
                          switch (connectionStatus) {
                            case SocketState.CONNECTED:
                              subtitle = "Connected (Tap to fetch logs)";
                              break;
                            default:
                              subtitle = "Disconnected (Nothing to do)";
                          }
                        } else {
                          subtitle = fetchStatus;
                        }

                        return SettingsTile(
                          title: "Fetch Server Logs & Share",
                          subTitle: subtitle,
                          onTap: () {
                            if (![SocketState.CONNECTED]
                                .contains(connectionStatus)) return;

                            if (this.mounted) {
                              setState(() {
                                fetchStatus = "Fetching logs, please wait...";
                              });
                            }

                            SocketManager()
                                .sendMessage("get-logs", {"count": 500},
                                    (Map<String, dynamic> res) {
                              if (res['status'] != 200) {
                                if (this.mounted) {
                                  setState(() {
                                    fetchStatus = "Failed to fetch logs!";
                                  });
                                }

                                return;
                              }

                              String appDocPath =
                                  SettingsManager().appDocDir.path;
                              File logFile =
                                  new File("$appDocPath/attachments/main.log");

                              if (logFile.existsSync()) {
                                logFile.deleteSync();
                              }

                              logFile.writeAsStringSync(res['data']);

                              try {
                                Share.file("BlueBubbles Server Log", "main.log",
                                    logFile.absolute.path, "text/log");

                                if (this.mounted) {
                                  setState(() {
                                    fetchStatus = null;
                                  });
                                }
                              } catch (ex) {
                                if (this.mounted) {
                                  setState(() {
                                    fetchStatus =
                                        "Failed to share file! ${ex.toString()}";
                                  });
                                }
                              }
                            });
                          },
                        );
                      }),
                  SettingsTile(
                    title: "Restart Server",
                    subTitle:
                        "Instruct the server to restart. This will disconnect you briefly.",
                    onTap: () async {
                      // Prevent restarting more than once every 30 seconds
                      int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                      if (lastRestart != null && now - lastRestart < 1000 * 30)
                        return;

                      // Perform the restart
                      MethodChannelInterface().invokeMethod(
                          "set-next-restart", {
                        "value": DateTime.now().toUtc().millisecondsSinceEpoch
                      });

                      // Save the last time we restarted
                      lastRestart = now;
                    },
                    trailing: Icon(Icons.refresh,
                        color: Theme.of(context).primaryColor),
                  )
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
