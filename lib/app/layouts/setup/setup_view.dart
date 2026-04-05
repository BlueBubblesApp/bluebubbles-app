import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/app/layouts/setup/pages/setup_checks/battery_optimization.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_connect_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/sync_settings.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/server_credentials.dart';
import 'package:bluebubbles/app/layouts/setup/pages/contacts/request_contacts.dart';
import 'package:bluebubbles/app/layouts/setup/pages/setup_checks/mac_setup_check.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/sync_progress.dart';
import 'package:bluebubbles/app/layouts/setup/pages/welcome/welcome_page.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart' hide Response;
import 'package:permission_handler/permission_handler.dart';

class SetupViewController extends StatefulController {
  final pageController = PageController(initialPage: 0);
  int currentPage = 1;
  int numberToDownload = 25;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;
  String error = "";
  bool obscurePass = true;

  int get pageOfNoReturn => kIsWeb || kIsDesktop ? 3 : 5;

  void updatePage(int newPage) {
    currentPage = newPage;
    updateWidgets<PageNumber>(newPage);
  }

  void updateNumberToDownload(int num) {
    numberToDownload = num;
    updateWidgets<NumberOfMessagesText>(num);
  }

  void updateConnectError(String newError) {
    error = newError;
    updateWidgets<ErrorText>(newError);
  }
}

class SetupView extends StatefulWidget {
  SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends OptimizedState<SetupView> {
  final controller = Get.put(SetupViewController(), permanent: true);

  @override
  void initState() {
    super.initState();

    ever(socket.state, (event) {
      if (event == SocketState.error
          && !ss.settings.finishedSetup.value
          && controller.pageController.hasClients
          && controller.currentPage > controller.pageOfNoReturn) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => FailedToConnectDialog(
            onDismiss: () {
              controller.pageController.animateToPage(
                controller.pageOfNoReturn - 1,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
              Navigator.of(context).pop();
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && kIsWeb) {
      return DebugQuickConnect(controller: controller);
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ss.settings.windowEffect.value != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              SetupHeader(),
              const SizedBox(height: 20),
              SetupPages(),
            ],
          ),
        ),
      ),
    );
  }
}

class DebugQuickConnect extends StatefulWidget {
  final SetupViewController controller;
  const DebugQuickConnect({super.key, required this.controller});

  @override
  State<DebugQuickConnect> createState() => _DebugQuickConnectState();
}

class _DebugQuickConnectState extends State<DebugQuickConnect> {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String error = '';
  bool connecting = false;

  Future<void> quickConnect() async {
    String url = urlController.text.trim();
    final password = passwordController.text;

    if (url.isEmpty || password.isEmpty) {
      setState(() => error = 'Please enter both URL and password');
      return;
    }
    if (url.endsWith("/")) url = url.substring(0, url.length - 1);

    String? addr = sanitizeServerAddress(address: url);
    if (addr == null) {
      setState(() => error = 'Invalid server address');
      return;
    }

    setState(() {
      connecting = true;
      error = '';
    });

    ss.settings.guidAuthKey.value = password;
    await saveNewServerUrl(addr, saveAdditionalSettings: ["guidAuthKey"]);

    dio.Response? serverResponse;
    await http.serverInfo().then((r) => serverResponse = r).catchError((err) {
      if (err is dio.Response) serverResponse = err;
    });

    if (serverResponse?.statusCode == 401) {
      socket.forgetConnection();
      setState(() { connecting = false; error = 'Authentication failed. Incorrect password!'; });
      return;
    }
    if (serverResponse?.statusCode != 200) {
      socket.forgetConnection();
      setState(() { connecting = false; error = 'Failed to connect to $addr'; });
      return;
    }

    // Try to get FCM data
    dio.Response? fcmResponse;
    await http.fcmClient().then((r) => fcmResponse = r).catchError((err) {
      if (err is dio.Response) fcmResponse = err;
    });
    try {
      final data = fcmResponse?.data;
      if (data != null && !isNullOrEmpty(data["data"])) {
        FCMData fcmData = FCMData.fromMap(data["data"]);
        await ss.saveFCMData(fcmData);
      }
    } catch (_) {}

    socket.restartSocket();
    ss.settings.finishedSetup.value = true;
    await ss.saveSettings();
    await ss.prefs.setString("lastOpenedApp", DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset("assets/icon/icon.png", width: 30, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    Text("BlueBubbles", style: context.theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Debug Quick Connect", style: context.theme.textTheme.titleMedium?.copyWith(color: Colors.orange)),
                const SizedBox(height: 24),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://your-server.trycloudflare.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => quickConnect(),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: connecting ? null : quickConnect,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: connecting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Connect', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SetupHeader extends StatelessWidget {
  final SetupViewController controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: kIsDesktop ? 40 : 20, left: 20, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Hero(
                tag: "setup-icon",
                child: Image.asset("assets/icon/icon.png", width: 30, fit: BoxFit.contain)
              ),
              const SizedBox(width: 10),
              Text(
                "BlueBubbles",
                style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2, fontSizeFactor: 1.35),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 13),
              child: PageNumber(parentController: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class PageNumber extends CustomStateful<SetupViewController> {
  PageNumber({required super.parentController});

  @override
  State<StatefulWidget> createState() => _PageNumberState();
}

class _PageNumberState extends CustomState<PageNumber, int, SetupViewController> {

  @override
  void updateWidget(int newVal) {
    controller.currentPage = newVal;
    super.updateWidget(newVal);
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "${controller.currentPage}",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          TextSpan(
            text: " of ${kIsWeb ? "4" : kIsDesktop ? "5" : "7"}",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: Colors.white38, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}

class SetupPages extends StatelessWidget {
  final SetupViewController controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PageView(
        onPageChanged: (page) {
          // skip pages if the things required are already complete
          if (!kIsWeb && !kIsDesktop && page == 1 && controller.currentPage == 1) {
            Permission.contacts.status.then((status) {
              if (status.isGranted) {
                controller.pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          if (!kIsWeb && !kIsDesktop && page == 2 && controller.currentPage == 2) {
            DisableBatteryOptimization.isAllBatteryOptimizationDisabled.then((isDisabled) {
              if (isDisabled ?? false) {
                controller.pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          controller.updatePage(page + 1);
        },
        physics: const NeverScrollableScrollPhysics(),
        controller: controller.pageController,
        children: <Widget>[
          WelcomePage(),
          if (!kIsWeb && !kIsDesktop) RequestContacts(),
          if (!kIsWeb && !kIsDesktop) BatteryOptimizationCheck(),
          MacSetupCheck(),
          ServerCredentials(),
          if (!kIsWeb)
            SyncSettings(),
          SyncProgress(),
          //ThemeSelector(),
        ],
      ),
    );
  }
}
