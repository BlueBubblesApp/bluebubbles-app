import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TestingModeBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TestingModeController>(() => TestingModeController());
  }
}

class TestingModeController extends GetxController {
  final RxString mostRecentReply = "N/A".obs;
}

class TestingMode extends GetView<TestingModeController> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "Testing Mode",
                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(height: 20.0),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "Use the button below to send a test notification.",
                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(height: 20.0),
              ClipOval(
                child: Material(
                  color: Theme.of(context).primaryColor, // button color
                  child: InkWell(
                    child: SizedBox(width: 60, height: 60, child: Icon(Icons.notification_add, color: Colors.white)),
                    onTap: () async {
                      ByteData file = await loadAsset("assets/images/person64.png");
                      Uint8List defaultAvatar = file.buffer.asUint8List();
                      NotificationManager().createNewMessageNotification(
                          "google-play-test-chat",
                          true,
                          "Test",
                          defaultAvatar,
                          "Tester",
                          defaultAvatar,
                          randomString(9),
                          "Testing #${Random().nextInt(9998)}",
                          DateTime.now(),
                          false,
                          Random().nextInt(9998) + 1
                      );
                    },
                  ),
                ),
              ),
              Container(height: 20.0),
              Obx(() => Text("Most recent reply: ${controller.mostRecentReply}")),
            ],
          ),
        ),
      ),
    );
  }

}