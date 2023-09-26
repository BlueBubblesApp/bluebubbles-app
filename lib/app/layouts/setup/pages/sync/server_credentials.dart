import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/app/layouts/settings/dialogs/custom_headers_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_scan_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/qr_code_scanner.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';
import 'package:window_to_front/window_to_front.dart';

class ServerCredentials extends StatefulWidget {
  @override
  State<ServerCredentials> createState() => _ServerCredentialsState();
}

class _ServerCredentialsState extends OptimizedState<ServerCredentials> {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final controller = Get.find<SetupViewController>();
  final FocusNode focusNode = FocusNode();

  bool showLoginButtons = true;
  bool obscureText = true;

  String? token;
  String? googleName;
  String? googlePicture;
  List<Map> usableProjects = [];
  List<RxBool> connected = [];
  List<RxBool> reachable = [];
  bool fetchingFirebase = false;

  @override
  Widget build(BuildContext context) {
    Size buttonSize = Size(context.width * 2 / 3, 36);
    return SetupPageTemplate(
      title: "Server Connection",
      subtitle: kIsWeb || kIsDesktop
          ? "Enter your server URL and password to access your messages."
          : "We've created a QR code on your server that you can scan with your phone for easy setup.\n\nAlternatively, you can manually input your URL and password.",
      contentWrapper: (child) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: !showLoginButtons && context.isPhone ? const SizedBox.shrink() : child,
      ),
      customButton: Column(
        children: [
          ErrorText(parentController: controller),
          if (token != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Signed in as", style: TextStyle(color: context.theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: context.theme.colorScheme.primaryContainer.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (googlePicture != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(googlePicture!, width: 40, fit: BoxFit.contain),
                        ),
                      const SizedBox(width: 10),
                      Text(googleName ?? "Unknown",
                          style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
                    ],
                  ),
                ),
              ],
            ),
          if (token != null) const SizedBox(height: 40),
          if (token != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.theme.colorScheme.primaryContainer),
              ),
              child: usableProjects.isNotEmpty
                  ? SingleChildScrollView(
                      child: Container(
                        width: double.maxFinite,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Text(fetchingFirebase ? "Loading Firebase projects" : "Select the Firebase project to use"),
                            ),
                            if (!fetchingFirebase)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: context.mediaQuery.size.height * 0.4,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: usableProjects.length,
                                  itemBuilder: (context, index) {
                                    return Obx(() {
                                      if (!connected[index].value) {
                                        Future(() async {
                                          try {
                                            await http.dio.get(usableProjects[index]['serverUrl']);
                                            reachable[index].value = true;
                                            if (index == 0 && usableProjects.length == 1) {
                                              requestPassword(usableProjects[index]['serverUrl']);
                                            }
                                          } catch (e) {
                                            reachable[index].value = false;
                                          } finally {
                                            connected[index].value = true;
                                          }
                                        });
                                      }
                                      return ClipRRect(
                                        clipBehavior: Clip.antiAlias,
                                        borderRadius: BorderRadius.circular(20),
                                        child: ListTile(
                                          tileColor: context.theme.colorScheme.primaryContainer.withOpacity(0.3),
                                          enabled: connected[index].value && reachable[index].value,
                                          title: Text.rich(TextSpan(children: [
                                            TextSpan(text: usableProjects[index]['displayName']),
                                            TextSpan(
                                              text: " ${connected[index].value ? "${reachable[index].value ? "R" : "Unr"}eachable" : "Checking"}",
                                              style: TextStyle(
                                                  fontWeight: reachable[index].value ? FontWeight.bold : FontWeight.normal,
                                                  color: connected[index].value
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
                                            requestPassword(usableProjects[index]['serverUrl']);
                                          },
                                          isThreeLine: true,
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ),
                            if (fetchingFirebase) const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            if (!fetchingFirebase)
                              ElevatedButton(
                                onPressed: () {
                                  for (int i = 0; i < connected.length; i++) {
                                    connected[i].value = false;
                                  }
                                },
                                child: const Text("Retry Connections"),
                              ),
                            if (!fetchingFirebase) const SizedBox(height: 10),
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
                        textScaleFactor: 1.1,
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          if (token != null) const SizedBox(height: 10),
          if (token != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                  maximumSize: MaterialStateProperty.all(buttonSize),
                  minimumSize: MaterialStateProperty.all(buttonSize),
                ),
                onPressed: () async {
                  setState(() {
                    token = null;
                    googleName = null;
                    googlePicture = null;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Choose a different account",
                        style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.primary)),
                  ],
                ),
              ),
            ),
          if (token != null) const SizedBox(height: 10),
          if (googleName == null && showLoginButtons)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: HexColor('4285F4'),
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
                  maximumSize: MaterialStateProperty.all(buttonSize),
                  minimumSize: MaterialStateProperty.all(buttonSize),
                ),
                onPressed: () async {
                  token = await googleOAuth();
                  if (token != null) {
                    final response = await http.getGoogleInfo(token!);
                    setState(() {
                      googleName = response.data['name'];
                      googlePicture = response.data['picture'];
                      fetchingFirebase = true;
                    });
                    fetchFirebaseProjects(token!).then((List<Map> value) {
                      setState(() {
                        usableProjects = value;
                        connected = List.generate(usableProjects.length, (i) => false.obs);
                        reachable = List.generate(usableProjects.length, (i) => false.obs);
                        fetchingFirebase = false;
                      });
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
                      child: Text("Sign in with Google", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          if (googleName == null && showLoginButtons) const SizedBox(height: 10),
          if (googleName == null && !kIsWeb && !kIsDesktop && showLoginButtons)
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
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                  shadowColor: MaterialStateProperty.all(Colors.transparent),
                  maximumSize: MaterialStateProperty.all(buttonSize),
                  minimumSize: MaterialStateProperty.all(buttonSize),
                ),
                onPressed: scanQRCode,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.camera, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                      child: Text("Scan QR Code", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          if (googleName == null && !kIsWeb && !kIsDesktop && showLoginButtons) const SizedBox(height: 10),
          if (googleName == null)
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
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  backgroundColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                  shadowColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                  maximumSize: MaterialStateProperty.all(buttonSize),
                  minimumSize: MaterialStateProperty.all(buttonSize),
                ),
                onPressed: () async {
                  setState(() {
                    showLoginButtons = !showLoginButtons;
                    focusNode.requestFocus();
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.text_cursor, color: context.theme.colorScheme.onBackground, size: 20),
                    const SizedBox(width: 10),
                    Text("Manual entry",
                        style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
                  ],
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: showLoginButtons
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
                          Container(
                            width: context.width * 2 / 3,
                            child: Focus(
                              focusNode: focusNode,
                              onKey: (node, event) {
                                if (event is RawKeyDownEvent && !event.data.isShiftPressed && event.logicalKey == LogicalKeyboardKey.tab) {
                                  node.nextFocus();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                cursorColor: context.theme.colorScheme.primary,
                                autocorrect: false,
                                autofocus: false,
                                controller: urlController,
                                textInputAction: TextInputAction.next,
                                autofillHints: [AutofillHints.username, AutofillHints.url],
                                decoration: InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: context.theme.colorScheme.outline), borderRadius: BorderRadius.circular(20)),
                                  focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: context.theme.colorScheme.primary), borderRadius: BorderRadius.circular(20)),
                                  labelText: "URL",
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: context.width * 2 / 3,
                            child: Focus(
                              onKey: (node, event) {
                                if (event is RawKeyDownEvent && event.data.isShiftPressed && event.logicalKey == LogicalKeyboardKey.tab) {
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
                                onSubmitted: (pass) => connect(urlController.text, pass),
                                decoration: InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: context.theme.colorScheme.outline), borderRadius: BorderRadius.circular(20)),
                                  focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: context.theme.colorScheme.primary), borderRadius: BorderRadius.circular(20)),
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
                                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                    ),
                                    backgroundColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                                    shadowColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                                    maximumSize: MaterialStateProperty.all(const Size(200, 36)),
                                    minimumSize: MaterialStateProperty.all(const Size(30, 30)),
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      showLoginButtons = true;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close, color: context.theme.colorScheme.onBackground, size: 20),
                                      const SizedBox(width: 10),
                                      Text("Cancel",
                                          style: context.theme.textTheme.bodyLarge!
                                              .apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
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
                                    ss.settings.customHeaders.value = {};
                                    http.onInit();
                                    connect(urlController.text, passwordController.text);
                                  },
                                  onLongPress: () async {
                                    await showCustomHeadersDialog(context);
                                    connect(urlController.text, passwordController.text);
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("Connect", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
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
          ),
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

  Future<String?> googleOAuth() async {
    String? token;

    final defaultScopes = [
      'https://www.googleapis.com/auth/cloudplatformprojects',
      'https://www.googleapis.com/auth/firebase',
      'https://www.googleapis.com/auth/datastore'
    ];

    // android / web implementation
    if (Platform.isAndroid || kIsWeb) {
      // on web, show a dialog to make sure users allow scopes
      if (kIsWeb) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
                backgroundColor: context.theme.colorScheme.properSurface,
                title: Text("Important Notice", style: context.theme.textTheme.titleLarge),
                content: Text(
                  'Please make sure to allow BlueBubbles to see, edit, configure, and delete your Google Cloud data after signing in. BlueBubbles will only use this ability to find your server URL.',
                  style: context.theme.textTheme.bodyLarge,
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ]);
          },
        );
      }

      // initialize gsi
      final gsi = GoogleSignIn(clientId: fdb.getClientId(), scopes: defaultScopes);
      try {
        // sign in
        final account = await gsi.signIn();
        if (account != null) {
          // get access token
          final auth = await account.authentication;
          token = auth.accessToken;
          // make sure scopes were granted on web
          if (kIsWeb && !(await gsi.canAccessScopes(defaultScopes, accessToken: token))) {
            final result = await gsi.requestScopes(defaultScopes);
            if (!result) {
              throw Exception("Scopes not granted!");
            }
          }
          // error if token is not present
          if (token == null) {
            throw Exception("No access token!");
          }
        } else {
          // error if account is not present
          throw Exception("No account!");
        }
      } catch (e) {
        Logger.error(e);
        showSnackbar("Error", "Something went wrong authenticating with Google! $e");
        return null;
      }
      // desktop implementation
    } else {
      final args = GoogleSignInArgs(
        clientId: fdb.getClientId()!,
        redirectUri: 'http://localhost:8641/oauth/callback',
        scope: defaultScopes.join(' '),
      );
      try {
        final width = ss.prefs.getDouble('window-width')?.toInt();
        final height = ss.prefs.getDouble('window-height')?.toInt();
        final result = await DesktopWebviewAuth.signIn(args,
            width: width != null ? (width * 0.9).ceil() : null, height: height != null ? (height * 0.9).ceil() : null);
        Future.delayed(const Duration(milliseconds: 500), () async => await WindowToFront.activate());
        token = result?.accessToken;
        // error if token is not present
        if (token == null) {
          throw Exception("No access token!");
        }
      } catch (e) {
        Logger.error(e);
        showSnackbar("Error", "Something went wrong authenticating with Google! $e");
        return null;
      }
    }
    return token;
  }

  Future<List<Map>> fetchFirebaseProjects(String token) async {
    List<Map> usableProjects = [];
    try {
      // query firebase projects
      final response = await http.getFirebaseProjects(token);
      final projects = response.data['results'];
      List<Object> errors = [];
      // find projects with RTDB or cloud firestore
      if (projects.isNotEmpty) {
        for (Map e in projects) {
          if (e['resources']['realtimeDatabaseInstance'] != null) {
            try {
              final serverUrlResponse = await http.getServerUrlRTDB(e['resources']['realtimeDatabaseInstance'], token);
              e['serverUrl'] = serverUrlResponse.data['serverUrl'];
              usableProjects.add(e);
            } catch (ex) {
              errors.add("Realtime Database Error: $ex");
            }
          } else {
            try {
              final serverUrlResponse = await http.getServerUrlCF(e['projectId'], token);
              e['serverUrl'] = serverUrlResponse.data['fields']['serverUrl']['stringValue'];
              usableProjects.add(e);
            } catch (ex) {
              errors.add("Firestore Database Error: $ex");
            }
          }
        }

        if (usableProjects.isEmpty && errors.isNotEmpty) {
          throw Exception(errors[0]);
        }

        usableProjects.removeWhere((element) => element['serverUrl'] == null);

        return usableProjects;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> requestPassword(String serverUrl) async {
    final TextEditingController passController = TextEditingController();
    await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            actions: [
              TextButton(
                child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () async {
                  if (passController.text.isEmpty) {
                    showSnackbar("Error", "Enter a valid password!");
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
            content: TextField(
              controller: passController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              obscureText: true,
              autofillHints: [AutofillHints.password],
              onSubmitted: (str) {
                if (passController.text.isEmpty) {
                  showSnackbar("Error", "Enter a valid password!");
                  return;
                }
                Navigator.of(context).pop();
              },
            ),
            title: Text("Enter Server Password", style: context.theme.textTheme.titleLarge),
            backgroundColor: context.theme.colorScheme.properSurface,
          );
        });

    if (passController.text.isNotEmpty) {
      connect(serverUrl, passController.text);
    } else {
      throw Exception("Invalid password provided!");
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            return false;
          },
          child: AlertDialog(
            title: Text(
              "Fetching server info...",
              style: context.theme.textTheme.titleLarge,
            ),
            backgroundColor: context.theme.colorScheme.properSurface,
            content: LinearProgressIndicator(
              backgroundColor: context.theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
            ),
          ),
        );
      },
    );

    dio.Response? serverResponse;
    await http.serverInfo().then((response) {
      serverResponse = response;
    }).catchError((err) {
      if (err is dio.Response) {
        serverResponse = err;
      }
    });
    dio.Response? fcmResponse;
    await http.fcmClient().then((response) {
      fcmResponse = response;
    }).catchError((err) {
      if (err is dio.Response) {
        fcmResponse = err;
      }
    });

    Get.back();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    // Unauthorized request
    if (serverResponse?.statusCode == 401) {
      socket.forgetConnection();
      return controller.updateConnectError("Authentication failed. Incorrect password!");
    }
    // Server didn't even respond
    if (serverResponse?.statusCode != 200) {
      socket.forgetConnection();
      return controller.updateConnectError("Failed to connect to $addr! Please ensure your Server's URL is accessible from your device.");
    }
    // Ignore any other server errors unless user is using ngrok or cloudflare
    final data = fcmResponse?.data;
    if ((data == null || isNullOrEmpty(data["data"])!) && (addr.contains("ngrok.io") || addr.contains("trycloudflare.com"))) {
      return controller.updateConnectError("Firebase is required when using Ngrok or Cloudflare!");
    } else {
      try {
        FCMData fcmData = FCMData.fromMap(data["data"]);
        ss.saveFCMData(fcmData);
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
                  "We couldn't find a Firebase setup on your server. To receive notifications, please enable the foreground service option from Settings > Misc & Advanced.",
                  style: context.theme.textTheme.bodyLarge,
                ),
                backgroundColor: context.theme.colorScheme.properSurface,
                actions: <Widget>[
                  TextButton(
                    child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
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
      socket.restartSocket();
      goToNextPage();
    }
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
