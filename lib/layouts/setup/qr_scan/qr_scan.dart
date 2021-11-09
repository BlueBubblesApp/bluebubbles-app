import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/connecting_alert/connecting_alert.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/failed_to_scan_dialog.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/text_input_url.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QRScan extends StatefulWidget {
  QRScan({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _QRScanState createState() => _QRScanState();
}

class _QRScanState extends State<QRScan> {
  Future<void> scanQRCode() async {
    dynamic result;
    try {
      result = await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) {
            return QRCodeScanner();
          },
        ),
      );

      if (isNullOrEmpty(result)!) {
        throw Exception("No data was scanned! Please re-scan your QRCode!");
      }

      result = jsonDecode(result);
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => FailedToScan(
          exception: e,
          title: "Failed to scan",
        ),
      );
      return;
    }
    if (result != null && result.length > 0) {
      FCMData? fcmData;

      if (result.length > 2) {
        fcmData = FCMData(
          projectID: result[2],
          storageBucket: result[3],
          apiKey: result[4],
          firebaseURL: result[5],
          clientID: result[6],
          applicationID: result[7],
        );
      } else {
        try {
          // Fetch FCM data from the server
          Map<String, dynamic> fcmMeta = await SocketManager().getFcmClient();

          // Parse out the new FCM data
          fcmData = parseFcmJson(fcmMeta);
        } catch (ex) {
          // If we fail, who cares!
        }
      }

      String? password = result[0];
      String? serverURL = getServerAddress(address: result[1]);

      showDialog(
        context: context,
        builder: (connectContext) => ConnectingAlert(
          onConnect: (bool result) {
            if (result) {
              if (Navigator.of(connectContext).canPop()) {
                Navigator.of(connectContext).pop();
              }

              goToNextPage();
            }
          },
        ),
        barrierDismissible: false,
      );

      try {
        if (fcmData == null) {
          throw Exception("FCM data was null! Failed to register device!");
        } else if (serverURL == null) {
          throw Exception("Server URL was null! Failed to register device!");
        } else if (password == null) {
          throw Exception("Password was null! Failed to register device!");
        }

        await SocketManager().setup.connectToServer(fcmData, serverURL, password);
      } catch (e) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        showDialog(
          context: context,
          builder: (context) => FailedToScan(
            exception: e,
            title: "Failed to scan",
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).accentColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  kIsWeb || kIsDesktop ? "Please enter your server URL and password to access your messages" : "BlueBubbles tries to make the setup process as easy as possible. We've created a QR code on your server that you can use to easily register this device with the server.",
                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(height: 20.0),
              if (!kIsWeb && !kIsDesktop)
                ClipOval(
                  child: Material(
                    color: Theme.of(context).primaryColor, // button color
                    child: InkWell(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: Icon(
                          Icons.camera,
                          color: Colors.white,
                        ),
                      ),
                      onTap: scanQRCode,
                    ),
                  ),
                ),
              if (!kIsWeb && !kIsDesktop)
                Container(height: 80.0),
              if (!kIsWeb && !kIsDesktop)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "Or alternatively... you can enter in your url here",
                    style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.15),
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
                          builder: (connectContext) => TextInputURL(
                            onConnect: () {
                              if (Navigator.of(connectContext).canPop()) {
                                Navigator.of(connectContext).pop();
                              }

                              goToNextPage();
                            },
                            onClose: () {
                              if (Navigator.of(connectContext).canPop()) {
                                Navigator.of(connectContext).pop();
                              }
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
      ),
    );
  }

  void goToNextPage() {
    widget.controller.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
