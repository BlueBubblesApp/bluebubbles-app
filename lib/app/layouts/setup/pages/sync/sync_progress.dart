import 'dart:math';

import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_panel.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/failed_to_scan_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:tuple/tuple.dart';

class SyncProgress extends StatefulWidget {
  @override
  State<SyncProgress> createState() => _SyncProgressState();
}

class _SyncProgressState extends OptimizedState<SyncProgress> {
  final confettiController = ConfettiController(duration: const Duration(milliseconds: 500));
  final Control animationController = Control.mirror;
  final controller = Get.find<SetupViewController>();
  final Tween<double> tween = Tween<double>(begin: 0, end: 5);
  final FullSyncManager syncManager = sync.fullSyncManager!;
  bool hasPlayed = false;

  @override
  void initState() {
    super.initState();

    ever<SyncStatus>(syncManager.status, (event) async {
      String err = syncManager.error ?? "Unknown Error";
      if (event == SyncStatus.COMPLETED_ERROR) {
        await showDialog(
          context: context,
          builder: (context) => FailedToScanDialog(exception: err, title: "An error occured during setup!"),
        );

        controller.pageController.animateToPage(
          controller.pageOfNoReturn - 1,
          duration: const Duration(milliseconds: 500),
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
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SetupPageTemplate(
          title: hasPlayed ? "Sync complete!" : "Syncing...",
          subtitle: "",
          customMiddle: hasPlayed ? null : Column(
            children: [
              Obx(() => Text(
                "${(syncManager.progress.value * 100).toInt()}%",
                style: context.theme.textTheme.bodyLarge!.apply(
                  fontSizeDelta: 1.5,
                  color: context.theme.colorScheme.onBackground,
                ).copyWith(height: 2),
              )),
              const SizedBox(height: 15),
              Obx(() => Padding(
                padding: EdgeInsets.symmetric(horizontal: ns.width(context) / 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: syncManager.progress.value == 0 ? null : syncManager.progress.value,
                    backgroundColor: context.theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                  ),
                ),
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: ns.width(context) * 4 / 5,
                height: context.height * 1 / 3,
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: context.theme.colorScheme.properSurface
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Obx(() => ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                  )),
                ),
              ),
            ],
          ),
          customButton: !hasPlayed ? const SizedBox.shrink() : Column(
            mainAxisSize: MainAxisSize.min,
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
                    maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                    minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                  ),
                  onPressed: () async {
                    Get.offAll(() => ConversationList(
                      showArchivedChats: false,
                      showUnknownSenders: false,
                    ),
                        routeName: "",
                        duration: Duration.zero,
                        transition: Transition.noTransition
                    );
                    Get.delete<SetupViewController>(force: true);
                    Navigator.of(Get.context!).push(
                      ThemeSwitcher.buildPageRoute(
                        builder: (BuildContext context) {
                          return SettingsPage(
                              initialPage: BackupRestorePanel(),
                          );
                        },
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload, color: context.theme.colorScheme.onBackground, size: 20),
                      const SizedBox(width: 10),
                      Text("Restore Backups",
                          style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                    Get.offAll(() => ConversationList(
                        showArchivedChats: false,
                        showUnknownSenders: false,
                      ),
                      routeName: "",
                      duration: Duration.zero,
                      transition: Transition.noTransition
                    );
                    Get.delete<SetupViewController>(force: true);
                  },
                  child: Shimmer.fromColors(
                    baseColor: Colors.white70,
                    highlightColor: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomAnimationBuilder<double>(
                          control: animationController,
                          tween: tween,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, _, anim) {
                            return const Padding(
                              padding: EdgeInsets.only(left: 0.0),
                              child: Icon(Icons.check, color: Colors.white, size: 25),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 0.0, left: 5.0),
                          child: Text("Finish", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: confettiController,
          blastDirection: pi / 2,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.35,
        ),
      ],
    );
  }
}
