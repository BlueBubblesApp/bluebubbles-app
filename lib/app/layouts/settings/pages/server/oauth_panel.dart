import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OauthPanel extends StatefulWidget {
  OauthPanel({
    Key? key,
  });

  @override
  State<OauthPanel> createState() => _OauthPanelState();
}

class _OauthPanelState extends OptimizedState<OauthPanel> {
  _OauthPanelState();

  String error = "";
  bool showSignInButton = true;

  String? token;
  String? googlePicture;
  String? googleName;
  List<Map> usableProjects = [];
  List<RxBool> triedConnecting = [];
  List<RxBool> reachable = [];
  bool fetchingFirebase = false;

  Future<void> connect(String url, String password) async {
    if (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }
    if (kIsWeb && url.startsWith("http://")) {
      error = "HTTP URLs are not supported on Web! You must use an HTTPS URL.";
      setState(() {});
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
      error = "Server address is invalid!";
      setState(() {});
      return;
    }

    String oldPassword = ss.settings.guidAuthKey.value;
    String oldAddr = ss.settings.serverAddress.value;

    ss.settings.serverAddress.value = addr;
    ss.settings.guidAuthKey.value = password;

    dio.Response? serverResponse;
    await http.ping().then((response) {
      serverResponse = response;
    }).catchError((err) {
      serverResponse = err;
    });

    if (serverResponse?.statusCode == 401) {
      error = "Authentication failed. Incorrect password!";
      ss.settings.serverAddress.value = oldAddr;
      ss.settings.guidAuthKey.value = oldPassword;
      await ss.settings.saveMany(["serverAddress", "guidAuthKey"]);
      return setState(() {});
    }
    if (serverResponse?.statusCode != 200) {
      error = "Failed to connect to $addr! Please ensure your Server's URL is accessible from your device.";
      ss.settings.serverAddress.value = oldAddr;
      ss.settings.guidAuthKey.value = oldPassword;
      await ss.settings.saveMany(["serverAddress", "guidAuthKey"]);
      return setState(() {});
    }

    error = "";
    setState(() {});

    await saveNewServerUrl(addr, restartSocket: false, force: true, saveAdditionalSettings: ["guidAuthKey"]);

    try {
      socket.restartSocket();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Size buttonSize = Size(ns.width(context) * 2 / 3, 36);

    return SettingsScaffold(
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
            // if (error != "")
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty)
                  Container(
                    width: context.width * 2 / 3,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(error,
                          style: context.theme.textTheme.bodyLarge!
                              .apply(
                                fontSizeDelta: 1.5,
                                color: context.theme.colorScheme.error,
                              )
                              .copyWith(height: 2)),
                    ),
                  ),
                if (error.isNotEmpty) const SizedBox(height: 20),
              ],
            ),
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
                                    findChildIndexCallback: (key) => findChildIndexByKey(usableProjects, key, (item) => item['projectId']),
                                    itemBuilder: (context, index) {
                                      return Obx(() {
                                        if (!triedConnecting[index].value) {
                                          Future(() async {
                                            try {
                                              await http.dio.get(usableProjects[index]['serverUrl']);
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
                                            tileColor: context.theme.colorScheme.primaryContainer.withOpacity(0.3),
                                            enabled: triedConnecting[index].value && reachable[index].value,
                                            title: Text.rich(TextSpan(children: [
                                              TextSpan(text: usableProjects[index]['displayName']),
                                              TextSpan(
                                                text: " ${triedConnecting[index].value ? "${reachable[index].value ? "R" : "Unr"}eachable" : "Checking"}",
                                                style: TextStyle(
                                                    fontWeight: reachable[index].value ? FontWeight.bold : FontWeight.normal,
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
                                              await requestPassword(context, usableProjects[index]['serverUrl'], connect);
                                              if (error == "") {
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
                              if (fetchingFirebase) const CircularProgressIndicator(),
                              const SizedBox(height: 10),
                              if (!fetchingFirebase)
                                ElevatedButton(
                                  onPressed: () {
                                    for (int i = 0; i < triedConnecting.length; i++) {
                                      triedConnecting[i].value = false;
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
                          textScaler: TextScaler.linear(1.1),
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
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.all(context.theme.colorScheme.background),
                    shadowColor: WidgetStateProperty.all(context.theme.colorScheme.background),
                    maximumSize: WidgetStateProperty.all(buttonSize),
                    minimumSize: WidgetStateProperty.all(buttonSize),
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
            if (googleName == null && showSignInButton)
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
                  onPressed: () async {
                    token = await googleOAuth(context);
                    if (token != null) {
                      final response = await http.getGoogleInfo(token!);
                      setState(() {
                        googleName = response.data['name'];
                        googlePicture = response.data['picture'];
                        fetchingFirebase = true;
                      });
                      fetchFirebaseProjects(token!).then((List<Map> value) async {
                        setState(() {
                          usableProjects = value;
                          triedConnecting = List.generate(usableProjects.length, (i) => false.obs);
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
            if (googleName == null && showSignInButton) const SizedBox(height: 10),
          ],
        ),
      ),
      bodySlivers: [],
    );
  }
}
