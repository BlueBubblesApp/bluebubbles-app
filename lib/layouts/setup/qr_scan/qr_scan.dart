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
import 'package:flutter/material.dart';

class QRScan extends StatefulWidget {
  QRScan({Key key, @required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _QRScanState createState() => _QRScanState();
}

class _QRScanState extends State<QRScan> {

  Future<void> scanQRCode() async {
    var result;
    try {
      result = await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) {
            return QRCodeScanner();
          },
        ),
      );

      if (isNullOrEmpty(result)) {
        throw new Exception("No data was scanned! Please re-scan your QRCode!");
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
      FCMData fcmData = FCMData(
        projectID: result[2],
        storageBucket: result[3],
        apiKey: result[4],
        firebaseURL: result[5],
        clientID: result[6],
        applicationID: result[7],
      );
      String password = result[0];
      String serverURL = getServerAddress(address: result[1]);

      showDialog(
        context: context,
        builder: (context) => ConnectingAlert(
          onConnect: (bool result) {
            if (result) {
              Navigator.of(context).pop();
              goToNextPage();
            }
          },
        ),
        barrierDismissible: false,
      );
      try {
        await SocketManager()
            .setup
            .connectToServer(fcmData, serverURL, password);
      } catch (e) {
        Navigator.of(context).pop();
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
                    child: Icon(
                      Icons.camera,
                      color: Colors.white,
                    ),
                  ),
                  onTap: scanQRCode,
                ),
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
                          onConnect: () {
                            Navigator.of(context).pop();
                            goToNextPage();
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

  void goToNextPage() {
    widget.controller.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
