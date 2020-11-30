import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/scheduler_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DebugPanel extends StatefulWidget {
  DebugPanel({Key key}) : super(key: key);

  @override
  _DebugPanelState createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  int latency;
  String fetchStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: true,
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
                "Debugging",
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
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
                          subtitle = "";
                      }

                      return SettingsTile(
                        title: "Test Latency",
                        subTitle: subtitle,
                        onTap: () async {
                          if (![SocketState.CONNECTED]
                              .contains(connectionStatus)) return;

                          int now =
                              DateTime.now().toUtc().millisecondsSinceEpoch;
                          SocketManager().sendMessage("get-server-metadata", {},
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
                            subtitle = "";
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
                              Share.file(
                                  "BlueBubbles Server Log",
                                  "main.log",
                                  logFile.absolute.path,
                                  "text/log");

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
                    })
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
      floatingActionButton: FloatingActionButton(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(Icons.create, color: Colors.white, size: 25),
          onPressed: () async {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (BuildContext context) {
                  return SchedulePanel();
                },
              ),
            );
          }),
    );
  }
}
