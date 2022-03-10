import 'dart:math';

import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/failed_to_scan_dialog.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/stateless_animation/custom_animation.dart';

class SyncingMessages extends StatefulWidget {
  SyncingMessages({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _SyncingMessagesState createState() => _SyncingMessagesState();
}

class _SyncingMessagesState extends State<SyncingMessages> {
  final confettiController = ConfettiController(duration: Duration(milliseconds: 500));
  bool hasPlayed = false;
  CustomAnimationControl controller = CustomAnimationControl.mirror;
  Tween<double> tween = Tween<double>(begin: 0, end: 5);

  @override
  void initState() {
    super.initState();
    ever<SetupData?>(SocketManager().setup.data, (event) async {
      if (event?.progress == -1) {
        await showDialog(
          context: context,
          builder: (context) =>
              FailedToScan(exception: event?.output.last.text, title: "An error occured during setup!"),
        );

        widget.controller.animateToPage(
          3,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else if ((event?.progress ?? 0) >= 100 && !hasPlayed) {
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
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
            ? Colors.transparent
            : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            Obx(() {
              double progress = SocketManager().setup.data.value?.progress ?? 0;
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText1!
                                      .apply(
                                        fontSizeFactor: 2.5,
                                        fontWeightDelta: 2,
                                      )
                                      .copyWith(height: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasPlayed)
                      Column(
                        children: [
                          Text(
                            "${progress.floor()}%",
                            style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                          ),
                          SizedBox(height: 15),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: CustomNavigator.width(context) / 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: progress != 100.0 && progress != 0.0 ? (progress / 100) : null,
                                backgroundColor: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Colors.grey : Colors.white,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
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
                                color: Theme.of(context).backgroundColor.computeLuminance() > 0.5
                                    ? Theme.of(context).colorScheme.secondary.lightenPercent(50)
                                    : Theme.of(context).colorScheme.secondary.darkenPercent(50),
                              ),
                              padding: EdgeInsets.all(10),
                              child: ListView.builder(
                                physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                itemBuilder: (context, index) {
                                  SetupOutputData data =
                                      SocketManager().setup.data.value?.output.reversed.toList()[index] ??
                                          SetupOutputData("Unknown", SetupOutputType.ERROR);
                                  return Text(
                                    data.text,
                                    style: TextStyle(
                                      color: data.type == SetupOutputType.LOG ? Colors.grey : Colors.red,
                                      fontSize: 10,
                                    ),
                                  );
                                },
                                itemCount: SocketManager().setup.data.value?.output.length ?? 0,
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
                                duration: Duration.zero,
                                transition: Transition.noTransition);
                          },
                          child: Shimmer.fromColors(
                            baseColor: Colors.white70,
                            highlightColor: Colors.white,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomAnimation<double>(
                                  control: controller,
                                  tween: tween,
                                  duration: Duration(milliseconds: 600),
                                  curve: Curves.easeOut,
                                  builder: (context, _, anim) {
                                    return Padding(
                                      padding: EdgeInsets.only(left: 0.0),
                                      child: Icon(Icons.check, color: Colors.white, size: 25),
                                    );
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                                  child: Text("Finish",
                                      style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.2, color: Colors.white)),
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
