import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/stateless_animation/custom_animation.dart';

class RequestContacts extends StatefulWidget {
  RequestContacts({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  State<RequestContacts> createState() => _RequestContactsState();
}

class _RequestContactsState extends State<RequestContacts> {
  CustomAnimationControl controller = CustomAnimationControl.mirror;
  Tween<double> tween = Tween<double>(begin: 0, end: 5);

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
                              child: Text("Contacts Permission",
                                  style: context.theme.textTheme.displaySmall!.apply(
                                        fontWeightDelta: 2,
                                      ).copyWith(height: 1.35, color: context.theme.colorScheme.onBackground)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("We'd like to access your contacts to show contact info in the app.",
                                style: context.theme.textTheme.bodyLarge!.apply(
                                  fontSizeDelta: 1.5,
                                  color: context.theme.colorScheme.outline,
                                ).copyWith(height: 2)
                            ),
                          ),
                        ),
                        FutureBuilder<PermissionStatus>(
                          future: Permission.contacts.status,
                          initialData: PermissionStatus.denied,
                          builder: (context, snapshot) {
                            bool granted = snapshot.data! == PermissionStatus.granted;
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Permission Status: ${granted ? "Granted" : "Denied"}",
                                    style: context.theme.textTheme.bodyLarge!.apply(
                                      fontSizeDelta: 1.5,
                                      color: granted ? Colors.green : context.theme.colorScheme.error,
                                    ).copyWith(height: 2)),
                              ),
                            );
                          },
                        )
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
                              widget.controller.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, color: context.theme.colorScheme.onBackground, size: 20),
                                SizedBox(width: 10),
                                Text("Back", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
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
                              if (!(await ContactManager().canAccessContacts())) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text(
                                        "Notice",
                                        style: context.theme.textTheme.titleLarge,
                                      ),
                                      backgroundColor: context.theme.colorScheme.properSurface,
                                      content: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                            "We weren't able to access your contacts.\n\nAre you sure you want to proceed without contacts?",
                                            style: context.theme.textTheme.bodyLarge),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            continueToNextPage();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                continueToNextPage();
                              }
                            },
                            child: Shimmer.fromColors(
                              baseColor: Colors.white70,
                              highlightColor: Colors.white,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 30.0),
                                    child: Text("Next",
                                        style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
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

  void continueToNextPage() {
    widget.controller.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
