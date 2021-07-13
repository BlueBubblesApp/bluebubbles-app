import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/foundation.dart';
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
  String? serverVersion;
  String? macOSVersion;

  // Restart trackers
  int? lastRestart;
  int? lastRestartMessages;
  bool isRestarting = false;
  bool isRestartingMessages = false;

  late Settings _settingsCopy;
  FCMData? _fcmDataCopy;

  @override
  void initState() {
    _settingsCopy = SettingsManager().settings;
    _fcmDataCopy = SettingsManager().fcmData;
    if (SocketManager().state == SocketState.CONNECTED) {
      int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
        int later = DateTime.now().toUtc().millisecondsSinceEpoch;
        if (this.mounted) {
          setState(() {
            latency = later - now;
          });
        }
      });
      SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
        if (mounted) {
          setState(() {
            macOSVersion = res['data']['os_version'];
            serverVersion = res['data']['server_version'];
          });
        }
      });
    }
    super.initState();
  }

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
                  "Connection & Server Management",
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
                        child: Text("Connection & Server Details".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data!;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        bool redact = SettingsManager().settings.redactedMode;
                        return Container(
                            color: tileColor,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                              child: SelectableText.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: "Connection Status: "),
                                      TextSpan(text: describeEnum(connectionStatus), style: TextStyle(color: getIndicatorColor(connectionStatus))),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "Server URL: ${redact ? "Redacted" : _settingsCopy.serverAddress}"),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "Latency: ${redact ? "Redacted" : ((latency ?? "N/A").toString() + " ms")}"),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "Server Version: ${redact ? "Redacted" : (serverVersion ?? "N/A")}"),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "macOS Version: ${redact ? "Redacted" : (macOSVersion ?? "N/A")}"),
                                      TextSpan(text: "\n\n"),
                                      TextSpan(text: "Tap to update values...", style: TextStyle(fontStyle: FontStyle.italic)),
                                    ]
                                  ),
                                onTap: () {
                                  if (connectionStatus != SocketState.CONNECTED) return;

                                  int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                                  SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                                    int later = DateTime.now().toUtc().millisecondsSinceEpoch;
                                    if (this.mounted) {
                                      setState(() {
                                        latency = later - now;
                                      });
                                    }
                                  });
                                  SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                                    if (mounted) {
                                      setState(() {
                                        macOSVersion = res['data']['os_version'];
                                        serverVersion = res['data']['server_version'];
                                      });
                                    }
                                  });
                                },
                              ),
                            )
                        );
                      }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Connection & Sync"
                  ),
                  SettingsTile(
                    title: "Re-configure with BlueBubbles Server",
                    subTitle: "Scan QR code",
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.gear,
                      materialIcon: Icons.room_preferences,
                    ),
                    backgroundColor: tileColor,
                    onTap: () async {
                      var fcmData;
                      try {
                        fcmData = jsonDecode(
                          await Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (BuildContext context) {
                                return QRCodeScanner();
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        return;
                      }
                      if (fcmData != null && fcmData[0] != null && getServerAddress(address: fcmData[1]) != null) {
                        _fcmDataCopy = FCMData(
                          projectID: fcmData[2],
                          storageBucket: fcmData[3],
                          apiKey: fcmData[4],
                          firebaseURL: fcmData[5],
                          clientID: fcmData[6],
                          applicationID: fcmData[7],
                        );
                        _settingsCopy.guidAuthKey = fcmData[0];
                        _settingsCopy.serverAddress = getServerAddress(address: fcmData[1])!;

                        SettingsManager().saveSettings(_settingsCopy);
                        SettingsManager().saveFCMData(_fcmDataCopy!);
                        SocketManager().authFCM();
                      }
                    },
                    showDivider: false,
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
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
                            subtitle = "Tap to sync messages";
                            break;
                          default:
                            subtitle = "Disconnected, cannot sync";
                        }

                        return SettingsTile(
                            title: "Manually Sync Messages",
                            subTitle: subtitle,
                            showDivider: false,
                            backgroundColor: tileColor,
                            leading: SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.arrow_2_circlepath,
                              materialIcon: Icons.sync,
                            ),
                            onTap: () async {
                              showDialog(
                                context: context,
                                builder: (context) => SyncDialog(),
                              );
                            });
                      }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Server Actions"
                  ),
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
                              subtitle = "Tap to fetch logs";
                              break;
                            default:
                              subtitle = "Disconnected, cannot fetch logs";
                          }
                        } else {
                          subtitle = fetchStatus;
                        }

                        return SettingsTile(
                          title: "Fetch & Share Server Logs",
                          subTitle: subtitle,
                          backgroundColor: tileColor,
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.doc_plaintext,
                            materialIcon: Icons.article,
                          ),
                          showDivider: false,
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
                                Share.file("BlueBubbles Server Log", logFile.absolute.path);

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
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
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

                        switch (connectionStatus) {
                          case SocketState.CONNECTED:
                            subtitle = (isRestartingMessages)
                                ? "Restart in progress..."
                                : "Restart the iMessage app";
                            break;
                          default:
                            subtitle = "Disconnected, cannot restart";
                        }

                        return SettingsTile(
                            title: "Restart iMessage",
                            subTitle: subtitle,
                            backgroundColor: tileColor,
                            leading: SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.chat_bubble,
                              materialIcon: Icons.sms,
                            ),
                            showDivider: false,
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
                                ? Icon(Icons.refresh, color: Colors.grey)
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
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  SettingsTile(
                      title: "Restart BlueBubbles Server",
                      subTitle: (isRestarting)
                          ? "Restart in progress..."
                          : "This will briefly disconnect you",
                      backgroundColor: tileColor,
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.desktopcomputer,
                        materialIcon: Icons.dvr,
                      ),
                      showDivider: false,
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
                          ? Icon(Icons.refresh, color: Colors.grey)
                          : Container(
                              constraints: BoxConstraints(
                                maxHeight: 20,
                                maxWidth: 20,
                              ),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              ))),
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
