import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/layouts/setup/text_input_url.dart';
import 'package:bluebubbles/layouts/setup/welcome_page.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
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
  FCMData _fcmDataCopy;
  double numberOfMessages = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;
    _fcmDataCopy = SettingsManager().fcmData;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        PageView(
          onPageChanged: (int page) {
            currentPage = page + 1;
            if (this.mounted) setState(() {});
          },
          physics: NeverScrollableScrollPhysics(),
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
              color: Theme.of(context).primaryColor, // button color
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
                },
              ),
            ),
          ),
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
                color: Theme.of(context).primaryColor, // button color
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
                  },
                ),
              ),
            ),
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
                color: Theme.of(context).primaryColor, // button color
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
                        _fcmDataCopy = FCMData(
                          projectID: fcmData[2],
                          storageBucket: fcmData[3],
                          apiKey: fcmData[4],
                          firebaseURL: fcmData[5],
                          clientID: fcmData[6],
                          applicationID: fcmData[7],
                        );
                        _settingsCopy.guidAuthKey = fcmData[0];
                        _settingsCopy.serverAddress = fcmData[1];
                        await SettingsManager().saveSettings(_settingsCopy);
                        await SettingsManager().saveFCMData(_fcmDataCopy);
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
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
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
                "Or alternatively... you can enter in your url here",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.15),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.0),
              child: ClipOval(
                child: Material(
                  color: Theme.of(context).primaryColor,
                  child: InkWell(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Icon(
                        Icons.input,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () async {
                      showDialog(
                        context: context,
                        builder: (context) => TextInputURL(
                          onError: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title:
                                    Text("An error occured trying to connect"),
                                actions: [
                                  FlatButton(
                                    child: Text("OK"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  )
                                ],
                              ),
                            );
                          },
                          onConnect: () {
                            Navigator.of(context).pop();
                            controller.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          onClose: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  ),
                ),
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
            Container(height: 50.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Number of Messages to Sync Per Chat: $numberOfMessages",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Slider(
                value: numberOfMessages,
                onChanged: (double value) {
                  if (!this.mounted) return;

                  setState(() {
                    numberOfMessages = value;
                  });
                },
                label: numberOfMessages.toString(),
                divisions: 9,
                min: 25,
                max: 250,
              ),
            ),
            Container(height: 20.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Download Attachments (long sync)",
                    style: Theme.of(context)
                        .textTheme
                        .bodyText1,
                    textAlign: TextAlign.center,
                  ),
                  Switch(
                    value: downloadAttachments,
                    activeColor: Theme.of(context).primaryColor,
                    activeTrackColor:
                        Theme.of(context).primaryColor.withAlpha(200),
                    inactiveTrackColor:
                        Theme.of(context).primaryColor.withAlpha(75),
                    inactiveThumbColor:
                        Theme.of(context).textTheme.bodyText1.color,
                    onChanged: (bool value) {
                      if (!this.mounted) return;

                      setState(() {
                        downloadAttachments = value;
                      });
                    },
                  )
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Skip empty chats",
                    style: Theme.of(context)
                        .textTheme
                        .bodyText1,
                    textAlign: TextAlign.center,
                  ),
                  Switch(
                    value: skipEmptyChats,
                    activeColor: Theme.of(context).primaryColor,
                    activeTrackColor:
                        Theme.of(context).primaryColor.withAlpha(200),
                    inactiveTrackColor:
                        Theme.of(context).primaryColor.withAlpha(75),
                    inactiveThumbColor:
                        Theme.of(context).textTheme.bodyText1.color,
                    onChanged: (bool value) {
                      if (!this.mounted) return;

                      setState(() {
                        skipEmptyChats = value;
                      });
                    },
                  )
                ],
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
                    child: Icon(
                      Icons.cloud_download,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () async {
                    if (_settingsCopy == null) {
                      controller.animateToPage(
                        3,
                        duration: Duration(milliseconds: 3),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // Set the number of messages to sync
                      SocketManager().setup.numberOfMessagesPerPage =
                          numberOfMessages;
                      SocketManager().setup.downloadAttachments =
                          downloadAttachments;
                      SocketManager().setup.skipEmptyChats =
                          skipEmptyChats;

                      // Start syncing
                      SocketManager().setup.startSync(
                        _settingsCopy,
                        () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor:
                                  Theme.of(context).backgroundColor,
                              title: Text(
                                "The socket connection failed, please check the server",
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
                          controller.animateToPage(
                            3,
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                      );
                      controller.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
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
