import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ServerManagementPanel extends StatefulWidget {
  ServerManagementPanel({Key? key}) : super(key: key);

  @override
  _ServerManagementPanelState createState() => _ServerManagementPanelState();
}

class _ServerManagementPanelState extends State<ServerManagementPanel> {
  int? latency;
  String? fetchStatus;

  // Restart trackers
  int? lastRestart;
  int? lastRestartMessages;
  bool isRestarting = false;
  bool isRestartingMessages = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(Get.mediaQuery.size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
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
                        SocketState? connectionStatus;
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
                            if (![SocketState.CONNECTED].contains(connectionStatus)) return;

                            int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                            SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                              int later = DateTime.now().toUtc().millisecondsSinceEpoch;
                              if (this.mounted) {
                                setState(() {
                                  latency = later - now;
                                });
                              }
                            });
                          },
                          trailing: Text((latency == null) ? "N/A" : "$latency ms"),
                        );
                      }),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState? connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String subtitle;

                        switch (connectionStatus) {
                          case SocketState.CONNECTED:
                            subtitle = "Tap to manually sync messages";
                            break;
                          default:
                            subtitle = "Disconnected (Nothing to do)";
                        }

                        return SettingsTile(
                            title: "Manually Sync Messages",
                            subTitle: subtitle,
                            onTap: () async {
                              showDialog(
                                context: context,
                                builder: (context) => SyncDialog(),
                              );
                            });
                      }),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState? connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String? subtitle;

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
                            if (![SocketState.CONNECTED].contains(connectionStatus)) return;

                            if (this.mounted) {
                              setState(() {
                                fetchStatus = "Fetching logs, please wait...";
                              });
                            }

                            SocketManager().sendMessage("get-logs", {"count": 500}, (Map<String, dynamic> res) {
                              if (res['status'] != 200) {
                                if (this.mounted) {
                                  setState(() {
                                    fetchStatus = "Failed to fetch logs!";
                                  });
                                }

                                return;
                              }

                              String appDocPath = SettingsManager().appDocDir.path;
                              File logFile = new File("$appDocPath/attachments/main.log");

                              if (logFile.existsSync()) {
                                logFile.deleteSync();
                              }

                              logFile.writeAsStringSync(res['data']);

                              try {
                                Share.file("BlueBubbles Server Log", "main.log", logFile.absolute.path, "text/log");

                                if (this.mounted) {
                                  setState(() {
                                    fetchStatus = null;
                                  });
                                }
                              } catch (ex) {
                                if (this.mounted) {
                                  setState(() {
                                    fetchStatus = "Failed to share file! ${ex.toString()}";
                                  });
                                }
                              }
                            });
                          },
                        );
                      }),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState? connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String? subtitle;

                        if (fetchStatus == null) {
                          switch (connectionStatus) {
                            case SocketState.CONNECTED:
                              subtitle = (isRestartingMessages)
                                  ? "Restart in progress..."
                                  : "Instruct the server to restart the iMessage app.";
                              break;
                            default:
                              subtitle = "Disconnected (Nothing to do)";
                          }
                        } else {
                          subtitle = fetchStatus;
                        }

                        return SettingsTile(
                            title: "Restart iMessage",
                            subTitle: subtitle,
                            onTap: () async {
                              if (![SocketState.CONNECTED].contains(connectionStatus) || isRestartingMessages) return;

                              if (this.mounted && !isRestartingMessages)
                                setState(() {
                                  isRestartingMessages = true;
                                });

                              // Prevent restarting more than once every 30 seconds
                              int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                              if (lastRestartMessages != null && now - lastRestartMessages! < 1000 * 30) return;

                              // Save the last time we restarted
                              lastRestartMessages = now;

                              // Create a temporary functon so we can call it easily
                              Function stopRestarting = () {
                                if (this.mounted && isRestartingMessages) {
                                  setState(() {
                                    isRestartingMessages = false;
                                  });
                                }
                              };

                              // Execute the restart
                              try {
                                // If it fails or there is an endpoint error, stop the loader
                                await SocketManager().sendMessage("restart-imessage", null, (_) {
                                  stopRestarting();
                                }).catchError((_) {
                                  stopRestarting();
                                });
                              } finally {
                                stopRestarting();
                              }
                            },
                            trailing: (!isRestartingMessages)
                                ? Icon(Icons.refresh, color: Theme.of(context).primaryColor)
                                : Container(
                                    constraints: BoxConstraints(
                                      maxHeight: 20,
                                      maxWidth: 20,
                                    ),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                    )));
                      }),
                  SettingsTile(
                      title: "Restart Server",
                      subTitle: (isRestarting)
                          ? "Restart in progress..."
                          : "Instruct the server to restart. This will disconnect you briefly.",
                      onTap: () async {
                        if (isRestarting) return;

                        if (this.mounted && !isRestarting)
                          setState(() {
                            isRestarting = true;
                          });

                        // Prevent restarting more than once every 30 seconds
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        if (lastRestart != null && now - lastRestart! < 1000 * 30) return;

                        // Save the last time we restarted
                        lastRestart = now;

                        Function stopRestarting = () {
                          if (this.mounted && isRestarting) {
                            setState(() {
                              isRestarting = false;
                            });
                          }
                        };

                        // Perform the restart
                        try {
                          MethodChannelInterface().invokeMethod(
                              "set-next-restart", {"value": DateTime.now().toUtc().millisecondsSinceEpoch});
                        } finally {
                          stopRestarting();
                        }

                        // After 5 seconds, remove the restarting message
                        Future.delayed(new Duration(seconds: 5), () {
                          stopRestarting();
                        });
                      },
                      trailing: (!isRestarting)
                          ? Icon(Icons.refresh, color: Theme.of(context).primaryColor)
                          : Container(
                              constraints: BoxConstraints(
                                maxHeight: 20,
                                maxWidth: 20,
                              ),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              ))),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState? connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String subtitle;

                        switch (connectionStatus) {
                          case SocketState.CONNECTED:
                            subtitle = "Fetch server version & OS";
                            break;
                          default:
                            subtitle = "Disconnected (cannot fetch data)";
                        }

                        return SettingsTile(
                            title: "Server Info",
                            subTitle: subtitle,
                            onTap: () async {
                              if (connectionStatus != SocketState.CONNECTED) return;

                              SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                                List<Widget> metaWidgets = [
                                  RichText(
                                      text: TextSpan(children: [
                                        TextSpan(
                                            text: "MacOS Version: ",
                                            style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2)),
                                        TextSpan(text: res['data']['os_version'], style: Theme.of(context).textTheme.bodyText1)
                                      ])),
                                  RichText(
                                      text: TextSpan(children: [
                                        TextSpan(
                                            text: "BlueBubbles Server Version: ",
                                            style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2)),
                                        TextSpan(
                                            text: res['data']['server_version'], style: Theme.of(context).textTheme.bodyText1)
                                      ]))
                                ];
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      "Metadata",
                                      style: Theme.of(context).textTheme.headline1,
                                      textAlign: TextAlign.center,
                                    ),
                                    backgroundColor: Theme.of(context).accentColor,
                                    content: SizedBox(
                                      width: Get.mediaQuery.size.width * 3 / 5,
                                      height: Get.mediaQuery.size.height * 1 / 4,
                                      child: Container(
                                        padding: EdgeInsets.all(10.0),
                                        decoration: BoxDecoration(
                                            color: Theme.of(context).backgroundColor,
                                            borderRadius: BorderRadius.all(Radius.circular(10))),
                                        child: ListView(
                                          physics: AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics(),
                                          ),
                                          children: metaWidgets,
                                        ),
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
                              });
                            },
                            trailing: Icon(Icons.info, color: Theme.of(context).primaryColor));
                      }),
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

class SyncDialog extends StatefulWidget {
  SyncDialog({Key? key}) : super(key: key);

  @override
  _SyncDialogState createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  String? errorCode;
  bool finished = false;
  String? message;
  double? progress;
  Duration? lookback;
  int page = 0;

  void syncMessages() async {
    if (lookback == null) return;

    DateTime now = DateTime.now().toUtc().subtract(lookback!);
    SocketManager().fetchMessages(null, after: now.millisecondsSinceEpoch)!.then((dynamic messages) {
      if (this.mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(null, messages, onProgress: (int progress, int length) {
        if (progress == 0 || length == 0) {
          this.progress = null;
        } else {
          this.progress = progress / length;
        }

        if (this.mounted)
          setState(() {
            message = "Adding $progress of $length (${((this.progress ?? 0) * 100).floor().toInt()}%)";
          });
      }).then((List<Message> items) {
        onFinish(true, items.length);
      });
    }).catchError((_) {
      onFinish(false, 0);
    });
  }

  void onFinish([bool success = true, int? total]) {
    if (!this.mounted) return;

    this.progress = 100;
    message = "Finished adding $total messages!";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String title = errorCode != null ? "Error!" : message ?? "";
    Widget content = Container();
    if (errorCode != null) {
      content = Text(errorCode!);
    } else {
      content = Container(
        height: 5,
        child: Center(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white,
            valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
          ),
        ),
      );
    }

    List<Widget> actions = [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text(
          "Ok",
          style: Theme.of(context).textTheme.bodyText1!.apply(
                color: Theme.of(context).primaryColor,
              ),
        ),
      )
    ];

    if (page == 0) {
      title = "How far back would you like to go?";
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Days: ${lookback?.inDays ?? "1"}",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Slider(
              value: lookback?.inDays.toDouble() ?? 1.0,
              onChanged: (double value) {
                if (!this.mounted) return;

                setState(() {
                  lookback = new Duration(days: value.toInt());
                });
              },
              label: lookback?.inDays.toString() ?? "1",
              divisions: 29,
              min: 1,
              max: 30,
            ),
          )
        ],
      );

      actions = [
        TextButton(
          onPressed: () {
            if (!this.mounted) return;
            if (lookback == null) lookback = new Duration(days: 1);
            page = 1;
            message = "Fetching messages...";
            setState(() {});
            syncMessages();
          },
          child: Text(
            "Sync",
            style: Theme.of(context).textTheme.bodyText1!.apply(
                  color: Theme.of(context).primaryColor,
                ),
          ),
        )
      ];
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).backgroundColor,
      title: Text(title, style: Theme.of(context).textTheme.headline1),
      content: content,
      actions: actions,
    );
  }
}
