import 'dart:convert';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
    // TODO: implement initState
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
            _getStartedPage(),
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
                "${currentPage}/6",
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _getStartedPage() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Welcome to BlueBubbles",
              style: Theme.of(context).textTheme.bodyText1,
            ),
            Text(
              "Let's get started",
              style: Theme.of(context).textTheme.bodyText1,
            ),
            RaisedButton(
              color: Colors.grey,
              onPressed: () {
                controller.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestContacts() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            "BlueBubbles needs to access contacts, cause its a messaging app, what do you expect?",
            style: Theme.of(context).textTheme.bodyText1,
            textAlign: TextAlign.center,
          ),
          RaisedButton(
            color: Colors.grey,
            onPressed: () {
              ContactManager().getContacts();
              controller.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Icon(
              Icons.check,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupMacApp() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Next download the BlueBubbles Server app on your Mac and install. Follow the setup process",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            RaisedButton(
              color: Colors.grey,
              onPressed: () {
                controller.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Icon(
                Icons.check,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanQRCode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "BlueBubbles tries to make the setup process as easy as possible",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            Text(
              "As such, we need to retreive some Firebase authentication data from the server. This is done through a QR Code present in the settings of the Mac Server",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            RaisedButton(
              color: Colors.grey,
              onPressed: () async {
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
                  controller.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  // Singleton().saveSettings(_settingsCopy);
                }
              },
              child: Text(
                "Scan QR Code",
                style: Theme.of(context).textTheme.bodyText1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prepareToSyncMessages() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "For the final step, BlueBubbles will download all of the messages from your Mac's Message database.",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            Text(
              "This may take a while, so please be patient and do not exit out of the app or let your phone fall asleep",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            RaisedButton(
              color: Colors.grey,
              onPressed: () {
                if (_settingsCopy == null) {
                  controller.animateToPage(3,
                      duration: Duration(milliseconds: 3),
                      curve: Curves.easeInOut);
                } else {
                  SocketManager().setup.startSync(_settingsCopy);
                  controller.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Text(
                "Begin Sync",
                style: Theme.of(context).textTheme.bodyText1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inSyncSetup() {
    return StreamBuilder(
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
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                  Spacer(
                    flex: 5,
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value:
                          progress != 1.0 && progress != 0.0 ? progress : null,
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
    );
  }
}
