import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class TextInputURL extends StatefulWidget {
  TextInputURL({Key key, this.onConnect, this.onError, this.onClose})
      : super(key: key);
  final Function() onConnect;
  final Function() onError;
  final Function() onClose;

  @override
  _TextInputURLState createState() => _TextInputURLState();
}

class _TextInputURLState extends State<TextInputURL> {
  bool connecting = false;
  TextEditingController urlController;
  TextEditingController passwordController;
  @override
  void initState() {
    super.initState();
    urlController = new TextEditingController();
    passwordController = new TextEditingController();
  }

  void connect(String url, String password) {
    SocketManager().closeSocket(force: true);
    StreamSubscription connectionStateSubscription;
    connectionStateSubscription =
        SocketManager().connectionStateStream.listen((event) {
      if (event == SocketState.CONNECTED) {
        // Navigator.of(context).pop();
        // controller.nextPage(
        //   duration: Duration(milliseconds: 300),
        //   curve: Curves.easeInOut,
        // );
        connectionStateSubscription.cancel();
        retreiveFCMData();
      } else if (event == SocketState.ERROR ||
          event == SocketState.DISCONNECTED) {
        // Navigator.of(context).pop();
        // showDialog(
        //   context: context,
        //   builder: (context) => AlertDialog(
        //     backgroundColor: Theme.of(context).backgroundColor,
        //     title: Text(
        //       "An error occurred trying to connect to the socket",
        //       style: Theme.of(context).textTheme.bodyText1,
        //     ),
        //     actions: <Widget>[
        //       FlatButton(
        //         child: Text("Ok", style: Theme.of(context).textTheme.bodyText1),
        //         onPressed: () {
        //           Navigator.of(context).pop();
        //         },
        //       )
        //     ],
        //   ),
        // );
        connectionStateSubscription.cancel();
      }
    });
    Settings copy = SettingsManager().settings;
    copy.serverAddress = url;
    copy.guidAuthKey = password;
    SettingsManager().saveSettings(copy);
    SocketManager().startSocketIO(forceNewConnection: true);
  }

  void retreiveFCMData() {
    SocketManager().sendMessage("get-fcm-client", {}, (_data) {
      if (_data["status"] != 200) {
        widget.onError();
        return;
      }
      FCMData copy = SettingsManager().fcmData;
      Map<String, dynamic> data = _data["data"];
      copy = FCMData.fromMap(data);

      SettingsManager().saveFCMData(copy);
      widget.onConnect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return !connecting
        ? AlertDialog(
            title: Text("Type in the URL from the server"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autocorrect: false,
                  autofocus: true,
                  controller: urlController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "URL",
                  ),
                ),
                TextField(
                  autocorrect: false,
                  autofocus: true,
                  controller: passwordController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Password",
                  ),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              FlatButton(
                child: Text("OK"),
                onPressed: () {
                  connecting = true;
                  if (this.mounted) setState(() {});
                  connect(urlController.text, passwordController.text);
                },
              ),
              FlatButton(
                child: Text("Cancel"),
                onPressed: widget.onClose,
              )
            ],
          )
        : AlertDialog(
            title: Text("Connecting..."),
            content: LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
  }
}
