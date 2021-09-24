import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: non_constant_identifier_names
BaseLogger Logger = Get.isRegistered<BaseLogger>() ? Get.find<BaseLogger>() : Get.put(BaseLogger());

enum LogLevel { INFO, WARN, ERROR, DEBUG }

extension LogLevelExtension on LogLevel {
  String get value {
    String self = this.toString();
    return self.substring(self.indexOf('.') + 1).toUpperCase();
  }
}

class BaseLogger extends GetxService {
  final RxBool saveLogs = false.obs;
  final int lineLimit = 5000;
  List<String> logs = [];
  List<LogLevel> enabledLevels = [LogLevel.INFO, LogLevel.WARN, LogLevel.DEBUG, LogLevel.ERROR];

  String get logPath {
    String directoryPath = "/storage/emulated/0/Download/BlueBubbles-log-";
    DateTime now = DateTime.now().toLocal();
    return directoryPath + "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}" + ".txt";
  }

  set setEnabledLevels(List<LogLevel> levels) => this.enabledLevels = levels;

  void startSavingLogs() {
    this.saveLogs.value = true;
  }

  Future<void> stopSavingLogs() async {
    this.saveLogs.value = false;

    // Write the log to a file so the user can view/share it
    await this.writeLogToFile();

    // Clear the logs
    this.logs.clear();
  }

  Future<void> writeLogToFile() async {
    // Create the log file and write to it
    if (kIsWeb) {
      final bytes = utf8.encode(logs.join('\n'));
      final content = base64.encode(bytes);
      html.AnchorElement(
          href: "data:application/octet-stream;charset=utf-16le;base64,$content")
        ..setAttribute("download", logPath.split("/").last)
        ..click();
      return;
    }
    String filePath = this.logPath;
    if (kIsDesktop) {
      filePath = (await getDownloadsDirectory())!.path;
      DateTime now = DateTime.now().toLocal();
      filePath += "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}" + ".txt";
    }
    File file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(logs.join('\n'));

    // Show the snackbar when finished
    showSnackbar(
      "Success",
      "Logs exported successfully to downloads folder",
      durationMs: 2500,
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

  void info(dynamic log, {String? tag}) => this._log(LogLevel.INFO, log, tag: tag);
  void warn(dynamic log, {String? tag}) => this._log(LogLevel.WARN, log, tag: tag);
  void debug(dynamic log, {String? tag}) => this._log(LogLevel.DEBUG, log, tag: tag);
  void error(dynamic log, {String? tag}) => this._log(LogLevel.ERROR, log, tag: tag);

  void _log(LogLevel level, dynamic log, {String name = "BlueBubblesApp", String? tag}) {
    if (!this.enabledLevels.contains(level)) return;

    try {
      // Example: [BlueBubblesApp][INFO][2021-01-01 01:01:01.000] (Some Tag) -> <Some log here>
      String theLog = this._buildLog(level, name, tag, log);

      // Log the data normally
      debugPrint(theLog);

      // If we aren't saving logs, return here
      if (!this.saveLogs.value) return;

      // Otherwise, add the log to the list
      logs.add(theLog);

      // Make sure we concatenate to our limit
      if (this.logs.length >= this.lineLimit) {
        // Be safe with it. Make sure we don't go negative or the ranges max < min
        int min = this.logs.length - this.lineLimit;
        int max = this.logs.length;
        if (min < 0) min = 0;
        if (max < min) max = min;

        // Take the last x amount of logs (based on the line limit)
        this.logs = this.logs.sublist(min, max);
      }
    } catch (ex, stacktrace) {
      debugPrint("Failed to write log! ${ex.toString()}");
      debugPrint(stacktrace.toString());
    }
  }

  String _buildLog(LogLevel level, String name, String? tag, dynamic log) {
    final time = DateTime.now().toLocal().toString();
    String theLog = "[$time][${level.value}]";

    // If we have a name, add the name
    if (name.isNotEmpty) {
      theLog = "[$name]$theLog";
    }

    // If we have a tag, add it before the log string
    if (tag != null && tag.isNotEmpty) {
      theLog = "$theLog ($tag) ->";
    }

    return "$theLog ${log.toString()}";
  }
}
