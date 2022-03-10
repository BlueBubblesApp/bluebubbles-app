import 'dart:math';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/simple_animations.dart';

class WelcomePage extends StatefulWidget {
  WelcomePage({Key? key, this.controller}) : super(key: key);
  final PageController? controller;

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _subtitleController;
  final confettiController = ConfettiController(duration: Duration(milliseconds: 500));
  final GlobalKey key = GlobalKey();
  double height = 250;
  CustomAnimationControl controller = CustomAnimationControl.mirror;
  Tween<double> tween = Tween<double>(begin: 0, end: 5);

  late Animation<double> opacityTitle;
  late Animation<double> opacitySubtitle;
  late Animation<double> opacityButton;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    SchedulerBinding.instance!.addPostFrameCallback((_) async {
      await animateTitle();
      await animateSubtitle();
    });
    _titleController = AnimationController(vsync: this, duration: Duration(seconds: 1));

    opacityTitle =
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));

    _subtitleController = AnimationController(vsync: this, duration: Duration(seconds: 1));

    opacitySubtitle = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));

    opacityButton = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));
  }

  Future<void> animateTitle() async {
    _titleController.forward();
    await Future.delayed(Duration(milliseconds: 500));
  }

  Future<void> animateSubtitle() async {
    _subtitleController.forward();
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: LayoutBuilder(
          builder: (context, size) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.maxHeight,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0, bottom: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          children: [
                            FadeTransition(
                              opacity: opacityTitle,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: Theme.of(context).backgroundColor.computeLuminance() > 0.5
                                      ? Theme.of(context).colorScheme.secondary.lightenPercent(50)
                                      : Theme.of(context).colorScheme.secondary.darkenPercent(50),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      ConfettiWidget(
                                        confettiController: confettiController,
                                        blastDirection: pi / 2,
                                        blastDirectionality: BlastDirectionality.explosive,
                                        emissionFrequency: 0.35,
                                        canvas: Size(context.width - 16, height + 50),
                                      ),
                                      Column(
                                          key: key,
                                          children: [
                                            AbsorbPointer(
                                              absorbing: true,
                                              child: MessageWidget(
                                                newerMessage: null,
                                                olderMessage: null,
                                                isFirstSentMessage: false,
                                                showHandle: true,
                                                showHero: false,
                                                showReplies: false,
                                                autoplayEffect: false,
                                                message: Message(
                                                  guid: "redacted-mode-demo",
                                                  dateDelivered2: DateTime.now().toLocal(),
                                                  dateCreated: DateTime.now().toLocal(),
                                                  isFromMe: false,
                                                  hasReactions: true,
                                                  hasAttachments: true,
                                                  text: "                                ",
                                                  handle: Handle(
                                                    id: Random.secure().nextInt(10000),
                                                    address: "",
                                                  ),
                                                  associatedMessages: [
                                                    Message(
                                                      dateCreated: DateTime.now().toLocal(),
                                                      guid: "redacted-mode-demo",
                                                      text: "Jane Doe liked a message you sent",
                                                      associatedMessageType: "like",
                                                      isFromMe: false,
                                                    ),
                                                  ],
                                                  attachments: [
                                                    Attachment(
                                                      guid: "redacted-mode-demo-attachment",
                                                      originalROWID: Random.secure().nextInt(10000),
                                                      transferName: "assets/images/transparent.png",
                                                      mimeType: "image/png",
                                                      width: 100,
                                                      height: 100,
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  height = (key.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 250;
                                                });
                                                confettiController.play();
                                              },
                                              child: AbsorbPointer(
                                                absorbing: true,
                                                child: MessageWidget(
                                                  newerMessage: null,
                                                  olderMessage: null,
                                                  isFirstSentMessage: false,
                                                  showHandle: false,
                                                  showHero: false,
                                                  showReplies: false,
                                                  autoplayEffect: false,
                                                  message: Message(
                                                    guid: "redacted-mode-demo-2",
                                                    dateDelivered2: DateTime.now().toLocal(),
                                                    dateCreated: DateTime.now().toLocal(),
                                                    isFromMe: true,
                                                    hasReactions: false,
                                                    hasAttachments: false,
                                                    text: "                  ",
                                                    expressiveSendStyleId: "com.apple.messages.effect.CKConfettiEffect",
                                                    handle: Handle(
                                                      id: Random.secure().nextInt(10000),
                                                      address: "",
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          ]
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            FadeTransition(
                              opacity: opacityTitle,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: context.width * 2 / 3,
                                    child: Text(
                                        "Welcome to BlueBubbles",
                                        style: Theme.of(context).textTheme.bodyText1!.apply(
                                          fontSizeFactor: 2.5,
                                          fontWeightDelta: 2,
                                        ).copyWith(height: 1.5)
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            FadeTransition(
                              opacity: opacityTitle,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      "Experience a clean, customizable iMessage client across all platforms.",
                                      style: Theme.of(context).textTheme.bodyText1!.apply(
                                        fontSizeFactor: 1.1,
                                        color: Colors.grey,
                                      ).copyWith(height: 2)
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        FadeTransition(
                          opacity: opacityButton,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
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
                                  maximumSize: MaterialStateProperty.all(Size(200, 36)),
                                ),
                                onPressed: () async {
                                  widget.controller!.nextPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Shimmer.fromColors(
                                  baseColor: Colors.white70,
                                  highlightColor: Colors.white,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 30.0),
                                        child: Text(
                                            "Next",
                                            style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1, color: Colors.white)
                                        ),
                                      ),
                                      Positioned(
                                        left: 40,
                                        child: CustomAnimation<double>(
                                          control: controller,
                                          tween: tween,
                                          duration: Duration(milliseconds: 600),
                                          curve: Curves.easeOut,
                                          builder: (context, _, anim) {
                                            return Padding(
                                              padding: EdgeInsets.only(left: anim),
                                              child: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                            );
                                          },
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
