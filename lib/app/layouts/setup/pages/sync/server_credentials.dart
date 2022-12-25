import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_scan_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/async_connecting_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/qr_code_scanner.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:universal_io/io.dart';

class ServerCredentials extends StatefulWidget {
  @override
  State<ServerCredentials> createState() => _ServerCredentialsState();
}

class _ServerCredentialsState extends OptimizedState<ServerCredentials> {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final controller = Get.find<SetupViewController>();

  bool showManualEntry = false;

  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Server Connection",
      subtitle: kIsWeb || kIsDesktop
          ? "Enter your server URL and password to access your messages."
          : "We've created a QR code on your server that you can scan with your phone for easy setup.\n\nAlternatively, you can manually input your URL and password.",
      contentWrapper: (child) => AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: showManualEntry && context.isPhone
              ? const SizedBox.shrink() : child,
      ),
      customButton: Column(
        children: [
          ErrorText(parentController: controller),
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
                      const Icon(CupertinoIcons.camera, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
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
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
              ),
            ),
            height: 40,
            padding: const EdgeInsets.all(2),
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
                  const SizedBox(width: 10),
                  Text("Manual entry",
                      style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !showManualEntry
                ? const SizedBox.shrink()
                : Theme(
              data: context.theme.copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    labelStyle: TextStyle(color: context.theme.colorScheme.outline),
                  )),
              child: Column(
                children: [
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  PasswordField(controller: passwordController, onSubmitted: (pass) {
                    connect(urlController.text, pass);
                  }),
                  const SizedBox(height: 20),
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
                        padding: const EdgeInsets.all(2),
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
                            maximumSize: MaterialStateProperty.all(const Size(200, 36)),
                            minimumSize: MaterialStateProperty.all(const Size(30, 30)),
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
                              const SizedBox(width: 10),
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
                            maximumSize: MaterialStateProperty.all(const Size(200, 36)),
                            minimumSize: MaterialStateProperty.all(const Size(30, 30)),
                          ),
                          onPressed: () async {
                            connect(urlController.text, passwordController.text);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Connect",
                                  style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
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
    );
  }

  void goToNextPage() {
    if (kIsWeb) {
      setup.startSetup(25, true, false);
    }

    if (controller.currentPage == controller.pageOfNoReturn) {
      controller.pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

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
    try {
      final response = await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) {
            return QRCodeScanner();
          },
        ),
      );

      if (isNullOrEmpty(response)!) {
        throw Exception("No data was scanned, please try again.");
      } else {
        final List result = jsonDecode(response);

        // make sure we have all the data we need
        if (result.length < 2) {
          throw Exception("Invalid data scanned!");
        }

        // Make sure we have a URL and password
        String? password = result[0];
        String? serverURL = sanitizeServerAddress(address: result[1]);
        if (serverURL == null || serverURL.isEmpty || password == null || password.isEmpty) {
          throw Exception("Could not detect server URL and password!");
        }

        connect(serverURL, password);
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FailedToScanDialog(title: "Error", exception: e.toString());
        },
      );
    }
  }

  Future<void> connect(String url, String password) async {
    if (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }
    if (kIsWeb && url.startsWith("http://")) {
      controller.updateConnectError("HTTP URLs are not supported on Web! You must use an HTTPS URL.");
      return;
    }
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
    // the getx regex only allows extensions up to 6 characters in length
    // this is a workaround for that
    if (!isValid && url.split(".").last.isAlphabetOnly && url.split(".").last.length > 6) {
      final newUrl = url.split(".").sublist(0, url.split(".").length - 1).join(".");
      isValid = ("$newUrl.com").isURL;
    }

    // If the URL is invalid, or the password is invalid, show an error
    if (!isValid || password.isEmpty) {
      controller.updateConnectError("Please enter a valid URL and password!");
      return;
    }

    String? addr = sanitizeServerAddress(address: url);
    if (addr == null) {
      controller.updateConnectError("Server address is invalid!");
      return;
    }

    ss.settings.serverAddress.value = addr;
    ss.settings.guidAuthKey.value = password;
    ss.settings.save();

    // Request data from the API
    Future<dio.Response> fcmFuture = http.fcmClient();

    Get.dialog(AsyncConnectingDialog(
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
            controller.updateConnectError("Failed to connect to server! ${data["error"]?["type"] ?? "API_ERROR"}: ${data["message"] ?? data["error"]["message"]}");
            return;
          }

          if (isNullOrEmpty(data["data"])! && (addr.contains("ngrok.io") || addr.contains("trycloudflare.com"))) {
            return setState(() {
              controller.updateConnectError("Firebase is required when using Ngrok or Cloudflare!");
            });
          } else {
            try {
              FCMData fcmData = FCMData.fromMap(data["data"]);
              ss.saveFCMData(fcmData);
            } catch (_) {
              if (Platform.isAndroid) {
                showSnackbar("Warning", "No Firebase project detected! You will not receive notifications for new messages!");
              }
            }
            socket.restartSocket();
            goToNextPage();
          }
        } else if (mounted) {
          if (err != null) {
            final errorData = jsonDecode(err as String);
            if (errorData['status'] == 401) {
              controller.updateConnectError("Authentication failed. Incorrect password!");
              return;
            } else {
              controller.updateConnectError("Failed to connect! Error: [${errorData['status']}] ${errorData['message']}");
              return;
            }
          } else {
            controller.updateConnectError("Failed to connect to $addr! Please ensure your credentials are correct and check the server logs for more info.");
            return;
          }
        }
      },
    ));
  }
}

class ErrorText extends CustomStateful<SetupViewController> {
  ErrorText({required super.parentController});

  @override
  State<StatefulWidget> createState() => _ErrorTextState();
}

class _ErrorTextState extends CustomState<ErrorText, String, SetupViewController> {

  @override
  void updateWidget(String newVal) {
    controller.error = newVal;
    super.updateWidget(newVal);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.error.isNotEmpty)
          Container(
            width: context.width * 2 / 3,
            child: Align(
              alignment: Alignment.center,
              child: Text(controller.error,
                  style: context.theme.textTheme.bodyLarge!.apply(
                    fontSizeDelta: 1.5,
                    color: context.theme.colorScheme.error,
                  ).copyWith(height: 2)),
            ),
          ),
        if (controller.error.isNotEmpty) 
          const SizedBox(height: 20),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  PasswordField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final Function(String) onSubmitted;

  @override
  State<StatefulWidget> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends OptimizedState<PasswordField> {
  bool obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width * 2 / 3,
      child: TextField(
        cursorColor: context.theme.colorScheme.primary,
        autocorrect: false,
        autofocus: false,
        controller: widget.controller,
        textInputAction: TextInputAction.next,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: context.theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(20)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: context.theme.colorScheme.primary),
              borderRadius: BorderRadius.circular(20)),
          labelText: "Password",
          contentPadding: const EdgeInsets.fromLTRB(12, 24, 40, 16),
          suffixIcon: IconButton(
            icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
            color: context.theme.colorScheme.outline,
            onPressed: () {
              setState(() {
                obscureText = !obscureText;
              });
            },
          ),
        ),
        obscureText: obscureText,
      ),
    );
  }
}
