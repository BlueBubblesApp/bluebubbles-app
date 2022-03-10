import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/connecting_alert/connecting_alert.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/stateless_animation/custom_animation.dart';

class QRScan extends StatefulWidget {
  QRScan({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _QRScanState createState() => _QRScanState();
}

class _QRScanState extends State<QRScan> {
  bool showManualEntry = false;
  TextEditingController urlController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  String error = "";
  CustomAnimationControl controller = CustomAnimationControl.mirror;
  Tween<double> tween = Tween<double>(begin: 0, end: 5);
  bool obscureText = true;

  Future<void> scanQRCode() async {
    PermissionStatus status = await Permission.contacts.status;
    if (!status.isPermanentlyDenied && !status.isGranted) {
      final result = await Permission.contacts.request();
      if (!result.isGranted) {
        showSnackbar("Error", "Camera permission required for QR scanning!");
        return;
      }
    } else if (status.isPermanentlyDenied) {
      showSnackbar("Error", "Camera permission permanently denied, please modify permissions from Android settings.");
      return;
    }
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
        throw Exception("No data was scanned, please try again.");
      } else {
        result = jsonDecode(result);
      }
    } catch (e) {
      Get.defaultDialog(
          title: "Error",
          titleStyle: Theme.of(context).textTheme.headline1,
          backgroundColor: Theme.of(context).backgroundColor.lightenPercent(),
          buttonColor: Theme.of(context).primaryColor,
          content: Container(
            constraints: BoxConstraints(
              maxHeight: 300,
            ),
            child: Center(
              child: Container(
                width: 300,
                height: 200,
                constraints: BoxConstraints(
                  maxHeight: Get.height - 300,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                      child: Text(
                          e.toString().contains("ROWID")
                              ? "iMessage is not configured on the macOS server, please sign in with an Apple ID and try again."
                              : e.toString(),
                          textAlign: TextAlign.center)),
                ),
              ),
            ),
          ),
          textConfirm: "OK",
          textCancel: "COPY",
          cancelTextColor: Theme.of(context).primaryColor,
          onConfirm: () async {
            Navigator.of(context).pop();
          },
          onCancel: () {
            Clipboard.setData(ClipboardData(text: e.toString()));
          });
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

        Get.defaultDialog(
            title: "Error",
            titleStyle: Theme.of(context).textTheme.headline1,
            backgroundColor: Theme.of(context).backgroundColor.lightenPercent(),
            buttonColor: Theme.of(context).primaryColor,
            content: Container(
              constraints: BoxConstraints(
                maxHeight: 300,
              ),
              child: Center(
                child: Container(
                  width: 300,
                  height: 200,
                  constraints: BoxConstraints(
                    maxHeight: Get.height - 300,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                        child: Text(
                            e.toString().contains("ROWID")
                                ? "iMessage is not configured on the macOS server, please sign in with an Apple ID and try again."
                                : e.toString(),
                            textAlign: TextAlign.center)),
                  ),
                ),
              ),
            ),
            textConfirm: "OK",
            textCancel: "COPY",
            cancelTextColor: Theme.of(context).primaryColor,
            onConfirm: () async {
              Navigator.of(context).pop();
            },
            onCancel: () {
              Clipboard.setData(ClipboardData(text: e.toString()));
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
            ? Colors.transparent
            : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: LayoutBuilder(builder: (context, size) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0, bottom: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    AnimatedSize(
                      duration: Duration(milliseconds: 200),
                      child: showManualEntry && context.isPhone
                          ? Container()
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: context.width * 2 / 3,
                                      child: Text("Server Connection",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1!
                                              .apply(
                                                fontSizeFactor: 2.5,
                                                fontWeightDelta: 2,
                                              )
                                              .copyWith(height: 1.5)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        kIsWeb || kIsDesktop
                                            ? "Enter your server URL and password to access your messages."
                                            : "We've created a QR code on your server that you can scan with your phone for easy setup.\n\nAlternatively, you can manually input your URL and password.",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText1!
                                            .apply(
                                              fontSizeFactor: 1.1,
                                              color: Colors.grey,
                                            )
                                            .copyWith(height: 2)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Column(
                      children: [
                        if (error.isNotEmpty)
                          Container(
                            width: context.width * 2 / 3,
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(error,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText1!
                                      .apply(
                                        fontSizeFactor: 1.1,
                                        color: Colors.red,
                                      )
                                      .copyWith(height: 2)),
                            ),
                          ),
                        if (error.isNotEmpty) SizedBox(height: 20),
                        if (!kIsWeb && !kIsDesktop)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.topStart,
                                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                              ),
                            ),
                            height: 40,
                            child: ElevatedButton(
                              style: ButtonStyle(
                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                                backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                shadowColor: MaterialStateProperty.all(Colors.transparent),
                                maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                                minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                              ),
                              onPressed: scanQRCode,
                              child: Shimmer.fromColors(
                                baseColor: Colors.white70,
                                highlightColor: Colors.white,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomAnimation<double>(
                                      control: controller,
                                      tween: tween,
                                      duration: Duration(milliseconds: 600),
                                      curve: Curves.easeOut,
                                      builder: (context, _, anim) {
                                        return Padding(
                                          padding: EdgeInsets.only(left: 0.0),
                                          child: Icon(CupertinoIcons.camera, color: Colors.white, size: 20),
                                        );
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                                      child: Text("Scan QR Code",
                                          style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: LinearGradient(
                              begin: AlignmentDirectional.topStart,
                              colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                            ),
                          ),
                          height: 40,
                          padding: EdgeInsets.all(2),
                          child: ElevatedButton(
                            style: ButtonStyle(
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                              backgroundColor: MaterialStateProperty.all(Theme.of(context).backgroundColor),
                              shadowColor: MaterialStateProperty.all(Theme.of(context).backgroundColor),
                              maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                              minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                            ),
                            onPressed: () async {
                              // showDialog(
                              //   context: context,
                              //   builder: (connectContext) => TextInputURL(
                              //     onConnect: () {
                              //       if (Navigator.of(connectContext).canPop()) {
                              //         Navigator.of(connectContext).pop();
                              //       }
                              //
                              //       goToNextPage();
                              //     },
                              //     onClose: () {
                              //       if (Navigator.of(connectContext).canPop()) {
                              //         Navigator.of(connectContext).pop();
                              //       }
                              //     },
                              //   ),
                              // );
                              setState(() {
                                showManualEntry = !showManualEntry;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.text_cursor, color: Theme.of(context).textTheme.bodyText1!.color, size: 20),
                                SizedBox(width: 10),
                                Text("Manual entry",
                                    style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1)),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: Duration(milliseconds: 200),
                          child: !showManualEntry
                              ? SizedBox.shrink()
                              : Theme(
                                  data: Theme.of(context).copyWith(
                                      inputDecorationTheme: const InputDecorationTheme(
                                    labelStyle: TextStyle(color: Colors.grey),
                                  )),
                                  child: Column(
                                    children: [
                                      SizedBox(height: 20),
                                      Container(
                                        width: context.width * 2 / 3,
                                        child: TextField(
                                          cursorColor: Theme.of(context).primaryColor,
                                          autocorrect: false,
                                          autofocus: true,
                                          controller: urlController,
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                            enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(color: Colors.grey),
                                                borderRadius: BorderRadius.circular(20)),
                                            focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                                borderRadius: BorderRadius.circular(20)),
                                            labelText: "URL",
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Container(
                                        width: context.width * 2 / 3,
                                        child: Stack(
                                          alignment: Alignment.centerRight,
                                          children: [
                                            TextField(
                                              cursorColor: Theme.of(context).primaryColor,
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
                                              },
                                              decoration: InputDecoration(
                                                enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.grey),
                                                    borderRadius: BorderRadius.circular(20)),
                                                focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                                    borderRadius: BorderRadius.circular(20)),
                                                labelText: "Password",
                                                contentPadding: EdgeInsets.fromLTRB(12, 24, 40, 16),
                                              ),
                                              obscureText: obscureText,
                                            ),
                                            IconButton(
                                              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                                              color: Colors.grey,
                                              onPressed: () {
                                                setState(() {
                                                  obscureText = !obscureText;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(25),
                                              gradient: LinearGradient(
                                                begin: AlignmentDirectional.topStart,
                                                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                              ),
                                            ),
                                            height: 40,
                                            padding: EdgeInsets.all(2),
                                            child: ElevatedButton(
                                              style: ButtonStyle(
                                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                                  RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20.0),
                                                  ),
                                                ),
                                                backgroundColor:
                                                    MaterialStateProperty.all(Theme.of(context).backgroundColor),
                                                shadowColor:
                                                    MaterialStateProperty.all(Theme.of(context).backgroundColor),
                                                maximumSize: MaterialStateProperty.all(Size(200, 36)),
                                              ),
                                              onPressed: () async {
                                                setState(() {
                                                  showManualEntry = false;
                                                });
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close, color: Colors.white, size: 20),
                                                  SizedBox(width: 10),
                                                  Text("Cancel",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1!
                                                          .apply(fontSizeFactor: 1.1)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(25),
                                              gradient: LinearGradient(
                                                begin: AlignmentDirectional.topStart,
                                                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                              ),
                                            ),
                                            height: 40,
                                            child: ElevatedButton(
                                              style: ButtonStyle(
                                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                                  RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20.0),
                                                  ),
                                                ),
                                                backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                                shadowColor: MaterialStateProperty.all(Colors.transparent),
                                                maximumSize: MaterialStateProperty.all(Size(200, 36)),
                                              ),
                                              onPressed: () async {
                                                if (urlController.text == "googleplaytest" &&
                                                    passwordController.text == "googleplaytest") {
                                                  Get.toNamed("/testing-mode");
                                                  return;
                                                }
                                                connect(urlController.text, passwordController.text);
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text("Connect",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1!
                                                          .apply(fontSizeFactor: 1.1, color: Colors.white)),
                                                  SizedBox(width: 10),
                                                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void goToNextPage() {
    if (kIsWeb) {
      // Set the number of messages to sync
      SocketManager().setup.numberOfMessagesPerPage = 25;
      SocketManager().setup.downloadAttachments = false;
      SocketManager().setup.skipEmptyChats = true;

      // Start syncing
      SocketManager().setup.startFullSync(SettingsManager().settings);
    }

    if (widget.controller.page == (kIsWeb || kIsDesktop ? 2 : 4)) {
      widget.controller.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void connect(String url, String password) async {
    bool isValid = url.isURL;
    if (url.contains(":") && !isValid) {
      final newUrl = url.split(":").first;
      isValid = newUrl.isIPv6 || newUrl.isIPv4;
    }
    if (url.endsWith(".network") && !isValid) {
      final newUrl = url.split(".network").first;
      isValid = (newUrl + ".com").isURL;
    }
    if (!isValid || password.isEmpty) {
      setState(() {
        error = "Please enter a valid URL and password!";
      });
      return;
    }
    Get.dialog(
      ConnectingAlert(
        onConnect: (bool result) {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }
          if (result) {
            setState(() {
              showManualEntry = false;
            });
            retreiveFCMData();
          } else {
            if (mounted) {
              setState(() {
                error =
                    "Failed to connect to ${getServerAddress()}! Please ensure your credentials are correct (including http://) and check the server logs for more info.";
              });
            }
          }
        },
      ),
      barrierDismissible: false,
    );
    SocketManager().closeSocket(force: true);
    String? addr = getServerAddress(address: url);
    if (addr == null) {
      error = "Server address is invalid!";
      if (mounted) setState(() {});
      return;
    }

    SettingsManager().settings.serverAddress.value = addr;
    SettingsManager().settings.guidAuthKey.value = password;
    SettingsManager().settings.save();
    try {
      SocketManager().startSocketIO(forceNewConnection: true, catchException: false);
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() {});
    }
  }

  void retreiveFCMData() {
    SocketManager().sendMessage("get-fcm-client", {}, (_data) {
      if (_data["status"] != 200) {
        error = _data["error"]["message"];
        if (mounted) setState(() {});
        return;
      }
      FCMData? copy = SettingsManager().fcmData;
      Map<String, dynamic>? data = _data["data"];
      if (data != null && data.isNotEmpty) {
        copy = FCMData.fromMap(data);

        SettingsManager().saveFCMData(copy);
      }
      goToNextPage();
    });
  }
}
