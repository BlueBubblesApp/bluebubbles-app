import 'dart:io';

import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class CustomConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      debugPrint(line);
      debugPrint("LOGGER " + SettingsManager().debugFile.path);
      SettingsManager()
          .debugFile
          .writeAsStringSync(line + "\n", mode: FileMode.append);
    }
  }
}
