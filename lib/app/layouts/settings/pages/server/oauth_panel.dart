import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OauthPanel extends StatefulWidget {
  const OauthPanel({super.key});

  @override
  State<OauthPanel> createState() => _OauthPanelState();
}

class _OauthPanelState extends State<OauthPanel> with ThemeHelpers {
  _OauthPanelState();

  final error = "".obs;
  final showSignInButton = true.obs;
  final googleFlow = GoogleOAuthFlowController();

  Rxn<String> get token => googleFlow.token;
  Rxn<String> get googlePicture => googleFlow.googlePicture;
  Rxn<String> get googleName => googleFlow.googleName;
  RxList<Map> get usableProjects => googleFlow.usableProjects;
  RxList<RxBool> get triedConnecting => googleFlow.triedConnecting;
  RxList<RxBool> get reachable => googleFlow.reachable;
  RxBool get fetchingFirebase => googleFlow.fetchingFirebase;
  RxBool get googleSignInInFlight => googleFlow.googleSignInInFlight;
  RxString get googleSignInStatus => googleFlow.googleSignInStatus;

  Future<void> connect(String url, String password) async {
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

    // If the URL is invalid, show an error
    String? addr = sanitizeServerAddress(address: url);
    if (!isValid || addr == null) {
      error.value = "Server address is invalid!";
      return;
    }

    String oldPassword = SettingsSvc.settings.guidAuthKey.value;
    String oldAddr = SettingsSvc.settings.serverAddress.value;

    SettingsSvc.settings.serverAddress.value = addr;
    SettingsSvc.settings.guidAuthKey.value = password;

    dio.Response? serverResponse;
    await HttpSvc.server.ping().then((response) {
      serverResponse = response;
    }).catchError((err) {
      serverResponse = err;
    });

    if (serverResponse?.statusCode == 401) {
      error.value = "Authentication failed. Incorrect password!";
      SettingsSvc.settings.serverAddress.value = oldAddr;
      SettingsSvc.settings.guidAuthKey.value = oldPassword;
      await SettingsSvc.settings.saveManyAsync(["serverAddress", "guidAuthKey"]);
      return;
    }
    if (serverResponse?.statusCode != 200) {
      error.value = "Failed to connect to $addr! Please ensure your Server's URL is accessible from your device.";
      SettingsSvc.settings.serverAddress.value = oldAddr;
      SettingsSvc.settings.guidAuthKey.value = oldPassword;
      await SettingsSvc.settings.saveManyAsync(["serverAddress", "guidAuthKey"]);
      return;
    }

    error.value = "";

    await saveNewServerUrl(addr, restartSocket: false, force: true, saveAdditionalSettings: ["guidAuthKey"]);

    try {
      SocketSvc.restartSocket();
    } catch (e) {
      error.value = e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    Size buttonSize = Size(NavigationSvc.width(context) * 2 / 3, 36);

    return Obx(() => SettingsScaffold(
          title: 'Sign-In With Google',
          initialHeader: '',
          iosSubtitle: null,
          materialSubtitle: null,
          headerColor: headerColor,
          tileColor: tileColor,
          stickySuffix: Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error.value.isNotEmpty)
                      SizedBox(
                        width: context.width * 2 / 3,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(error.value,
                              style: context.theme.textTheme.bodyLarge!
                                  .apply(
                                    fontSizeDelta: 1.5,
                                    color: context.theme.colorScheme.error,
                                  )
                                  .copyWith(height: 2)),
                        ),
                      ),
                    if (error.value.isNotEmpty) const SizedBox(height: 20),
                  ],
                ),
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
                                                        fontWeight: reachable[index].value
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
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
                                                onTap: () async {
                                                  await requestPassword(
                                                      context, usableProjects[index]['serverUrl'], connect);
                                                  if (error.value == "") {
                                                    Navigator.of(context).pop();
                                                  }
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
                                      onPressed: googleFlow.retryConnections,
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
                        error.value = "";
                        await googleFlow.chooseDifferentAccount();
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
                if (googleName.value == null && showSignInButton.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: googleSignInInFlight.value ? 1 : 0,
                      child: Text(
                        googleSignInStatus.value,
                        textAlign: TextAlign.center,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                if (googleName.value == null && showSignInButton.value)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: HexColor('4285F4'),
                    ),
                    height: 40,
                    width: buttonSize.width,
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
                      onPressed: googleSignInInFlight.value
                          ? null
                          : () => googleFlow.handleGoogleSignIn(
                                context,
                                onError: (message) => error.value = message,
                              ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (googleSignInInFlight.value)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          if (!googleSignInInFlight.value)
                            Image.asset("assets/images/google-sign-in.png", width: 30, fit: BoxFit.contain),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                            child: Text(googleSignInInFlight.value ? "Loading..." : "Sign in with Google",
                                style:
                                    context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (googleName.value == null && showSignInButton.value) const SizedBox(height: 10),
              ],
            ),
          ),
          bodySlivers: [],
        ));
  }
}
