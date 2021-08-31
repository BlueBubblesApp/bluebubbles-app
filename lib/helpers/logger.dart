import 'dart:io';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Logger extends GetxService {
  final RxBool logToTxt = false.obs;
  String txtLog = "";

  static Logger get instance {
    if (Get.isRegistered<Logger>()) {
      return Get.find<Logger>();
    } else {
      return Get.put(Logger());
    }
  }

  Future<void> endTxtLogging() async {
    String directoryPath = "/storage/emulated/0/Download/BlueBubbles-log-";
    DateTime now = DateTime.now().toLocal();
    String filePath = directoryPath + "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}" + ".txt";
    File file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(txtLog);
    showSnackbar(
      "Success",
      "Logs exported successfully to downloads folder",
      durationMs: 2000,
      button: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Get.theme.accentColor,
        ),
        onPressed: () {
          Share.file("BlueBubbles Logs", filePath);
        },
        child: Text("SHARE", style: TextStyle(color: Theme.of(Get.context!).primaryColor)),
      ),
    );
  }

  void log(dynamic log, {String title = "[BlueBubblesApp]"}) {
    debugPrint(title + " " + log.toString());
    if (logToTxt.value) {
      txtLog = txtLog + title + " " + log.toString() + "\n";
      if ("\n".allMatches(txtLog).length >= 5000) {
        logToTxt.value = false;
        endTxtLogging();
      }
    }
  }
}