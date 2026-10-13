import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

typedef GoogleOAuthStageCallback = void Function(String status);

class GoogleOAuthException implements Exception {
  final String userMessage;
  final String technicalMessage;

  const GoogleOAuthException({
    required this.userMessage,
    required this.technicalMessage,
  });

  @override
  String toString() => technicalMessage;
}

class GoogleOAuthFlowController {
  final Rxn<String> token = Rxn<String>();
  final Rxn<String> googlePicture = Rxn<String>();
  final Rxn<String> googleName = Rxn<String>();
  final RxList<Map> usableProjects = <Map>[].obs;
  final RxList<RxBool> triedConnecting = <RxBool>[].obs;
  final RxList<RxBool> reachable = <RxBool>[].obs;
  final RxBool fetchingFirebase = false.obs;
  final RxBool googleSignInInFlight = false.obs;
  final RxString googleSignInStatus = "".obs;
  final RxBool forceGoogleAccountPicker = false.obs;

  Future<void> handleGoogleSignIn(
    BuildContext context, {
    void Function(String message)? onError,
  }) async {
    if (googleSignInInFlight.value) return;

    onError?.call("");
    googleSignInInFlight.value = true;
    googleSignInStatus.value = "Preparing Google sign-in...";
    try {
      final signInToken = await googleOAuth(
        context,
        onStageChanged: (status) => googleSignInStatus.value = status,
        forceAccountPicker: forceGoogleAccountPicker.value,
      );
      forceGoogleAccountPicker.value = false;
      token.value = signInToken;
      if (signInToken == null) return;

      googleSignInStatus.value = "Loading account details...";
      try {
        final response = await HttpSvc.firebase.getGoogleInfo(signInToken);
        googleName.value = response.data['name'];
        googlePicture.value = response.data['picture'];
      } catch (e, stack) {
        Logger.error("Failed to load Google account details", error: e, trace: stack);
        throw const GoogleOAuthException(
          userMessage: "Signed in, but we couldn't load your Google account details. Please try again.",
          technicalMessage: "Failed to load Google account details after sign-in.",
        );
      }

      fetchingFirebase.value = true;
      googleSignInStatus.value = "Loading Firebase projects...";
      final projects = await fetchFirebaseProjects(signInToken);
      usableProjects.value = projects;
      triedConnecting.value = List.generate(usableProjects.length, (_) => false.obs);
      reachable.value = List.generate(usableProjects.length, (_) => false.obs);
      fetchingFirebase.value = false;
    } on GoogleOAuthException catch (e) {
      clearSessionData();
      onError?.call(e.userMessage);
    } catch (e, stack) {
      Logger.error("Failed to complete Google sign-in flow", error: e, trace: stack);
      clearSessionData();
      onError?.call("Google sign-in failed. Please try again.");
    } finally {
      googleSignInInFlight.value = false;
      googleSignInStatus.value = "";
    }
  }

  Future<void> chooseDifferentAccount() async {
    forceGoogleAccountPicker.value = true;
    await forgetGoogleOAuthSession();
    clearSessionData();
  }

  void clearSessionData() {
    token.value = null;
    googleName.value = null;
    googlePicture.value = null;
    usableProjects.clear();
    triedConnecting.clear();
    reachable.clear();
    fetchingFirebase.value = false;
  }

  void retryConnections() {
    for (final state in triedConnecting) {
      state.value = false;
    }
  }
}

Future<String?> googleOAuth(
  BuildContext context, {
  GoogleOAuthStageCallback? onStageChanged,
  bool forceAccountPicker = false,
}) async {
  String? token;
  final stopwatch = Stopwatch()..start();

  const defaultScopes = [
    'https://www.googleapis.com/auth/cloudplatformprojects',
    'https://www.googleapis.com/auth/firebase',
    'https://www.googleapis.com/auth/datastore'
  ];

  void reportStage(String status) {
    onStageChanged?.call(status);
    Logger.info('$status (${stopwatch.elapsedMilliseconds} ms)', tag: 'Google OAuth');
  }

  // android / web implementation
  if (Platform.isAndroid || kIsWeb) {
    // on web, show a dialog to make sure users allow scopes
    if (kIsWeb) {
      await showBBDialog(
        context: context,
        barrierDismissible: false,
        title: "Important Notice",
        body:
            'Please make sure to allow BlueBubbles to see, edit, configure, and delete your Google Cloud data after signing in. BlueBubbles will only use this ability to find your server URL.',
        actions: [
          BBDialogAction(
            text: "OK",
            isDefault: true,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      );
    }

    // initialize gsi
    final gsi = GoogleSignIn.instance;
    reportStage("Initializing Google Sign-In");
    await gsi.initialize(
      clientId: kIsWeb ? fdb.getClientId() : null,
      serverClientId: !kIsWeb && Platform.isAndroid ? fdb.getServerClientId() : null,
    );
    GoogleSignInAccount? account;
    if (!forceAccountPicker) {
      reportStage("Checking for an existing Google session");
      account = await gsi.attemptLightweightAuthentication();
    }
    if (account == null) {
      try {
        // Reset the cached SDK session before interactive auth so the account
        // chooser can appear when the user explicitly requests a different account.
        reportStage(forceAccountPicker ? "Resetting Google session" : "Preparing Google account chooser");
        await gsi.signOut();
        reportStage("Opening Google sign-in popup");
        account = await gsi.authenticate(scopeHint: defaultScopes);
      } catch (e, stack) {
        Logger.error("Failed to sign in with Google (Android/Web)", error: e, trace: stack);
        throw const GoogleOAuthException(
          userMessage: "Google sign-in was canceled or could not be started. Please try again.",
          technicalMessage: "Failed to start interactive Google sign-in.",
        );
      }
    }

    try {
      reportStage("Authorizing Google API scopes");
      GoogleSignInClientAuthorization? authorization =
          await account.authorizationClient.authorizationForScopes(defaultScopes);
      authorization ??= await account.authorizationClient.authorizeScopes(defaultScopes);

      token = authorization.accessToken;
      if (token.isEmpty) {
        throw Exception("No access token!");
      }
    } catch (e, stack) {
      Logger.error("Failed to authorize Google API access (Android/Web)", error: e, trace: stack);
      throw const GoogleOAuthException(
        userMessage: "Google sign-in succeeded, but required Google permissions were not granted.",
        technicalMessage: "Failed to authorize Google API scopes after sign-in.",
      );
    }
    // desktop implementation
  } else {
    final args = GoogleSignInArgs(
      clientId: fdb.getClientId()!,
      redirectUri: 'http://localhost:8641/oauth/callback',
      scope: defaultScopes.join(' '),
    );
    try {
      final width = PrefsSvc.desktop.getWindowWidth()?.toInt();
      final height = PrefsSvc.desktop.getWindowHeight()?.toInt();
      reportStage("Opening Google sign-in window");
      final result = await DesktopWebviewAuth.signIn(
        args,
        width: width != null ? (width * 0.9).ceil() : null,
        height: height != null ? (height * 0.9).ceil() : null,
      );
      Future.delayed(const Duration(milliseconds: 500), () async => await windowManager.show());
      token = result?.accessToken;
      // error if token is not present
      if (token == null) {
        throw Exception("No access token!");
      }
    } catch (e, stack) {
      Logger.error("Failed to sign in with Google (Desktop)", error: e, trace: stack);
      throw const GoogleOAuthException(
        userMessage: "Google sign-in could not be completed. Please try again.",
        technicalMessage: "Desktop Google sign-in failed.",
      );
    }
  }
  Logger.info('Google sign-in completed in ${stopwatch.elapsedMilliseconds} ms', tag: 'Google OAuth');
  return token;
}

Future<void> forgetGoogleOAuthSession() async {
  if (Platform.isAndroid || kIsWeb) {
    try {
      final gsi = GoogleSignIn.instance;
      await gsi.initialize(
        clientId: kIsWeb ? fdb.getClientId() : null,
        serverClientId: !kIsWeb && Platform.isAndroid ? fdb.getServerClientId() : null,
      );
      await gsi.signOut();
    } catch (e, stack) {
      Logger.error("Failed to forget Google session", error: e, trace: stack);
    }
  }
}

Future<List<Map>> fetchFirebaseProjects(String token) async {
  List<Map> usableProjects = [];
  try {
    // query firebase projects
    final response = await HttpSvc.firebase.getFirebaseProjects(token);
    final projects = response.data['results'];
    List<Object> errors = [];
    // find projects with RTDB or cloud firestore
    if (projects.isNotEmpty) {
      for (Map e in projects) {
        if (e['resources']['realtimeDatabaseInstance'] != null) {
          try {
            final serverUrlResponse =
                await HttpSvc.firebase.getServerUrlRTDB(e['resources']['realtimeDatabaseInstance'], token);
            e['serverUrl'] = serverUrlResponse.data['serverUrl'];
            usableProjects.add(e);
          } catch (ex) {
            errors.add("Realtime Database Error: $ex");
          }
        } else {
          try {
            final serverUrlResponse = await HttpSvc.firebase.getServerUrlCF(e['projectId'], token);
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
  } on GoogleOAuthException {
    rethrow;
  } catch (e, stack) {
    Logger.error("Failed to fetch Firebase projects", error: e, trace: stack);
    throw const GoogleOAuthException(
      userMessage:
          "We couldn't load your Firebase projects. Please verify your Google account has access and try again.",
      technicalMessage: "Failed to fetch Firebase projects from Google APIs.",
    );
  }
}

Future<void> requestPassword(
    BuildContext context, String serverUrl, Future<void> Function(String url, String password) connect) async {
  final TextEditingController passController = TextEditingController();
  final RxBool enabled = false.obs;
  final submitted = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (_) {
      return Obx(
        () => AlertDialog(
          actions: [
            TextButton(
              child: Text("Cancel",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
            AnimatedContainer(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              duration: const Duration(milliseconds: 100),
              child: AbsorbPointer(
                absorbing: !enabled.value,
                child: TextButton(
                  child: Text(
                    "OK",
                    style: context.theme.textTheme.bodyLarge!.copyWith(
                      color: enabled.value ? context.theme.colorScheme.primary : context.theme.disabledColor,
                    ),
                  ),
                  onPressed: () async {
                    if (passController.text.isEmpty) {
                      return;
                    }
                    Navigator.of(context, rootNavigator: true).pop(true);
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
            onSubmitted: (str) {
              if (passController.text.isEmpty) {
                return;
              }
              Navigator.of(context, rootNavigator: true).pop(true);
            },
          ),
          title: Text("Enter Server Password", style: context.theme.textTheme.titleLarge),
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
        ),
      );
    },
  );

  // Cancel closes the dialog without a result; don't try to connect with an empty password
  if (submitted != true) return;
  await connect(serverUrl, passController.text);
}
