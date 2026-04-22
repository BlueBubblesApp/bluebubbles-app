import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/app/layouts/settings/dialogs/custom_headers_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_scan_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/qr_code_scanner.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

class ServerCredentials extends StatefulWidget {
  const ServerCredentials({super.key});

  @override
  State<ServerCredentials> createState() => _ServerCredentialsState();
}

class _ServerCredentialsState extends State<ServerCredentials> with ThemeHelpers {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final controller = Get.find<SetupViewController>();
  final FocusScopeNode focusScopeNode = FocusScopeNode(traversalEdgeBehavior: TraversalEdgeBehavior.stop);

  final RxBool showLoginButtons = true.obs;
  final RxBool obscureText = true.obs;

  final Rxn<String> token = Rxn<String>();
  final Rxn<String> googleName = Rxn<String>();
  final Rxn<String> googlePicture = Rxn<String>();
  final RxList<Map> usableProjects = <Map>[].obs;
  List<RxBool> triedConnecting = [];
  List<RxBool> reachable = [];
  final RxBool fetchingFirebase = false.obs;

  @override
  Widget build(BuildContext context) {
    Size buttonSize = Size(context.width * 2 / 3, 36);
    return SetupPageTemplate(
      title: "Server Connection",
      subtitle: kIsWeb || kIsDesktop
          ? "Enter your server URL and password to access your messages."
          : "We've created a QR code on your server that you can scan with your phone for easy setup.\nAlternatively, you can manually input your URL and password.",
      contentWrapper: (child) => Obx(() => AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !showLoginButtons.value && context.isPhone ? const SizedBox.shrink() : child,
          )),
      customButton: Obx(() => Column(
            children: [
              ErrorText(parentController: controller),
              if (token.value != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Signed in as", style: TextStyle(color: context.theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (googlePicture.value != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(googlePicture.value!, width: 40, fit: BoxFit.contain),
                            ),
                          const SizedBox(width: 10),
                          Text(googleName.value ?? "Unknown",
                              style: context.theme.textTheme.bodyLarge!
                                  .apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  ],
                ),
              if (token.value != null) const SizedBox(height: 40),
              if (token.value != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.theme.colorScheme.primaryContainer),
                  ),
                  child: usableProjects.isNotEmpty
                      ? SingleChildScrollView(
                          child: SizedBox(
                            width: double.maxFinite,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Text(fetchingFirebase.value
                                      ? "Loading Firebase projects"
                                      : "Select the Firebase project to use"),
                                ),
                                if (!fetchingFirebase.value)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: context.mediaQuery.size.height * 0.4,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: usableProjects.length,
                                      findChildIndexCallback: (key) =>
                                          findChildIndexByKey(usableProjects, key, (item) => item['projectId']),
                                      itemBuilder: (context, index) {
                                        return Obx(() {
                                          if (!triedConnecting[index].value) {
                                            Future(() async {
                                              try {
                                                await HttpSvc.dio.get(usableProjects[index]['serverUrl']);
                                                reachable[index].value = true;
                                              } catch (e) {
                                                reachable[index].value = false;
                                              }
                                              triedConnecting[index].value = true;
                                            });
                                          }
                                          return ClipRRect(
                                            key: ValueKey(usableProjects[index]['projectId']),
                                            clipBehavior: Clip.antiAlias,
                                            borderRadius: BorderRadius.circular(20),
                                            child: ListTile(
                                              tileColor:
                                                  context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                              enabled: triedConnecting[index].value && reachable[index].value,
                                              title: Text.rich(TextSpan(children: [
                                                TextSpan(text: usableProjects[index]['displayName']),
                                                TextSpan(
                                                  text:
                                                      " ${triedConnecting[index].value ? "${reachable[index].value ? "R" : "Unr"}eachable" : "Checking"}",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          reachable[index].value ? FontWeight.bold : FontWeight.normal,
                                                      color: triedConnecting[index].value
                                                          ? reachable[index].value
                                                              ? Colors.green
                                                              : Colors.red
                                                          : Colors.yellow),
                                                ),
                                              ])),
                                              subtitle: Text(
                                                "${usableProjects[index]['projectId']}\n${usableProjects[index]['serverUrl']}",
                                              ),
                                              onTap: () {
                                                requestPassword(context, usableProjects[index]['serverUrl'], connect);
                                              },
                                              isThreeLine: true,
                                            ),
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                if (fetchingFirebase.value) const CircularProgressIndicator(),
                                const SizedBox(height: 10),
                                if (!fetchingFirebase.value)
                                  ElevatedButton(
                                    onPressed: () {
                                      for (int i = 0; i < triedConnecting.length; i++) {
                                        triedConnecting[i].value = false;
                                      }
                                    },
                                    child: const Text("Retry Connections"),
                                  ),
                                if (!fetchingFirebase.value) const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          alignment: Alignment.center,
                          width: double.maxFinite,
                          padding: const EdgeInsets.all(24),
                          child: const Text(
                            "No Firebase Projects found!\n\nMake sure you're signed in to the same Google account that you used on your server!",
                            textScaler: TextScaler.linear(1.1),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              if (token.value != null) const SizedBox(height: 10),
              Container(
                height: 40,
                padding: const EdgeInsets.all(2),
                child: TextButton(
                  onPressed: () async {
                    await showCustomHeadersDialog(context);
                  },
                  child: Text("Enter Custom Headers",
                      style: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.primary)),
                ),
              ),
              const SizedBox(height: 10),
              if (token.value != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  height: 40,
                  padding: const EdgeInsets.all(2),
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.all(context.theme.colorScheme.surface),
                      shadowColor: WidgetStateProperty.all(context.theme.colorScheme.surface),
                      maximumSize: WidgetStateProperty.all(buttonSize),
                      minimumSize: WidgetStateProperty.all(buttonSize),
                    ),
                    onPressed: () async {
                      token.value = null;
                      googleName.value = null;
                      googlePicture.value = null;
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Choose a different account",
                            style: context.theme.textTheme.bodyLarge!
                                .apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              if (token.value != null) const SizedBox(height: 10),
              if (googleName.value == null && showLoginButtons.value && !isSnap)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: HexColor('4285F4'),
                  ),
                  height: 40,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                      shadowColor: WidgetStateProperty.all(Colors.transparent),
                      maximumSize: WidgetStateProperty.all(buttonSize),
                      minimumSize: WidgetStateProperty.all(buttonSize),
                    ),
                    onPressed: () async {
                      token.value = await googleOAuth(context);
                      if (token.value != null) {
                        final response = await HttpSvc.getGoogleInfo(token.value!);
                        googleName.value = response.data['name'];
                        googlePicture.value = response.data['picture'];
                        fetchingFirebase.value = true;
                        fetchFirebaseProjects(token.value!).then((List<Map> value) async {
                          usableProjects.value = value;
                          triedConnecting = List.generate(usableProjects.length, (i) => false.obs);
                          reachable = List.generate(usableProjects.length, (i) => false.obs);
                          fetchingFirebase.value = false;
                        });
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/google-sign-in.png", width: 30, fit: BoxFit.contain),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                          child: Text("Sign in with Google",
                              style:
                                  context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              if (googleName.value == null && showLoginButtons.value && !isSnap) const SizedBox(height: 10),
              if (googleName.value == null && !kIsWeb && !kIsDesktop && showLoginButtons.value)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                    ),
                  ),
                  height: 40,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                      shadowColor: WidgetStateProperty.all(Colors.transparent),
                      maximumSize: WidgetStateProperty.all(buttonSize),
                      minimumSize: WidgetStateProperty.all(buttonSize),
                    ),
                    onPressed: scanQRCode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.camera, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                          child: Text("Scan QR Code",
                              style:
                                  context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              if (googleName.value == null && !kIsWeb && !kIsDesktop && showLoginButtons.value)
                const SizedBox(height: 10),
              if (googleName.value == null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                    ),
                  ),
                  height: 40,
                  padding: const EdgeInsets.all(2),
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.all(context.theme.colorScheme.surface),
                      shadowColor: WidgetStateProperty.all(context.theme.colorScheme.surface),
                      maximumSize: WidgetStateProperty.all(buttonSize),
                      minimumSize: WidgetStateProperty.all(buttonSize),
                    ),
                    onPressed: () async {
                      showLoginButtons.value = !showLoginButtons.value;
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.text_cursor, color: context.theme.colorScheme.onSurface, size: 20),
                        const SizedBox(width: 10),
                        Text("Manual entry",
                            style: context.theme.textTheme.bodyLarge!
                                .apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onSurface)),
                      ],
                    ),
                  ),
                ),
              Obx(() => AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: showLoginButtons.value
                        ? const SizedBox.shrink()
                        : Theme(
                            data: context.theme.copyWith(
                              inputDecorationTheme: InputDecorationTheme(
                                labelStyle: TextStyle(color: context.theme.colorScheme.outline),
                              ),
                            ),
                            child: AutofillGroup(
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  FocusScope(
                                    node: focusScopeNode,
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          width: context.width * 2 / 3,
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
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: context.width * 2 / 3,
                                          child: TextField(
                                            cursorColor: context.theme.colorScheme.primary,
                                            autocorrect: false,
                                            autofocus: false,
                                            controller: passwordController,
                                            textInputAction: TextInputAction.next,
                                            autofillHints: [AutofillHints.password],
                                            onSubmitted: (pass) => connect(urlController.text, pass),
                                            decoration: InputDecoration(
                                              enabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: context.theme.colorScheme.outline),
                                                  borderRadius: BorderRadius.circular(20)),
                                              focusedBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: context.theme.colorScheme.primary),
                                                  borderRadius: BorderRadius.circular(20)),
                                              labelText: "Password",
                                              contentPadding: const EdgeInsets.fromLTRB(12, 24, 40, 16),
                                              suffixIcon: Focus(
                                                canRequestFocus: false,
                                                descendantsAreFocusable: false,
                                                child: IconButton(
                                                  icon:
                                                      Icon(obscureText.value ? Icons.visibility_off : Icons.visibility),
                                                  color: context.theme.colorScheme.outline,
                                                  onPressed: () {
                                                    obscureText.value = !obscureText.value;
                                                  },
                                                ),
                                              ),
                                            ),
                                            obscureText: obscureText.value,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                                            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                              RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20.0),
                                              ),
                                            ),
                                            backgroundColor: WidgetStateProperty.all(context.theme.colorScheme.surface),
                                            shadowColor: WidgetStateProperty.all(context.theme.colorScheme.surface),
                                            maximumSize: WidgetStateProperty.all(const Size(200, 36)),
                                            minimumSize: WidgetStateProperty.all(const Size(30, 30)),
                                          ),
                                          onPressed: () async {
                                            showLoginButtons.value = true;
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.close, color: context.theme.colorScheme.onSurface, size: 20),
                                              const SizedBox(width: 10),
                                              Text("Cancel",
                                                  style: context.theme.textTheme.bodyLarge!.apply(
                                                      fontSizeFactor: 1.1, color: context.theme.colorScheme.onSurface)),
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
                                            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                              RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20.0),
                                              ),
                                            ),
                                            backgroundColor: WidgetStateProperty.all(Colors.transparent),
                                            shadowColor: WidgetStateProperty.all(Colors.transparent),
                                            maximumSize: WidgetStateProperty.all(const Size(200, 36)),
                                            minimumSize: WidgetStateProperty.all(const Size(30, 30)),
                                          ),
                                          onPressed: () async {
                                            SettingsSvc.settings.customHeaders.value = {};
                                            HttpSvc.updateHeaders();
                                            connect(urlController.text, passwordController.text);
                                          },
                                          onLongPress: () async {
                                            await showCustomHeadersDialog(context);
                                            connect(urlController.text, passwordController.text);
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text("Connect",
                                                  style: context.theme.textTheme.bodyLarge!
                                                      .apply(fontSizeFactor: 1.1, color: Colors.white)),
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
                          ),
                  )),
            ],
          )),
    );
  }

  Future<void> goToNextPage() async {
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
            return const QRCodeScanner();
          },
        ),
      );

      if (isNullOrEmpty(response)) {
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
      controller.updateConnectError("Please enter a valid URL and password!");
      return;
    }

    String? addr = sanitizeServerAddress(address: url);
    if (addr == null) {
      controller.updateConnectError("Server address is invalid!");
      return;
    }

    SettingsSvc.settings.guidAuthKey.value = password;
    await saveNewServerUrl(addr, saveAdditionalSettings: ["guidAuthKey"]);

    // Request data from the API
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              "Fetching server info...",
              style: context.theme.textTheme.titleLarge,
            ),
            backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
            content: LinearProgressIndicator(
              backgroundColor: context.theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
            ),
          ),
        );
      },
    );

    dio.Response? serverResponse;
    String? connectionError;
    await HttpSvc.serverInfo()
        .timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw dio.DioException(
        requestOptions: dio.RequestOptions(path: ''),
        type: dio.DioExceptionType.connectionTimeout,
      ),
    )
        .then((response) {
      serverResponse = response;
    }).catchError((err) {
      if (err is dio.Response) {
        serverResponse = err;
      } else if (err is dio.DioException) {
        // Detect TLS/certificate errors so we can give the user actionable feedback (#3004).
        // When shouldAcceptCertificate returns false (or an untrusted cert is rejected),
        // Dart throws a HandshakeException which Dio surfaces as connectionError/unknown.
        final inner = err.error;
        final isHandshake = inner is HandshakeException ||
            (inner?.toString().toLowerCase().contains('handshake') ?? false) ||
            (inner?.toString().toLowerCase().contains('certificate') ?? false) ||
            err.type == dio.DioExceptionType.badCertificate;
        if (isHandshake) {
          connectionError =
              "SSL certificate error connecting to $addr. If your server uses a self-signed certificate, make sure the URL starts with https:// and try again.";
        } else if (err.type == dio.DioExceptionType.connectionTimeout ||
            err.type == dio.DioExceptionType.receiveTimeout ||
            err.type == dio.DioExceptionType.sendTimeout) {
          connectionError =
              "Connection timed out connecting to $addr. Check that the URL and port are correct and that your device can reach the server.";
        } else {
          connectionError =
              "Failed to connect to $addr! ${err.message?.isNotEmpty == true ? err.message : 'Please ensure your server is running and accessible.'}";
        }
      }
    });
    dio.Response? fcmResponse;
    await HttpSvc.fcmClient().then((response) {
      fcmResponse = response;
    }).catchError((err) {
      if (err is dio.Response) {
        fcmResponse = err;
      }
    });

    Navigator.of(context, rootNavigator: true).pop();
    FocusManager.instance.primaryFocus?.unfocus();

    // Connection-level error (cert, timeout, unreachable)
    if (connectionError != null) {
      SocketSvc.forgetConnection();
      return controller.updateConnectError(connectionError!);
    }
    // Unauthorized request
    if (serverResponse?.statusCode == 401) {
      SocketSvc.forgetConnection();
      return controller.updateConnectError("Authentication failed. Incorrect password!");
    }
    // Server didn't even respond
    if (serverResponse?.statusCode != 200) {
      SocketSvc.forgetConnection();
      return controller.updateConnectError(
          "Failed to connect to $addr! Please ensure your Server's URL is accessible from your device.");
    }
    // Ignore any other server errors unless user is using ngrok or cloudflare
    final data = fcmResponse?.data;
    if ((data == null || isNullOrEmpty(data["data"])) &&
        (addr.contains("ngrok.io") || addr.contains("trycloudflare.com"))) {
      return controller.updateConnectError("Firebase is required when using Ngrok or Cloudflare!");
    } else {
      try {
        FCMData fcmData = FCMData.fromMap(data["data"]);
        await SettingsSvc.saveFCMData(fcmData);
      } catch (_) {
        if (Platform.isAndroid) {
          showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  "No Firebase Detected",
                  style: context.theme.textTheme.titleLarge,
                ),
                content: Text(
                  "We couldn't find a Firebase setup on your server. To receive notifications, please enable the background service option from Settings > Misc & Advanced.",
                  style: context.theme.textTheme.bodyLarge,
                ),
                backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                actions: <Widget>[
                  TextButton(
                    child: Text("Close",
                        style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
      }
      SocketSvc.restartSocket();
      goToNextPage();
    }
  }
}

class ErrorText extends CustomStateful<SetupViewController> {
  const ErrorText({super.key, required super.parentController});

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
          SizedBox(
            width: context.width * 2 / 3,
            child: Align(
              alignment: Alignment.center,
              child: Text(controller.error,
                  style: context.theme.textTheme.bodyLarge!
                      .apply(
                        fontSizeDelta: 1.5,
                        color: context.theme.colorScheme.error,
                      )
                      .copyWith(height: 2)),
            ),
          ),
        if (controller.error.isNotEmpty) const SizedBox(height: 20),
      ],
    );
  }
}
