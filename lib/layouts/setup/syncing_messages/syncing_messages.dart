import 'dart:math';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/failed_to_scan_dialog.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/sync/full_sync_manager.dart';
import 'package:bluebubbles/managers/sync/sync_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:tuple/tuple.dart';

class SyncingMessages extends StatefulWidget {
  SyncingMessages({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  State<SyncingMessages> createState() => _SyncingMessagesState();
}

class _SyncingMessagesState extends State<SyncingMessages> {
  final confettiController = ConfettiController(duration: Duration(milliseconds: 500));
  bool hasPlayed = false;
  Control controller = Control.mirror;
  Tween<double> tween = Tween<double>(begin: 0, end: 5);
  late FullSyncManager syncManager;

  @override
  void initState() {
    super.initState();

    syncManager = SocketManager().setup.fullSyncManager;
    ever<SyncStatus>(syncManager.status, (event) async {
      String err = syncManager.error ?? "Unknown Error";
      if (event == SyncStatus.COMPLETED_ERROR) {
        await showDialog(
          context: context,
          builder: (context) => FailedToScan(exception: err, title: "An error occured during setup!"),
        );

        widget.controller.animateToPage(
          3,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else if (event == SyncStatus.COMPLETED_SUCCESS && !hasPlayed) {
        setState(() {
          hasPlayed = true;
        });
        confettiController.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: context.theme.colorScheme.background,
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            Obx(() {
              double progress = syncManager.progress.value;
              return Padding(
                padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0, bottom: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: context.width * 2 / 3,
                              child: Text(hasPlayed ? "Sync complete!" : "Syncing...",
                                style: context.theme.textTheme.displayMedium!.apply(
                                  fontWeightDelta: 2,
                                ).copyWith(height: 1.35, color: context.theme.colorScheme.onBackground)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasPlayed)
                      Column(
                        children: [
                          Text(
                            "${(progress * 100).round()}%",
                            style: context.theme.textTheme.bodyLarge!.apply(
                              fontSizeDelta: 1.5,
                              color: context.theme.colorScheme.onBackground,
                            ).copyWith(height: 2),
                          ),
                          SizedBox(height: 15),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: CustomNavigator.width(context) / 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: progress == 0 ? null : progress,
                                backgroundColor: context.theme.colorScheme.outline,
                                valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: CustomNavigator.width(context) * 4 / 5,
                            height: context.height * 1 / 3,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                color: context.theme.colorScheme.properSurface
                              ),
                              padding: EdgeInsets.all(10),
                              child: ListView.builder(
                                physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                itemBuilder: (context, index) {
                                  Tuple2<LogLevel, String> log = syncManager.output.reversed.toList()[index];
                                  return Text(
                                    log.item2,
                                    style: TextStyle(
                                      color: log.item1 == LogLevel.INFO ? context.theme.colorScheme.properOnSurface : context.theme.colorScheme.error,
                                      fontSize: 10,
                                    ),
                                  );
                                },
                                itemCount: syncManager.output.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!hasPlayed) Container(),
                    if (hasPlayed)
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
                          onPressed: () {
                            SocketManager().toggleSetupFinished(true, applyToDb: true);
                            Get.offAll(
                                () => ConversationList(
                                      showArchivedChats: false,
                                      showUnknownSenders: false,
                                    ),
                                routeName: "",
                                duration: Duration.zero,
                                transition: Transition.noTransition);
                          },
                          child: Shimmer.fromColors(
                            baseColor: Colors.white70,
                            highlightColor: Colors.white,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomAnimationBuilder<double>(
                                  control: controller,
                                  tween: tween,
                                  duration: Duration(milliseconds: 600),
                                  curve: Curves.easeOut,
                                  builder: (context, anim, _) {
                                    return Padding(
                                      padding: EdgeInsets.only(left: 0.0),
                                      child: Icon(Icons.check, color: Colors.white, size: 25),
                                    );
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                                  child: Text("Finish",
                                      style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            ConfettiWidget(
              confettiController: confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.35,
            ),
          ],
        ),
      ),
    );
  }
}
