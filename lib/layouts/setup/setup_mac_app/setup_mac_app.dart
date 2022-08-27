import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class SetupMacApp extends StatelessWidget {
  SetupMacApp({Key? key, required this.controller}) : super(key: key);
  final PageController controller;
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
                              child: Text("Setup Check",
                                  style: context.theme.textTheme.displayMedium!.apply(
                                    fontWeightDelta: 2,
                                  ).copyWith(height: 1.35, color: context.theme.colorScheme.onBackground)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                "Please ensure you have set up the BlueBubbles Server on macOS before proceeding.\n\nAdditionally, please ensure iMessage is signed into your Apple ID on macOS.",
                                style: context.theme.textTheme.bodyLarge!.apply(
                              fontSizeDelta: 1.5,
                              color: context.theme.colorScheme.outline,
                            ).copyWith(height: 2)),
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
                                  maximumSize: MaterialStateProperty.all(Size(300, 36)),
                                  minimumSize: MaterialStateProperty.all(Size(30, 30)),
                                ),
                                onPressed: () async {
                                  await launchUrl(Uri(scheme: "https", host: "bluebubbles.app", path: "install"));
                                },
                                child: Shimmer.fromColors(
                                  baseColor: Colors.white70,
                                  highlightColor: Colors.white,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          "Server setup instructions",
                                          style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)
                                      ),
                                      SizedBox(width: 10),
                                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
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
                              backgroundColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                              shadowColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                              maximumSize: MaterialStateProperty.all(Size(200, 36)),
                              minimumSize: MaterialStateProperty.all(Size(30, 30)),
                            ),
                            onPressed: () async {
                              controller.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back,
                                    color: context.theme.colorScheme.onBackground, size: 20),
                                SizedBox(width: 10),
                                Text("Back",
                                    style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
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
                              minimumSize: MaterialStateProperty.all(Size(30, 30)),
                            ),
                            onPressed: () async {
                              controller.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Next", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              ],
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
