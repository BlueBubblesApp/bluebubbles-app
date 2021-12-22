import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/battery_optimization/battery_optimization.dart';
import 'package:bluebubbles/layouts/setup/connecting_alert/failed_to_connect_dialog.dart';
import 'package:bluebubbles/layouts/setup/prepare_to_download/prepare_to_download.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/qr_scan.dart';
import 'package:bluebubbles/layouts/setup/request_contact/request_contacts.dart';
import 'package:bluebubbles/layouts/setup/setup_mac_app/setup_mac_app.dart';
import 'package:bluebubbles/layouts/setup/syncing_messages/syncing_messages.dart';
import 'package:bluebubbles/layouts/setup/welcome_page/welcome_page.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SetupView extends StatefulWidget {
  SetupView({Key? key}) : super(key: key);

  @override
  _SetupViewState createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final controller = PageController(initialPage: 0);
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    ever(SocketManager().state, (event) {
      if (!SettingsManager().settings.finishedSetup.value &&
          controller.hasClients &&
          ((kIsWeb && currentPage > 3) || currentPage > 5)) {
        switch (event) {
          case SocketState.FAILED:
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => FailedToConnectDialog(
                onDismiss: () {
                  controller.animateToPage(
                    kIsWeb || kIsDesktop ? 2 : 4,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                  Navigator.of(context).pop();
                },
              ),
            );
            break;
          default:
            Logger.info("Default case: " + event.toString());
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.topCenter,
              children: <Widget>[
                PageView(
                  onPageChanged: (int page) {
                    currentPage = page + 1;
                    if (mounted) setState(() {});
                  },
                  physics: NeverScrollableScrollPhysics(),
                  controller: controller,
                  children: <Widget>[
                    WelcomePage(
                      controller: controller,
                    ),
                    if (!kIsWeb && !kIsDesktop) RequestContacts(controller: controller),
                    if (!kIsWeb && !kIsDesktop) BatteryOptimizationPage(controller: controller),
                    SetupMacApp(controller: controller),
                    QRScan(
                      controller: controller,
                    ),
                    if (!kIsWeb)
                      PrepareToDownload(
                        controller: controller,
                      ),
                    SyncingMessages(
                      controller: controller,
                    ),
                    //ThemeSelector(),
                  ],
                ),
                Container(
                  color: Theme.of(context).backgroundColor,
                  child: Padding(
                    padding: EdgeInsets.only(top: 20, left: 20, right: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Hero(
                                tag: "setup-icon",
                                child: Image.asset("assets/icon/icon.png", width: 30, fit: BoxFit.contain)),
                            SizedBox(width: 10),
                            Text(
                              "BlueBubbles",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText1!
                                  .apply(fontWeightDelta: 2, fontSizeFactor: 1.35),
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
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                      text: "$currentPage",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText1!
                                          .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                  TextSpan(
                                      text: " of ${kIsWeb ? "4" : kIsDesktop ? "5" : "7"}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText1!
                                          .copyWith(color: Colors.white38, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
