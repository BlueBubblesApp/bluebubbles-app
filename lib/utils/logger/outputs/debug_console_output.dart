import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';


class DebugConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // For "boxed" logs, print them as-is.
    // For not-boxed logs, print them as a single line.
    if ([Level.fatal, Level.error, Level.trace].contains(event.level)) {
      return event.lines.forEach(debugPrint);
    }

    // Pull out and remove the first item (date)
    final date = event.lines.removeAt(0);

    // If it's just a single-line log, print it as a single line.
    // If there are multiple lines, print it as a block.
    if (event.lines.length == 1) {
      debugPrint("$date ${event.lines.first}");
    } else {
      debugPrint("$date ->\n${event.lines.join('\n')}");
    }
  }
}
