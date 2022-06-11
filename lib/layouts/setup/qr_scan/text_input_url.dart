import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/connecting_alert/connecting_alert.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/failed_to_scan_dialog.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

class TextInputURL extends StatefulWidget {
  TextInputURL({Key? key, required this.onConnect, required this.onClose}) : super(key: key);
  final Function() onConnect;
  final Function() onClose;

  @override
  State<TextInputURL> createState() => _TextInputURLState();
}

class _TextInputURLState extends State<TextInputURL> {
  bool connecting = false;
  late TextEditingController urlController;
  late TextEditingController passwordController;
  String? error;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController();
    passwordController = TextEditingController();
  }

  void connect(String url, String password) async {
    SocketManager().closeSocket(force: true);
    Settings copy = SettingsManager().settings;
    String? addr = sanitizeServerAddress(address: url);
    if (addr == null) {
      error = "Server address is invalid!";
      if (mounted) setState(() {});
      return;
    }

    copy.serverAddress.value = addr;
    copy.guidAuthKey.value = password;
    await SettingsManager().saveSettings(copy);
    try {
      SocketManager().startSocketIO(forceNewConnection: true, catchException: false);
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() {});
    }
  }

  void retreiveFCMData() {
    // Get the FCM Client and make sure we have a valid response
    // If so, save. Let the parent widget know we've connected as long as
    // we get 200 from the API.
    api.fcmClient().then((response) {
      Map<String, dynamic>? data = response.data["data"];
      if (!isNullOrEmpty(data)!) {
        FCMData newData = FCMData.fromMap(data!);
        SettingsManager().saveFCMData(newData);
      }

      widget.onConnect();
    }).catchError((err) {
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err.toString();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!connecting) {
      return AlertDialog(
        title: Text(
          "Enter Server Details",
          style: context.theme.textTheme.titleLarge,
        ),
        backgroundColor: context.theme.colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              cursorColor: context.theme.colorScheme.primary,
              autocorrect: false,
              autofocus: true,
              controller: urlController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(20)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(20)),
                labelText: "URL",
              ),
            ),
            SizedBox(height: 10),
            TextField(
              cursorColor: context.theme.colorScheme.primary,
              autocorrect: false,
              autofocus: false,
              controller: passwordController,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                if (urlController.text == "googleplaytest" &&
                    passwordController.text == "googleplaytest") {
                  Get.toNamed("/testing-mode");
                  return;
                }
                connect(urlController.text, passwordController.text);
                connecting = true;
                if (mounted) setState(() {});
              },
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(20)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(20)),
                labelText: "Password",
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: widget.onClose,
          ),
          TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              if (urlController.text == "googleplaytest" && passwordController.text == "googleplaytest") {
                Get.toNamed("/testing-mode");
                return;
              }
              connect(urlController.text, passwordController.text);
              connecting = true;
              if (mounted) setState(() {});
            },
          ),
        ],
      );
    } else if (error != null) {
      return FailedToScan(
        title: "An error occured while trying to retreive data!",
        exception: error,
      );
    } else {
      return ConnectingAlert(
        onConnect: (bool result) {
          if (result) {
            retreiveFCMData();
          } else {
            if (mounted) {
              setState(() {
                error =
                    "Failed to connect to ${sanitizeServerAddress()}! Please check that the url is correct (including http://) and the server logs for more info.";
              });
            }
          }
        },
      );
    }
  }
}
