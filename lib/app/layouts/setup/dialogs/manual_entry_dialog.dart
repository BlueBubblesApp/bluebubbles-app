import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/connecting_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_scan_dialog.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

class ManualEntryDialog extends StatefulWidget {
  const ManualEntryDialog({super.key, required this.onConnect, required this.onClose});
  final Function() onConnect;
  final Function() onClose;

  @override
  State<ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<ManualEntryDialog> {
  final connecting = false.obs;
  final TextEditingController urlController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final error = Rx<String?>(null);

  void connect(String url, String password) async {
    if (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }
    if (kIsWeb && url.startsWith("http://")) {
      error.value = "HTTP URLs are not supported on Web! You must use an HTTPS URL.";
      return;
    }
    // Check if the URL is valid
    bool isValid = url.isURL;
    if (url.contains(":") && !isValid) {
      // port applied to URL
      if (":".allMatches(url).length == 2) {
        final newUrl = url.split(":")[1].split("/").last;
        isValid = "https://${(newUrl.split(".")..removeLast()).join(".")}.com".isURL || newUrl.isIPv6 || newUrl.isIPv4;
      } else {
        final newUrl = url.split(":").first;
        isValid = newUrl.isIPv6 || newUrl.isIPv4;
      }
    }
    // the getx regex only allows extensions up to 6 characters in length
    // this is a workaround for that
    if (!isValid && url.split(".").last.isAlphabetOnly && url.split(".").last.length > 6) {
      final newUrl = (url.split(".")..removeLast()).join(".");
      isValid = ("$newUrl.com").isURL;
    }

    // If the URL is invalid, or the password is invalid, show an error
    if (!isValid || password.isEmpty) {
      error.value = "Please enter a valid URL and password!";
      return;
    }

    String? addr = sanitizeServerAddress(address: url);
    if (addr == null) {
      error.value = "Server address is invalid!";
      return;
    }

    SettingsSvc.settings.guidAuthKey.value = password;
    await saveNewServerUrl(addr, restartSocket: false, force: true, saveAdditionalSettings: ["guidAuthKey"]);

    try {
      SocketSvc.restartSocket();
    } catch (e) {
      error.value = e.toString();
    }
  }

  void retreiveFCMData() {
    // The socket has already connected successfully by the time this runs —
    // FCM/push registration is a secondary concern, so its failure is
    // reported as a non-blocking toast rather than a failed connection.
    HttpSvc.fcm.getServiceAccount().then((response) async {
      Map<String, dynamic>? data = response.data["data"];
      if (!isNullOrEmpty(data)) {
        FCMData newData = FCMData.fromMap(data!);
        await SettingsSvc.saveFCMData(newData);
      }
    }).catchError((err) {
      final String message = err is Response ? err.data["error"]["message"] : err.toString();
      if (message == 'Google Services file not found.') {
        showToast('Connected! Firebase is not set up on the server.');
      } else {
        showToast('Connected, but push notification setup failed', isError: true);
      }
    }).whenComplete(() {
      widget.onConnect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!connecting.value) {
        return AlertDialog(
          title: Text(
            "Enter Server Details",
            style: context.theme.textTheme.titleLarge,
          ),
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
          content: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        !HardwareKeyboard.instance.isShiftPressed &&
                        event.logicalKey == LogicalKeyboardKey.tab) {
                      node.nextFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    cursorColor: context.theme.colorScheme.primary,
                    autocorrect: false,
                    autofocus: true,
                    controller: urlController,
                    textInputAction: TextInputAction.next,
                    autofillHints: [AutofillHints.username, AutofillHints.url],
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
                const SizedBox(height: 10),
                Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        HardwareKeyboard.instance.isShiftPressed &&
                        event.logicalKey == LogicalKeyboardKey.tab) {
                      node.previousFocus();
                      node.previousFocus(); // This is intentional. Should probably figure out why it's needed
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    cursorColor: context.theme.colorScheme.primary,
                    autocorrect: false,
                    autofocus: false,
                    controller: passwordController,
                    textInputAction: TextInputAction.next,
                    autofillHints: [AutofillHints.password],
                    onSubmitted: (_) {
                      connect(urlController.text, passwordController.text);
                      connecting.value = true;
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
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: widget.onClose,
              child: Text("Cancel",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            ),
            TextButton(
              child: Text("OK",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () {
                connect(urlController.text, passwordController.text);
                connecting.value = true;
              },
            ),
          ],
        );
      } else if (error.value != null) {
        return FailedToScanDialog(
          title: "An error occured while trying to retreive data!",
          exception: error.value,
        );
      } else {
        return ConnectingDialog(
          onConnect: (bool result) {
            if (result) {
              retreiveFCMData();
            } else {
              error.value =
                  "Failed to connect to ${sanitizeServerAddress()}! Please check that the url is correct (including http://) and the server logs for more info.";
            }
          },
        );
      }
    });
  }
}
