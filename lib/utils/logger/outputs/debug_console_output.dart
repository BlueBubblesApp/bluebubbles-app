import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';


class DebugConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    List<String> lines = List.from(event.lines);

    // For "boxed" logs, print them as-is.
    // For not-boxed logs, print them as a single line.
    if ([Level.fatal, Level.error, Level.trace].contains(event.level)) {
      StackTrace? trace = event.origin.stackTrace;
      bool hasTrace = trace != null && trace.toString().isNotEmpty;
      if (!hasTrace) {
        trace = StackTrace.current;
      }

      String traceStr = trace.toString();
      const colorPrefix = (kDebugMode) ? '\x1B[38;5;196m' : '';

      // Only take the last 3 lines of the trace
      if (traceStr.trim().isNotEmpty) {
        // If there is no trace, (so we are using the current trace),
        // we need to omit the first 5 lines of the trace, as they are
        // part of the logger itself.
        List<String> traceLines = traceStr.split('\n').where((txt) => txt != '<asynchronous suspension>').toList();
        traceStr = traceLines.map((e) => '$colorPrefix| $e').join('\n');

        // Insert the trace into the box
        lines.insert(lines.length - 1, '$colorPrefix|');
        lines.insert(lines.length - 1, '$colorPrefix| Traceback:');
        lines.insert(lines.length - 1, '$colorPrefix$traceStr');
      }

      // Add the level to the date entry
      lines[1] = '$colorPrefix${lines[1]} $colorPrefix[${event.level.name.toUpperCase()}]';
      return lines.forEach(debugPrint);
    }

    // Pull out and remove the first item (date)
    final date = lines.removeAt(0);

    // If it's just a single-line log, print it as a single line.
    // If there are multiple lines, print it as a block.
    if (lines.length == 1) {
      debugPrint("$date [${event.level.name.toUpperCase()}] ${lines.first}");
    } else {
      debugPrint("$date [${event.level.name.toUpperCase()}] ->\n${lines.join('\n')}");
    }
  }
}
