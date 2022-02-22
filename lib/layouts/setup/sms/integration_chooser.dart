import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:telephony/telephony.dart';

class IntegrationChooserController extends GetxController {
  final RxInt selectedIntegration = 1.obs;


}

class IntegrationChooser extends StatelessWidget {
  IntegrationChooser({Key? key, required this.controller, required this.onIntegrationSelected}) : super(key: key);
  final PageController controller;
  final void Function(int) onIntegrationSelected;
  final IntegrationChooserController icc = Get.put(IntegrationChooserController());

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
                              child: Text("Choose Integrations",
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
                                "Your choice can always be changed in the app settings.",
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
                      ],
                    ),
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Obx(() => Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: icc.selectedIntegration.value == 1 ? LinearGradient(
                                    begin: AlignmentDirectional.topStart,
                                    colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                  ) : null,
                                ),
                                padding: icc.selectedIntegration.value == 1 ? EdgeInsets.all(1) : null,
                                child: Container(
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10.0),
                                        border: icc.selectedIntegration.value == 1 ? null : Border.all(color: Theme.of(context).colorScheme.secondary),
                                        color: icc.selectedIntegration.value == 1 ? context.theme.backgroundColor : null,
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        icc.selectedIntegration.value = 1;
                                      },
                                      leading: Padding(
                                        padding: const EdgeInsets.only(left: 10.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(CupertinoIcons.conversation_bubble, color: context.theme.textTheme.bodyText1!.color),
                                          ],
                                        ),
                                      ),
                                      title: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("iMessage only", style: context.theme.textTheme.bodyText1!.apply(fontSizeFactor: 1.3)),
                                            SizedBox(height: 5),
                                            Text("Separate your SMS and iMessage chats", style: context.theme.textTheme.subtitle1,)
                                          ],
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.forward,
                                            color: context.theme.textTheme.subtitle1!.color,
                                          ),
                                        ],
                                      ),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                    )
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: icc.selectedIntegration.value == 2 ? LinearGradient(
                                    begin: AlignmentDirectional.topStart,
                                    colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                  ) : null,
                                ),
                                padding: icc.selectedIntegration.value == 2 ? EdgeInsets.all(1) : null,
                                child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10.0),
                                      border: icc.selectedIntegration.value == 2 ? null : Border.all(color: Theme.of(context).colorScheme.secondary),
                                      color: icc.selectedIntegration.value == 2 ? context.theme.backgroundColor : null,
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        icc.selectedIntegration.value = 2;
                                      },
                                      leading: Padding(
                                        padding: const EdgeInsets.only(left: 10.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.sms, color: context.theme.textTheme.bodyText1!.color),
                                          ],
                                        ),
                                      ),
                                      title: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("SMS only", style: context.theme.textTheme.bodyText1!.apply(fontSizeFactor: 1.3)),
                                            SizedBox(height: 5),
                                            Text("Bring the iMessage look to your SMS chats", style: context.theme.textTheme.subtitle1,)
                                          ],
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.forward,
                                            color: context.theme.textTheme.subtitle1!.color,
                                          ),
                                        ],
                                      ),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                    )
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: icc.selectedIntegration.value == 3 ? LinearGradient(
                                    begin: AlignmentDirectional.topStart,
                                    colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                  ) : null,
                                ),
                                padding: icc.selectedIntegration.value == 3 ? EdgeInsets.all(1) : null,
                                child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10.0),
                                      border: icc.selectedIntegration.value == 3 ? null : Border.all(color: Theme.of(context).colorScheme.secondary),
                                      color: icc.selectedIntegration.value == 3 ? context.theme.backgroundColor : null,
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        icc.selectedIntegration.value = 3;
                                      },
                                      leading: Padding(
                                        padding: const EdgeInsets.only(left: 10.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(CupertinoIcons.text_bubble, color: context.theme.textTheme.bodyText1!.color),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                      title: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("iMessage and SMS", style: context.theme.textTheme.bodyText1!.apply(fontSizeFactor: 1.3)),
                                            SizedBox(height: 5),
                                            Text("Get the best of both worlds in one app", style: context.theme.textTheme.subtitle1,)
                                          ],
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.forward,
                                            color: context.theme.textTheme.subtitle1!.color,
                                          ),
                                        ],
                                      ),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                    )
                                ),
                              ),
                            ]
                        )),
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
                              controller.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyText1!.color, size: 20),
                                SizedBox(width: 10),
                                Text("Back", style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1)),
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
                              if (icc.selectedIntegration.value > 1) {
                                final result = await Telephony.instance.requestPhoneAndSmsPermissions;
                                if (result != true) {
                                  showSnackbar("Error", "Phone and SMS permissions are required!");
                                  return;
                                }
                                onIntegrationSelected.call(icc.selectedIntegration.value);
                              }
                              controller.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Next", style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.1, color: Colors.white)),
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
