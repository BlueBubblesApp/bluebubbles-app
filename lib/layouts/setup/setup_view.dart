import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/layouts/setup/welcome_page.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SetupView extends StatefulWidget {
  SetupView({Key key}) : super(key: key);

  @override
  _SetupViewState createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final controller = PageController(initialPage: 0);
  int currentPage = 1;
  Settings _settingsCopy;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        PageView(
          onPageChanged: (int page) {
            currentPage = page + 1;
            setState(() {});
          },
          physics:
              AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          controller: controller,
          children: <Widget>[
            WelcomePage(
              controller: controller,
            ),
            _requestContacts(),
            _setupMacApp(),
            _scanQRCode(),
            _prepareToSyncMessages(),
            _inSyncSetup(),
          ],
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text(
                "$currentPage/6",
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _requestContacts() {
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "BlueBubbles needs to access contacts. Tap the check to allow the permission.",
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .apply(fontSizeFactor: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          Container(height: 20.0),
          ClipOval(
              child: Material(
                  color: Colors.blue, // button color
                  child: InkWell(
                      child: SizedBox(
                          width: 60,
                          height: 60,
                          child: Icon(Icons.check, color: Colors.white)),
                      onTap: () async {
                        ContactManager().getContacts();
                        controller.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }))),
        ],
      ),
    );
  }

  Widget _setupMacApp() {
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Next download the BlueBubbles Server app on your Mac and install. Follow the setup process",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 20.0),
            ClipOval(
                child: Material(
                    color: Colors.blue, // button color
                    child: InkWell(
                        child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Icon(Icons.check, color: Colors.white)),
                        onTap: () async {
                          controller.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }))),
          ],
        ),
      ),
    );
  }

  Widget _scanQRCode() {
    TextEditingController textController = new TextEditingController();

    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "BlueBubbles tries to make the setup process as easy as possible. We've created a QR code on your server that you can use to easily register this device with the server.",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 20.0),
            ClipOval(
              child: Material(
                color: Colors.blue, // button color
                child: InkWell(
                    child: SizedBox(
                        width: 60,
                        height: 60,
                        child: Icon(Icons.camera, color: Colors.white)),
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
                      if (fcmData != null) {
                        _settingsCopy.fcmAuthData = {
                          "project_id": fcmData[2],
                          "storage_bucket": fcmData[3],
                          "api_key": fcmData[4],
                          "firebase_url": fcmData[5],
                          "client_id": fcmData[6],
                          "application_id": fcmData[7],
                        };
                        _settingsCopy.guidAuthKey = fcmData[0];
                        _settingsCopy.serverAddress = fcmData[1];
                        await SettingsManager().saveSettings(
                          _settingsCopy,
                          connectToSocket: false,
                          authorizeFCM: false,
                        );
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Theme.of(context).backgroundColor,
                            title: Text(
                              "Connecting",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                            content: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  // height: 70,
                                  // color: Colors.black,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (SocketManager().state == SocketState.CONNECTED) {
                          Navigator.of(context).pop();
                          controller.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }

                        SocketManager().startSocketIO();

                        StreamSubscription connectionStateSubscription;
                        connectionStateSubscription = SocketManager()
                            .connectionStateStream
                            .listen((event) {
                          if (event == SocketState.CONNECTED) {
                            Navigator.of(context).pop();
                            controller.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            connectionStateSubscription.cancel();
                          } else if (event == SocketState.ERROR ||
                              event == SocketState.DISCONNECTED) {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor:
                                    Theme.of(context).backgroundColor,
                                title: Text(
                                  "An error occurred trying to connect to the socket",
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                                actions: <Widget>[
                                  FlatButton(
                                    child: Text("Ok",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText1),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  )
                                ],
                              ),
                            );
                            connectionStateSubscription.cancel();
                          }
                        });
                      }
                    }),
              ),
            ),
            Container(height: 80.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Or alternatively... you can enter in your ngrok url here: ",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.25),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Spacer(
                    flex: 1,
                  ),
                  Text("https://"),
                  Expanded(
                    child: CupertinoTextField(
                      controller: textController,
                      maxLength: 10,
                      maxLengthEnforced: false,
                      maxLines: 1,
                    ),
                  ),
                  Text(".ngrok.io"),
                  Spacer(
                    flex: 1,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _prepareToSyncMessages() {
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "For the final step, BlueBubbles will download the first 25 messages for each of your chats.",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 10.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Don't worry, you can see your chat history by scrolling up in a chat.",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 20.0),
            ClipOval(
                child: Material(
                    color: Colors.green.withAlpha(200), // button color
                    child: InkWell(
                        child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Icon(Icons.cloud_download,
                                color: Colors.white)),
                        onTap: () async {
                          if (_settingsCopy == null) {
                            controller.animateToPage(3,
                                duration: Duration(milliseconds: 3),
                                curve: Curves.easeInOut);
                          } else {
                            SocketManager().setup.startSync(_settingsCopy, () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor:
                                      Theme.of(context).backgroundColor,
                                  title: Text(
                                    "The socket connection failed, please check the server",
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                  actions: <Widget>[
                                    FlatButton(
                                      child: Text("Ok",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    )
                                  ],
                                ),
                              );
                              controller.animateToPage(3,
                                  duration: Duration(milliseconds: 500),
                                  curve: Curves.easeInOut);
                            });
                            controller.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        })))
          ],
        ),
      ),
    );
  }

  Widget _inSyncSetup() {
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: StreamBuilder(
        stream: SocketManager().setup.stream,
        builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
          double progress = SocketManager().setup.progress;
          if (snapshot.hasData) {
            progress = snapshot.data;
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width / 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Spacer(
                      flex: 100,
                    ),
                    Text(
                      "${(progress * 100).floor()}%",
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .apply(fontSizeFactor: 1.5),
                    ),
                    Spacer(
                      flex: 5,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress != 1.0 && progress != 0.0
                            ? progress
                            : null,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    Spacer(
                      flex: 100,
                    ),
                  ],
                ),
              ),
            );
          } else {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width / 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Spacer(
                      flex: 100,
                    ),
                    Text(
                      progress == 0.0 ? "Starting setup" : "Finishing setup",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    Spacer(
                      flex: 5,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    Spacer(
                      flex: 100,
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
