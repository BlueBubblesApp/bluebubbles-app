import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/stateful_wrapper.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/stateless_animation/custom_animation.dart';

class BatteryOptimizationPage extends StatefulWidget {
  BatteryOptimizationPage({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  State<BatteryOptimizationPage> createState() => _BatteryOptimizationPageState();
}

class _BatteryOptimizationPageState extends State<BatteryOptimizationPage> {
  CustomAnimationControl animationController = CustomAnimationControl.mirror;

  Tween<double> tween = Tween<double>(begin: 0, end: 5);

  bool bOptimized = false;

  @override
  void initState() {
    super.initState();
    checkOptimizationStatus();
  }

  void checkOptimizationStatus() async {
    // If battery optimizations are already disabled, go to the next page
    bOptimized = await DisableBatteryOptimization.isBatteryOptimizationDisabled;
    // TODO fix auto next page. Weird error when going back from Mac Setup page
    /*await controller.nextPage(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );*/
    setState(() {});
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
        body: LayoutBuilder(builder: (context, size) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.maxHeight,
              ),
              child: Padding(
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
                              child: Text("Battery Optimization",
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
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                "We recommend disabling battery optimization for BlueBubbles to ensure you receive all your notifications.",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1!
                                    .apply(
                                      fontSizeFactor: 1.1,
                                      color: Colors.grey,
                                    )
                                    .copyWith(height: 2)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 13),
                          child: Align(
                            alignment: Alignment.centerLeft,
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
                                  maximumSize: MaterialStateProperty.all(Size(213, 36)),
                                ),
                                onPressed: () async {
                                  if (!bOptimized) {
                                    await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
                                    setState(() {});
                                    if (await DisableBatteryOptimization.isBatteryOptimizationDisabled) {
                                      bOptimized = true;
                                      setState(() {});
                                    }
                                  } else {
                                    setState(() {});
                                  }
                                },
                                child: Shimmer.fromColors(
                                  baseColor: bOptimized ? Colors.white : Colors.white70,
                                  highlightColor: Colors.white,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      bOptimized
                                          ? Text("Optimized",
                                              style:
                                                  Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1))
                                          : Text("Disable optimization",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText1!
                                                  .apply(fontSizeFactor: 1.1, color: Colors.white)),
                                      SizedBox(width: 10),
                                      bOptimized
                                          ? Icon(Icons.check, color: Colors.white, size: 20)
                                          : Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          padding: EdgeInsets.all(2),
                          child: ElevatedButton(
                            style: ButtonStyle(
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                              backgroundColor: MaterialStateProperty.all(Theme.of(context).backgroundColor),
                              shadowColor: MaterialStateProperty.all(Theme.of(context).backgroundColor),
                              maximumSize: MaterialStateProperty.all(Size(200, 36)),
                            ),
                            onPressed: () async {
                              widget.controller.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyText1!.color, size: 20),
                                SizedBox(width: 10),
                                Text("Back",
                                    style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1)),
                              ],
                            ),
                          ),
                        ),
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
                              maximumSize: MaterialStateProperty.all(Size(200, 36)),
                            ),
                            onPressed: () async {
                              widget.controller.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Shimmer.fromColors(
                              baseColor: bOptimized ? Colors.white70 : Colors.white,
                              highlightColor: Colors.white,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 30.0),
                                    child: Text("Next",
                                        style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                                  ),
                                  Positioned(
                                    left: 40,
                                    child: CustomAnimation<double>(
                                      control: animationController,
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
