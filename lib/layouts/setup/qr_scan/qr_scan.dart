import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/connecting_alert/future_loader_dialog.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/stateless_animation/custom_animation.dart';

class QRScan extends StatefulWidget {
  QRScan({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  State<QRScan> createState() => _QRScanState();
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
    // Make sure we have the correct permissions
    PermissionStatus status = await Permission.camera.status;
    if (!status.isPermanentlyDenied && !status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        showSnackbar("Error", "Camera permission required for QR scanning!");
        return;
      }
    } else if (status.isPermanentlyDenied) {
      showSnackbar("Error", "Camera permission permanently denied, please modify permissions from Android settings.");
      return;
    }

    // Open the QR Scanner and get the result
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
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Error",
              style: context.theme.textTheme.titleLarge,
            ),
            backgroundColor: context.theme.colorScheme.properSurface,
            content: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                  physics: ThemeSwitcher.getScrollPhysics(),
                  child: Text(
                      e.toString().contains("ROWID")
                          ? "iMessage is not configured on the macOS server, please sign in with an Apple ID and try again."
                          : e.toString(),
                      style: context.theme.textTheme.bodyLarge)),
            ),
            actions: <Widget>[
              TextButton(
                child: Text("Copy", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () {
                  Navigator.of(context).pop();
                  Clipboard.setData(ClipboardData(text: e.toString()));
                },
              ),
              TextButton(
                child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    if (result == null || (result is! List) || result.length < 2) {
      showSnackbar("Error", "Received invalid data from QR Scanner!");
      return;
    }

    // Make sure we have a URL and password
    String? password = result[0];
    String? serverURL = sanitizeServerAddress(address: result[1]);
    if (serverURL == null || serverURL.isEmpty || password == null || password.isEmpty) {
      showSnackbar("Error", "Your server URL or password was unable to be parsed!");
      return;
    }

    connect(serverURL, password);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness:
          context.theme.colorScheme.background.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.background.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.theme.colorScheme.background,
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
                                          style: context.theme.textTheme.displaySmall!.apply(
                                            fontWeightDelta: 2,
                                          ).copyWith(height: 1.35, color: context.theme.colorScheme.onBackground)),
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
                                        style: context.theme.textTheme.bodyLarge!.apply(
                                          fontSizeDelta: 1.5,
                                          color: context.theme.colorScheme.outline,
                                        ).copyWith(height: 2)),
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
                                  style: context.theme.textTheme.bodyLarge!.apply(
                                    fontSizeDelta: 1.5,
                                    color: context.theme.colorScheme.error,
                                  ).copyWith(height: 2)),
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
                                          style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
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
                              backgroundColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                              shadowColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                              maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                              minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                            ),
                            onPressed: () async {
                              setState(() {
                                showManualEntry = !showManualEntry;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.text_cursor,
                                    color: context.theme.colorScheme.onBackground, size: 20),
                                SizedBox(width: 10),
                                Text("Manual entry",
                                    style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: Duration(milliseconds: 200),
                          child: !showManualEntry
                              ? SizedBox.shrink()
                              : Theme(
                                  data: context.theme.copyWith(
                                      inputDecorationTheme: InputDecorationTheme(
                                    labelStyle: TextStyle(color: context.theme.colorScheme.outline),
                                  )),
                                  child: Column(
                                    children: [
                                      SizedBox(height: 20),
                                      Container(
                                        width: context.width * 2 / 3,
                                        child: TextField(
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
                                      ),
                                      SizedBox(height: 20),
                                      Container(
                                        width: context.width * 2 / 3,
                                        child: Stack(
                                          alignment: Alignment.centerRight,
                                          children: [
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
                                              },
                                              decoration: InputDecoration(
                                                enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                                                    borderRadius: BorderRadius.circular(20)),
                                                focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                                                    borderRadius: BorderRadius.circular(20)),
                                                labelText: "Password",
                                                contentPadding: EdgeInsets.fromLTRB(12, 24, 40, 16),
                                              ),
                                              obscureText: obscureText,
                                            ),
                                            IconButton(
                                              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                                              color: context.theme.colorScheme.outline,
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
                                                    MaterialStateProperty.all(context.theme.colorScheme.background),
                                                shadowColor:
                                                    MaterialStateProperty.all(context.theme.colorScheme.background),
                                                maximumSize: MaterialStateProperty.all(Size(200, 36)),
                                                minimumSize: MaterialStateProperty.all(Size(30, 30)),
                                              ),
                                              onPressed: () async {
                                                setState(() {
                                                  showManualEntry = false;
                                                });
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close, color: context.theme.colorScheme.onBackground, size: 20),
                                                  SizedBox(width: 10),
                                                  Text("Cancel",
                                                      style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
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
                                                minimumSize: MaterialStateProperty.all(Size(30, 30)),
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
                                                      style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
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
    // Check if the URL is valid
    bool isValid = url.isURL;
    if (url.contains(":") && !isValid) {
      if (":".allMatches(url).length == 2) {
        final newUrl = url.split(":")[1].split("/").last;
        isValid = newUrl.isIPv6 || newUrl.isIPv4;
      } else {
        final newUrl = url.split(":").first;
        isValid = newUrl.isIPv6 || newUrl.isIPv4;
      }
    }
    if (url.endsWith(".network") && !isValid) {
      final newUrl = url.split(".network").first;
      isValid = ("$newUrl.com").isURL;
    }

    // If the URL is invalid, or the password is invalid, show an error
    if (!isValid || password.isEmpty) {
      return setState(() {
        error = "Please enter a valid URL and password!";
      });
    }

    String? addr = sanitizeServerAddress(address: url);
    if (addr == null && mounted) {
      return setState(() {
        error = "Server address is invalid!";
      });
    }

    SettingsManager().settings.serverAddress.value = addr!;
    SettingsManager().settings.guidAuthKey.value = password;
    SettingsManager().settings.save();

    // Request data from the API
    Future<dio.Response> fcmFuture = api.fcmClient();

    Get.dialog(FutureLoaderDialog(
      future: fcmFuture,
      showErrorDialog: false,
      onConnect: (bool result, Object? err) async {
        if (result) {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }

          setState(() {
            showManualEntry = false;
          });

          dio.Response fcmResponse = await fcmFuture;
          Map<String, dynamic> data = fcmResponse.data;
          if (fcmResponse.statusCode != 200) {
            return setState(() {
              error =
                  "Failed to connect to server! ${data["error"]?["type"] ?? "API_ERROR"}: ${data["message"] ?? data["error"]["message"]}";
            });
          }

          FCMData fcmData = FCMData.fromMap(data["data"]);
          SettingsManager().saveFCMData(fcmData);
          goToNextPage();
        } else if (mounted) {
          if (err != null) {
            final errorData = jsonDecode(err as String);
            if (errorData['status'] == 401) {
              setState(() {
                error = "Authentication failed. Incorrect password!";
              });
            } else {
              setState(() {
                error = "Failed to connect! Error: [${errorData['status']}] ${errorData['message']}";
              });
            }
          } else {
            setState(() {
              error =
                  "Failed to connect to $addr! Please ensure your credentials are correct (including http://) and check the server logs for more info.";
            });
          }
        }
      },
    ));
  }
}
