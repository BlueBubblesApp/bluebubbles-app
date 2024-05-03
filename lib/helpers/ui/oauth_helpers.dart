import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

Future<String?> googleOAuth(BuildContext context) async {
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
      // sign out then sign in
      await gsi.signOut();
      final account = await gsi.signIn();
      if (account != null) {
        // get access token
        await account.clearAuthCache();
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
      Future.delayed(const Duration(milliseconds: 500), () async => await windowManager.show());
      token = result?.accessToken;
      // error if token is not present
      if (token == null) {
        throw Exception("No access token!");
      }
    } catch (e) {
      Logger.error(e);
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

Future<void> requestPassword(BuildContext context, String serverUrl, Future<void> Function(String url, String password) connect) async {
  final TextEditingController passController = TextEditingController();
  final RxBool enabled = false.obs;
  await showDialog(
      context: context,
      builder: (_) {
        return Obx(
          () => AlertDialog(
            actions: [
              TextButton(
                child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () => Get.back(),
              ),
              AnimatedContainer(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                duration: const Duration(milliseconds: 100),
                child: AbsorbPointer(
                  absorbing: !enabled.value,
                  child: TextButton(
                    child: Text("OK",
                        style: context.theme.textTheme.bodyLarge!.copyWith(
                          color: enabled.value ? context.theme.colorScheme.primary : context.theme.disabledColor,
                        )),
                    onPressed: () async {
                      if (passController.text.isEmpty) {
                        return;
                      }
                      Get.back();
                    },
                  ),
                ),
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
              onChanged: (str) {
                if (enabled.value ^ str.isNotEmpty) {
                  enabled.value = str.isNotEmpty;
                }
              },
              onEditingComplete: () {
                if (passController.text.isEmpty) {
                  return;
                }
              },
              onSubmitted: (str) {
                if (passController.text.isEmpty) {
                  return;
                }
                Get.back();
              },
            ),
            title: Text("Enter Server Password", style: context.theme.textTheme.titleLarge),
            backgroundColor: context.theme.colorScheme.properSurface,
          ),
        );
      });

  await connect(serverUrl, passController.text);
}
